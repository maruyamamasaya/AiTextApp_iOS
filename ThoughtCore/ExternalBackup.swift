import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct BackupManifest: Codable, Equatable, Sendable {
    public struct FileEntry: Codable, Equatable, Sendable {
        public let path: String
        public let size: UInt64
        public let sha256: String?
    }

    public let backupFormatVersion: Int
    public let createdAt: Date
    public let appVersion: String
    public let buildVersion: String
    public let sqliteUserVersion: Int32
    public let databaseFileName: String
    public let databaseFileSize: UInt64
    public let files: [FileEntry]

    public init(backupFormatVersion: Int = 1, createdAt: Date, appVersion: String,
                buildVersion: String, sqliteUserVersion: Int32, databaseFileName: String,
                databaseFileSize: UInt64, files: [FileEntry]) {
        self.backupFormatVersion = backupFormatVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.sqliteUserVersion = sqliteUserVersion
        self.databaseFileName = databaseFileName
        self.databaseFileSize = databaseFileSize
        self.files = files
    }
}

public enum ExternalBackupError: Error, LocalizedError, Equatable {
    case inaccessibleDestination
    case invalidManifest
    case unsupportedFormat(Int)
    case unsafePath
    case symbolicLink
    case missingDatabase
    case sizeMismatch
    case checksumMismatch
    case invalidSQLite(String)
    case unsupportedSchema(Int32)
    case noPendingRestore
    case fileOperation(String)

    public var errorDescription: String? {
        switch self {
        case .inaccessibleDestination: "バックアップ保存先へアクセスできません。"
        case .invalidManifest: "manifest.jsonが不正です。"
        case .unsupportedFormat(let version): "未対応のバックアップ形式です（v\(version)）。"
        case .unsafePath: "バックアップに安全でないパスが含まれています。"
        case .symbolicLink: "バックアップにシンボリックリンクが含まれています。"
        case .missingDatabase: "SQLiteバックアップがありません。"
        case .sizeMismatch: "SQLiteバックアップのサイズがmanifestと一致しません。"
        case .checksumMismatch: "SQLiteバックアップのSHA-256が一致しません。"
        case .invalidSQLite(let message): "SQLiteバックアップが不正です: \(message)"
        case .unsupportedSchema(let version): "未対応のSQLite schemaです（v\(version)）。"
        case .noPendingRestore: "適用待ちのRestoreがありません。"
        case .fileOperation(let message): "バックアップファイル操作に失敗しました: \(message)"
        }
    }
}

public final class ExternalBackupService: @unchecked Sendable {
    public static let databaseFileName = "thought-timeline.sqlite3"
    public static let manifestFileName = "manifest.json"
    public static let formatVersion = 1

    private let repository: SQLiteThoughtRepository
    private let fileManager: FileManager
    private let appVersion: String
    private let buildVersion: String
    private let now: () -> Date

    public init(repository: SQLiteThoughtRepository, fileManager: FileManager = .default,
                appVersion: String, buildVersion: String, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.fileManager = fileManager
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.now = now
    }

    @discardableResult
    public func createBackup(in selectedFolder: URL) throws -> BackupManifest {
        guard selectedFolder.isFileURL else { throw ExternalBackupError.inaccessibleDestination }
        let root = selectedFolder.appendingPathComponent("AiText Backup", isDirectory: true)
        let transaction = root.appendingPathComponent(".new-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = transaction.appendingPathComponent(Self.databaseFileName)
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try rejectSymbolicLink(root)
            try fileManager.createDirectory(at: transaction, withIntermediateDirectories: false)
            try repository.createSnapshot(at: databaseURL)
            let inspected = try Self.inspectSQLite(at: databaseURL)
            let size = try Self.fileSize(at: databaseURL, fileManager: fileManager)
            let hash = try Self.sha256(at: databaseURL)
            let manifest = BackupManifest(
                createdAt: now(), appVersion: appVersion, buildVersion: buildVersion,
                sqliteUserVersion: inspected, databaseFileName: Self.databaseFileName,
                databaseFileSize: size,
                files: [.init(path: Self.databaseFileName, size: size, sha256: hash)]
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: transaction.appendingPathComponent(Self.manifestFileName), options: .atomic)
            _ = try Self.validateBackup(at: transaction, maximumSchemaVersion: SQLiteThoughtRepository.schemaVersion, fileManager: fileManager)
            try rotate(transaction: transaction, root: root)
            return manifest
        } catch let error as ExternalBackupError {
            try? fileManager.removeItem(at: transaction)
            throw error
        } catch {
            try? fileManager.removeItem(at: transaction)
            throw ExternalBackupError.fileOperation(String(describing: error))
        }
    }

