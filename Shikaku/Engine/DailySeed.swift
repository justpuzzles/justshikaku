import Foundation

#if canImport(PuzzleKit)
// Absent under a bare `swiftc` bench, which compiles PuzzleKit's sources into
// the same module instead (docs/ENGINEERING.md).
import PuzzleKit
#endif

/// The curriculum-tied daily: every player gets the same board, and each
/// day's board is generated to exercise a **named technique** — the thing no
/// other app in the category can offer, because no other app classifies
/// boards by reasoning.
///
/// **Never change the seed string or the schedule once shipped** — doing so
/// changes every future (and past) daily for everyone.
nonisolated enum DailySeed {

    /// FNV-1a over "shikaku.daily.v1.YYYY-MM-DD", through PuzzleKit since
    /// 1.2 (`DayKey` lives there too); the prefix and schedule are Shikaku's.
    static func seed(for day: DayKey) -> UInt64 {
        DaySeed.seed(prefix: "shikaku.daily.v1.", day: day)
    }

    /// The week climbs the curriculum: easy arguments early, the one-ply
    /// techniques at the weekend. Sizes stay 5×5/7×7 — both free, so the
    /// daily needs no paywall exemption machinery at all.
    ///
    /// `oneCell` never leads (trivial) and `corridorCount` cannot (measured:
    /// zero appearances in generated traces; it is drill-only by design).
    static func spec(for day: DayKey) -> (technique: Technique, size: BoardSize, difficulty: Difficulty) {
        switch weekday(of: day) {
        case 2: (.primeStrip, .five, .gentle)      // Mon
        case 3: (.onlyFit, .five, .steady)         // Tue
        case 4: (.mustCover, .seven, .steady)      // Wed
        case 5: (.soleOwner, .seven, .sharp)       // Thu
        case 6: (.mustCover, .seven, .deep)        // Fri
        case 7: (.soleOwner, .seven, .severe)      // Sat
        default: (.strandedCell, .seven, .severe)  // Sun — the deep end
        }
    }

    /// 1 = Sunday … 7 = Saturday, from the date itself (never a `Calendar`).
    /// PuzzleKit's Julian-day weekday; its tests pin it equal to the Zeller
    /// formula 1.1 shipped with, on every day from 1900 to 2300.
    static func weekday(of day: DayKey) -> Int {
        day.weekday
    }

    /// The day's board, and whether the scheduled technique really appears in
    /// its trace.
    struct DailyResult: Sendable {
        let puzzle: Puzzle
        let technique: Technique
        let techniqueMatched: Bool
    }

    /// Salted retry (round 0 unsalted, so a date that generates first try
    /// keeps its board forever): a seed whose board misses the scheduled
    /// technique retries deterministically, and every player self-heals to
    /// the same replacement. If no round matches, the last valid board ships
    /// with `techniqueMatched: false` — the card then speaks generically
    /// rather than naming a technique the board does not contain.
    static func generate(for day: DayKey, isCancelled: () -> Bool = { false }) -> DailyResult {
        let plan = spec(for: day)
        let outcome = ShikakuGenerator.generate(
            featuring: plan.technique, size: plan.size, tier: plan.difficulty,
            seed: seed(for: day), isCancelled: isCancelled)
        return DailyResult(puzzle: outcome.result.puzzle, technique: plan.technique,
                           techniqueMatched: outcome.matched)
    }
}
