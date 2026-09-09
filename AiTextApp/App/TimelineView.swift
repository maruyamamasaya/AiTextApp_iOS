import SwiftUI

struct TimelineView: View {
    @ObservedObject var store: ThoughtStore
    @FocusState private var composerIsFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if store.thoughts.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.thoughts) { thought in
                            ThoughtRow(thought: thought) {
                                store.requestDeletion(of: thought)
                            }

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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        HistoryReviewView(store: store)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("History Reviewを開く")
                    .accessibilityHint("日付や期間から過去のThoughtを振り返ります")
                    .accessibilityIdentifier("historyReviewButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Markdownを共有") { store.export(.markdown) }
                            .accessibilityIdentifier("exportMarkdownButton")
                        Button("JSONを共有") { store.export(.json) }
                            .accessibilityIdentifier("exportJSONButton")
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("ThoughtをExport")
                    .accessibilityHint("MarkdownまたはJSONとして共有します")
                    .accessibilityIdentifier("exportMenu")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let manager = store.externalBackupManager {
                        NavigationLink {
                            BackupManagementView(manager: manager)
                        } label: {
                            Image(systemName: "externaldrive.badge.timemachine")
                        }
                        .accessibilityLabel("バックアップ管理を開く")
                        .accessibilityIdentifier("backupManagementButton")
                    }
                }
            }
            .sheet(item: $store.exportArtifact) { artifact in
                ShareSheet(url: artifact.url, onFailure: store.sharingFailed)
            }
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

