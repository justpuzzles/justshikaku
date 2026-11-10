import Foundation
import Testing
@testable import Shikaku

@Suite struct DailyTests {

    // MARK: - Seed & schedule

    @Test func seedIsDeterministicAndDayUnique() {
        let a = DayKey(year: 2026, month: 8, day: 30)
        let b = DayKey(year: 2026, month: 8, day: 31)
        #expect(DailySeed.seed(for: a) == DailySeed.seed(for: a))
        #expect(DailySeed.seed(for: a) != DailySeed.seed(for: b))
    }

    /// Zeller against a known anchor: 2026-08-30 is a Sunday.
    @Test func zellerWeekdayMatchesKnownDates() {
        #expect(DailySeed.weekday(of: DayKey(year: 2026, month: 8, day: 30)) == 1)
        #expect(DailySeed.weekday(of: DayKey(year: 2026, month: 8, day: 31)) == 2)
        #expect(DailySeed.weekday(of: DayKey(year: 2000, month: 1, day: 1)) == 7)
    }

    /// The schedule may never hand out a paywalled size (the daily is free by
    /// construction, not by exemption machinery) and never schedules the two
    /// techniques that cannot lead a generated board.
    @Test func scheduleStaysFreeAndGeneratable() {
        for offset in 0..<14 {
            let day = DayKey(date: Date(timeIntervalSince1970: 1_800_000_000
                                        + Double(offset) * 86_400))
            let plan = DailySeed.spec(for: day)
            #expect(FeatureGate.isBoardSizeAvailable(plan.size, unlocked: false))
            #expect(plan.technique != .oneCell)
            #expect(!Technique.allowedAbsentFromGeneratedPuzzles.contains(plan.technique))
        }
    }

    // MARK: - PuzzleKit (1.2)

    /// The seed moved into PuzzleKit in 1.2. Pinned to the value 1.1's own
    /// FNV-1a produced, and to 1.1's code over a century of days: if either
    /// fails, every player's daily changed.
    @Test func seedMatchesTheShippedHash() {
        #expect(DailySeed.seed(for: DayKey(year: 2026, month: 1, day: 1)) == 0x33dbc374d28f0bfb)
        var day = DayKey(year: 2026, month: 8, day: 1)
        for _ in 0..<36_525 {
            #expect(DailySeed.seed(for: day) == Self.shippedSeed(day))
            #expect(DailySeed.weekday(of: day) == Self.shippedWeekday(day))
            day = day.next()
        }
    }

    private static func shippedSeed(_ day: DayKey) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in "shikaku.daily.v1.\(day.isoString)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private static func shippedWeekday(_ day: DayKey) -> Int {
        var y = day.year
        var m = day.month
        if m < 3 {
            m += 12
            y -= 1
        }
        let k = y % 100
        let j = y / 100
        let h = (day.day + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
        return ((h + 6) % 7) + 1
    }

    /// 1.1 stored whole seconds; PuzzleKit's record holds `TimeInterval`.
    /// The 1.1 JSON reads, and what 1.2 writes still decodes as 1.1's
    /// `[String: Int]`, so a downgrade keeps the history.
    @Test func a1_1RecordReadsAndStaysReadableBy1_1() throws {
        let name = "daily-compat-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let json = #"{"lastCompleted":{"year":2026,"month":11,"day":9},"currentStreak":3,"bestStreak":5,"completedTimes":{"2026-11-09":95}}"#
        defaults.set(Data(json.utf8), forKey: "shikaku.daily.v1")

        let store = ProgressStore(userDefaults: defaults)
        #expect(store.dailyTime(DayKey(year: 2026, month: 11, day: 9)) == 95)
        #expect(store.displayStreak(today: DayKey(year: 2026, month: 11, day: 10)) == 3)
        store.recordDailyCompleted(day: DayKey(year: 2026, month: 11, day: 10), seconds: 61)

        struct OldRecord: Decodable {
            var lastCompleted: DayKey?
            var currentStreak: Int
            var bestStreak: Int
            var completedTimes: [String: Int]
        }
        let old = try JSONDecoder().decode(OldRecord.self, from: defaults.data(forKey: "shikaku.daily.v1")!)
        #expect(old.completedTimes == ["2026-11-09": 95, "2026-11-10": 61])
        #expect(old.currentStreak == 4)
    }

