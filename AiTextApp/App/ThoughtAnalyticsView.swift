import SwiftUI

struct ThoughtAnalyticsView: View {
    @ObservedObject var store: ThoughtStore
    private let calendar = Calendar.current

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
            DailyActivityCalendar(
                counts: analytics.dailyCounts,
                calendar: calendar
            )

            Text("色が濃い日ほど投稿数が多く、枠線は今日を示します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

private struct DailyActivityCalendar: View {
    let counts: [DailyThoughtCount]
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var maximum: Int { counts.map(\.count).max() ?? 0 }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = calendar.firstWeekday - 1
        return Array(symbols[index...] + symbols[..<index])
    }

    private var leadingEmptyDayCount: Int {
        guard let firstDate = counts.first?.date else { return 0 }
        return (calendar.component(.weekday, from: firstDate) - calendar.firstWeekday + 7) % 7
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }

            ForEach(0..<leadingEmptyDayCount, id: \.self) { _ in
                Color.clear
                    .frame(minHeight: 46)
                    .accessibilityHidden(true)
            }

            ForEach(Array(counts.enumerated()), id: \.offset) { index, item in
                dayCell(item, isFirst: index == 0)
            }
        }
    }

    private func dayCell(_ item: DailyThoughtCount, isFirst: Bool) -> some View {
        let isToday = calendar.isDateInToday(item.date)

        return VStack(spacing: 3) {
            Text(dayLabel(item.date, isFirst: isFirst))
                .font(.caption2.weight(isToday ? .bold : .regular))
            Text("\(item.count)件")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(activityColor(for: item.count), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.date.formatted(date: .long, time: .omitted))、\(item.count)件")
        .accessibilityIdentifier(isToday ? "analyticsDailyCellToday" : "analyticsDailyCell")
    }

    private func dayLabel(_ date: Date, isFirst: Bool) -> String {
        let day = calendar.component(.day, from: date)
        if isFirst || day == 1 {
            return date.formatted(.dateTime.month(.defaultDigits).day())
        }
        return "\(day)"
    }

    private func activityColor(for count: Int) -> Color {
        guard count > 0, maximum > 0 else { return Color.secondary.opacity(0.08) }
        let intensity = Double(count) / Double(maximum)
        return Color.accentColor.opacity(0.18 + 0.52 * intensity)
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
