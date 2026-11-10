//
//  WeekView.swift
//  Shikaku
//
//  This week's dailies: seven slots, Monday to Sunday. Finish all seven
//  and the week gets its seal. Missed days stay playable — the boards are
//  deterministic, so yesterday's room is still yesterday's room.
//

import SwiftUI

struct WeekView: View {
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var progress
    @Environment(TodayClock.self) private var clock

    /// From `TodayClock`, so the row moves on at midnight.
    private var today: DayKey { clock.today }

    var body: some View {
        let days = ProgressStore.weekDays(containing: today)
        let sealed = progress.weeklySeals.contains(ProgressStore.weekKey(of: today))
        VStack(alignment: .leading, spacing: Layout.s2) {
            HStack {
                Text("This week")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                if sealed {
                    // 15pt bold: bone on vermilion is 3.9:1, which passes only
                    // as large text (14pt bold and up).
                    Text("週")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.onShu)
                        .frame(width: 26, height: 26)
                        .background(Theme.shu)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Week finished")
                }
            }
            // 44pt touch targets on a 2pt gap; the drawn slot is 34pt.
            HStack(spacing: 2) {
                ForEach(days, id: \.self) { day in
                    daySlot(day)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func daySlot(_ day: DayKey) -> some View {
        let done = progress.hasCompletedDaily(day)
        let isToday = day == today
        let isFuture = day > today
        Button {
            path.append(.daily(day))
        } label: {
            // Future days are dimmed by their slot (no fill), not by
            // fading the letter: a 0.4 letter fell to 2.5:1. A finished day
            // carries a tick as well as the green, so the state is not
            // colour alone.
            Text(dayLetter(day))
                .font(Theme.numberFont(size: 13))
                .foregroundStyle(done ? Theme.ink : Theme.inkSoft)
                .frame(width: 34, height: 34)
                .background(done ? AnyShapeStyle(Theme.mat) : (isFuture ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Theme.frame)))
                .overlay(Rectangle().strokeBorder(
                    isToday ? Theme.heri : Theme.hairline,
                    style: StrokeStyle(lineWidth: isToday ? 2 : 1, dash: isFuture ? [3, 3] : [])))
                .overlay(alignment: .topTrailing) {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(3)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(slotLabel(day, done: done, isToday: isToday, isFuture: isFuture))
    }

    private func dayLetter(_ day: DayKey) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][DailySeed.weekday(of: day) - 1]
    }

    private func slotLabel(_ day: DayKey, done: Bool, isToday: Bool, isFuture: Bool) -> String {
        let name = ["Sunday", "Monday", "Tuesday", "Wednesday",
                    "Thursday", "Friday", "Saturday"][DailySeed.weekday(of: day) - 1]
        if isFuture { return "\(name), not yet" }
        if done { return "\(name), finished" }
        return isToday ? "\(name), today's room" : "\(name), still open"
    }
}
