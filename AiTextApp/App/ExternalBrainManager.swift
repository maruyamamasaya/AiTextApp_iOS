import Combine
import Foundation
import Security
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GitHubExternalBrainRemote: ExternalBrainRemote, GitHubRepositoryConnectionTesting {
    private struct TreeResponse: Decodable { struct Item: Decodable { let path, type: String; let sha: String }; let tree: [Item] }
    private struct RepositoryResponse: Decodable {
        struct Permissions: Decodable { let push: Bool }
        let permissions: Permissions?
    }
    func listMarkdownFiles(configuration: ExternalBrainRepositoryConfiguration, token: String) async throws -> [ExternalBrainRemoteFile] {
        let branch = configuration.branch.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? configuration.branch
        let url = try apiURL("repos/\(configuration.owner)/\(configuration.repository)/git/trees/\(branch)?recursive=1")
        let (data, _) = try await request(url, token: token, scope: .branch)
        return try JSONDecoder().decode(TreeResponse.self, from: data).tree.filter { $0.type == "blob" && $0.path.lowercased().hasSuffix(".md") }.map { ExternalBrainRemoteFile(path: $0.path, sha: $0.sha) }
    }
    func download(path: String, configuration: ExternalBrainRepositoryConfiguration, token: String) async throws -> Data {
        guard ExternalBrainPath.isSafe(path) else { throw ExternalBrainError.unsafePath(path) }
        let encoded = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        let ref = configuration.branch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? configuration.branch
        let (data, _) = try await request(try apiURL("repos/\(configuration.owner)/\(configuration.repository)/contents/\(encoded)?ref=\(ref)"), token: token, accept: "application/vnd.github.raw+json", scope: .repository)
        return data
    }
    func testConnection(configuration: ExternalBrainRepositoryConfiguration, token: String) async throws -> GitHubRepositoryCapabilities {
        guard configuration.isConfigured else { throw GitHubConnectionIssue.notConfigured }
        guard !token.isEmpty else { throw GitHubConnectionIssue.tokenMissing }
        let (repositoryData, repositoryResponse) = try await request(try apiURL("repos/\(configuration.owner)/\(configuration.repository)"), token: token, scope: .repository)
        let repository = try JSONDecoder().decode(RepositoryResponse.self, from: repositoryData)
        let encodedBranch = configuration.branch.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? configuration.branch
        let (_, branchResponse) = try await request(try apiURL("repos/\(configuration.owner)/\(configuration.repository)/branches/\(encodedBranch)"), token: token, scope: .branch)
        let remaining = branchResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init) ?? repositoryResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init)
        let writable = repository.permissions?.push == true
        return .init(authentication: true, repositoryRead: true, branchRead: true, writeDrafts: writable, writeKnowledge: writable, branch: configuration.branch, rateLimitRemaining: remaining)
    }
    private func apiURL(_ path: String) throws -> URL { guard let url = URL(string: "https://api.github.com/\(path)") else { throw ExternalBrainError.remote("URL") }; return url }
    private func request(_ url: URL, token: String, accept: String = "application/vnd.github+json", scope: GitHubConnectionCheckScope) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url); request.httpMethod = "GET"; request.timeoutInterval = 30
        request.setValue(accept, forHTTPHeaderField: "Accept"); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GitHubConnectionIssue.network }
            guard (200..<300).contains(http.statusCode) else {
                throw GitHubConnectionIssue.classify(statusCode: http.statusCode, rateLimitRemaining: http.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init), scope: scope)
            }
            return (data, http)
        } catch let issue as GitHubConnectionIssue { throw issue }
        catch { throw GitHubConnectionIssue.network }
    }
}

enum ExternalBrainDraftWriteError: Error, LocalizedError {
    case tokenMissing, permissionDenied, conflict, network, invalidResponse
    var errorDescription: String? { switch self {
    case .tokenMissing: "GitHub tokenが設定されていません。"
    case .permissionDenied: "GitHub tokenにContentsのwrite権限がありません。"
    case .conflict: "同名のDraftがすでに存在します。上書きは行いません。"
    case .network: "GitHubへ接続できません。Draft内容は保持されています。"
    case .invalidResponse: "GitHubへDraftを保存できませんでした。Draft内容は保持されています。"
    } }
}

