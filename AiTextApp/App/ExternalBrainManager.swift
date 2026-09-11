import Combine
import Foundation
import Security
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GitHubExternalBrainRemote: ExternalBrainRemote {
    private struct TreeResponse: Decodable { struct Item: Decodable { let path, type: String; let sha: String }; let tree: [Item] }
    func listMarkdownFiles(configuration: ExternalBrainRepositoryConfiguration, token: String) async throws -> [ExternalBrainRemoteFile] {
        let branch = configuration.branch.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? configuration.branch
        let url = try apiURL("repos/\(configuration.owner)/\(configuration.repository)/git/trees/\(branch)?recursive=1")
        let data = try await request(url, token: token)
        return try JSONDecoder().decode(TreeResponse.self, from: data).tree.filter { $0.type == "blob" && $0.path.lowercased().hasSuffix(".md") }.map { ExternalBrainRemoteFile(path: $0.path, sha: $0.sha) }
    }
    func download(path: String, configuration: ExternalBrainRepositoryConfiguration, token: String) async throws -> Data {
        guard ExternalBrainPath.isSafe(path) else { throw ExternalBrainError.unsafePath(path) }
        let encoded = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        let ref = configuration.branch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? configuration.branch
        return try await request(try apiURL("repos/\(configuration.owner)/\(configuration.repository)/contents/\(encoded)?ref=\(ref)"), token: token, accept: "application/vnd.github.raw+json")
    }
    private func apiURL(_ path: String) throws -> URL { guard let url = URL(string: "https://api.github.com/\(path)") else { throw ExternalBrainError.remote("URL") }; return url }
    private func request(_ url: URL, token: String, accept: String = "application/vnd.github+json") async throws -> Data {
        var request = URLRequest(url: url); request.httpMethod = "GET"; request.timeoutInterval = 30
        request.setValue(accept, forHTTPHeaderField: "Accept"); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ExternalBrainError.remote("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)") }
        return data
    }
}

enum ExternalBrainTokenStore {
    private static let service = "AiTextApp.ExternalBrain.GitHub"
    static func save(_ token: String) throws {
        let data = Data(token.utf8); let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ExternalBrainError.remote("Keychain") }
    }
    static func load() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }; return String(data: data, encoding: .utf8)
    }
    static func remove() { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary) }
}

@MainActor
final class ExternalBrainManager: ObservableObject {
    @Published var repository: ExternalBrainRepositoryConfiguration { didSet { persist() } }
    @Published var personaConfigurations: [UUID: PersonaExternalBrainConfiguration] { didSet { persist() } }
    @Published private(set) var manifest = ExternalBrainManifest()
    @Published private(set) var isSyncing = false
    @Published var message: String?
    private let defaults: UserDefaults
    private let cache: ExternalBrainCache?
    private let remote: any ExternalBrainRemote
    private let repositoryKey = "externalBrain.repository.v1", personaKey = "externalBrain.personas.v1"

    init(rootURL: URL, defaults: UserDefaults = .standard, remote: any ExternalBrainRemote = GitHubExternalBrainRemote()) {
        self.defaults = defaults; self.remote = remote
        repository = defaults.data(forKey: repositoryKey).flatMap { try? JSONDecoder().decode(ExternalBrainRepositoryConfiguration.self, from: $0) } ?? .init()
        personaConfigurations = defaults.data(forKey: personaKey).flatMap { try? JSONDecoder().decode([UUID: PersonaExternalBrainConfiguration].self, from: $0) } ?? [:]
        cache = try? ExternalBrainCache(rootURL: rootURL); manifest = cache?.manifest() ?? .init()
    }
    func configuration(for personaID: UUID) -> PersonaExternalBrainConfiguration { personaConfigurations[personaID] ?? .init(personaID: personaID) }
    func savePersona(_ value: PersonaExternalBrainConfiguration) { personaConfigurations[value.personaID] = value }
    func saveToken(_ token: String) -> Bool { do { let value = token.trimmingCharacters(in: .whitespacesAndNewlines); if value.isEmpty { ExternalBrainTokenStore.remove() } else { try ExternalBrainTokenStore.save(value) }; message = "認証情報をKeychainへ保存しました。"; return true } catch { message = "認証情報を保存できませんでした。"; return false } }
    func synchronize() async {
        guard !isSyncing, repository.isConfigured, let cache, let token = ExternalBrainTokenStore.load(), !token.isEmpty else { message = "RepositoryとGitHub tokenを設定してください。"; return }
        isSyncing = true; defer { isSyncing = false }
        do { let result = try await cache.synchronize(remote: remote, configuration: repository, token: token); manifest = cache.manifest(); message = result.usedExistingCache ? "同期できないため前回同期済みキャッシュを使用します。" : "同期しました（更新 \(result.downloaded)、変更なし \(result.unchanged)、削除 \(result.removed)）。" }
        catch { message = "同期できませんでした。External BrainなしでAI Replyを続行できます。" }
    }
    func retrieve(personaID: UUID, query: String) -> ExternalBrainContext? {
        guard let cache else { return nil }; return try? ExternalBrainRetriever(cache: cache).retrieve(configuration: configuration(for: personaID), query: query)
    }
    var cacheByteCount: Int64 {
        guard let cache else { return 0 }; let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let files = FileManager.default.enumerator(at: cache.rootURL, includingPropertiesForKeys: keys) else { return 0 }
        return files.compactMap { $0 as? URL }.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: Set(keys)).fileSize) ?? 0) }
    }
    private func persist() { if let data = try? JSONEncoder().encode(repository) { defaults.set(data, forKey: repositoryKey) }; if let data = try? JSONEncoder().encode(personaConfigurations) { defaults.set(data, forKey: personaKey) } }
}
