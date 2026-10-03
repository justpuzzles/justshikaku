//
//  BoardAccessibility.swift
//  Shikaku
//
//  The board for assistive technologies. The drawn board is positioned
//  mats, numerals and a drag gesture, none of which VoiceOver, Switch
//  Control or Voice Control can operate. This replaces its accessibility
//  children with one element per cell: where it is, what it holds, and
//  actions that place and remove rectangles through ShikakuGame's assistive
//  input (the same rules as a drag). Every change is confirmed aloud.
//

import SwiftUI

struct BoardCellsAccessibility: View {
    let game: ShikakuGame
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let n = game.puzzle.size
        SwiftUI.Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<n, id: \.self) { r in
                GridRow {
                    ForEach(0..<n, id: \.self) { c in
                        cell(Cell(row: r, col: c))
                    }
                }
            }
        }
    }

    private func cell(_ cell: Cell) -> some View {
        let covering = game.board.coveringRect(of: cell)
        let pending = game.pendingCorner
        let onlyFit = game.onlyFit(forClueAt: cell)
        return Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement()
            .accessibilityLabel(BoardSpeech.cellLabel(cell, game: game, showMistakes: progress.settings.errorFeedback))
            .accessibilityHint(pending == nil
                ? "Double-tap to start a rectangle here."
                : "Double-tap to finish the rectangle here.")
            .accessibilityAddTraits(pending == cell ? .isSelected : [])
            .accessibilityAction {
                BoardSpeech.announce(game.assistiveCorner(cell), game: game)
            }
            .accessibilityActions {
                if covering != nil {
                    Button("Remove this rectangle") {
                        BoardSpeech.announce(game.assistiveRemove(at: cell), game: game)
                    }
                }
                if onlyFit != nil {
                    Button("Place the only rectangle that fits") {
                        BoardSpeech.announce(game.assistivePlaceOnlyFit(at: cell), game: game)
                    }
                }
                if pending != nil {
                    Button("Cancel the rectangle") {
                        BoardSpeech.announce(game.assistiveCancel(), game: game)
                    }
                }
            }
    }
}

/// Everything the board says, in one place.
enum BoardSpeech {

    static func position(_ c: Cell) -> String { "row \(c.row + 1), column \(c.col + 1)" }

    static func shape(_ r: GridRect) -> String { "\(r.width) by \(r.height)" }

    @MainActor
    static func cellLabel(_ cell: Cell, game: ShikakuGame, showMistakes: Bool) -> String {
        var parts = ["Row \(cell.row + 1), column \(cell.col + 1)"]
        if let i = game.puzzle.clueIndex(at: cell) {
            parts.append("clue \(game.puzzle.clues[i].value)")
        }
        if let placed = game.board.coveringRect(of: cell) {
            let value = game.puzzle.clues[placed.clueIndex].value
            var mat = "in a \(shape(placed.rect)) rectangle for the \(value)"
            if game.areaConflict(placed) {
                mat += ", which holds \(placed.rect.area) cells instead of \(value)"
            } else if showMistakes && game.isWrong(placed) {
                mat += ", which is not part of the answer"
            }
            parts.append(mat)
        } else if game.board.claims[cell] != nil {
            parts.append("claimed")
        } else {
            parts.append("empty")
        }
        if game.pendingCorner == cell { parts.append("first corner") }
        return parts.joined(separator: ", ")
    }

    @MainActor
    static func text(_ outcome: ShikakuGame.AssistiveOutcome, game: ShikakuGame) -> String? {
        switch outcome {
        case .cornerSet(let c):
            return "First corner at \(position(c)). Choose the opposite corner."
        case .placed(let r, let value, let conflict):
            return conflict
                ? "\(shape(r)) rectangle placed for the \(value), but it holds \(r.area) cells."
                : "\(shape(r)) rectangle placed for the \(value)."
        case .rejected(let r, let count):
            return count == 0
                ? "No rectangle: those \(r.area) cells hold no clue."
                : "No rectangle: those cells hold \(count) clues, and a rectangle needs exactly one."
        case .removed(let r, let value):
            return "Removed the \(shape(r)) rectangle for the \(value)."
        case .cancelled:
            return "Rectangle cancelled."
        case .nothing:
            return nil
        }
    }

    @MainActor
    static func announce(_ outcome: ShikakuGame.AssistiveOutcome, game: ShikakuGame) {
        guard let text = text(outcome, game: game) else { return }
        AccessibilityNotification.Announcement(text).post()
    }

    /// A hint as spoken: its text, then where on the board it points, since
    /// the text refers to drawn marks ("the marked cell", "the struck
    /// rectangle").
    static func spokenHint(_ hint: Hint) -> String {
        var parts = [hint.text]
        if !hint.focusCells.isEmpty {
            let cells = hint.focusCells.sorted().map(position)
            parts.append("Marked: " + cells.joined(separator: "; ") + ".")
        }
        if hint.level == .resolution, let placement = hint.step?.placement {
            parts.append("The rectangle runs from \(position(Cell(row: placement.rect.minRow, col: placement.rect.minCol))) to \(position(Cell(row: placement.rect.maxRow, col: placement.rect.maxCol))).")
        }
        for r in hint.errorRects {
            parts.append("The rectangle from \(position(Cell(row: r.minRow, col: r.minCol))) to \(position(Cell(row: r.maxRow, col: r.maxCol))) is wrong.")
        }
        return parts.joined(separator: " ")
    }
}
