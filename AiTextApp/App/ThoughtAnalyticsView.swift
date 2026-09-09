import SwiftUI

struct ThoughtAnalyticsView: View {
    @ObservedObject var store: ThoughtStore

    var body: some View {
        List {
            Section {
                Label("この分析は端末内のSQLiteデータだけを使用します", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let analytics = store.analytics {
                summarySection(analytics)
                dailySection(analytics)
                weekdaySection(analytics)
                timeOfDaySection(analytics)
                tagSection(analytics)
                continuationSection(analytics)
            } else if store.isLoadingAnalytics {
                Section { ProgressView("集計しています…") }
            } else {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis").font(.title2)
                        Text("分析を表示できません").font(.headline)
                        Text("Timelineへ戻って、もう一度お試しください。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle("ローカル分析")
        .navigationBarTitleDisplayMode(.inline)
        .task { store.loadAnalytics() }
    }

    private func summarySection(_ analytics: ThoughtAnalyticsSnapshot) -> some View {
        Section("基本サマリー") {
            metricRow("今日", value: "\(analytics.summary.todayCount)件", identifier: "analyticsTodayCount")
            metricRow("過去7日", value: "\(analytics.summary.pastSevenDaysCount)件", identifier: "analyticsSevenDayCount")
            metricRow("過去30日", value: "\(analytics.summary.pastThirtyDaysCount)件", identifier: "analyticsThirtyDayCount")
            metricRow("過去30日の活動日", value: "\(analytics.summary.activeDayCount)日", identifier: "analyticsActiveDayCount")
            metricRow(
                "1活動日あたり平均",
                value: analytics.summary.averagePerActiveDay.formatted(.number.precision(.fractionLength(1))) + "件",
                identifier: "analyticsAveragePerActiveDay"
            )
            Text("平均は、Thoughtを投稿した日だけを分母にしています。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func dailySection(_ analytics: ThoughtAnalyticsSnapshot) -> some View {
        Section("過去30日の日別投稿数") {
            ForEach(analytics.dailyCounts) { item in
                DistributionRow(
                    title: item.date.formatted(.dateTime.month().day()),
                    count: item.count,
                    maximum: analytics.dailyCounts.map(\.count).max() ?? 0
                )
            }
        }
    }

    private func weekdaySection(_ analytics: ThoughtAnalyticsSnapshot) -> some View {
        Section("曜日別投稿数") {
            ForEach(analytics.weekdayCounts) { item in
                DistributionRow(
                    title: weekdayName(item.weekday),
                    count: item.count,
                    maximum: analytics.weekdayCounts.map(\.count).max() ?? 0
                )
            }
        }
    }

    private func timeOfDaySection(_ analytics: ThoughtAnalyticsSnapshot) -> some View {
        Section("時間帯別投稿数") {
            ForEach(analytics.timeOfDayCounts) { item in
                DistributionRow(
                    title: item.timeOfDay.title,
                    count: item.count,
                    maximum: analytics.timeOfDayCounts.map(\.count).max() ?? 0
                )
            }
        }
    }

    private func tagSection(_ analytics: ThoughtAnalyticsSnapshot) -> some View {
        Section("過去30日のタグ（上位5件）") {
            if analytics.topTags.isEmpty {
                Label("この期間に使われたタグはありません", systemImage: "tag.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("analyticsTagsEmptyState")
            } else {
                ForEach(analytics.topTags) { item in
                    metricRow(item.tag.name, value: "\(item.count)件")
                }
            }
        }
    }

    private func continuationSection(_ analytics: ThoughtAnalyticsSnapshot) -> some View {
        Section("Continuation") {
            metricRow(
                "Continuationを持つThought",
                value: "\(analytics.thoughtsWithContinuationsCount)件",
                identifier: "analyticsContinuationParentCount"
            )
            Text("過去30日内の、削除されていない親・子Thought間のContinuationを集計しています。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func metricRow(_ title: String, value: String, identifier: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)、\(value)")
        .modifier(OptionalAccessibilityIdentifier(identifier: identifier))
    }

    private func weekdayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        let symbols = formatter.weekdaySymbols ?? []
        guard symbols.indices.contains(weekday - 1) else { return "曜日\(weekday)" }
        return symbols[weekday - 1]
    }
}

private struct DistributionRow: View {
    let title: String
    let count: Int
    let maximum: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)件").monospacedDigit()
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.accentColor.opacity(count == 0 ? 0.12 : 0.65))
                    .frame(width: barWidth(in: geometry.size.width))
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)、\(count)件")
    }

    private func barWidth(in availableWidth: CGFloat) -> CGFloat {
        guard maximum > 0 else { return 0 }
        return availableWidth * CGFloat(count) / CGFloat(maximum)
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier { content.accessibilityIdentifier(identifier) }
        else { content }
    }
}
