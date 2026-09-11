import SwiftUI
import PhotosUI
import UIKit

struct TimelineView: View {
    @ObservedObject var store: ThoughtStore
    @Binding var presentedRoute: AppRoute?
    @FocusState private var composerIsFocused: Bool
    @State private var showsSettings = false
    @State private var replyTarget: Thought?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if store.thoughts.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.thoughts) { thought in
                            let replyTarget = store.replyTargetsByThoughtID[thought.id]
                            ThoughtRow(
                                thought: thought,
                                persona: store.personasByThoughtID[thought.id] ?? store.defaultHumanPersona,
                                mentionedPersona: store.mentionedPersonasByThoughtID[thought.id],
                                replyTarget: replyTarget,
                                replyTargetPersona: replyTarget.flatMap { store.personasByThoughtID[$0.id] },
                                tags: store.tagsByThoughtID[thought.id] ?? [],
                                onRequestReply: { self.replyTarget = thought },
                                onDelete: { store.requestDeletion(of: thought) }
                            )
                            if thought.id != store.thoughts.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .animation(.easeOut(duration: 0.2), value: store.thoughts.map(\.id))
            .navigationTitle("Thoughts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { thoughtID in
                ThoughtDetailView(store: store, initialThoughtID: thoughtID)
            }
            .navigationDestination(for: TagRoute.self) { route in
                TaggedThoughtListView(store: store, tag: route.tag)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { presentedRoute = .quickCapture } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Quick Captureを開く")
                    .accessibilityHint("入力に集中してThoughtを投稿します")
                    .accessibilityIdentifier("quickCaptureButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        ThoughtSearchView(store: store)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Thought検索を開く")
                    .accessibilityHint("キーワードから過去のThoughtを検索します")
                    .accessibilityIdentifier("thoughtSearchButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        ThoughtAnalyticsView(store: store)
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .accessibilityLabel("ローカル分析を開く")
                    .accessibilityHint("端末内の過去30日のThought傾向を確認します")
                    .accessibilityIdentifier("thoughtAnalyticsButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        DailySummaryCalendarView(store: store)
                    } label: {
                        Image(systemName: "calendar.badge.checkmark")
                    }
                    .accessibilityLabel("Daily Summaryを開く")
                    .accessibilityHint("日ごとのThoughtと要約状況を確認します")
                    .accessibilityIdentifier("dailySummaryButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showsSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定を開く")
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(item: $store.exportArtifact) { artifact in
                ShareSheet(url: artifact.url, onFailure: store.sharingFailed)
            }
            .sheet(isPresented: $showsSettings) { SettingsView(store: store) }
            .sheet(item: $replyTarget) { thought in AIReplyRequestView(store: store, thought: thought) }
            .confirmationDialog(
                "このThoughtを削除しますか？",
                isPresented: deletionDialogIsPresented,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) { store.confirmDeletion() }
                    .accessibilityIdentifier("confirmDeleteButton")
                Button("キャンセル", role: .cancel) { store.cancelDeletion() }
                    .accessibilityIdentifier("cancelDeleteButton")
            } message: {
                Text("削除したThoughtはタイムラインに表示されなくなります。")
            }
            .alert("エラー", isPresented: errorIsPresented) {
                Button("OK") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .center, spacing: 8) {
            Menu {
                ForEach(store.personas.filter { $0.kind == .ai }) { persona in
                    Button("@\(persona.displayName)") { store.selectedMentionPersona = persona }
                }
                if store.selectedMentionPersona != nil { Button("メンションを外す", role: .destructive) { store.selectedMentionPersona = nil } }
            } label: {
                Text(store.selectedMentionPersona.map { "@\($0.displayName)" } ?? "@")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .disabled(store.personas.allSatisfy { $0.kind != .ai })
            .accessibilityLabel(store.selectedMentionPersona.map { "\($0.displayName)をメンション中" } ?? "AI Personaをメンション")
            .accessibilityIdentifier("mentionPersonaMenu")

            ZStack(alignment: .leading) {
                if store.draft.isEmpty {
                    Text("今なに考えてる？")
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: Binding(get: { store.draft }, set: store.updateDraft))
                    .focused($composerIsFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 1)
                    .padding(.vertical, 4)
                    .frame(height: 44)
                    .accessibilityLabel("Thoughtを入力")
                    .accessibilityHint("140文字以内で入力します")
                    .accessibilityIdentifier("thoughtComposer")
            }

            if !store.draft.isEmpty {
                characterCount
                    .transition(.opacity)
            }

            if store.canPost {
                Button("投稿") {
                    if store.post() { composerIsFocused = false }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .accessibilityLabel("Thoughtを投稿")
                .accessibilityHint("入力したThoughtを投稿します")
                .accessibilityIdentifier("postButton")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeOut(duration: 0.16), value: store.canPost)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    private var characterCount: some View {
        Text("\(store.draft.count) / \(ThoughtDraft.characterLimit)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(store.draft.count >= 130 ? Color.orange : Color.secondary)
            .accessibilityLabel("文字数 \(store.draft.count)、上限 \(ThoughtDraft.characterLimit)")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("まだThoughtはありません")
                .font(.headline)
            Text("思いついたことを\n140文字以内で残してみましょう。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var deletionDialogIsPresented: Binding<Bool> {
        Binding(
            get: { store.deletionCandidate != nil },
            set: { if !$0 { store.cancelDeletion() } }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

private struct SettingsView: View {
    @ObservedObject var store: ThoughtStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsPersonas = false

    var body: some View {
        NavigationStack {
            Form {
                Section("アカウント") {
                    Button { showsPersonas = true } label: {
                        HStack(spacing: 12) {
                            PersonaIcon(persona: store.defaultHumanPersona, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("プロフィールとPersona")
                                Text(store.defaultHumanPersona.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("profileButton")
                }

                Section("AI") {
                    NavigationLink {
                        AIAPIUsageAnalyticsView(store: store)
                    } label: {
                        Label("AI使用状況", systemImage: "waveform.path.ecg")
                    }
                    .accessibilityIdentifier("aiUsageAnalyticsButton")

                    NavigationLink { ExternalBrainSettingsView(store: store) } label: {
                        HStack {
                            Label("External Brain", systemImage: "brain.head.profile")
                            Spacer()
                            Text(store.externalBrainManager.repository.isConfigured ? (store.externalBrainManager.connectionCapabilities?.issue == nil && store.externalBrainManager.connectionCapabilities != nil ? "Connected" : "Configured") : "Not configured")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { KnowledgeManagementView(store: store) } label: { Label("Knowledge Drafts", systemImage: "doc.text.magnifyingglass") }
                }

                Section("データ") {
                    Button { store.export(.markdown) } label: {
                        Label("Markdownを共有", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("exportMarkdownButton")

                    Button { store.export(.json) } label: {
                        Label("JSONを共有", systemImage: "curlybraces")
                    }
                    .accessibilityIdentifier("exportJSONButton")

                    if let manager = store.externalBackupManager {
                        NavigationLink {
                            BackupManagementView(manager: manager)
                        } label: {
                            Label("バックアップ", systemImage: "externaldrive.badge.timemachine")
                        }
                        .accessibilityIdentifier("backupManagementButton")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .sheet(isPresented: $showsPersonas) { PersonaManagementView(store: store) }
            .sheet(item: $store.exportArtifact) { artifact in
                ShareSheet(url: artifact.url, onFailure: store.sharingFailed)
            }
        }
    }
}

private struct BackupManagementView: View {
    enum PickerPurpose: Identifiable { case destination, restore; var id: Int { self == .destination ? 0 : 1 } }
    @ObservedObject var manager: ExternalBackupManager
    @State private var pickerPurpose: PickerPurpose?

    var body: some View {
        Form {
            Section("保存先") {
                LabeledContent("フォルダ", value: manager.destinationName ?? "未選択")
                LabeledContent("状態", value: manager.destinationAvailable ? "利用可能" : "利用できません")
                Button("バックアップ保存先を選択") { pickerPurpose = .destination }
                    .accessibilityIdentifier("selectBackupDestinationButton")
            }
            Section {
                LabeledContent("最終バックアップ") {
                    Text(manager.lastBackupAt?.formatted(date: .numeric, time: .shortened) ?? "未作成")
                }
                Button("今すぐバックアップ") { manager.createBackup() }
                    .disabled(!manager.destinationAvailable)
                    .accessibilityIdentifier("createExternalBackupButton")
            } header: {
                Text("外部完全バックアップ")
            } footer: {
                Text("SQLite全体をFilesまたはiCloud Driveへ保存します。アプリ内の2世代バックアップやMarkdown／JSON Exportとは別の、削除・再インストール時の復旧用です。")
            }
            Section {
                Button("バックアップから復元", role: .destructive) { pickerPurpose = .restore }
                    .accessibilityIdentifier("restoreExternalBackupButton")
            } header: {
                Text("Restore")
            } footer: {
                Text("選択後に内容を検証し、確認画面を表示します。現在のデータは次回起動時まで置き換えません。")
            }
        }
        .navigationTitle("バックアップ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { manager.refreshDestinationStatus() }
        .sheet(item: $pickerPurpose) { purpose in
            FolderPicker { url in
                pickerPurpose = nil
                if purpose == .destination { manager.selectDestination(url) }
                else { manager.prepareRestoreSelection(url) }
            } onCancel: { pickerPurpose = nil }
        }
        .alert("バックアップから復元", isPresented: restoreConfirmationIsPresented) {
            Button("キャンセル", role: .cancel) { manager.cancelRestore() }
            Button("復元する", role: .destructive) { manager.confirmRestore() }
        } message: {
            Text("このバックアップで現在のAiTextデータを置き換えます。\n\nバックアップ日時: \(manager.restoreCandidate?.manifest.createdAt.formatted(date: .numeric, time: .shortened) ?? "不明")\n\n適用は次回アプリ起動時です。")
        }
        .alert("バックアップ", isPresented: messageIsPresented) {
            Button("OK") { manager.message = nil }
        } message: { Text(manager.message ?? "") }
    }

    private var restoreConfirmationIsPresented: Binding<Bool> {
        Binding(get: { manager.restoreCandidate != nil }, set: { if !$0 { manager.cancelRestore() } })
    }
    private var messageIsPresented: Binding<Bool> {
        Binding(get: { manager.message != nil }, set: { if !$0 { manager.message = nil } })
    }
}

private struct TagRoute: Hashable {
    let tag: ThoughtTag
}

private struct TagStrip: View {
    let tags: [ThoughtTag]

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(tags.prefix(2))) { tag in
                    NavigationLink(value: TagRoute(tag: tag)) {
                        Label(tag.name, systemImage: "tag.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("タグ \(tag.name)")
                    .accessibilityHint("このタグのThought一覧を開きます")
                    .accessibilityIdentifier("thoughtTag_\(tag.id.uuidString)")
                }
                if tags.count > 2 {
                    Text("+\(tags.count - 2)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("他\(tags.count - 2)個のタグ")
                }
            }
        }
    }

}

private struct ThoughtSearchView: View {
    @ObservedObject var store: ThoughtStore
    @State private var query = ""

    var body: some View {
        Group {
            if !store.hasSearchQuery {
                searchInitialState
            } else if store.searchResults.isEmpty {
                searchEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.searchResults) { thought in
                            VStack(alignment: .leading, spacing: 8) {
                                NavigationLink {
                                    ThoughtDetailView(store: store, initialThoughtID: thought.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                    Text(thought.body)
                                        .font(.body)
                                        .lineSpacing(4)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                    Text(ThoughtDateText.string(for: thought.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("検索結果、\(thought.body)")
                                .accessibilityHint("ダブルタップして詳細とHistoryを開きます")
                                .accessibilityIdentifier("searchResult_\(thought.id.uuidString)")
                                TagStrip(tags: store.tagsByThoughtID[thought.id] ?? [])
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            if thought.id != store.searchResults.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("Thought検索")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Thought本文を検索"
        )
        .onChange(of: query) { store.search($0) }
        .onDisappear { store.clearSearch() }
    }

    private var searchInitialState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("キーワードでThoughtを探す")
                .font(.headline)
            Text("本文の一部を入力してください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("thoughtSearchInitialState")
    }

    private var searchEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("一致するThoughtはありません")
                .font(.headline)
            Text("別のキーワードを試してください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("thoughtSearchEmptyState")
    }
}

private struct ThoughtTagListView: View {
    @ObservedObject var store: ThoughtStore

    var body: some View {
        Group {
            if store.allTags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag").font(.title2).foregroundStyle(.secondary)
                    Text("タグはありません").font(.headline)
                    Text("Thought Detailからタグを追加できます。").font(.subheadline).foregroundStyle(.secondary)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                    .accessibilityIdentifier("thoughtTagListEmptyState")
            } else {
                List(store.allTags) { tag in
                    NavigationLink(value: TagRoute(tag: tag)) {
                        Label(tag.name, systemImage: "tag")
                    }
                    .accessibilityIdentifier("tagListItem_\(tag.id.uuidString)")
                }
            }
        }
        .navigationTitle("タグ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.loadAllTags() }
    }
}

private struct TaggedThoughtListView: View {
    @ObservedObject var store: ThoughtStore
    let tag: ThoughtTag

    var body: some View {
        Group {
            if store.taggedThoughts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag").font(.title2).foregroundStyle(.secondary)
                    Text("Thoughtはありません").font(.headline)
                    Text("削除されていないThoughtはありません。").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.taggedThoughts) { thought in
                            VStack(alignment: .leading, spacing: 8) {
                                NavigationLink(value: thought.id) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(thought.body)
                                            .font(.body)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                        Text(ThoughtDateText.string(for: thought.createdAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("taggedThought_\(thought.id.uuidString)")
                                TagStrip(tags: store.tagsByThoughtID[thought.id] ?? [])
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            if thought.id != store.taggedThoughts.last?.id { Divider().padding(.leading, 16) }
                        }
                    }
                }
            }
        }
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.loadThoughts(taggedWith: tag) }
    }
}

private struct ThoughtTagEditorView: View {
    @ObservedObject var store: ThoughtStore
    let thought: Thought
    @State private var newTagName = ""
    @Environment(\.dismiss) private var dismiss

    private var currentTags: [ThoughtTag] { store.tagsByThoughtID[thought.id] ?? [] }
    private var availableTags: [ThoughtTag] {
        let currentIDs = Set(currentTags.map(\.id))
        return store.allTags.filter { !currentIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("現在のタグ") {
                    if currentTags.isEmpty { Text("タグなし").foregroundStyle(.secondary) }
                    ForEach(currentTags) { tag in
                        HStack {
                            Label(tag.name, systemImage: "tag")
                            Spacer()
                            Button("削除", role: .destructive) { store.removeTag(tag, from: thought.id) }
                                .accessibilityIdentifier("removeThoughtTag_\(tag.id.uuidString)")
                        }
                    }
                }
                if !availableTags.isEmpty {
                    Section("既存タグを追加") {
                        ForEach(availableTags) { tag in
                            Button { store.addTag(named: tag.name, to: thought.id) } label: {
                                Label(tag.name, systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("attachExistingTag_\(tag.id.uuidString)")
                        }
                    }
                }
                Section("新しいタグ") {
                    TextField("タグ名", text: $newTagName)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .accessibilityIdentifier("newThoughtTagField")
                        .onSubmit(addNewTag)
                    Button("タグを追加", action: addNewTag)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .disabled(ThoughtTag.displayName(from: newTagName) == nil)
                        .accessibilityIdentifier("addThoughtTagButton")
                }
                if let message = store.tagMessage {
                    Section { Text(message).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("タグを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }.accessibilityIdentifier("closeThoughtTagEditor")
                }
            }
            .onAppear {
                store.refreshTags(for: [thought.id])
                store.loadAllTags()
                store.tagMessage = nil
            }
        }
    }

    private func addNewTag() {
        guard let displayName = ThoughtTag.displayName(from: newTagName) else { return }
        store.addTag(named: displayName, to: thought.id)
        if store.tagMessage == nil { newTagName = "" }
    }
}

private struct ThoughtDetailView: View {
    @ObservedObject var store: ThoughtStore
    let initialThoughtID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var currentThoughtID: UUID
    @State private var showsComposer = false
    @State private var showsTagEditor = false
    @State private var showsAIReply = false
    @State private var showsHumanReplyComposer = false
    @State private var knowledgeDraftInput: KnowledgeDraftInput?
    @FocusState private var composerIsFocused: Bool

    init(store: ThoughtStore, initialThoughtID: UUID) {
        self.store = store
        self.initialThoughtID = initialThoughtID
        _currentThoughtID = State(initialValue: initialThoughtID)
    }

    private var currentThought: Thought? {
        store.history.first { $0.id == currentThoughtID }?.thought
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let currentThought {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(currentThought.deletedAt == nil ? currentThought.body : "削除されたThought")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(currentThought.deletedAt == nil ? Color.primary : Color.secondary)
                        Text(ThoughtDateText.string(for: currentThought.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TagStrip(tags: store.tagsByThoughtID[currentThought.id] ?? [])
                        Button("タグを編集") { showsTagEditor = true }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("editThoughtTagsButton")
                        Button("続きを書く") {
                            showsComposer.toggle()
                            showsHumanReplyComposer = false
                            if showsComposer { composerIsFocused = true }
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .accessibilityLabel("このThoughtの続きを書く")
                        .accessibilityHint("\(currentThought.deletedAt == nil ? currentThought.body : "削除されたThought")の続きを作成します")
                        .accessibilityIdentifier("writeContinuationButton")
                        if store.mentionedPersonasByThoughtID[currentThought.id] != nil {
                            Button("AIに返信を依頼") { showsAIReply = true }
                                .buttonStyle(.bordered)
                                .disabled(store.isGeneratingAIReply || !store.personas.contains(where: { $0.id == store.mentionedPersonasByThoughtID[currentThought.id]?.id }))
                                .accessibilityIdentifier("requestAIReplyButton")
                        }
                        Button("返信を書く") {
                            showsHumanReplyComposer.toggle()
                            showsComposer = false
                            if showsHumanReplyComposer { composerIsFocused = true }
                        }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("writeReplyButton")
                        if let input = store.knowledgeDraftInput(for: currentThought) {
                            Button("外部脳に残す") { knowledgeDraftInput = input }.buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                    if showsComposer { continuationComposer(parent: currentThought) }
                    if showsHumanReplyComposer { humanReplyComposer(target: currentThought) }
                    if let replies = store.aiRepliesByTargetID[currentThought.id], !replies.isEmpty {
                        Divider(); Text("AI Reply").font(.headline).padding(.horizontal, 16).padding(.top, 18)
                        ForEach(replies) { reply in
                            HStack(alignment: .top, spacing: 10) { PersonaIcon(persona: store.personasByThoughtID[reply.id] ?? store.defaultHumanPersona, size: 32); VStack(alignment: .leading) { Text(store.personasByThoughtID[reply.id]?.displayName ?? "AI").font(.subheadline.weight(.semibold)); Text(reply.body); Text(ThoughtDateText.string(for: reply.createdAt)).font(.caption).foregroundStyle(.secondary); if let input = store.knowledgeDraftInput(for: reply) { Button("外部脳に残す") { knowledgeDraftInput = input }.buttonStyle(.bordered) } } }.padding(16)
                        }
                    }
                }

                Divider()
                Text("History")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                ForEach(Array(store.history.enumerated()), id: \.element.id) { index, entry in
                    historyRow(entry)
                    if index < store.history.count - 1 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 1, height: 18)
                            .padding(.leading, 24 + CGFloat(entry.depth) * 14)
                    }
                }
            }
        }
        .navigationTitle("Thought")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.loadHistory(for: currentThoughtID); store.loadAIReplies(to: currentThoughtID) }
        .onChange(of: currentThoughtID) { store.loadAIReplies(to: $0) }
        .sheet(isPresented: Binding(get: { knowledgeDraftInput != nil }, set: { if !$0 { knowledgeDraftInput = nil } })) { if let input = knowledgeDraftInput { KnowledgeDraftFlowView(store: store, input: input) } }
        .sheet(isPresented: $showsTagEditor) {
            if let currentThought {
                ThoughtTagEditorView(store: store, thought: currentThought)
            }
        }
        .sheet(isPresented: $showsAIReply) { if let currentThought { AIReplyRequestView(store: store, thought: currentThought) } }
    }

    private func continuationComposer(parent: Thought) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("続きを書く")
                .font(.headline)
            TextEditor(text: Binding(get: { store.continuationDraft }, set: store.updateContinuationDraft))
                .focused($composerIsFocused)
                .frame(minHeight: 96, maxHeight: 140)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("\(parent.deletedAt == nil ? parent.body : "削除されたThought")の続きを入力")
                .accessibilityHint("140文字以内で入力します")
                .accessibilityIdentifier("continuationComposer")
            HStack {
                Text("\(store.continuationDraft.count) / \(ThoughtDraft.characterLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(store.continuationDraft.count >= 130 ? Color.orange : Color.secondary)
                Spacer()
                Button("投稿") {
                    if let created = store.postContinuation(parentThoughtID: parent.id) {
                        currentThoughtID = created.id
                        showsComposer = false
                        composerIsFocused = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!store.canPostContinuation)
                .accessibilityLabel("続きを投稿")
                .accessibilityIdentifier("postContinuationButton")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func historyRow(_ entry: ThoughtHistoryEntry) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                currentThoughtID = entry.id
                showsComposer = false
                store.loadHistory(for: entry.id)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(entry.id == currentThoughtID ? Color.accentColor : Color.secondary.opacity(0.45))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.thought.deletedAt == nil ? entry.thought.body : "削除されたThought")
                                .font(entry.id == currentThoughtID ? .body.weight(.semibold) : .body)
                                .foregroundStyle(entry.thought.deletedAt == nil ? Color.primary : Color.secondary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if entry.id == currentThoughtID {
                                Text("現在")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        Text(ThoughtDateText.string(for: entry.thought.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 16 + CGFloat(entry.depth) * 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("History Thought、\(entry.thought.deletedAt == nil ? entry.thought.body : "削除されたThought")\(entry.id == currentThoughtID ? "、現在" : "")")
            .accessibilityHint("ダブルタップしてこのThoughtを現在位置にします")
            .accessibilityIdentifier("historyThought_\(entry.id.uuidString)")

            if entry.thought.deletedAt == nil {
                Menu {
                    Button("削除", role: .destructive) { store.requestDeletion(of: entry.thought) }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("History Thoughtの操作")
                .accessibilityIdentifier("historyThoughtMenu_\(entry.id.uuidString)")
            }
        }
        .padding(.trailing, 8)
        .background(entry.id == currentThoughtID ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private func humanReplyComposer(target: Thought) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("返信を書く").font(.headline)
            TextEditor(text: Binding(get: { store.humanReplyDraft }, set: store.updateHumanReplyDraft))
                .focused($composerIsFocused)
                .frame(minHeight: 80)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("humanReplyComposer")
            HStack {
                Text("\(store.humanReplyDraft.count) / \(ThoughtDraft.characterLimit)")
                    .font(.caption.monospacedDigit())
                Spacer()
                Button("返信") {
                    if store.postHumanReply(to: target) != nil {
                        showsHumanReplyComposer = false
                        composerIsFocused = false
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canPostHumanReply)
                .accessibilityIdentifier("postHumanReplyButton")
            }
        }.padding(.horizontal, 16).padding(.bottom, 16)
    }
}

private struct ThoughtRow: View {
    let thought: Thought
    let persona: Persona
    let mentionedPersona: Persona?
    let replyTarget: Thought?
    let replyTargetPersona: Persona?
    let tags: [ThoughtTag]
    let onRequestReply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PersonaIcon(persona: persona, size: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                NavigationLink(value: thought.id) {
                    VStack(alignment: .leading, spacing: 8) {
                    Text(persona.displayName)
                        .font(.subheadline.weight(.semibold))
                    if persona.kind == .ai {
                        Text("AI").font(.caption2.weight(.bold)).foregroundStyle(.tint)
                    }
                    if let replyTarget {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("返信先 @\(replyTargetPersona?.displayName ?? "不明")")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                            HStack(alignment: .top, spacing: 7) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.35))
                                    .frame(width: 2)
                                Text(replyTarget.deletedAt == nil ? replyTarget.body : "削除されたThought")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("replyContext_\(thought.id.uuidString)")
                    }
                    Text(thought.body)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .accessibilityIdentifier("thoughtBody_\(thought.id.uuidString)")
                    Text(ThoughtDateText.string(for: thought.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(timelineAccessibilityLabel)
                .accessibilityHint("ダブルタップして詳細とHistoryを開きます")
                .accessibilityIdentifier("timelineThought_\(thought.id.uuidString)")
                TagStrip(tags: tags)
                if let mentionedPersona {
                    Text("@\(mentionedPersona.displayName)")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tint)
                        .accessibilityLabel("\(mentionedPersona.displayName)をメンション")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                if mentionedPersona?.deletedAt == nil { Button("AIに返信を依頼", action: onRequestReply) }
                Button("削除", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Thoughtの操作")
            .accessibilityHint("削除メニューを表示します")
            .accessibilityIdentifier("thoughtMenu")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
        .contentShape(Rectangle())
    }

    private var timelineAccessibilityLabel: String {
        guard let replyTarget else { return "Thought、\(thought.body)" }
        let targetBody = replyTarget.deletedAt == nil ? replyTarget.body : "削除されたThought"
        return "\(replyTargetPersona?.displayName ?? "不明")への返信、返信先、\(targetBody)、本文、\(thought.body)"
    }
}

private struct ExternalBrainSettingsView: View {
    @ObservedObject var store: ThoughtStore
    @ObservedObject var manager: ExternalBrainManager
    @State private var owner = ""
    @State private var repository = ""
    @State private var branch = "main"
    @State private var token = ""
    @State private var showsToken = false
    @State private var confirmsRepositoryChange = false
    @State private var confirmsTokenRemoval = false
    init(store: ThoughtStore) { self.store = store; self.manager = store.externalBrainManager }
    private var editedConfiguration: ExternalBrainRepositoryConfiguration {
        .init(owner: owner.trimmingCharacters(in: .whitespacesAndNewlines), repository: repository.trimmingCharacters(in: .whitespacesAndNewlines), branch: branch.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    private var hasLocalKnowledge: Bool { !store.knowledgeDrafts.isEmpty || !store.knowledgeDocuments.isEmpty }

    var body: some View {
        Form {
            Section("GitHub Repository") {
                TextField("Owner", text: $owner).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Repository", text: $repository).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Branch", text: $branch).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Repository設定を保存") {
                    if hasLocalKnowledge && editedConfiguration != manager.repository { confirmsRepositoryChange = true }
                    else { manager.repository = editedConfiguration }
                }
            }
            Section("Personal Access Token") {
                HStack {
                    Group {
                        if showsToken { TextField("新しいGitHub token", text: $token) }
                        else { SecureField(manager.hasToken ? "••••••••••••••" : "GitHub fine-grained token", text: $token) }
                    }
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(showsToken ? "Hide" : "Show") { showsToken.toggle() }.buttonStyle(.borderless)
                }
                LabeledContent("Status", value: manager.hasToken ? "Keychainに設定済み" : "未設定")
                Button("Tokenを保存") { if manager.saveToken(token) { token = ""; showsToken = false } }.disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if manager.hasToken { Button("Remove Token", role: .destructive) { confirmsTokenRemoval = true } }
            }
            Section("GitHub Connection") {
                Button(manager.isTestingConnection ? "確認中…" : "Test Connection") { Task { await manager.testConnection() } }.disabled(manager.isTestingConnection)
                capability("Authentication", manager.connectionCapabilities?.authentication)
                capability("Repository Read", manager.connectionCapabilities?.repositoryRead)
                capability("Branch \(manager.repository.branch)", manager.connectionCapabilities?.branchRead)
                capability("Write Drafts", manager.connectionCapabilities?.writeDrafts)
                capability("Write Knowledge", manager.connectionCapabilities?.writeKnowledge)
                if let issue = manager.connectionCapabilities?.issue { Text(issue.localizedDescription).font(.footnote).foregroundStyle(.red) }
                if let remaining = manager.connectionCapabilities?.rateLimitRemaining { LabeledContent("Rate limit remaining", value: "\(remaining)") }
                Text("接続確認はRepository・Branch・権限情報の読取りだけを行い、ファイルを書き込みません。").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Paths") {
                LabeledContent("Draft Path", value: manager.draftDirectory)
                LabeledContent("Knowledge Path", value: manager.knowledgeDirectory)
            }
            Section("同期") {
                if let date = manager.manifest.syncedAt { LabeledContent("最終同期", value: date.formatted(date: .abbreviated, time: .shortened)) }
                else { LabeledContent("最終同期", value: "未同期") }
                LabeledContent("キャッシュ", value: ByteCountFormatter.string(fromByteCount: manager.cacheByteCount, countStyle: .file))
                Button(manager.isSyncing ? "同期中…" : "今すぐ同期") { Task { await manager.synchronize() } }.disabled(manager.isSyncing)
                if let message = manager.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
            Section("Capabilities") {
                LabeledContent("GitHub", value: manager.repository.isConfigured ? (manager.connectionCapabilities?.issue == nil && manager.connectionCapabilities != nil ? "Connected" : "Configured") : "Not configured")
                LabeledContent("Repository", value: manager.repositoryDisplayName)
                LabeledContent("Branch", value: manager.repository.branch)
                LabeledContent("Drafts", value: manager.canWriteDrafts ? "Writable" : "設定または権限が必要")
                LabeledContent("Knowledge", value: manager.canWriteKnowledge ? "Writable" : "設定または権限が必要")
            }
            Section { Text("TokenはKeychainへ保存され、SQLite・Markdown・Usage・ログには含まれません。Write DraftsにはGitHub Contentsのwrite権限が必要です。書き込み失敗はRead機能へ影響しません。").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("External Brain")
        .onAppear { owner = manager.repository.owner; repository = manager.repository.repository; branch = manager.repository.branch; store.loadKnowledge() }
        .confirmationDialog("GitHub Repositoryを変更しますか？", isPresented: $confirmsRepositoryChange, titleVisibility: .visible) {
            Button("変更する") { manager.repository = editedConfiguration }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("既存のローカルKnowledgeとDraftは削除されません。今後のGitHub同期・保存先が変更されます。") }
        .confirmationDialog("GitHub tokenを削除しますか？", isPresented: $confirmsTokenRemoval, titleVisibility: .visible) {
            Button("削除", role: .destructive) { manager.removeToken() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    @ViewBuilder private func capability(_ title: String, _ value: Bool?) -> some View {
        LabeledContent(title, value: value.map { $0 ? "✓" : "×" } ?? "未確認")
    }
}

struct KnowledgeDraftFlowView: View {
    @ObservedObject var store: ThoughtStore
    let input: KnowledgeDraftInput
    @State private var type: KnowledgeDraftType = .knowledge
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Source") { LabeledContent("種類", value: input.source.displayName); Text(input.sourceContent).lineLimit(8) }
                Section("Draft Type") { Picker("種類", selection: $type) { ForEach(KnowledgeDraftType.allCases, id: \.self) { Text($0.displayName).tag($0) } } }
                Section { Text("生成を押すまでAI通信は行いません。生成後のPreview確認とGitHub保存は別操作です。").font(.footnote).foregroundStyle(.secondary) }
                if let error = store.knowledgeDraftError { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Knowledge Draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.isGeneratingKnowledgeDraft ? "生成中…" : "Draft生成") { Task { await store.generateKnowledgeDraft(input: input, type: type) } }.disabled(store.isGeneratingKnowledgeDraft) }
            }
            .sheet(item: Binding(get: { store.knowledgeDraft }, set: { if $0 == nil { store.cancelKnowledgeDraft() } })) { KnowledgeDraftPreviewView(store: store, draft: $0) }
        }
    }
}

private struct KnowledgeDraftPreviewView: View {
    @ObservedObject var store: ThoughtStore
    @State private var draft: KnowledgeDraft
    @State private var showsGitHubSettings = false
    @Environment(\.dismiss) private var dismiss
    init(store: ThoughtStore, draft: KnowledgeDraft) { self.store = store; _draft = State(initialValue: draft) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Draft") {
                    TextField("Title", text: $draft.title)
                    Picker("Type", selection: $draft.type) { ForEach(KnowledgeDraftType.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    TextField("Project", text: $draft.project)
                    TextField("Tags（カンマ区切り）", text: Binding(get: { draft.tags.joined(separator: ", ") }, set: { draft.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }))
                    LabeledContent("Source", value: draft.source.displayName)
                    LabeledContent("保存予定path", value: draft.targetPath)
                }
                Section("Markdown本文") { TextEditor(text: $draft.body).frame(minHeight: 260).font(.system(.caption, design: .monospaced)) }
                Section("Markdown全文") { Text(draft.markdown).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                Section("関連する既存資料") {
                    if draft.relatedDocuments.isEmpty { Text("なし").foregroundStyle(.secondary) }
                    ForEach(Array(draft.relatedDocuments.enumerated()), id: \.offset) { item in VStack(alignment: .leading) { Text(item.element.documentPath).font(.subheadline.weight(.semibold)); Text(item.element.heading).font(.caption).foregroundStyle(.secondary) } }
                }
                if let message = store.knowledgeDraftMessage { Section { Text(message).foregroundStyle(.green) } }
                if let error = store.knowledgeDraftError { Section { Text(error).foregroundStyle(.red) } }
                if !store.externalBrainManager.canWriteDrafts {
                    Section("GitHub") {
                        Text("GitHub is not configured.").foregroundStyle(.secondary)
                        Button("Open GitHub Settings") { showsGitHubSettings = true }
                    }
                }
                if draft.savedPath == nil { Section { Text("保存の承認はGitHub drafts/への新規作成までです。確定知識への昇格ではありません。").font(.footnote).foregroundStyle(.secondary) } }
            }
            .navigationTitle("Draft Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.isSavingKnowledgeDraft ? "保存中…" : "GitHubへ保存") { Task { await store.saveKnowledgeDraft(draft); if let saved = store.knowledgeDraft { draft = saved } } }.disabled(store.isSavingKnowledgeDraft || draft.savedPath != nil || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .sheet(isPresented: $showsGitHubSettings) { NavigationStack { ExternalBrainSettingsView(store: store) } }
        }
    }
}

private struct KnowledgeManagementView: View {
    @ObservedObject var store: ThoughtStore
    @State private var filter: KnowledgeDraftReviewStatus?
    @State private var query = ""
    private var drafts: [KnowledgeDraft] { store.knowledgeDrafts.filter { filter == nil || $0.reviewStatus == filter } }
    var body: some View {
        List {
            Section { NavigationLink { KnowledgeQualityView(store:store) } label: { Label("Quality",systemImage:"checkmark.seal") } }
            Section("Review Analytics") { ForEach([KnowledgeLifecycleEventType.approved,.rejected,.promoted],id:\.rawValue) { type in LabeledContent(type.rawValue,value:"\(store.knowledgeLifecycleEvents.filter { $0.type == type }.count)") } }
            Section {
                Picker("Status", selection:$filter) { Text("All").tag(Optional<KnowledgeDraftReviewStatus>.none); ForEach(KnowledgeDraftReviewStatus.allCases,id:\.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }
                TextField("Draftを検索",text:$query).textInputAutocapitalization(.never).onSubmit { store.loadKnowledge(search:query) }
                if !query.isEmpty { Button("検索をクリア") { query=""; store.loadKnowledge() } }
            }
            Section("Drafts") { if drafts.isEmpty { Text("Draftはありません").foregroundStyle(.secondary) }; ForEach(drafts) { draft in NavigationLink { KnowledgeDraftReviewView(store:store,draftID:draft.id) } label: { VStack(alignment:.leading,spacing:4) { Text(draft.title).font(.headline); Text("\(draft.type.displayName) · \(draft.source.displayName)").font(.caption); Text("\(draft.reviewStatus.rawValue) · \(draft.syncStatus.rawValue)").font(.caption2).foregroundStyle(.secondary); Text("作成 \(draft.createdAt.formatted())").font(.caption2).foregroundStyle(.secondary); Text("更新 \(draft.updatedAt.formatted())").font(.caption2).foregroundStyle(.secondary) } } } }
            Section("Knowledge") { if store.knowledgeDocuments.isEmpty { Text("正式Knowledgeはありません").foregroundStyle(.secondary) }; ForEach(store.knowledgeDocuments) { document in NavigationLink { KnowledgeDocumentDetailView(store:store,documentID:document.id) } label: { VStack(alignment:.leading) { Text(document.title); Text("\(document.status.rawValue) · \(document.path)").font(.caption).foregroundStyle(.secondary) } } } }
        }.navigationTitle("Knowledge").onAppear { store.loadKnowledge() }
    }
}

private struct KnowledgeDocumentDetailView: View {
    @ObservedObject var store:ThoughtStore; let documentID:UUID
    private var document:KnowledgeDocument? { store.knowledgeDocuments.first{$0.id==documentID} }
    var body: some View { List { if let document { Section("Metadata") { LabeledContent("Source",value:document.source.displayName); LabeledContent("Status",value:document.status.rawValue); LabeledContent("Path",value:document.path); LabeledContent("Tags",value:document.tags.joined(separator:", ")); LabeledContent("Updated",value:document.updatedAt.formatted()); LabeledContent("Used by AI",value:"\(document.retrievalCount) times"); LabeledContent("Last used",value:document.lastRetrievedAt?.formatted() ?? "未使用"); if let id=document.supersededByKnowledgeID { LabeledContent("Superseded by",value:id.uuidString) } }; Section("Markdown") { Text(document.markdown).font(.system(.caption,design:.monospaced)).textSelection(.enabled) }; if document.status == .active { Section { Button("Archive",role:.destructive) { store.archiveKnowledge(document) } } } } }.navigationTitle(document?.title ?? "Knowledge").onAppear { store.loadKnowledge() } }
}

private struct KnowledgeQualityView: View {
    @ObservedObject var store:ThoughtStore
    var body: some View { List {
        Section { Button("Analyze Knowledge") { store.analyzeKnowledgeQuality() }; Text("ローカル解析のみ。Knowledge本文・状態を自動変更せず、AI APIも呼びません。").font(.footnote).foregroundStyle(.secondary) }
        candidateSection("Duplicate Candidates",type:.duplicate)
        candidateSection("Similar Knowledge",type:.similar)
        candidateSection("Stale Candidates",type:.stale)
        Section("Recently Used") { ForEach(store.knowledgeDocuments.filter{$0.lastRetrievedAt != nil}.sorted{$0.lastRetrievedAt! > $1.lastRetrievedAt!}.prefix(10)) { document in NavigationLink { KnowledgeDocumentDetailView(store:store,documentID:document.id) } label: { VStack(alignment:.leading) { Text(document.title); Text("\(document.retrievalCount) uses · \(document.lastRetrievedAt?.formatted() ?? "")").font(.caption).foregroundStyle(.secondary) } } } }
        if let message=store.knowledgeDraftMessage { Section { Text(message).foregroundStyle(.secondary) } }
    }.navigationTitle("Knowledge Quality").onAppear { store.loadKnowledge() } }
    @ViewBuilder private func candidateSection(_ title:String,type:KnowledgeQualityCandidateType)->some View { Section(title) { let values=store.knowledgeQualityCandidates.filter{$0.type==type && $0.status == .open}; if values.isEmpty { Text("候補なし").foregroundStyle(.secondary) }; ForEach(values) { candidate in VStack(alignment:.leading,spacing:8) { if let first=store.knowledgeDocuments.first(where:{$0.id==candidate.knowledgeID}) { Text(first.title).font(.headline); Text("\(first.source.displayName) · \(first.updatedAt.formatted())").font(.caption) }; if let relatedID=candidate.relatedKnowledgeID,let second=store.knowledgeDocuments.first(where:{$0.id==relatedID}) { Text("↔ \(second.title)").font(.subheadline); Text("\(second.source.displayName) · \(second.updatedAt.formatted())").font(.caption); Text(candidate.score >= 0.75 ? "High similarity" : "Medium similarity").font(.caption.weight(.semibold)); NavigationLink("Compare") { KnowledgeCompareView(store:store,candidate:candidate) }; Button("Create Merge Draft") { store.createMergeDraft(candidate) } }; Text(candidate.reason).font(.caption).foregroundStyle(.secondary); Button("Dismiss") { store.dismissQualityCandidate(candidate) } } } } }
}

private struct KnowledgeCompareView: View {
    @ObservedObject var store:ThoughtStore; let candidate:KnowledgeQualityCandidate
    @State private var confirmsSupersede=false
    private var first:KnowledgeDocument? { store.knowledgeDocuments.first{$0.id==candidate.knowledgeID} }; private var second:KnowledgeDocument? { guard let id=candidate.relatedKnowledgeID else{return nil}; return store.knowledgeDocuments.first{$0.id==id} }
    var body: some View { List { if let first { comparison(first,label:"Knowledge A") }; if let second { comparison(second,label:"Knowledge B") }; if let first,let second,first.status == .active,second.status == .active { Section("Actions") { Button("AをBでSupersede",role:.destructive) { confirmsSupersede=true }; Button("Create Merge Draft") { store.createMergeDraft(candidate) } } } }.navigationTitle("Compare").confirmationDialog("Knowledge AをBでSupersedeしますか？",isPresented:$confirmsSupersede,titleVisibility:.visible) { Button("Supersede",role:.destructive) { if let first,let second { store.supersedeKnowledge(first,by:second) } }; Button("キャンセル",role:.cancel){} } }
    @ViewBuilder private func comparison(_ document:KnowledgeDocument,label:String)->some View { Section(label) { Text(document.title).font(.headline); LabeledContent("Source",value:document.source.displayName); LabeledContent("Created",value:document.createdAt.formatted()); LabeledContent("Updated",value:document.updatedAt.formatted()); LabeledContent("Tags",value:document.tags.joined(separator:", ")); Text(document.markdown).font(.system(.caption,design:.monospaced)).textSelection(.enabled) } }
}

private struct KnowledgeDraftReviewView: View {
    @ObservedObject var store: ThoughtStore
    let draftID: UUID
    @State private var edited: KnowledgeDraft?
    @State private var confirmsPromotion=false
    private var current: KnowledgeDraft? { edited ?? store.knowledgeDrafts.first { $0.id == draftID } }
    var body: some View {
        Form {
            if var draft=current {
                Section("Review") { TextField("Title",text:Binding(get:{ edited?.title ?? draft.title },set:{ edited = edited ?? draft; edited?.title=$0 })); Picker("Type",selection:Binding(get:{ edited?.type ?? draft.type },set:{ edited = edited ?? draft; edited?.type=$0 })) { ForEach(KnowledgeDraftType.allCases,id:\.self) { Text($0.displayName).tag($0) } }; TextField("Project",text:Binding(get:{ edited?.project ?? draft.project },set:{ edited = edited ?? draft; edited?.project=$0 })); TextField("Tags（カンマ区切り）",text:Binding(get:{ (edited?.tags ?? draft.tags).joined(separator:", ") },set:{ edited = edited ?? draft; edited?.tags=$0.split(separator:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }.filter { !$0.isEmpty } })); TextEditor(text:Binding(get:{ edited?.body ?? draft.body },set:{ edited = edited ?? draft; edited?.body=$0 })).frame(minHeight:240).disabled(draft.reviewStatus == .promoted); if edited != nil && draft.reviewStatus != .promoted { Button("編集を保存") { if let edited { store.updateKnowledgeDraft(edited); self.edited=nil } } } }
                Section("Metadata") { LabeledContent("Source",value:draft.source.displayName); LabeledContent("Status",value:draft.reviewStatus.rawValue); LabeledContent("GitHub",value:draft.syncStatus.rawValue); LabeledContent("Draft path",value:draft.savedPath ?? "local"); if let path=draft.knowledgePath { LabeledContent("Knowledge path",value:path) }; LabeledContent("Created",value:draft.createdAt.formatted()); LabeledContent("Updated",value:draft.updatedAt.formatted()); if let id=draft.provenance.sourceID { LabeledContent("Source ID",value:id) }; if let persona=draft.provenance.personaID { LabeledContent("Persona ID",value:persona.uuidString) } }
                Section("Related Knowledge") { if draft.relatedDocuments.isEmpty { Text("なし") }; ForEach(Array(draft.relatedDocuments.enumerated()),id:\.offset) { Text("\($0.element.documentPath) > \($0.element.heading)") } }
                if draft.reviewStatus != .promoted { Section("Actions") { if draft.reviewStatus == .unreviewed || draft.reviewStatus == .rejected { Button("Approve") { store.reviewKnowledgeDraft(edited ?? draft,status:.approved); edited=nil } }; if draft.reviewStatus == .unreviewed || draft.reviewStatus == .approved { Button("Reject",role:.destructive) { store.reviewKnowledgeDraft(edited ?? draft,status:.rejected); edited=nil } }; if draft.reviewStatus == .approved { Button("Promote to Knowledge") { confirmsPromotion=true } } } }
                if let message=store.knowledgeDraftMessage { Section { Text(message).foregroundStyle(.green) } }; if let error=store.knowledgeDraftError { Section { Text(error).foregroundStyle(.red) } }
            }
        }.navigationTitle("Draft Review").onAppear { store.loadKnowledge() }.confirmationDialog("正式Knowledgeへ昇格しますか？",isPresented:$confirmsPromotion,titleVisibility:.visible) { Button("Promote") { if let current { Task { await store.promoteKnowledgeDraft(current) } } }; Button("キャンセル",role:.cancel) {} } message: { if let current { Text("Title: \(current.title)\nDestination: \(KnowledgeDocumentPath.targetPath(date:Date(),title:current.title))\nSource: \(current.source.displayName)") } }
    }
}

private struct AIReplyRequestView: View {
    @ObservedObject var store: ThoughtStore
    let thought: Thought
    @Environment(\.dismiss) private var dismiss
    @State private var userRequest = "このThoughtに返信してください"
    var body: some View {
        NavigationStack {
            List {
                if let persona = store.mentionedPersonasByThoughtID[thought.id] {
                    Section("返信するAI") { HStack { PersonaIcon(persona: persona, size: 40); VStack(alignment: .leading) { Text(persona.displayName).font(.headline); Text(store.aiConfigurations[persona.id]?.role ?? "").font(.caption).foregroundStyle(.secondary) } } }
                    Section("対象Thought") { Text(thought.body) }
                    Section("依頼") { TextField("AIへの今回の依頼", text: $userRequest, axis: .vertical).lineLimit(2...5) }
                    if let configuration = store.aiConfigurations[persona.id] { Section("指示") { Text(configuration.instructions) } }
                }
                Section { Text("確認を押すまでAI通信は行いません。").font(.footnote).foregroundStyle(.secondary) }
                if let error = store.aiReplyError { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("AIに返信を依頼")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("確認") { store.prepareAIReply(to: thought, userRequest: userRequest) }.disabled(userRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
            .sheet(item: $store.aiReplyPreview) { AIReplyPreviewView(store: store, preview: $0, parentDismiss: dismiss) }
        }
    }
}

private struct AIReplyPreviewView: View {
    @ObservedObject var store: ThoughtStore
    let preview: AIThoughtReplyPreview
    let parentDismiss: DismissAction
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("返信するAI") { Text(preview.persona.displayName); LabeledContent("役割", value: preview.configuration.role) }
                Section("対象Thought") { Text(preview.targetThought.body) }
                Section("依頼") { Text(preview.userRequest) }
                Section("会話文脈") {
                    ForEach(preview.context.entries, id: \.thought.id) { entry in
                        HStack(alignment: .top, spacing: 10) {
                            PersonaIcon(persona: entry.author, size: 32)
                            VStack(alignment: .leading, spacing: 4) { Text(entry.author.displayName).font(.subheadline.weight(.semibold)); Text(entry.author.kind == .human ? "Human" : "AI").font(.caption2).foregroundStyle(.secondary); Text(entry.thought.body) }
                        }
                    }
                }
                Section("External Brain") {
                    if let brain = preview.externalBrain {
                        LabeledContent("使用Persona", value: preview.persona.displayName)
                        LabeledContent("AGENT.md", value: brain.agentPath)
                        VStack(alignment: .leading, spacing: 4) { Text("Retrieval Route").font(.caption).foregroundStyle(.secondary); ForEach(Array(brain.routes.enumerated()), id: \.offset) { Text("\($0.offset + 1). \($0.element)") } }
                        if brain.chunks.isEmpty { Text("参照資料なし").foregroundStyle(.secondary) }
                        ForEach(Array(brain.chunks.enumerated()), id: \.offset) { item in
                            VStack(alignment: .leading, spacing: 4) { Text(item.element.documentPath).font(.subheadline.weight(.semibold)); Text(item.element.heading).font(.caption).foregroundStyle(.secondary); Text(item.element.excerpt).font(.caption).lineLimit(6) }
                        }
                    } else { Text("利用なし").foregroundStyle(.secondary) }
                }
                Section("最終payload") { Text(preview.request.prompt).font(.caption).textSelection(.enabled) }
                Section("生成元") { LabeledContent("Provider", value: ReviewSummaryAIConfiguration.providerName); LabeledContent("Model", value: ReviewSummaryAIConfiguration.modelName) }
                if let error = store.aiReplyError { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("送信前プレビュー")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { store.cancelAIReplyPreview(); dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(store.isGeneratingAIReply ? "生成中…" : "送信") { Task { await store.generateAIReply(from: preview); if store.aiReplyError == nil { dismiss(); parentDismiss() } } }.disabled(store.isGeneratingAIReply) } }
        }
    }
}

struct PersonaIcon: View {
    let persona: Persona
    let size: CGFloat

    var body: some View {
        Group {
            if let data = persona.iconData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct PersonaManagementView: View {
    @ObservedObject var store: ThoughtStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsHumanEditor = false
    @State private var showsNewAIEditor = false
    @State private var editingAI: Persona?
    @State private var postingAI: Persona?

    var body: some View {
        NavigationStack {
            List {
                Section("あなた") {
                    Button { showsHumanEditor = true } label: { personaRow(store.defaultHumanPersona) }.buttonStyle(.plain)
                }
                Section("AI Personas") {
                    ForEach(store.personas.filter { $0.kind == .ai }) { persona in
                        VStack(alignment: .leading, spacing: 8) {
                            Button { editingAI = persona } label: { personaRow(persona) }.buttonStyle(.plain)
                            Button("このAIに投稿を依頼") { postingAI = persona }.buttonStyle(.bordered)
                        }.padding(.vertical, 4)
                    }
                    Button { showsNewAIEditor = true } label: { Label("AI Personaを追加", systemImage: "plus.circle") }
                        .accessibilityIdentifier("addAIPersonaButton")
                }
                Section { Text("AI Personaは投稿者の土台です。この段階ではAI通信や自動投稿は行いません。").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Personas")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
            .sheet(isPresented: $showsHumanEditor) { ProfileEditorView(store: store) }
            .sheet(isPresented: $showsNewAIEditor) { AIPersonaEditorView(store: store, persona: nil) }
            .sheet(item: $editingAI) { AIPersonaEditorView(store: store, persona: $0) }
            .sheet(item: $postingAI) { AIPostRequestView(store: store, persona: $0) }
        }
    }

    private func personaRow(_ persona: Persona) -> some View {
        HStack(spacing: 12) {
            PersonaIcon(persona: persona, size: 44)
            VStack(alignment: .leading) { Text(persona.displayName).foregroundStyle(.primary); Text(persona.kind == .human ? "人間" : "AI").font(.caption).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.contentShape(Rectangle())
    }
}

private struct AIPersonaEditorView: View {
    @ObservedObject var store: ThoughtStore
    let persona: Persona?
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var iconData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var role: String
    @State private var instructions: String
    @State private var brainEnabled: Bool
    @State private var agentPath: String
    @State private var maxChunks: Int

    init(store: ThoughtStore, persona: Persona?) {
        self.store = store; self.persona = persona
        _displayName = State(initialValue: persona?.displayName ?? "")
        _iconData = State(initialValue: persona?.iconData)
        let configuration = persona.flatMap { store.aiConfigurations[$0.id] }
        _role = State(initialValue: configuration?.role ?? "")
        _instructions = State(initialValue: configuration?.instructions ?? "")
        let brain = persona.map { store.externalBrainManager.configuration(for: $0.id) }
        _brainEnabled = State(initialValue: brain?.enabled ?? false)
        _agentPath = State(initialValue: brain?.agentPath ?? "")
        _maxChunks = State(initialValue: brain?.maxRetrievedChunks ?? 5)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("アイコン") {
                    HStack { Spacer(); PersonaIcon(persona: previewPersona, size: 96); Spacer() }
                    PhotosPicker(selection: $selectedItem, matching: .images) { Label("写真を選ぶ", systemImage: "photo") }
                    if iconData != nil { Button("アイコンを削除", role: .destructive) { iconData = nil } }
                }
                Section("表示名") { TextField("AI Persona名", text: $displayName) }
                Section("役割") { TextField("例：アイデアを広げる相棒", text: $role, axis: .vertical) }
                Section("指示") { TextField("口調、視点、避けることなど", text: $instructions, axis: .vertical).lineLimit(3...8) }
                Section("External Brain") {
                    Toggle("External Brain", isOn: $brainEnabled)
                    TextField("personas/architect/AGENT.md", text: $agentPath).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Stepper("最大参照 \(maxChunks)件", value: $maxChunks, in: 1...5)
                }
                if let persona { Section { Button("AI Personaを無効化", role: .destructive) { store.deactivateAIPersona(persona); dismiss() } } }
            }
            .navigationTitle(persona == nil ? "AI Personaを追加" : "AI Personaを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let saved = persona.map { store.updateAIPersona($0, displayName: displayName, iconData: iconData, role: role, instructions: instructions) }
                            ?? store.createAIPersona(displayName: displayName, iconData: iconData, role: role, instructions: instructions, externalBrainEnabled: brainEnabled, agentPath: agentPath, maxRetrievedChunks: maxChunks)
                        if saved { if let persona { store.externalBrainManager.savePersona(.init(personaID: persona.id, enabled: brainEnabled, agentPath: agentPath, maxRetrievedChunks: maxChunks)) }; dismiss() }
                    }.disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || displayName.count > 40 || role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (brainEnabled && !ExternalBrainPath.isSafe(agentPath)))
                }
            }
            .onChange(of: selectedItem) { item in
                Task { guard let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }; iconData = image.squareJPEG(maxPixels: 512, quality: 0.82) }
            }
        }
    }

    private var previewPersona: Persona { Persona(id: persona?.id ?? UUID(), displayName: displayName, kind: .ai, iconData: iconData, iconMIMEType: iconData == nil ? nil : "image/jpeg") }
}

private struct AIPostRequestView: View {
    @ObservedObject var store: ThoughtStore
    let persona: Persona
    @Environment(\.dismiss) private var dismiss
    @State private var userRequest = ""

    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { PersonaIcon(persona: persona, size: 44); VStack(alignment: .leading) { Text(persona.displayName).font(.headline); Text(store.aiConfigurations[persona.id]?.role ?? "").font(.caption).foregroundStyle(.secondary) } } }
                Section("依頼") { TextField("このAIに考えて投稿してほしいこと", text: $userRequest, axis: .vertical).lineLimit(3...8) }
                Section { Text("確認画面で最終payloadを確認し、送信を押すまでAI通信も投稿も行いません。").font(.footnote).foregroundStyle(.secondary) }
                if let error = store.aiPostError { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("AIに投稿を依頼")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("確認") { store.prepareAIPost(persona: persona, userRequest: userRequest) }.disabled(userRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .sheet(item: $store.aiPostPreview) { AIPostPreviewView(store: store, preview: $0) }
        }
    }
}

private struct AIPostPreviewView: View {
    @ObservedObject var store: ThoughtStore
    let preview: AIPostPreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("投稿者") { Text(preview.persona.displayName); LabeledContent("役割", value: preview.configuration.role) }
                Section("依頼") { Text(preview.userRequest) }
                Section("External Brain") {
                    if let brain = preview.externalBrain {
                        LabeledContent("AGENT.md", value: brain.agentPath)
                        VStack(alignment: .leading, spacing: 4) { Text("選択Route").font(.caption).foregroundStyle(.secondary); ForEach(Array(brain.routes.enumerated()), id: \.offset) { Text("\($0.offset + 1). \($0.element)") } }
                        if brain.chunks.isEmpty { Text("参照資料なし").foregroundStyle(.secondary) }
                        ForEach(Array(brain.chunks.enumerated()), id: \.offset) { item in
                            VStack(alignment: .leading, spacing: 4) { Text(item.element.documentPath).font(.subheadline.weight(.semibold)); Text(item.element.heading).font(.caption).foregroundStyle(.secondary); Text(item.element.excerpt).font(.caption).lineLimit(6) }
                        }
                    } else { Text("利用なし").foregroundStyle(.secondary) }
                }
                Section("最終payload") { Text(preview.request.prompt).font(.caption).textSelection(.enabled) }
                if let error = store.aiPostError { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("送信前プレビュー")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { store.cancelAIPostPreview(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.isGeneratingAIPost ? "生成中…" : "送信") { Task { await store.generateAIPost(from: preview); if store.aiPostError == nil { dismiss() } } }.disabled(store.isGeneratingAIPost) }
            }
        }
    }
}

private struct ProfileEditorView: View {
    @ObservedObject var store: ThoughtStore
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var iconData: Data?
    @State private var selectedItem: PhotosPickerItem?

    init(store: ThoughtStore) {
        self.store = store
        _displayName = State(initialValue: store.defaultHumanPersona.displayName)
        _iconData = State(initialValue: store.defaultHumanPersona.iconData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("アイコン") {
                    HStack { Spacer(); PersonaIcon(persona: previewPersona, size: 96); Spacer() }
                    PhotosPicker(selection: $selectedItem, matching: .images) { Label("写真を選ぶ", systemImage: "photo") }
                    if iconData != nil { Button("アイコンを削除", role: .destructive) { iconData = nil } }
                }
                Section("表示名") { TextField("自分", text: $displayName).textInputAutocapitalization(.never) }
                Section { Text("プロフィールは端末内だけに保存され、既存のThoughtにも同じ名前とアイコンが表示されます。").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { if store.updateDefaultHumanPersona(displayName: displayName, iconData: iconData) { dismiss() } }
                        .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || displayName.count > 40)
                }
            }
            .onChange(of: selectedItem) { item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                    iconData = image.squareJPEG(maxPixels: 512, quality: 0.82)
                }
            }
        }
    }

    private var previewPersona: Persona {
        Persona(id: store.defaultHumanPersona.id, displayName: displayName, kind: .human, iconData: iconData, iconMIMEType: iconData == nil ? nil : "image/jpeg")
    }
}

private extension UIImage {
    func squareJPEG(maxPixels: CGFloat, quality: CGFloat) -> Data? {
        let side = min(size.width, size.height)
        guard side > 0 else { return nil }
        let targetSide = min(maxPixels, side)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSide, height: targetSide))
        let output = renderer.image { _ in
            let scale = targetSide / side
            let drawnSize = CGSize(width: size.width * scale, height: size.height * scale)
            draw(in: CGRect(x: (targetSide - drawnSize.width) / 2, y: (targetSide - drawnSize.height) / 2, width: drawnSize.width, height: drawnSize.height))
        }
        return output.jpegData(compressionQuality: quality)
    }
}

enum ThoughtDateText {
    static func string(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨日 \(time)"
        }
        return date.formatted(.dateTime.month(.defaultDigits).day().hour().minute())
    }
}

#Preview {
    TimelineView(store: ThoughtStore(repository: MemoryThoughtRepository(records: [
        Thought(body: "AIを入れる前に、まず毎日使える入力体験を完成させたい。"),
        Thought(body: "SQLite化まで終わったので、次はUIをもっと軽くしたい。", createdAt: .now.addingTimeInterval(-3_600))
    ])), presentedRoute: .constant(nil))
}
