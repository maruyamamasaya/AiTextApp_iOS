import SwiftUI

struct AIAPIUsageAnalyticsView: View {
    @ObservedObject var store: ThoughtStore
    @State private var period: AIAPIUsagePeriod = .thirtyDays

    var body: some View {
        Form {
            Picker("期間", selection: $period) {
                ForEach(AIAPIUsagePeriod.allCases, id: \.rawValue) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            if let value = store.aiUsageAnalytics {
                Section("概要") {
                    LabeledContent("今日のAPI Call", value: value.todayCallCount.formatted())
                    LabeledContent("今週のAPI Call", value: value.sevenDayCallCount.formatted())
                    LabeledContent("今月のAPI Call", value: value.monthCallCount.formatted())
                    LabeledContent("API Call", value: value.callCount.formatted())
                    LabeledContent("成功率", value: value.successRate.formatted(.percent.precision(.fractionLength(1))))
                    if let input = value.inputTokens, let output = value.outputTokens, value.tokenizedCallCount == value.callCount {
                        LabeledContent("入力（実測）", value: "\(input.formatted()) tokens")
                        LabeledContent("出力（実測）", value: "\(output.formatted()) tokens")
                    } else {
                        LabeledContent("入力文字数", value: value.inputCharacters.formatted())
                        LabeledContent("出力文字数", value: value.outputCharacters.formatted())
                        if value.tokenizedCallCount > 0 { Text("Token実測値は一部のCallだけのため、合計には混在させていません。").font(.caption).foregroundStyle(.secondary) }
                    }
                    LabeledContent("平均応答時間", value: value.averageLatencyMilliseconds.map { String(format: "%.1f秒", Double($0) / 1_000) } ?? "利用不可")
                    LabeledContent("料金", value: "不明")
                }
                countSection("機能別", values: value.byFeature)
                if !value.byPersona.isEmpty { countSection("Persona別", values: value.byPersona) }
                countSection("Provider / Model別", values: value.byModel)
                Section("External Brain") {
                    LabeledContent("使用", value: "\(value.externalBrainCallCount) / \(value.callCount) calls")
                    LabeledContent("使用率", value: value.externalBrainRate.formatted(.percent.precision(.fractionLength(1))))
                    LabeledContent("平均取得", value: value.averageRetrievedChunkCount.map { String(format: "%.1f chunks", $0) } ?? "利用なし")
                }
                if !value.byError.isEmpty { countSection("Errors", values: value.byError) }
                if !value.daily.isEmpty {
                    Section("日別推移") {
                        ForEach(value.daily) { day in
                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent(day.day.formatted(date: .abbreviated, time: .omitted), value: "\(day.calls) calls")
                                Text("入力 \(day.inputCharacters.formatted())文字 / 出力 \(day.outputCharacters.formatted())文字").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else if store.isLoadingAIUsageAnalytics { ProgressView() }
            else { Label("利用履歴がありません", systemImage: "waveform.path.ecg").foregroundStyle(.secondary) }
        }
        .navigationTitle("AI使用状況")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.loadAIUsageAnalytics(period: period) }
        .onChange(of: period) { store.loadAIUsageAnalytics(period: $0) }
        .alert("AI使用状況", isPresented: Binding(get: { store.aiUsageAnalyticsError != nil }, set: { if !$0 { store.aiUsageAnalyticsError = nil } })) { Button("OK") { store.aiUsageAnalyticsError = nil } } message: { Text(store.aiUsageAnalyticsError ?? "") }
    }

    @ViewBuilder private func countSection(_ title: String, values: [AIAPIUsageCount]) -> some View {
        Section(title) {
            ForEach(values) { item in
                VStack(alignment: .leading, spacing: 3) {
                    LabeledContent(item.name, value: "\(item.calls) calls")
                    if item.failures > 0 { Text("成功 \(item.successes) / 失敗 \(item.failures)").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }
}
