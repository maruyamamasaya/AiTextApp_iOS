import Foundation

public struct DailyThoughtCount: Identifiable, Equatable, Sendable {
    public let date: Date
    public let count: Int
    public var id: Date { date }
    public init(date: Date, count: Int) { self.date = date; self.count = count }
}

public struct WeekdayThoughtCount: Identifiable, Equatable, Sendable {
    /// Calendar weekday where 1 is Sunday and 7 is Saturday.
    public let weekday: Int
    public let count: Int
    public var id: Int { weekday }
    public init(weekday: Int, count: Int) { self.weekday = weekday; self.count = count }
}

public enum TimeOfDay: Int, CaseIterable, Hashable, Identifiable, Sendable {
    case lateNight
    case morning
    case afternoon
    case night

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .lateNight: "深夜（0〜5時）"
        case .morning: "朝（6〜11時）"
        case .afternoon: "昼（12〜17時）"
        case .night: "夜（18〜23時）"
        }
    }

    public static func containing(hour: Int) -> Self {
        switch hour {
        case 0..<6: .lateNight
        case 6..<12: .morning
        case 12..<18: .afternoon
        default: .night
        }
    }
}

public struct TimeOfDayThoughtCount: Identifiable, Equatable, Sendable {
    public let timeOfDay: TimeOfDay
    public let count: Int
    public var id: TimeOfDay { timeOfDay }
    public init(timeOfDay: TimeOfDay, count: Int) { self.timeOfDay = timeOfDay; self.count = count }
}

public struct TagThoughtCount: Identifiable, Equatable, Sendable {
    public let tag: ThoughtTag
    public let count: Int
    public var id: UUID { tag.id }
    public init(tag: ThoughtTag, count: Int) { self.tag = tag; self.count = count }
}

public struct ThoughtAnalyticsSummary: Equatable, Sendable {
    public let todayCount: Int
    public let pastSevenDaysCount: Int
    public let pastThirtyDaysCount: Int
    public let activeDayCount: Int

    public init(todayCount: Int, pastSevenDaysCount: Int, pastThirtyDaysCount: Int, activeDayCount: Int) {
        self.todayCount = todayCount
        self.pastSevenDaysCount = pastSevenDaysCount
        self.pastThirtyDaysCount = pastThirtyDaysCount
        self.activeDayCount = activeDayCount
    }

    public var averagePerActiveDay: Double {
        guard activeDayCount > 0 else { return 0 }
        return Double(pastThirtyDaysCount) / Double(activeDayCount)
    }
}

public struct ThoughtAnalyticsSnapshot: Equatable, Sendable {
    public let period: DateInterval
    public let summary: ThoughtAnalyticsSummary
    public let dailyCounts: [DailyThoughtCount]
    public let weekdayCounts: [WeekdayThoughtCount]
    public let timeOfDayCounts: [TimeOfDayThoughtCount]
    public let topTags: [TagThoughtCount]
    public let thoughtsWithContinuationsCount: Int

    public init(
        period: DateInterval,
        summary: ThoughtAnalyticsSummary,
        dailyCounts: [DailyThoughtCount],
        weekdayCounts: [WeekdayThoughtCount],
        timeOfDayCounts: [TimeOfDayThoughtCount],
        topTags: [TagThoughtCount],
        thoughtsWithContinuationsCount: Int
    ) {
        self.period = period
        self.summary = summary
        self.dailyCounts = dailyCounts
        self.weekdayCounts = weekdayCounts
        self.timeOfDayCounts = timeOfDayCounts
        self.topTags = topTags
        self.thoughtsWithContinuationsCount = thoughtsWithContinuationsCount
    }
}

public struct ThoughtAnalyticsDay: Equatable, Sendable {
    public let interval: DateInterval
    public let weekday: Int
}

public struct ThoughtAnalyticsTimeWindow: Equatable, Sendable {
    public let interval: DateInterval
    public let timeOfDay: TimeOfDay
}

public struct ThoughtAnalyticsRequest: Equatable, Sendable {
    public let days: [ThoughtAnalyticsDay]
    public let timeWindows: [ThoughtAnalyticsTimeWindow]
    public let firstWeekday: Int
    public let period: DateInterval

    init(days: [ThoughtAnalyticsDay], timeWindows: [ThoughtAnalyticsTimeWindow], firstWeekday: Int) {
        precondition(!days.isEmpty)
        self.days = days
        self.timeWindows = timeWindows
        self.firstWeekday = firstWeekday
        period = DateInterval(start: days[0].interval.start, end: days[days.count - 1].interval.end)
    }
}

public protocol ThoughtAnalyticsRepository: Sendable {
    func fetchAnalytics(_ request: ThoughtAnalyticsRequest) throws -> ThoughtAnalyticsSnapshot
}

public struct LoadThoughtAnalytics: Sendable {
    private let repository: any ThoughtAnalyticsRepository
    private var calendar: Calendar

    public init(repository: any ThoughtAnalyticsRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    public func callAsFunction(containing date: Date = Date()) throws -> ThoughtAnalyticsSnapshot {
        let period = ThoughtReviewPeriod.pastThirtyDays(containing: date, calendar: calendar)
        var days: [ThoughtAnalyticsDay] = []
        var windows: [ThoughtAnalyticsTimeWindow] = []
        var dayStart = period.start

        while dayStart < period.end {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            days.append(.init(
                interval: DateInterval(start: dayStart, end: dayEnd),
                weekday: calendar.component(.weekday, from: dayStart)
            ))
            let boundaries = [0, 6, 12, 18].map { hour in
                calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)!
            } + [dayEnd]
            for (index, timeOfDay) in TimeOfDay.allCases.enumerated() {
                windows.append(.init(
                    interval: DateInterval(start: boundaries[index], end: boundaries[index + 1]),
                    timeOfDay: timeOfDay
                ))
            }
            dayStart = dayEnd
        }

        return try repository.fetchAnalytics(.init(
            days: days,
            timeWindows: windows,
            firstWeekday: calendar.firstWeekday
        ))
    }
}