struct GitHubExternalBrainDraftWriter: ExternalBrainDraftWriter {
    private struct Body: Encodable { let message, content, branch: String }
    func createDraft(path: String, markdown: String, configuration: ExternalBrainRepositoryConfiguration, token: String) async throws {
        try KnowledgeDraftPath.validate(path)
        guard configuration.isConfigured else { throw ExternalBrainDraftWriteError.invalidResponse }
        guard !token.isEmpty else { throw ExternalBrainDraftWriteError.tokenMissing }
        let encoded = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        guard let url = URL(string: "https://api.github.com/repos/\(configuration.owner)/\(configuration.repository)/contents/\(encoded)") else { throw ExternalBrainDraftWriteError.invalidResponse }
        var request = URLRequest(url: url); request.httpMethod = "PUT"; request.timeoutInterval = 30
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept"); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(message: "Add knowledge draft \(path)", content: Data(markdown.utf8).base64EncodedString(), branch: configuration.branch))
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { throw ExternalBrainDraftWriteError.invalidResponse }
            switch status { case 201: return; case 401, 403: throw ExternalBrainDraftWriteError.permissionDenied; case 409, 422: throw ExternalBrainDraftWriteError.conflict; default: throw ExternalBrainDraftWriteError.invalidResponse }
        } catch let error as ExternalBrainDraftWriteError { throw error }
        catch { throw ExternalBrainDraftWriteError.network }
    }
}

struct GitHubExternalBrainKnowledgeWriter: ExternalBrainKnowledgeWriter {
    private struct Body: Encodable { let message, content, branch: String }
    private struct Response: Decodable { struct Content: Decodable { let sha: String }; let content: Content }
    func createKnowledge(path: String, markdown: String, configuration: ExternalBrainRepositoryConfiguration, token: String) async throws -> String {
        try KnowledgeDocumentPath.validate(path); guard configuration.isConfigured else { throw ExternalBrainDraftWriteError.invalidResponse }; guard !token.isEmpty else { throw ExternalBrainDraftWriteError.tokenMissing }
        let encoded = path.split(separator:"/").map { String($0).addingPercentEncoding(withAllowedCharacters:.urlPathAllowed) ?? String($0) }.joined(separator:"/")
        guard let url = URL(string:"https://api.github.com/repos/\(configuration.owner)/\(configuration.repository)/contents/\(encoded)") else { throw ExternalBrainDraftWriteError.invalidResponse }
        var request = URLRequest(url:url); request.httpMethod="PUT"; request.timeoutInterval=30; request.setValue("application/vnd.github+json",forHTTPHeaderField:"Accept"); request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization"); request.setValue("2022-11-28",forHTTPHeaderField:"X-GitHub-Api-Version"); request.setValue("application/json",forHTTPHeaderField:"Content-Type"); request.httpBody = try JSONEncoder().encode(Body(message:"Promote knowledge \(path)",content:Data(markdown.utf8).base64EncodedString(),branch:configuration.branch))
        do { let (data,response)=try await URLSession.shared.data(for:request); guard let status=(response as? HTTPURLResponse)?.statusCode else { throw ExternalBrainDraftWriteError.invalidResponse }; switch status { case 201: return try JSONDecoder().decode(Response.self,from:data).content.sha; case 401,403: throw ExternalBrainDraftWriteError.permissionDenied; case 409,422: throw ExternalBrainDraftWriteError.conflict; default: throw ExternalBrainDraftWriteError.invalidResponse } } catch let error as ExternalBrainDraftWriteError { throw error } catch { throw ExternalBrainDraftWriteError.network }
    }
}

