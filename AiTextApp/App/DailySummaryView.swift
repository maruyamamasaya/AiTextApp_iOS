import SwiftUI

struct DailySummarySections: View {
    let summary: DailySummary
    var body: some View {
        Section("概要") { Text(summary.content.overview) }
        valueSection("主なテーマ", summary.content.themes)
        if !summary.content.tagGroups.isEmpty {
            Section("タグ別") { ForEach(summary.content.tagGroups, id: \.tagName) { group in VStack(alignment: .leading, spacing: 4) { Text("#\(group.tagName)").font(.headline); Text(group.summary); if !group.themes.isEmpty { Text(group.themes.joined(separator: "、")).font(.caption).foregroundStyle(.secondary) }; Text("\(group.thoughtCount)件").font(.caption2).foregroundStyle(.secondary) } } }
        }
        if !summary.content.aiInteractions.isEmpty {
            Section("AIとの対話") { ForEach(summary.content.aiInteractions, id: \.personaName) { interaction in VStack(alignment: .leading, spacing: 4) { Text(interaction.personaName).font(.headline); Text(interaction.summary); if !interaction.topics.isEmpty { Text(interaction.topics.joined(separator: "、")).font(.caption).foregroundStyle(.secondary) } } } }
        }
        valueSection("思考パターン", summary.content.thoughtPatterns)
        valueSection("深掘りしていた内容", summary.content.deepDives)
        valueSection("悩み / 検討", summary.content.concerns)
        Section("思考の流れ") { Text(summary.content.thoughtFlow) }
        if !summary.content.timeOfDayInsights.isEmpty {
            Section("時間帯の傾向") { ForEach(summary.content.timeOfDayInsights, id: \.period) { value in VStack(alignment: .leading, spacing: 4) { Text(value.period).font(.headline); Text(value.insight) } } }
        }
        valueSection("継続候補", summary.content.continuationCandidates)
        valueSection("明日以降への持ち越し", summary.content.carryOvers)
        if !summary.content.existingTagCandidates.isEmpty || !summary.content.newTagCandidates.isEmpty {
            Section("タグ候補") { if !summary.content.existingTagCandidates.isEmpty { LabeledContent("既存タグ", value: summary.content.existingTagCandidates.joined(separator: "、")) }; if !summary.content.newTagCandidates.isEmpty { LabeledContent("AIの新規提案", value: summary.content.newTagCandidates.joined(separator: "、")) } }
        }
        Section("生成情報") {
            LabeledContent("生成日時", value: summary.createdAt.formatted())
            LabeledContent("生成元", value: "\(summary.provider) / \(summary.model)")
            LabeledContent("対象", value: "\(summary.thoughtCount) Thoughts")
        }
    }

    @ViewBuilder private func valueSection(_ title: String, _ values: [String]) -> some View {
        if !values.isEmpty { Section(title) { ForEach(values, id: \.self) { Text($0) } } }
    }
}