private struct HistoryReviewView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case today = "今日"
        case yesterday = "昨日"
        case sevenDays = "過去7日"
        case date = "日付指定"
        var id: Self { self }
    }

    @ObservedObject var store: ThoughtStore
    @State private var filter: Filter = .today
    @State private var selectedDate = Date()

    private var interval: DateInterval {
        switch filter {
        case .today: ThoughtReviewPeriod.today(containing: Date())
        case .yesterday: ThoughtReviewPeriod.yesterday(containing: Date())
        case .sevenDays: ThoughtReviewPeriod.pastSevenDays(containing: Date())
        case .date: ThoughtReviewPeriod.day(containing: selectedDate)
        }
    }

    private var groupedThoughts: [(date: Date, thoughts: [Thought])] {
        Dictionary(grouping: store.reviewThoughts) { Calendar.current.startOfDay(for: $0.createdAt) }
            .map { (date: $0.key, thoughts: $0.value) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("期間", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("historyReviewFilter")
                    Spacer()
                    Text("\(store.reviewThoughts.count) Thoughts")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("historyReviewCount")
                }

                if filter == .date {
                    DatePicker(
                        "振り返る日",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("historyReviewDatePicker")
                }

                Button {
                    store.prepareReviewSummary(in: interval)
                } label: {
                    HStack(spacing: 8) {
                        if store.isGeneratingReviewSummary { ProgressView() }
                        Text(store.reviewSummary == nil ? "AIで要約" : "もう一度AIで要約")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.reviewThoughts.isEmpty || store.isGeneratingReviewSummary)
                .accessibilityIdentifier("reviewAISummaryButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
            .overlay(alignment: .bottom) { Divider() }

            if store.reviewThoughts.isEmpty {
                VStack(spacing: 6) {
                    Text(filter == .today ? "今日はまだThoughtがありません" : "この期間にThoughtはありません")
                        .font(.headline)
                    Text("別の日付や期間も振り返れます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("historyReviewEmptyState")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if let summary = store.reviewSummary {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("AI要約", systemImage: "sparkles")
                                        .font(.headline)
                                    Spacer()
                                    NavigationLink {
                                        ReviewSummaryHistoryView(
                                            store: store,
                                            interval: interval
                                        )
                                    } label: {
                                        Text("履歴 \(store.reviewSummaries.count)件")
                                            .font(.caption)
                                    }
                                    .accessibilityIdentifier("reviewAISummaryHistoryButton")
                                }
                                Text(summary.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(summary.content)
                                    .font(.body)
                                    .textSelection(.enabled)
                                if summary.provider == "mock" {
                                    Text("Mockによる表示です。Firebase接続後に実AIへ切り替わります。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(16)
                            .accessibilityIdentifier("reviewAISummaryResult")
                        }

                        if let message = store.reviewSummaryError {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                                Button("再試行") { store.prepareReviewSummary(in: interval) }
                                    .disabled(store.isGeneratingReviewSummary)
                                    .accessibilityIdentifier("reviewAISummaryRetryButton")
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }

                        ForEach(groupedThoughts, id: \.date) { group in
                            Section {
                                ForEach(group.thoughts) { thought in
                                    reviewRow(thought)
                                    if thought.id != group.thoughts.last?.id {
                                        Divider().padding(.leading, 58)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(ReviewDateText.heading(for: group.date))
                                        .font(.headline)
                                    Spacer()
                                    Text("\(group.thoughts.count) Thoughts")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(.regularMaterial)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .onChange(of: filter) { _ in reload() }
        .onChange(of: selectedDate) { _ in if filter == .date { reload() } }
        .onChange(of: store.thoughts.map(\.id)) { _ in reload() }
        .sheet(item: Binding(
            get: { store.reviewSummaryPreview },
            set: { if $0 == nil { store.cancelReviewSummaryPreview() } }
        )) { preview in
            ReviewSummaryPreviewView(
                preview: preview,
                onCancel: { store.cancelReviewSummaryPreview() },
                onSubmit: {
                    store.cancelReviewSummaryPreview()
                    Task { await store.generateReviewSummary(from: preview) }
                }
            )
        }
    }

    private func reload() {
        store.loadReview(in: interval)
    }

    private func reviewRow(_ thought: Thought) -> some View {
        NavigationLink {
            ThoughtDetailView(store: store, initialThoughtID: thought.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(thought.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text(thought.body)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let count = store.reviewContinuationCounts[thought.id], count > 0 {
                        Text("↳ 続き \(count)件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(thought.createdAt.formatted(date: .omitted, time: .shortened))、\(thought.body)" + continuationAccessibilityText(for: thought))
        .accessibilityHint("ダブルタップしてThought Detailを開きます")
        .accessibilityIdentifier("historyReviewThought_\(thought.id.uuidString)")
    }

    private func continuationAccessibilityText(for thought: Thought) -> String {
        guard let count = store.reviewContinuationCounts[thought.id], count > 0 else { return "" }
        return "、続き\(count)件"
    }
}

private struct ReviewSummaryPreviewView: View {
    let preview: ReviewSummaryPreview
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("送信内容の確認", systemImage: "sparkles")
                                .font(.headline)
                            Text("以下のThought本文がAIサービスへ送信されます。自動送信は行わず、この画面で送信を選んだ時だけ実行します。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            previewMetadata("対象期間", value: periodText)
                            previewMetadata("対象Thought", value: "\(preview.thoughtCount)件")
                            previewMetadata("送信予定", value: "\(preview.payloadCharacterCount)文字")
                            Text("送信予定文字数には、以下の本文と要約形式の指示文を含みます。本文は合計\(preview.thoughtCharacterCount)文字です。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("reviewSummaryPreviewMetadata")

                        VStack(alignment: .leading, spacing: 0) {
                            Text("送信するThought")
                                .font(.headline)
                                .padding(.bottom, 8)
                            ForEach(preview.thoughts) { thought in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(thought.createdAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, alignment: .leading)
                                    Text(thought.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 10)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("reviewSummaryPreviewThought_\(thought.id.uuidString)")
                                if thought.id != preview.thoughts.last?.id { Divider() }
                            }
                        }
                    }
                    .padding(16)
                }

                Divider()
                Button("AIへ送信して要約", action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .accessibilityIdentifier("confirmReviewSummarySubmission")
            }
            .navigationTitle("AI要約プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                        .accessibilityIdentifier("cancelReviewSummarySubmission")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func previewMetadata(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private var periodText: String {
        let start = preview.interval.start.formatted(date: .abbreviated, time: .omitted)
        let inclusiveEnd = preview.interval.end.addingTimeInterval(-1)
            .formatted(date: .abbreviated, time: .omitted)
        return start == inclusiveEnd ? start : "\(start)〜\(inclusiveEnd)"
    }
}

private struct ReviewSummaryHistoryView: View {
    @ObservedObject var store: ThoughtStore
    let interval: DateInterval
    @State private var deletionCandidate: ReviewSummary?
    @State private var showingDeletionConfirmation = false

    private var summaries: [ReviewSummary] { store.reviewSummaries }

    var body: some View {
        Group {
            if summaries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("AI要約履歴はありません")
                        .font(.headline)
                    Text("この期間でAI要約を作成すると、ここに履歴が残ります。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
                .multilineTextAlignment(.center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text(periodText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)

                        if let message = store.reviewSummaryDeletionError {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .accessibilityIdentifier("reviewAISummaryDeletionError")
                        }

                        if let message = store.reviewSummaryExportError {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .accessibilityIdentifier("reviewAISummaryExportError")
                        }

                        ForEach(summaries) { summary in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(summary.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    if summary.id == summaries.first?.id {
                                        Text("最新")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.accentColor.opacity(0.12))
                                            .clipShape(Capsule())
                                            .accessibilityIdentifier("reviewAISummaryLatest")
                                    }
                                    Spacer()
                                    Menu {
                                        Button("Markdownを共有") {
                                            store.exportReviewSummary(id: summary.id, format: .markdown)
                                        }
                                        .accessibilityIdentifier("exportReviewSummaryMarkdown_\(summary.id.uuidString)")
                                        Button("JSONを共有") {
                                            store.exportReviewSummary(id: summary.id, format: .json)
                                        }
                                        .accessibilityIdentifier("exportReviewSummaryJSON_\(summary.id.uuidString)")
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .frame(width: 32, height: 32)
                                    }
                                    .accessibilityLabel("このAI要約をExport")
                                    .accessibilityHint("MarkdownまたはJSONとして共有します")
                                    .accessibilityIdentifier("exportReviewSummary_\(summary.id.uuidString)")
                                    Button(role: .destructive) {
                                        deletionCandidate = summary
                                        showingDeletionConfirmation = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .frame(width: 32, height: 32)
                                    }
                                    .accessibilityLabel("このAI要約を削除")
                                    .accessibilityHint("確認後、このAI要約だけを削除します")
                                    .accessibilityIdentifier("deleteReviewSummary_\(summary.id.uuidString)")
                                }

                                Text(summary.content)
                                    .font(.body)
                                    .textSelection(.enabled)

                                Text("対象 \(summary.thoughtCount) Thoughts ・ \(providerText(summary))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("reviewAISummaryHistoryItem_\(summary.id.uuidString)")
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("AI要約履歴")
        .navigationBarTitleDisplayMode(.inline)
        .alert("AI要約を削除しますか？", isPresented: $showingDeletionConfirmation, presenting: deletionCandidate) { summary in
            Button("キャンセル", role: .cancel) {
                deletionCandidate = nil
            }
            Button("削除", role: .destructive) {
                store.deleteReviewSummary(id: summary.id)
                deletionCandidate = nil
            }
        } message: { _ in
            Text("選択したAI要約だけを削除します。Thought原文と他のAI要約は削除されません。")
        }
    }

    private var periodText: String {
        let start = interval.start.formatted(date: .abbreviated, time: .omitted)
        let inclusiveEnd = interval.end.addingTimeInterval(-1)
            .formatted(date: .abbreviated, time: .omitted)
        return start == inclusiveEnd ? start : "\(start)〜\(inclusiveEnd)"
    }

    private func providerText(_ summary: ReviewSummary) -> String {
        if summary.provider == "mock" { return "Mock" }
        return "\(summary.provider) / \(summary.model)"
    }
}

private enum ReviewDateText {
    static func heading(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "今日" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "昨日" }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.year().month().day())
    }
}

private struct ThoughtDetailView: View {
    @ObservedObject var store: ThoughtStore
    let initialThoughtID: UUID
    @State private var currentThoughtID: UUID
    @State private var showsComposer = false
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
                        Button("続きを書く") {
                            showsComposer.toggle()
                            if showsComposer { composerIsFocused = true }
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .accessibilityLabel("このThoughtの続きを書く")
                        .accessibilityHint("\(currentThought.deletedAt == nil ? currentThought.body : "削除されたThought")の続きを作成します")
                        .accessibilityIdentifier("writeContinuationButton")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                    if showsComposer { continuationComposer(parent: currentThought) }
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
        .onAppear { store.loadHistory(for: currentThoughtID) }
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
}

private struct ThoughtRow: View {
    let thought: Thought
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            NavigationLink(value: thought.id) {
                VStack(alignment: .leading, spacing: 8) {
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
            .accessibilityLabel("Thought、\(thought.body)")
            .accessibilityHint("ダブルタップして詳細とHistoryを開きます")
            .accessibilityIdentifier("timelineThought_\(thought.id.uuidString)")

            Menu {
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
    ])))
}
