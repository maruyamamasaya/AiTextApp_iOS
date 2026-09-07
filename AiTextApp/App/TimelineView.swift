import SwiftUI

struct TimelineView: View {
    @ObservedObject var store: ThoughtStore
    @FocusState private var composerIsFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    composer

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
        VStack(alignment: .leading, spacing: 10) {
            Text("今なに考えてる？")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if store.draft.isEmpty {
                    Text("Thoughtを入力")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: Binding(get: { store.draft }, set: store.updateDraft))
                    .focused($composerIsFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .accessibilityLabel("Thoughtを入力")
                    .accessibilityHint("140文字以内で入力します")
                    .accessibilityIdentifier("thoughtComposer")
            }
            .frame(minHeight: 104, maxHeight: 152)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { composerIsFocused = true }

            HStack(alignment: .center, spacing: 12) {
                characterCount
                Spacer(minLength: 8)
                Button("投稿") {
                    if store.post() { composerIsFocused = false }
                }
                .font(.body.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.regular)
                .disabled(!store.canPost)
                .accessibilityLabel("Thoughtを投稿")
                .accessibilityHint(store.canPost ? "入力したThoughtを投稿します" : "文字を入力すると投稿できます")
                .accessibilityIdentifier("postButton")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var characterCount: some View {
        Text("\(store.draft.count) / \(ThoughtDraft.characterLimit)")
            .font(.caption.monospacedDigit())
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
