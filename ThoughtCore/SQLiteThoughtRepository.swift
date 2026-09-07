import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

public enum SQLiteThoughtRepositoryError: Error, LocalizedError, Equatable {
    case open(String)
    case database(String)
    case invalidRecord
    case migration(String)

    public var errorDescription: String? {
        switch self {
        case .open(let message): "SQLiteを開けませんでした: \(message)"
        case .database(let message): "SQLite操作に失敗しました: \(message)"
        case .invalidRecord: "SQLite内のThoughtデータが不正です。"
        case .migration(let message): "JSON migrationに失敗しました: \(message)"
        }
    }
}

public final class SQLiteThoughtRepository: ThoughtRepository, @unchecked Sendable {
    public static let schemaVersion: Int32 = 1

    private let databaseURL: URL
    private let legacyJSONURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private var database: OpaquePointer?

    public convenience init(fileManager: FileManager = .default) throws {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = baseURL.appendingPathComponent("ThoughtTimeline", isDirectory: true)
        try self.init(
            databaseURL: directory.appendingPathComponent("thought-timeline.sqlite3"),
            legacyJSONURL: directory.appendingPathComponent("thoughts.json"),
            fileManager: fileManager
        )
    }

    public init(databaseURL: URL, legacyJSONURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.databaseURL = databaseURL
        self.legacyJSONURL = legacyJSONURL
            ?? databaseURL.deletingLastPathComponent().appendingPathComponent("thoughts.json")
        self.fileManager = fileManager

        do {
            try fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try open()
            try configureAndMigrateSchema()
            try migrateLegacyJSONIfNeeded()
            createRollingBackupIfPossible()
        } catch {
            if let database { sqlite3_close(database) }
            database = nil
            NSLog("Thought database initialization failed: %@", String(describing: error))
            throw error
        }
    }

    deinit { if let database { sqlite3_close(database) } }

    public func create(_ thought: Thought) throws {
        try lock.withLock {
            try executeThoughtInsert(thought, conflictClause: "")
            createRollingBackupIfPossible()
        }
    }

    public func fetchTimeline() throws -> [Thought] {
        try lock.withLock {
            try query("""
                SELECT id, body, created_at, updated_at, deleted_at
                FROM thoughts WHERE deleted_at IS NULL
                ORDER BY created_at DESC, id DESC
                """)
        }
    }

    public func fetchByID(_ id: UUID) throws -> Thought? {
        try lock.withLock {
            let values = try query("""
                SELECT id, body, created_at, updated_at, deleted_at
                FROM thoughts WHERE id = ? LIMIT 1
                """, bind: { statement in
                    try self.bind(id.uuidString, to: 1, in: statement)
                })
            return values.first
        }
    }

    public func fetchAll() throws -> [Thought] {
        try lock.withLock {
            try query("""
                SELECT id, body, created_at, updated_at, deleted_at
                FROM thoughts ORDER BY created_at DESC, id DESC
                """)
        }
    }

    public func softDelete(id: UUID, at date: Date) throws -> Bool {
        try lock.withLock {
            let statement = try prepare("UPDATE thoughts SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL")
            defer { sqlite3_finalize(statement) }
            try bind(date.timeIntervalSince1970, to: 1, in: statement)
            try bind(date.timeIntervalSince1970, to: 2, in: statement)
            try bind(id.uuidString, to: 3, in: statement)
            try stepDone(statement)
            let changed = sqlite3_changes(database) > 0
            if changed { createRollingBackupIfPossible() }
            return changed
        }
    }