enum ExternalBrainTokenStore {
    private static let service = "AiTextApp.ExternalBrain.GitHub"
    static func save(_ token: String) throws {
        let data = Data(token.utf8); let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw ExternalBrainError.remote("Keychain") }
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
    @Published var repository: ExternalBrainRepositoryConfiguration { didSet { persist(); connectionCapabilities = nil; connectionCheckedAt = nil } }
    @Published var personaConfigurations: [UUID: PersonaExternalBrainConfiguration] { didSet { persist() } }
    @Published private(set) var manifest = ExternalBrainManifest()
    @Published private(set) var isSyncing = false
    @Published private(set) var isTestingConnection = false
    @Published private(set) var connectionCapabilities: GitHubRepositoryCapabilities?
    @Published private(set) var connectionCheckedAt: Date?
    @Published var message: String?
    private let defaults: UserDefaults
    private let cache: ExternalBrainCache?
    private let remote: any ExternalBrainRemote
    private let draftWriter: any ExternalBrainDraftWriter
    private let knowledgeWriter: any ExternalBrainKnowledgeWriter
    private let connectionTester: any GitHubRepositoryConnectionTesting
    private let repositoryKey = "externalBrain.repository.v1", personaKey = "externalBrain.personas.v1"
    private let excludedPathsKey = "externalBrain.excludedKnowledgePaths.v1"
    private var excludedKnowledgePaths: Set<String>

