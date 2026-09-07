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

private struct ThoughtRow: View {
    let thought: Thought
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(thought.body)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            HStack(alignment: .center, spacing: 8) {
                Text(ThoughtDateText.string(for: thought.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Menu {
                    Button("削除", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("Thoughtの操作")
                .accessibilityHint("削除メニューを表示します")
                .accessibilityIdentifier("thoughtMenu_\(thought.id.uuidString)")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
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
