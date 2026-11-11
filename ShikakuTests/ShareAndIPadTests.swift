import Foundation
import SwiftUI
import Testing
@testable import Shikaku

@Suite("Daily share")
struct DailyShareTests {
    private let day = DayKey(year: 2026, month: 10, day: 21)

    private let english = Locale(identifier: "en_US")

    /// PuzzleKit's family format since 1.2.
    @Test func textCarriesDateSizeTimeStreakAndSeal() {
        let text = DailyShareCard.text(day: day, size: 10, seconds: 272, streak: 5, weekSealed: true,
                                       locale: english)
        #expect(text == "Just Shikaku · Daily · Oct 21, 2026\nSolved in 4:32 · 10×10 · week sealed\n5-day streak\nhttps://kaikunze.de/justshikaku/")
    }

    /// A one-day "streak" says nothing, and a late missed day has none.
    @Test func streakIsLeftOutWhenItSaysNothing() {
        for streak in [nil, 0, 1] as [Int?] {
            let text = DailyShareCard.text(day: day, size: 7, seconds: 59, streak: streak,
                                           weekSealed: false, locale: english)
            #expect(!text.contains("streak"))
            #expect(!text.contains("sealed"))
            #expect(text.contains("Solved in 0:59 · 7×7"))
        }
    }

    @Test func dateLabelIsFixedEnglish() {
        #expect(DailyShareCard.dateLabel(DayKey(year: 2027, month: 1, day: 3)) == "3 Jan 2027")
        #expect(DailyShareCard.dateLabel(DayKey(year: 2026, month: 12, day: 31)) == "31 Dec 2026")
    }

    /// `ImageRenderer` returns nil rather than throwing when a view can't be
    /// drawn off screen; the win overlay would then quietly fall back to text.
    @Test @MainActor func cardRendersOffScreen() {
        let card = DailyShareCard(puzzle: BakedPuzzles.puzzle(size: .ten), day: day,
                                  seconds: 100, streak: 3, weekSealed: true)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }
}

@Suite("iPad sizes")
struct IPadSizeTests {

    @Test func fifteenIsOfferedOnIPadOnly() {
        #expect(BoardSize.offered(onPad: true) == BoardSize.allCases)
        #expect(!BoardSize.offered(onPad: false).contains(.fifteen))
        #expect(BoardSize.offered(onPad: false) == [.five, .seven, .ten, .twelve])
    }

    /// The bigger budget is for 15×15 alone: every other size, and so every
    /// shipped daily, keeps generating exactly the boards it did in 1.0.
    @Test func onlyFifteenGetsTheBiggerBudget() {
        for size in BoardSize.allCases where size != .fifteen {
            #expect(ShikakuGenerator.nodeBudget(for: size) == ShikakuGenerator.nodeBudget)
        }
        #expect(ShikakuGenerator.nodeBudget(for: .fifteen) > ShikakuGenerator.nodeBudget)
    }

    @Test func fifteenGeneratesAValidUniqueBoard() {
        let result = ShikakuGenerator.generate(size: .fifteen, tier: .steady, seed: 7)
        #expect(result.puzzle.size == 15)
        #expect(!result.isFallback)
        let covered = result.puzzle.solution.reduce(0) { $0 + $1.area }
        #expect(covered == 225)
    }
}