    init(rootURL: URL, defaults: UserDefaults = .standard, remote: any ExternalBrainRemote = GitHubExternalBrainRemote(), draftWriter: any ExternalBrainDraftWriter = GitHubExternalBrainDraftWriter(), knowledgeWriter: any ExternalBrainKnowledgeWriter = GitHubExternalBrainKnowledgeWriter(), connectionTester: any GitHubRepositoryConnectionTesting = GitHubExternalBrainRemote()) {
        self.defaults = defaults; self.remote = remote; self.draftWriter = draftWriter; self.knowledgeWriter = knowledgeWriter; self.connectionTester = connectionTester; excludedKnowledgePaths = Set(defaults.stringArray(forKey:"externalBrain.excludedKnowledgePaths.v1") ?? [])
        repository = defaults.data(forKey: repositoryKey).flatMap { try? JSONDecoder().decode(ExternalBrainRepositoryConfiguration.self, from: $0) } ?? .init()
        personaConfigurations = defaults.data(forKey: personaKey).flatMap { try? JSONDecoder().decode([UUID: PersonaExternalBrainConfiguration].self, from: $0) } ?? [:]
        cache = try? ExternalBrainCache(rootURL: rootURL); manifest = cache?.manifest() ?? .init()
    }
    func configuration(for personaID: UUID) -> PersonaExternalBrainConfiguration { personaConfigurations[personaID] ?? .init(personaID: personaID) }
    func savePersona(_ value: PersonaExternalBrainConfiguration) { personaConfigurations[value.personaID] = value }
    func connectionStatus(for personaID: UUID) -> PersonaExternalBrainConnectionStatus {
        let configuration = configuration(for: personaID)
        let agentPath = ExternalBrainPath.normalized(configuration.agentPath)
        return .resolve(
            configuration: configuration,
            repositoryConfigured: repository.isConfigured,
            hasToken: hasToken,
            hasCachedAgent: manifest.files[agentPath] != nil,
            capabilities: connectionCapabilities
        )
    }
    var hasToken: Bool { !(ExternalBrainTokenStore.load() ?? "").isEmpty }
    var repositoryDisplayName: String { repository.isConfigured ? "\(repository.owner)/\(repository.repository)" : "未設定" }
    var draftDirectory: String { KnowledgeDraftPath.directory + "/" }
    var knowledgeDirectory: String { KnowledgeDocumentPath.directory + "/" }
    func saveToken(_ token: String) -> Bool { do { let value = token.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { message = "新しいTokenを入力してください。"; return false }; try ExternalBrainTokenStore.save(value); connectionCapabilities = nil; connectionCheckedAt = nil; message = "認証情報をKeychainへ保存しました。"; return true } catch { message = "認証情報を保存できませんでした。"; return false } }
    func removeToken() { ExternalBrainTokenStore.remove(); connectionCapabilities = nil; connectionCheckedAt = nil; message = "GitHub tokenを削除しました。" }
    func testConnection() async {
        guard !isTestingConnection else { return }
        guard repository.isConfigured else { connectionCapabilities = .failure(.notConfigured, branch: repository.branch); connectionCheckedAt = Date(); return }
        guard let token = ExternalBrainTokenStore.load(), !token.isEmpty else { connectionCapabilities = .failure(.tokenMissing, branch: repository.branch); connectionCheckedAt = Date(); return }
        isTestingConnection = true; defer { isTestingConnection = false }
        defer { connectionCheckedAt = Date() }
        do { connectionCapabilities = try await connectionTester.testConnection(configuration: repository, token: token); message = "GitHub接続を確認しました。" }
        catch let issue as GitHubConnectionIssue { connectionCapabilities = .failure(issue, branch: repository.branch); message = issue.localizedDescription }
        catch { connectionCapabilities = .failure(.network, branch: repository.branch); message = GitHubConnectionIssue.network.localizedDescription }
    }
    func synchronize() async {
        guard !isSyncing, repository.isConfigured, let cache, let token = ExternalBrainTokenStore.load(), !token.isEmpty else { message = "RepositoryとGitHub tokenを設定してください。"; return }
        isSyncing = true; defer { isSyncing = false }
        do { let result = try await cache.synchronize(remote: remote, configuration: repository, token: token); for path in excludedKnowledgePaths { try? cache.index.delete(documentPath:path) }; manifest = cache.manifest(); message = result.usedExistingCache ? "同期できないため前回同期済みキャッシュを使用します。" : "同期しました（更新 \(result.downloaded)、変更なし \(result.unchanged)、削除 \(result.removed)）。" }
        catch { message = "同期できませんでした。External BrainなしでAI Replyを続行できます。" }
    }
    func retrieve(personaID: UUID, query: String) -> ExternalBrainContext? {
        guard let cache else { return nil }; return try? ExternalBrainRetriever(cache: cache).retrieve(configuration: configuration(for: personaID), query: query)
    }
    func excludeFromRetrieval(path:String) { excludedKnowledgePaths.insert(path); defaults.set(Array(excludedKnowledgePaths).sorted(),forKey:excludedPathsKey); try? cache?.index.delete(documentPath:path) }
    var canRead: Bool { repository.isConfigured && !manifest.files.isEmpty }
    var canWriteDrafts: Bool { repository.isConfigured && hasToken && (connectionCapabilities?.writeDrafts ?? true) }
    var canWriteKnowledge: Bool { repository.isConfigured && hasToken && (connectionCapabilities?.writeKnowledge ?? true) }
    func relatedKnowledge(query: String) -> [ExternalBrainRetrievedChunk] { (try? cache?.index.searchRelated(query: query, maximum: 3)) ?? [] }
    func saveDraft(_ draft: KnowledgeDraft) async throws -> String {
        let path = draft.targetPath; try KnowledgeDraftPath.validate(path)
        guard let token = ExternalBrainTokenStore.load(), !token.isEmpty else { throw ExternalBrainDraftWriteError.tokenMissing }
        try await draftWriter.createDraft(path: path, markdown: draft.markdown, configuration: repository, token: token)
        return path
    }
    func promote(_ draft: KnowledgeDraft, path: String) async throws -> String {
        try KnowledgeDocumentPath.validate(path); guard draft.reviewStatus == .approved else { throw KnowledgeDraftTransitionError.invalidTransition }; guard let token=ExternalBrainTokenStore.load(),!token.isEmpty else { throw ExternalBrainDraftWriteError.tokenMissing }
        let sha = try await knowledgeWriter.createKnowledge(path:path,markdown:draft.markdown.replacingOccurrences(of:"status: draft",with:"status: active"),configuration:repository,token:token)
        try? cache?.storePromotedKnowledge(path:path,sha:sha,markdown:draft.markdown.replacingOccurrences(of:"status: draft",with:"status: active"))
        manifest = cache?.manifest() ?? manifest; return sha
    }
    var cacheByteCount: Int64 {
        guard let cache else { return 0 }; let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let files = FileManager.default.enumerator(at: cache.rootURL, includingPropertiesForKeys: keys) else { return 0 }
        return files.compactMap { $0 as? URL }.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: Set(keys)).fileSize) ?? 0) }
    }
    private func persist() { if let data = try? JSONEncoder().encode(repository) { defaults.set(data, forKey: repositoryKey) }; if let data = try? JSONEncoder().encode(personaConfigurations) { defaults.set(data, forKey: personaKey) } }
}