    public static func validateBackup(at generation: URL, maximumSchemaVersion: Int32,
                                      fileManager: FileManager = .default) throws -> BackupManifest {
        guard generation.isFileURL else { throw ExternalBackupError.unsafePath }
        try rejectSymbolicLinkStatic(generation, fileManager: fileManager)
        let manifestURL = generation.appendingPathComponent(manifestFileName)
        try rejectSymbolicLinkStatic(manifestURL, fileManager: fileManager)
        let manifest: BackupManifest
        do {
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            manifest = try decoder.decode(BackupManifest.self, from: Data(contentsOf: manifestURL))
        } catch { throw ExternalBackupError.invalidManifest }
        guard manifest.backupFormatVersion == formatVersion else { throw ExternalBackupError.unsupportedFormat(manifest.backupFormatVersion) }
        guard isSafeSingleComponent(manifest.databaseFileName), manifest.databaseFileName == databaseFileName else { throw ExternalBackupError.unsafePath }
        guard manifest.files.count == 1, manifest.files[0].path == manifest.databaseFileName,
              isSafeSingleComponent(manifest.files[0].path) else { throw ExternalBackupError.unsafePath }
        let databaseURL = generation.appendingPathComponent(manifest.databaseFileName)
        guard fileManager.fileExists(atPath: databaseURL.path) else { throw ExternalBackupError.missingDatabase }
        try rejectSymbolicLinkStatic(databaseURL, fileManager: fileManager)
        let size = try fileSize(at: databaseURL, fileManager: fileManager)
        guard size > 0, size == manifest.databaseFileSize, size == manifest.files[0].size else { throw ExternalBackupError.sizeMismatch }
        if let expected = manifest.files[0].sha256, try sha256(at: databaseURL) != expected { throw ExternalBackupError.checksumMismatch }
        let schema = try inspectSQLite(at: databaseURL)
        guard schema == manifest.sqliteUserVersion, schema <= maximumSchemaVersion else { throw ExternalBackupError.unsupportedSchema(schema) }
        return manifest
    }

    private func rotate(transaction: URL, root: URL) throws {
        let latest = root.appendingPathComponent("latest", isDirectory: true)
        let previous = root.appendingPathComponent("previous", isDirectory: true)
        let savedLatest = root.appendingPathComponent(".saved-latest-\(UUID().uuidString)", isDirectory: true)
        let savedPrevious = root.appendingPathComponent(".saved-previous-\(UUID().uuidString)", isDirectory: true)
        var latestWasMoved = false
        var newLatestInstalled = false
        do {
            if fileManager.fileExists(atPath: latest.path) {
                try fileManager.moveItem(at: latest, to: savedLatest); latestWasMoved = true
            }
            try fileManager.moveItem(at: transaction, to: latest); newLatestInstalled = true
            if fileManager.fileExists(atPath: previous.path) { try fileManager.moveItem(at: previous, to: savedPrevious) }
            if latestWasMoved { try fileManager.moveItem(at: savedLatest, to: previous) }
            try? fileManager.removeItem(at: savedPrevious)
        } catch {
            if newLatestInstalled { try? fileManager.removeItem(at: latest) }
            if latestWasMoved { try? fileManager.moveItem(at: savedLatest, to: latest) }
            if fileManager.fileExists(atPath: savedPrevious.path), !fileManager.fileExists(atPath: previous.path) {
                try? fileManager.moveItem(at: savedPrevious, to: previous)
            }
            throw error
        }
    }

    private func rejectSymbolicLink(_ url: URL) throws { try Self.rejectSymbolicLinkStatic(url, fileManager: fileManager) }
    private static func rejectSymbolicLinkStatic(_ url: URL, fileManager: FileManager) throws {
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw ExternalBackupError.symbolicLink }
    }
    private static func isSafeSingleComponent(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\") && URL(fileURLWithPath: value).lastPathComponent == value
    }
    private static func fileSize(at url: URL, fileManager: FileManager) throws -> UInt64 {
        guard let value = try fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber else { throw ExternalBackupError.sizeMismatch }
        return value.uint64Value
    }
    fileprivate static func inspectSQLite(at url: URL) throws -> Int32 {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }; throw ExternalBackupError.invalidSQLite("open failed")
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA integrity_check", -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ExternalBackupError.invalidSQLite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0), String(cString: text) == "ok" else {
            throw ExternalBackupError.invalidSQLite("integrity_check failed")
        }
        var versionStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &versionStatement, nil) == SQLITE_OK, let versionStatement else {
            throw ExternalBackupError.invalidSQLite("user_version unavailable")
        }
        defer { sqlite3_finalize(versionStatement) }
        guard sqlite3_step(versionStatement) == SQLITE_ROW else { throw ExternalBackupError.invalidSQLite("user_version unavailable") }
        return sqlite3_column_int(versionStatement, 0)
    }
    private static func sha256(at url: URL) throws -> String? {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return nil
        #endif
    }
}

