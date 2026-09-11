# LazyVGrid child identity fix

Date: 2026-09-11

## Scope

- Investigated every `LazyVGrid` in the app for sibling `ForEach` identity collisions.
- Kept cell ordering, content, and accessibility behavior unchanged.

## Changes

- Replaced the three overlapping integer ID spaces in `DailyActivityCalendar` with typed, namespaced IDs for weekday headers, leading spacers, and date cells.
- Applied the same stable identity model to `DailySummaryCalendarView` so all `LazyVGrid` children use namespaced IDs.
- Used calendar dates as day-cell domain keys and deterministic indices only inside the weekday/spacer namespaces; no runtime UUIDs are generated.

## Verification

- Audited both app `LazyVGrid` declarations and all of their direct `ForEach` children.
- Debug iOS Simulator build succeeded with Xcode 26.6.
- Runtime console reproduction still requires opening both calendar screens on a device or Simulator; the duplicate integer ID sources are no longer present in the view definitions.