    /// Opening another day's room and leaving without a mat must not replace
    /// a half-finished daily (1.1 wrote the slot unconditionally).
    @Test func anUntouchedRoomKeepsTheDailySlot() {
        let store = freshStore()
        let monday = DayKey(year: 2026, month: 11, day: 9)
        let tuesday = DayKey(year: 2026, month: 11, day: 10)
        let lesson = TutorialPuzzles.lesson(for: .onlyFit)
        let snapshot = GameSnapshot(
            puzzle: lesson.puzzle, board: lesson.startingBoard,
            elapsedSeconds: 75, sizeRaw: BoardSize.five.rawValue,
            difficultyRaw: Difficulty.gentle.rawValue, hintsUsed: 0)
        store.saveDaily(snapshot, day: monday)
        store.saveDaily(snapshot, day: tuesday, hasProgress: false)
        #expect(store.dailySave?.day == monday)
        // The same day without progress still writes (its clock moves on).
        var later = snapshot
        later.elapsedSeconds = 90
        store.saveDaily(later, day: monday, hasProgress: false)
        #expect(store.dailySnapshot(for: monday)?.elapsedSeconds == 90)
        store.saveDaily(snapshot, day: tuesday, hasProgress: true)
        #expect(store.dailySave?.day == tuesday)
    }

    /// The week is pure date arithmetic now: Monday to Sunday across a DST
    /// change, a month end and a year end.
    @Test func weekDaysAreSevenConsecutiveDays() {
        for anchor in [DayKey(year: 2026, month: 3, day: 29),    // EU DST Sunday
                       DayKey(year: 2026, month: 10, day: 25),   // EU DST end
                       DayKey(year: 2026, month: 12, day: 31),
                       DayKey(year: 2027, month: 1, day: 3)] {
            let week = ProgressStore.weekDays(containing: anchor)
            #expect(week.count == 7)
            #expect(week.contains(anchor))
            #expect(week[0].weekday == 2, "\(anchor)")
            for i in 1..<7 { #expect(week[i] == week[i - 1].next()) }
        }
    }

    // MARK: - Streak

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "daily-tests-\(UUID().uuidString)")!
        return ProgressStore(userDefaults: defaults)
    }

    /// The daily's own save slot: keyed by day, gone once the day is finished.
    @Test func dailySlotResumesOnlyItsOwnUnfinishedDay() {
        let store = freshStore()
        let today = DayKey(year: 2026, month: 11, day: 6)
        let lesson = TutorialPuzzles.lesson(for: .onlyFit)
        let snapshot = GameSnapshot(
            puzzle: lesson.puzzle, board: lesson.startingBoard,
            elapsedSeconds: 75, sizeRaw: BoardSize.five.rawValue,
            difficultyRaw: Difficulty.gentle.rawValue, hintsUsed: 0)
        store.saveDaily(snapshot, day: today)
        #expect(store.dailySnapshot(for: today)?.elapsedSeconds == 75)
        #expect(store.dailySnapshot(for: DayKey(year: 2026, month: 11, day: 7)) == nil)
        store.recordDailyCompleted(day: today, seconds: 120)
        #expect(store.dailySnapshot(for: today) == nil, "a finished day replays fresh")
        store.clearDailySave()
        #expect(store.dailySave == nil)
    }

    @Test func consecutiveDaysGrowTheStreak() {
        let store = freshStore()
        let d1 = DayKey(year: 2026, month: 8, day: 29)
        let d2 = DayKey(year: 2026, month: 8, day: 30)
        store.recordDailyCompleted(day: d1, seconds: 100)
        store.recordDailyCompleted(day: d2, seconds: 90)
        #expect(store.displayStreak(today: d2) == 2)
        #expect(store.daily.bestStreak == 2)
    }

    @Test func aGapResetsTheDisplayedStreakWithoutErasingBest() {
        let store = freshStore()
        store.recordDailyCompleted(day: DayKey(year: 2026, month: 8, day: 25), seconds: 100)
        store.recordDailyCompleted(day: DayKey(year: 2026, month: 8, day: 26), seconds: 100)
        // Two days missed.
        let today = DayKey(year: 2026, month: 8, day: 29)
        #expect(store.displayStreak(today: today) == 0)
        #expect(store.daily.bestStreak == 2)
        store.recordDailyCompleted(day: today, seconds: 80)
        #expect(store.displayStreak(today: today) == 1)
    }

    @Test func recordingIsIdempotentPerDay() {
        let store = freshStore()
        let day = DayKey(year: 2026, month: 8, day: 30)
        store.recordDailyCompleted(day: day, seconds: 100)
        store.recordDailyCompleted(day: day, seconds: 50)
        #expect(store.dailyTime(day) == 100)
        #expect(store.daily.currentStreak == 1)
    }

    /// Replaying an older day must not rewind `lastCompleted` (the monotonic
    /// guard a sibling learned the hard way).
    @Test func replayingAnOlderDayCannotRewindTheChain() {
        let store = freshStore()
        let today = DayKey(year: 2026, month: 8, day: 30)
        store.recordDailyCompleted(day: today, seconds: 100)
        store.recordDailyCompleted(day: DayKey(year: 2026, month: 8, day: 20), seconds: 100)
        #expect(store.daily.lastCompleted == today)
    }

    /// The week view invites playing a missed day after a later one. That
    /// late solve records its time and touches nothing else; it used to reset
    /// the live streak to 1 (the same bug Hashi shipped in 1.0).
    @Test func finishingAMissedDayOfTheWeekKeepsTheStreak() {
        let store = freshStore()
        let wednesday = DayKey(year: 2026, month: 8, day: 26)
        let thursday = DayKey(year: 2026, month: 8, day: 27)
        let tuesday = DayKey(year: 2026, month: 8, day: 25)
        store.recordDailyCompleted(day: wednesday, seconds: 100)
        store.recordDailyCompleted(day: thursday, seconds: 100)
        store.recordDailyCompleted(day: tuesday, seconds: 90)
        #expect(store.daily.lastCompleted == thursday)
        #expect(store.daily.currentStreak == 2)
        #expect(store.daily.bestStreak == 2)
        #expect(store.dailyTime(tuesday) == 90)
        #expect(store.displayStreak(today: DayKey(year: 2026, month: 8, day: 28)) == 2)
    }
}