public enum RestoreCoordinator {
    public static let pendingDirectoryName = "RestorePending"
    private static let markerName = "restore-pending.json"

    public static func stageRestore(from generation: URL, applicationSupportDirectory: URL,
                                    fileManager: FileManager = .default) throws -> BackupManifest {
        let manifest = try ExternalBackupService.validateBackup(at: generation, maximumSchemaVersion: SQLiteThoughtRepository.schemaVersion, fileManager: fileManager)
        let pending = applicationSupportDirectory.appendingPathComponent(pendingDirectoryName, isDirectory: true)
        let candidate = pending.appendingPathComponent("candidate", isDirectory: true)
        let staging = applicationSupportDirectory.appendingPathComponent(".restore-stage-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
            try fileManager.copyItem(at: generation.appendingPathComponent(ExternalBackupService.databaseFileName), to: staging.appendingPathComponent(ExternalBackupService.databaseFileName))
            try fileManager.copyItem(at: generation.appendingPathComponent(ExternalBackupService.manifestFileName), to: staging.appendingPathComponent(ExternalBackupService.manifestFileName))
            _ = try ExternalBackupService.validateBackup(at: staging, maximumSchemaVersion: SQLiteThoughtRepository.schemaVersion, fileManager: fileManager)
            if fileManager.fileExists(atPath: pending.path) { try fileManager.removeItem(at: pending) }
            try fileManager.createDirectory(at: pending, withIntermediateDirectories: false)
            try fileManager.moveItem(at: staging, to: candidate)
            try Data("pending".utf8).write(to: pending.appendingPathComponent(markerName), options: .atomic)
            return manifest
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    @discardableResult
    public static func applyPendingRestoreIfNeeded(databaseURL: URL, applicationSupportDirectory: URL,
                                                   fileManager: FileManager = .default) throws -> Bool {
        let pending = applicationSupportDirectory.appendingPathComponent(pendingDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: pending.appendingPathComponent(markerName).path) else { return false }
        let candidate = pending.appendingPathComponent("candidate", isDirectory: true)
        _ = try ExternalBackupService.validateBackup(at: candidate, maximumSchemaVersion: SQLiteThoughtRepository.schemaVersion, fileManager: fileManager)
        let incoming = candidate.appendingPathComponent(ExternalBackupService.databaseFileName)
        let canonicalFiles = [databaseURL, URL(fileURLWithPath: databaseURL.path + "-wal"), URL(fileURLWithPath: databaseURL.path + "-shm")]
        let rollbackFiles = canonicalFiles.enumerated().map { index, _ in
            databaseURL.deletingLastPathComponent().appendingPathComponent(".restore-rollback-\(index)")
        }
        for url in rollbackFiles { try? fileManager.removeItem(at: url) }
        var movedIndexes: [Int] = []
        do {
            try fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            for (index, url) in canonicalFiles.enumerated() where fileManager.fileExists(atPath: url.path) {
                try fileManager.moveItem(at: url, to: rollbackFiles[index])
                movedIndexes.append(index)
            }
            try fileManager.moveItem(at: incoming, to: databaseURL)
            let installedSchema = try ExternalBackupService.inspectSQLite(at: databaseURL)
            guard installedSchema <= SQLiteThoughtRepository.schemaVersion else { throw ExternalBackupError.unsupportedSchema(installedSchema) }
            for url in rollbackFiles { try? fileManager.removeItem(at: url) }
            try fileManager.removeItem(at: pending)
            return true
        } catch {
            try? fileManager.removeItem(at: databaseURL)
            for index in movedIndexes where fileManager.fileExists(atPath: rollbackFiles[index].path) {
                try? fileManager.moveItem(at: rollbackFiles[index], to: canonicalFiles[index])
            }
            throw error
        }
    }
}
