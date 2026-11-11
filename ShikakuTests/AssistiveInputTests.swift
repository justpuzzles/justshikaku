import Foundation
import Testing
@testable import Shikaku

/// The board must be playable without a drag: VoiceOver, Switch Control and
/// Voice Control place rectangles corner by corner (BoardAccessibility.swift).
@Suite @MainActor struct AssistiveInputTests {

    private func game(_ size: BoardSize = .seven) -> ShikakuGame {
        ShikakuGame(puzzle: BakedPuzzles.puzzle(size: size), size: size, difficulty: .gentle)
    }

    private func corners(_ r: GridRect) -> (Cell, Cell) {
        (Cell(row: r.minRow, col: r.minCol), Cell(row: r.maxRow, col: r.maxCol))
    }

    @Test(arguments: BoardSize.allCases)
    func aWholeRoomCanBeSolvedByCornersAlone(size: BoardSize) {
        let g = game(size)
        for rect in g.puzzle.solution {
            let (a, b) = corners(rect)
            #expect(g.assistiveCorner(a) == .cornerSet(a))
            if case .placed = g.assistiveCorner(b) {} else { Issue.record("rectangle \(rect) was not placed") }
        }
        #expect(g.isSolved)
        #expect(g.didWin)
    }

    @Test func cornersInEitherOrderGiveTheSameRectangle() {
        let g = game()
        let rect = g.puzzle.solution[0]
        let (a, b) = corners(rect)
        _ = g.assistiveCorner(b)
        _ = g.assistiveCorner(a)
        #expect(g.board.placed.map(\.rect) == [rect])
    }

    @Test func aRectangleWithNoClueIsRejectedAndChangesNothing() throws {
        let g = game()
        let empty = try #require((0..<7).flatMap { r in (0..<7).map { Cell(row: r, col: $0) } }
            .first { g.puzzle.clueIndex(at: $0) == nil })
        _ = g.assistiveCorner(empty)
        let outcome = g.assistiveCorner(empty)
        #expect(outcome == .rejected(GridRect(minRow: empty.row, minCol: empty.col,
                                              maxRow: empty.row, maxCol: empty.col), clueCount: 0))
        #expect(g.board.placed.isEmpty)
        #expect(g.pendingCorner == nil)
    }

    @Test func removeAndCancel() {
        let g = game()
        let rect = g.puzzle.solution[0]
        let (a, b) = corners(rect)
        _ = g.assistiveCorner(a); _ = g.assistiveCorner(b)
        #expect(g.assistiveRemove(at: a) == .removed(rect, value: g.puzzle.clues[0].value))
        #expect(g.board.placed.isEmpty)
        _ = g.assistiveCorner(a)
        #expect(g.assistiveCancel() == .cancelled)
        #expect(g.pendingCorner == nil)
        #expect(g.assistiveCancel() == .nothing)
    }

    @Test func placingThroughAssistiveInputIsUndoable() {
        let g = game()
        let (a, b) = corners(g.puzzle.solution[0])
        _ = g.assistiveCorner(a); _ = g.assistiveCorner(b)
        #expect(g.canUndo)
        g.undo()
        #expect(g.board.placed.isEmpty)
    }

    @Test func cellLabelsSayWhereAndWhat() {
        let g = game()
        let clue = g.puzzle.clues[0]
        let label = BoardSpeech.cellLabel(clue.cell, game: g, showMistakes: false)
        #expect(label.hasPrefix("Row \(clue.cell.row + 1), column \(clue.cell.col + 1)"))
        #expect(label.contains("clue \(clue.value)"))
        #expect(label.hasSuffix("empty"))
    }

    @Test func confirmationsAreSpoken() {
        let g = game()
        let rect = g.puzzle.solution[0]
        let (a, b) = corners(rect)
        #expect(BoardSpeech.text(g.assistiveCorner(a), game: g)?.hasPrefix("First corner at row") == true)
        let placed = BoardSpeech.text(g.assistiveCorner(b), game: g) ?? ""
        #expect(placed.contains("\(rect.width) by \(rect.height) rectangle"))
        #expect(BoardSpeech.text(.nothing, game: g) == nil)
    }
}