@Suite @MainActor struct MasteryWiringTests {

    /// The regression that made mastery dead code: the credit path must run
    /// from a real commit, advance to .learned after 5 unaided placements,
    /// and never fire for hint-applied ones.
    @Test func unaidedCommitsAdvanceMasteryAndHintedOnesDoNot() {
        let defaults = UserDefaults(suiteName: "mastery-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        let tracker = MasteryTracker(store: store)

        for round in 0..<6 {
            let lesson = TutorialPuzzles.lesson(for: .primeStrip)
            let game = ShikakuGame(puzzle: lesson.puzzle, size: .five,
                                   difficulty: .gentle, board: lesson.startingBoard)
            game.mastery = tracker
            // Drive the real input path: drag out the solver's own solution
            // for every clue, so each commit is correct and derivable.
            for (index, rect) in lesson.puzzle.solution.enumerated() {
                if round == 5 {
                    // The hinted round: applied placements must not credit.
                    game.applyHintPlacement(Placement(clueIndex: index, rect: rect))
                } else {
                    game.dragChanged(anchor: Cell(row: rect.minRow, col: rect.minCol),
                                     current: Cell(row: rect.maxRow, col: rect.maxCol))
                    game.dragEnded()
                }
            }
            #expect(game.didWin)
        }

        // Five clean boards of this two-clue puzzle = at least 5 unaided
        // credits on some technique; primeStrip's lesson credits primeStrip.
        #expect(tracker.stage(for: .primeStrip) == .learned)
        let before = store.mastery.perTechnique.values.reduce(0) { $0 + $1.unaided }
        // The all-hints round contributed nothing unaided.
        #expect(before <= 5 * TutorialPuzzles.lesson(for: .primeStrip).puzzle.clues.count)
    }
}

@Suite @MainActor struct ProofAndPathTests {

    /// A lesson advances the seal to .seen and leaves drill stats alone —
    /// the regression Kai saw as "the path doesn't show correctly".
    @Test func aFinishedLessonMarksSeenWithoutTouchingDrills() {
        let defaults = UserDefaults(suiteName: "proof-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        let tracker = MasteryTracker(store: store)
        tracker.recordLesson(technique: .oneCell)
        #expect(tracker.stage(for: .oneCell) == .seen)
        #expect(store.mastery.perTechnique[Technique.oneCell.rawValue]?.drilled == 0)
    }

    /// The grader: a hint-laid move is "shown", an unaided derivable move is
    /// "deduced", judged against the position it was played in.
    @Test func graderSeparatesShownFromDeduced() {
        let lesson = TutorialPuzzles.lesson(for: .primeStrip)
        let game = ShikakuGame(puzzle: lesson.puzzle, size: .five,
                               difficulty: .gentle, board: lesson.startingBoard)
        let solution = lesson.puzzle.solution
        // First clue by hint, the rest by hand.
        game.applyHintPlacement(Placement(clueIndex: 0, rect: solution[0]))
        for index in 1..<solution.count {
            let rect = solution[index]
            game.dragChanged(anchor: Cell(row: rect.minRow, col: rect.minCol),
                             current: Cell(row: rect.maxRow, col: rect.maxCol))
            game.dragEnded()
        }
        #expect(game.didWin)
        let graded = SolveGrader.grade(puzzle: lesson.puzzle, moves: game.history)
        #expect(graded.count == solution.count)
        #expect(graded.first?.verdict == .shown)
        let counts = SolveGrader.counts(graded)
        #expect(counts.shown == 1)
        #expect(counts.deduced + counts.leaps == solution.count - 1)
        #expect(counts.deduced >= 1)
    }

    /// generate(featuring:) really puts the technique in the trace.
    @Test func featuringGeneratorDeliversTheTechnique() {
        let outcome = ShikakuGenerator.generate(
            featuring: .onlyFit, size: .five, tier: .steady, seed: 424242)
        #expect(outcome.matched)
        #expect(outcome.result.trace.contains { $0.technique == .onlyFit })
    }
}

@Suite struct RoundSixTests {

