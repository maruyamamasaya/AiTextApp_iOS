import SwiftUI

struct QuickCaptureView: View {
    @ObservedObject var store: ThoughtStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var isSubmitting = false
    @State private var confirmsDiscard = false
    @State private var postErrorMessage: String?
    @State private var mentionedPersona: Persona?
    @FocusState private var editorIsFocused: Bool

    private var canPost: Bool { ThoughtDraft.validBody(from: draft) != nil && !isSubmitting }
    private var hasDraft: Bool { !draft.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: Binding(
                    get: { draft },
                    set: { draft = $0 }
                ))
                .focused($editorIsFocused)
                .font(.body)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Quick Capture Thoughtを入力")
                .accessibilityHint("140文字以内で入力します")
                .accessibilityIdentifier("quickCaptureEditor")

                HStack {
                    Menu {
                        ForEach(store.personas.filter { $0.kind == .ai }) { persona in Button("@\(persona.displayName)") { mentionedPersona = persona } }
                        if mentionedPersona != nil { Button("メンションを外す", role: .destructive) { mentionedPersona = nil } }
                    } label: { Text(mentionedPersona.map { "@\($0.displayName)" } ?? "@").lineLimit(1) }
                    .disabled(store.personas.allSatisfy { $0.kind != .ai })
                    .accessibilityLabel(mentionedPersona.map { "\($0.displayName)をメンション中" } ?? "AI Personaをメンション")
                    .accessibilityIdentifier("quickCaptureMentionMenu")
                    Text("\(draft.count) / \(ThoughtDraft.characterLimit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(draft.count > ThoughtDraft.characterLimit ? Color.red : (draft.count >= 130 ? Color.orange : Color.secondary))
                        .accessibilityLabel("文字数 \(draft.count)、上限 \(ThoughtDraft.characterLimit)")
                        .accessibilityIdentifier("quickCaptureCharacterCount")
                    Spacer()
                    Button("投稿", action: submit)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(!canPost)
                        .accessibilityIdentifier("quickCapturePostButton")
                }
            }
            .padding(16)
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: cancel)
                        .accessibilityIdentifier("quickCaptureCancelButton")
                }
            }
            .alert("入力中のThoughtを破棄しますか？", isPresented: $confirmsDiscard) {
                Button("続ける", role: .cancel) {}
                Button("破棄", role: .destructive) { dismiss() }
                    .accessibilityIdentifier("confirmQuickCaptureDiscard")
            } message: {
                Text("投稿していない入力内容は元に戻せません。")
            }
            .alert("投稿できませんでした", isPresented: postErrorIsPresented) {
                Button("OK") { postErrorMessage = nil }
            } message: {
                Text(postErrorMessage ?? "入力内容を保持しています。もう一度お試しください。")
            }
        }
        .interactiveDismissDisabled(hasDraft)
        .onAppear {
            DispatchQueue.main.async { editorIsFocused = true }
        }
    }

    private func submit() {
        guard canPost else { return }
        isSubmitting = true
        if store.post(draft, mentioning: mentionedPersona) {
            draft = ""
            mentionedPersona = nil
            dismiss()
        } else {
            isSubmitting = false
            postErrorMessage = store.errorMessage ?? "入力内容を保持しています。もう一度お試しください。"
            store.errorMessage = nil
        }
    }

    private func cancel() {
        if hasDraft { confirmsDiscard = true }
        else { dismiss() }
    }

    private var postErrorIsPresented: Binding<Bool> {
        Binding(
            get: { postErrorMessage != nil },
            set: { if !$0 { postErrorMessage = nil } }
        )
    }
}