struct DailySummaryCalendarView: View {
    @ObservedObject var store: ThoughtStore
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    Spacer()
                    Text(month.formatted(.dateTime.year().month(.wide))).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(weekdaySymbols, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            NavigationLink {
                                DailySummaryDetailView(store: store, day: day)
                            } label: {
                                dayCell(day)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accessibilityText(day))
                        } else {
                            Color.clear.frame(height: 52)
                        }
                    }
                }
                .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 8) {
                    legend("checkmark.circle.fill", "要約済み", .green)
                    legend("circle.fill", "Thoughtあり / 未要約", .orange)
                    legend("circle", "Thoughtなし", .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Daily Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = calendar.firstWeekday - 1
        return Array(symbols[index...] + symbols[..<index])
    }

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }.map(Optional.some)
    }

    private func dayCell(_ day: Date) -> some View {
        let status = status(for: day)
        return VStack(spacing: 5) {
            Text("\(calendar.component(.day, from: day))").font(.body.weight(calendar.isDateInToday(day) ? .bold : .regular))
            Image(systemName: status.icon).font(.caption).foregroundStyle(status.color)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(calendar.isDateInToday(day) ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay { if calendar.isDateInToday(day) { RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1) } }
        .contentShape(Rectangle())
    }

    private func status(for day: Date) -> (icon: String, color: Color, text: String) {
        if store.dailySummaries.contains(where: { calendar.isDate($0.dayStart, inSameDayAs: day) }) { return ("checkmark.circle.fill", .green, "要約済み") }
        if store.thoughts.contains(where: { calendar.isDate($0.createdAt, inSameDayAs: day) }) { return ("circle.fill", .orange, "Thoughtあり、未要約") }
        return ("circle", .secondary, "Thoughtなし")
    }

    private func accessibilityText(_ day: Date) -> String { "\(day.formatted(date: .long, time: .omitted))、\(status(for: day).text)" }
    private func moveMonth(_ value: Int) { if let next = calendar.date(byAdding: .month, value: value, to: month) { month = next } }
    private func legend(_ icon: String, _ text: String, _ color: Color) -> some View { Label(text, systemImage: icon).font(.subheadline).foregroundStyle(color) }
}

private struct DailySummaryDetailView: View {
    @ObservedObject var store: ThoughtStore
    let day: Date

    var body: some View {
        List {
            Section {
                LabeledContent("Thought", value: "\(store.dailySummaryDayThoughts.count)件")
                LabeledContent("Continuation", value: "\(store.dailySummaryDayContinuationCount)件")
                LabeledContent("既存タグ", value: store.dailySummaryDayTags.isEmpty ? "なし" : store.dailySummaryDayTags.joined(separator: "、"))
            }
            if let summary = store.dailySummary {
                DailySummarySections(summary: summary)
            } else {
                Section {
                    Button("この日をまとめる") { store.prepareDailySummary(for: day) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(store.dailySummaryDayThoughts.isEmpty)
                        .accessibilityIdentifier("prepareDailySummaryButton")
                }
            }
            if let error = store.dailySummaryError { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.loadDailySummary(for: day) }
        .sheet(item: Binding(get: { store.dailySummaryPreview }, set: { if $0 == nil { store.cancelDailySummaryPreview() } })) { preview in
            DailySummaryPreviewView(store: store, preview: preview)
        }
    }

}

private struct DailySummaryPreviewView: View {
    @ObservedObject var store: ThoughtStore
    let preview: DailySummaryPreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("送信内容") {
                    LabeledContent("対象", value: "\(preview.thoughts.count) Thoughts")
                    LabeledContent("payload", value: "\(preview.request.prompt.count)文字")
                    LabeledContent("Continuation", value: "\(preview.continuationCount)件")
                }
                Section("対象Thought") { ForEach(preview.thoughts) { Text($0.body) } }
                Section("構造化された送信対象") {
                    ForEach(preview.inputs, id: \.thought.id) { input in
                        HStack(alignment: .top, spacing: 10) { PersonaIcon(persona: input.author, size: 32); VStack(alignment: .leading, spacing: 3) { Text(input.author.displayName).font(.subheadline.weight(.semibold)); Text(input.author.kind == .human ? "Human" : "AI").font(.caption2).foregroundStyle(.secondary); if input.author.kind == .human, !input.tags.isEmpty { Text(input.tags.map { "#\($0.name)" }.joined(separator: " ")).font(.caption).foregroundStyle(.tint) }; Text(input.thought.body) } }
                    }
                }
                Section("最終payload") { Text(preview.request.prompt).font(.caption).textSelection(.enabled) }
            }
            .navigationTitle("送信前プレビュー")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { store.cancelDailySummaryPreview(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.isGeneratingDailySummary ? "生成中…" : "送信") {
                        Task { await store.generateDailySummary(from: preview); if store.dailySummaryError == nil { dismiss() } }
                    }.disabled(store.isGeneratingDailySummary)
                }
            }
        }
    }
}