    /// The miner's contract: from each position's placements alone, the
    /// first applicable technique is the target.
    @Test func minedPositionsPutTheTechniqueFirst() {
        let positions = LessonPositions.mine(technique: .soleOwner, count: 3, seed: 7)
        #expect(!positions.isEmpty)
        for position in positions {
            var state = SolverState(puzzle: position.puzzle)
            for p in position.preplaced { state.apply(placement: p) }
            let first = LogicalSolver.nextStep(puzzle: position.puzzle, state: state)
            #expect(first?.technique == .soleOwner)
            #expect(position.puzzle.solution.indices.contains(position.answerClue))
        }
    }

    /// Week math: seven days Monday–Sunday, stable key, seal awarding.
    @Test func weekSealAwardsOnlyWhenAllSevenAreDone() {
        let defaults = UserDefaults(suiteName: "week-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        let anchor = DayKey(year: 2026, month: 8, day: 26)   // a Wednesday
        let week = ProgressStore.weekDays(containing: anchor)
        #expect(week.count == 7)
        #expect(DailySeed.weekday(of: week[0]) == 2)          // Monday
        #expect(DailySeed.weekday(of: week[6]) == 1)          // Sunday
        for day in week.dropLast() {
            store.recordDailyCompleted(day: day, seconds: 60)
            store.awardWeekIfComplete(containing: day)
        }
        #expect(store.weeklySeals.isEmpty)
        store.recordDailyCompleted(day: week[6], seconds: 60)
        store.awardWeekIfComplete(containing: week[6])
        #expect(store.weeklySeals == [ProgressStore.weekKey(of: anchor)])
        // Idempotent.
        store.awardWeekIfComplete(containing: anchor)
        #expect(store.weeklySeals.count == 1)
    }

    /// Climb best is monotonic.
    @Test func climbBestOnlyRises() {
        let defaults = UserDefaults(suiteName: "climb-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        store.recordClimb(rooms: 5)
        store.recordClimb(rooms: 3)
        #expect(store.climbBest == 5)
    }
}

@Suite struct ModeGuideTests {

    /// Every way to play must be explained, and the explanations obey the
    /// same copy rules as the rest of the app (no em dashes, real sentences).
    @Test func everyModeIsExplainedInPlainLanguage() {
        for mode in Mode.allCases {
            let title = ModeGuide.title(mode)
            let oneLine = ModeGuide.oneLine(mode)
            let explanation = ModeGuide.explanation(mode)
            #expect(!title.isEmpty)
            #expect(!oneLine.isEmpty)
            #expect(explanation.count > 80, "\(mode) needs a real explanation")
            for text in [title, oneLine, explanation] {
                #expect(!text.contains("—"), "\(mode): em dash in player-facing copy")
                #expect(!text.contains("–"), "\(mode): en dash in player-facing copy")
            }
            #expect(oneLine.hasSuffix("."))
        }
    }

    /// The listed order is what Learn and Settings show; every mode appears
    /// exactly once, so a new mode cannot be added without a guide entry.
    @Test func everyModeIsListedOnce() {
        #expect(Set(ModeGuide.listed).count == ModeGuide.listed.count)
        #expect(Set(ModeGuide.listed) == Set(Mode.allCases))
    }
}

@Suite("Day key calendar")
struct DayKeyCalendarTests {
    /// The daily is keyed on Gregorian Y-M-D whatever calendar the phone uses;
    /// a Japanese-calendar year (Reiwa 8) would otherwise seed a different board.
    @Test func defaultCalendarIsGregorianLocalTime() {
        #expect(DayKey.localCalendar.identifier == .gregorian)
        // PuzzleKit reads the auto-updating zone (it follows a time-zone
        // change with the app open), which is not `==` to `.current`.
        #expect(DayKey.localCalendar.timeZone.identifier == TimeZone.current.identifier)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let parts = DayKey.localCalendar.dateComponents([.year, .month, .day], from: date)
        #expect(DayKey(date: date) == DayKey(year: parts.year!, month: parts.month!, day: parts.day!))
    }

    @Test func otherCalendarsGiveOtherYears() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = .current
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(DayKey(date: date, calendar: japanese) != DayKey(date: date))
    }
}