    /// Keeps two SQLite-native snapshots beside the canonical database. Backup
    /// errors are logged but never turn an already successful post/delete into a
    /// user-visible failure.
    private func createRollingBackupIfPossible() {
        guard let database else { return }
        let olderURL = databaseURL.appendingPathExtension("backup.2")
        let latestURL = databaseURL.appendingPathExtension("backup.1")
        let temporaryURL = databaseURL.appendingPathExtension("backup.tmp")
        try? fileManager.removeItem(at: temporaryURL)

        var destination: OpaquePointer?
        guard sqlite3_open_v2(temporaryURL.path, &destination, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let destination else {
            if let destination { sqlite3_close(destination) }
            NSLog("Thought database backup could not be opened")
            return
        }
        defer { sqlite3_close(destination) }

        guard let backup = sqlite3_backup_init(destination, "main", database, "main") else {
            NSLog("Thought database backup could not start: %@", String(cString: sqlite3_errmsg(destination)))
            return
        }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else {
            try? fileManager.removeItem(at: temporaryURL)
            NSLog("Thought database backup failed")
            return
        }

        do {
            try? fileManager.removeItem(at: olderURL)
            if fileManager.fileExists(atPath: latestURL.path) {
                try fileManager.moveItem(at: latestURL, to: olderURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: latestURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            NSLog("Thought database backup rotation failed: %@", String(describing: error))
        }
    }

    private func open() throws {
        var connection: OpaquePointer?
        let result = sqlite3_open_v2(databaseURL.path, &connection, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        guard result == SQLITE_OK, let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let connection { sqlite3_close(connection) }
            throw SQLiteThoughtRepositoryError.open(message)
        }
        database = connection
    }

    private func configureAndMigrateSchema() throws {
        try execute("PRAGMA foreign_keys = ON")
        let version = try scalarInt("PRAGMA user_version")
        guard version <= Self.schemaVersion else {
            throw SQLiteThoughtRepositoryError.database("unsupported schema version \(version)")
        }
        if version == 0 {
            try transaction {
                try execute("""
                    CREATE TABLE IF NOT EXISTS thoughts (
                        id TEXT PRIMARY KEY NOT NULL,
                        body TEXT NOT NULL,
                        created_at REAL NOT NULL,
                        updated_at REAL NOT NULL,
                        deleted_at REAL NULL
                    )
                    """)
                try execute("CREATE INDEX IF NOT EXISTS thoughts_timeline_idx ON thoughts(deleted_at, created_at DESC, id DESC)")
                try execute("CREATE TABLE IF NOT EXISTS migrations (name TEXT PRIMARY KEY NOT NULL, completed_at REAL NOT NULL)")
                try execute("PRAGMA user_version = 1")
            }
        }
    }

    private func migrateLegacyJSONIfNeeded() throws {
        guard try !migrationCompleted("legacy_json_v1") else { return }
        guard fileManager.fileExists(atPath: legacyJSONURL.path) else {
            try markMigrationCompleted("legacy_json_v1")
            return
        }

        let thoughts: [Thought]
        do {
            let data = try Data(contentsOf: legacyJSONURL)
            thoughts = try Self.jsonDecoder.decode([Thought].self, from: data)
        } catch {
            throw SQLiteThoughtRepositoryError.migration(String(describing: error))
        }

        do {
            try transaction {
                for thought in thoughts { try executeThoughtInsert(thought, conflictClause: "OR IGNORE") }
                for thought in thoughts {
                    guard try queryByID(thought.id) == thought else {
                        throw SQLiteThoughtRepositoryError.migration("import verification failed for \(thought.id)")
                    }
                }
                try insertMigrationMarker("legacy_json_v1")
            }
        } catch {
            // The transaction rolls back and the source JSON is intentionally never removed.
            throw SQLiteThoughtRepositoryError.migration(String(describing: error))
        }
    }

    private func migrationCompleted(_ name: String) throws -> Bool {
        let statement = try prepare("SELECT 1 FROM migrations WHERE name = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        try bind(name, to: 1, in: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW || result == SQLITE_DONE else { throw lastError() }
        return result == SQLITE_ROW
    }

    private func markMigrationCompleted(_ name: String) throws {
        try transaction { try insertMigrationMarker(name) }
    }

    private func insertMigrationMarker(_ name: String) throws {
        let statement = try prepare("INSERT OR IGNORE INTO migrations(name, completed_at) VALUES (?, ?)")
        defer { sqlite3_finalize(statement) }
        try bind(name, to: 1, in: statement)
        try bind(Date().timeIntervalSince1970, to: 2, in: statement)
        try stepDone(statement)
    }

    private func executeThoughtInsert(_ thought: Thought, conflictClause: String) throws {
        let statement = try prepare("INSERT \(conflictClause) INTO thoughts(id, body, created_at, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?)")
        defer { sqlite3_finalize(statement) }
        try bind(thought.id.uuidString, to: 1, in: statement)
        try bind(thought.body, to: 2, in: statement)
        try bind(thought.createdAt.timeIntervalSince1970, to: 3, in: statement)
        try bind(thought.updatedAt.timeIntervalSince1970, to: 4, in: statement)
        if let deletedAt = thought.deletedAt {
            try bind(deletedAt.timeIntervalSince1970, to: 5, in: statement)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        try stepDone(statement)
    }

    private func queryByID(_ id: UUID) throws -> Thought? {
        try query("SELECT id, body, created_at, updated_at, deleted_at FROM thoughts WHERE id = ? LIMIT 1", bind: {
            try self.bind(id.uuidString, to: 1, in: $0)
        }).first
    }

    private func query(_ sql: String, bind binder: (OpaquePointer) throws -> Void = { _ in }) throws -> [Thought] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try binder(statement)
        var output: [Thought] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0),
                  let bodyText = sqlite3_column_text(statement, 1),
                  let id = UUID(uuidString: String(cString: idText)) else {
                throw SQLiteThoughtRepositoryError.invalidRecord
            }
            output.append(Thought(
                id: id,
                body: String(cString: bodyText),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                deletedAt: sqlite3_column_type(statement, 4) == SQLITE_NULL
                    ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            ))
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw lastError() }
        return output
    }

    private func scalarInt(_ sql: String) throws -> Int32 {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw lastError() }
        return sqlite3_column_int(statement, 0)
    }

    private func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try work()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteThoughtRepositoryError.database(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw lastError() }
        return statement
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else { throw lastError() }
    }

    private func bind(_ value: Double, to index: Int32, in statement: OpaquePointer) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else { throw lastError() }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else { throw lastError() }
    }

    private func lastError() -> SQLiteThoughtRepositoryError {
        .database(database.map { String(cString: sqlite3_errmsg($0)) } ?? "database is closed")
    }

    private static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
