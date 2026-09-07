import Combine
import Foundation

@MainActor
final class ExternalBackupManager: ObservableObject {
    private static let bookmarkKey = "externalBackupFolderBookmark.v1"
    private static let lastBackupKey = "externalBackupLastCreatedAt.v1"

    @Published private(set) var destinationName: String?
    @Published private(set) var destinationAvailable = false
    @Published private(set) var lastBackupAt: Date?
    @Published var restoreCandidate: RestoreCandidate?
    @Published var message: String?

    struct RestoreCandidate: Identifiable {
        let id = UUID()
        let generationURL: URL
        let accessURL: URL
        let manifest: BackupManifest
    }

    private let service: ExternalBackupService
    private let applicationSupportDirectory: URL
    private let defaults: UserDefaults
    private var bookmarkData: Data?

    init(repository: SQLiteThoughtRepository, fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let info = Bundle.main.infoDictionary ?? [:]
        service = ExternalBackupService(
            repository: repository,
            fileManager: fileManager,
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            buildVersion: info["CFBundleVersion"] as? String ?? "unknown"
        )
        applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        bookmarkData = defaults.data(forKey: Self.bookmarkKey)
        lastBackupAt = defaults.object(forKey: Self.lastBackupKey) as? Date
        refreshDestinationStatus()
    }

    func selectDestination(_ url: URL) {
        do {
            let data = try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: Self.bookmarkKey)
            bookmarkData = data
            destinationName = url.lastPathComponent
            destinationAvailable = true
        } catch {
            message = "保存先を記憶できませんでした。"
        }
    }

    func createBackup() {
        do {
            try withDestination { url in
                let manifest = try service.createBackup(in: url)
                lastBackupAt = manifest.createdAt
                defaults.set(manifest.createdAt, forKey: Self.lastBackupKey)
            }
            message = "外部バックアップを作成しました。"
        } catch { message = error.localizedDescription }
    }

    func prepareRestoreSelection(_ selectedURL: URL) {
        do {
            let accessing = selectedURL.startAccessingSecurityScopedResource()
            defer { if accessing { selectedURL.stopAccessingSecurityScopedResource() } }
            let generation = restoreGeneration(in: selectedURL)
            let manifest = try ExternalBackupService.validateBackup(at: generation, maximumSchemaVersion: SQLiteThoughtRepository.schemaVersion)
            restoreCandidate = RestoreCandidate(generationURL: generation, accessURL: selectedURL, manifest: manifest)
        } catch { message = error.localizedDescription }
    }

    func confirmRestore() {
        guard let candidate = restoreCandidate else { return }
        do {
            let accessing = candidate.accessURL.startAccessingSecurityScopedResource()
            defer { if accessing { candidate.accessURL.stopAccessingSecurityScopedResource() } }
            _ = try RestoreCoordinator.stageRestore(
                from: candidate.generationURL,
                applicationSupportDirectory: applicationSupportDirectory
            )
            restoreCandidate = nil
            message = "Restoreを準備しました。アプリを終了し、もう一度起動すると適用されます。"
        } catch { message = error.localizedDescription }
    }

    func cancelRestore() { restoreCandidate = nil }

    func refreshDestinationStatus() {
        guard let bookmarkData else {
            destinationName = nil; destinationAvailable = false; return
        }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale { selectDestination(url) }
            destinationName = url.lastPathComponent
            let accessing = url.startAccessingSecurityScopedResource()
            destinationAvailable = accessing && FileManager.default.isWritableFile(atPath: url.path)
            if accessing { url.stopAccessingSecurityScopedResource() }
        } catch { destinationAvailable = false }
    }

    private func withDestination<T>(_ body: (URL) throws -> T) throws -> T {
        guard let bookmarkData else { throw ExternalBackupError.inaccessibleDestination }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale { selectDestination(url) }
        guard url.startAccessingSecurityScopedResource() else { throw ExternalBackupError.inaccessibleDestination }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body(url)
    }

    private func restoreGeneration(in selected: URL) -> URL {
        if selected.lastPathComponent == "latest" || selected.lastPathComponent == "previous" { return selected }
        if selected.lastPathComponent == "AiText Backup" { return selected.appendingPathComponent("latest", isDirectory: true) }
        return selected.appendingPathComponent("AiText Backup/latest", isDirectory: true)
    }
}
