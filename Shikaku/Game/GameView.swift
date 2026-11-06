//
//  GameView.swift
//  Shikaku
//
//  The play screen: chrome around BoardView, the save-as-you-work policy,
//  and the win moment. Saving happens on board change + scene backgrounding
//  + disappear — never phase-change-only, which silently loses a game that
//  was started and never paused (a sibling shipped that twice).
//

import SwiftUI

struct GameView: View {
    let game: ShikakuGame

    @Environment(ProgressStore.self) private var progress
    @Environment(PuzzleCache.self) private var cache
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var wasRecord = false

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            // The room sits in the middle of the screen with the controls
            // docked to the bottom edge. It used to be top-aligned against a
            // 64pt cell cap, which left the lower 40% of every screen — and
            // every App Store screenshot — empty.
            VStack(spacing: Layout.s4) {
                header
                Spacer(minLength: 0)
                // No horizontal padding: the wood band runs to the screen
                // edges, so the room is the full width of the phone.
                RoomBoard(game: game)
                Spacer(minLength: 0)
                // Docked directly above the controls rather than floating
                // under the board: the rail then appears in the same place
                // every time instead of shunting the room up the screen.
                HintBanner(game: game)
                    .animation(Motion.chrome, value: game.activeHint)
                footer
            }
            .padding(.top, Layout.s3)
            if game.didWin {
                WinOverlay(game: game, wasRecord: wasRecord) {
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .swipeBackDisabled()
        .modeGuide(mode)
        .navigationBarBackButtonHidden(game.didWin)
        .task(id: game.didWin) {
            guard game.didWin else { return }
            progress.recordLastSolve(ProgressStore.LastSolve(
                puzzle: game.puzzle, moves: game.history,
                sizeRaw: game.size.rawValue, difficultyRaw: game.difficulty.rawValue,
                seconds: game.elapsedSeconds))
            if let day = game.dailyDay {
                // The daily records into the streak, not the best-time table,
                // and never owned the save slot.
                progress.recordDailyCompleted(day: day, seconds: game.elapsedSeconds)
                progress.awardWeekIfComplete(containing: day)
                progress.clearDailySave()
            } else {
                progress.clearSavedGame()
                wasRecord = progress.recordSolve(
                    size: game.size, difficulty: game.difficulty,
                    seconds: game.elapsedSeconds, hintsUsed: game.hintsUsed)
                cache.warm(size: game.size, tier: game.difficulty)
            }
        }
        .task {
            // One warm pass for "next puzzle" while the player thinks.
            cache.warm(size: game.size, tier: game.difficulty)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                game.tickSecond()
            }
        }
        // Board change + scene backgrounding + disappear, never phase-change
        // only (the family invariant).
        .onChange(of: game.board) { persist() }
        .onChange(of: scenePhase) {
            if scenePhase != .active { persist() }
        }
        .onDisappear { persist() }
    }

    /// The daily has its own slot keyed by day; free play has the Continue
    /// slot, written only once a mat is down (or when this *is* the saved
    /// game), so laying out a room and backing out cannot erase it.
    private func persist() {
        guard !game.didWin else { return }
        if let day = game.dailyDay {
            progress.saveDaily(game.snapshot, day: day)
        } else if game.featuring == nil {
            guard game.hasMoves || progress.savedGame?.puzzle == game.puzzle else { return }
            progress.save(game.snapshot)
        }
    }

    private var header: some View {
        HStack {
            Text(headerLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(TimeFormatting.clock(game.elapsedSeconds))
                .numberFont(17)
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
                .accessibilityLabel("Elapsed \(TimeFormatting.spoken(game.elapsedSeconds))")
        }
        .padding(.horizontal, Layout.s4)
    }

    /// Which way to play this game is, for the info button.
    private var mode: Mode {
        if game.dailyDay != nil { return .daily }
        if game.featuring != nil { return .techniqueRoom }
        return .freePlay
    }

    private var headerLabel: String {
        if game.dailyDay != nil { return "Today's room · \(game.size.label)" }
        if let technique = game.featuring {
            return "Needs \(TechniqueContent.name(for: technique)) · \(game.size.label)"
        }
        return "\(game.size.label) · \(game.difficulty.label)"
    }

    private var footer: some View {
        HStack(spacing: Layout.s5) {
            Button {
                game.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(!game.canUndo)
            .accessibilityLabel("Undo")

            Spacer()

            // The hint ladder arrives with the Teaching layer; the button is
            // laid out now so the board height is final.
            HintButton(game: game)
        }
        .padding(.horizontal, Layout.s5)
        .padding(.bottom, Layout.s3)
    }
}

// MARK: - Win

/// The room finishes: a light sweep crosses the floor and the vermilion hanko
/// stamp lands with the time. The only celebration in the app, and the only
/// time shu appears at full strength.
private struct WinOverlay: View {
    let game: ShikakuGame
    let wasRecord: Bool
    let done: () -> Void

    @State private var stamped = false
    @State private var shareImage: Image?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        VStack(spacing: Layout.s4) {
            Spacer()
            stamp
            Text("The room is finished.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            Text(TimeFormatting.clock(game.elapsedSeconds))
                .numberFont(34)
                .foregroundStyle(Theme.ink)
            if wasRecord {
                Text("Your best yet on this size.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let day = game.dailyDay {
                shareButton(day)
            }
            Spacer()
            Button("Done") { done() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.s6)
                .padding(.bottom, Layout.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.floor.opacity(0.94).ignoresSafeArea())
        .onAppear {
            // Under Reduce Motion the stamp is simply there: no swing, no
            // scale, no fade.
            if reduceMotion { stamped = true } else {
                withAnimation(Motion.winSweep) { stamped = true }
            }
            AccessibilityNotification.Announcement(
                "Solved. The room is finished in \(TimeFormatting.spoken(game.elapsedSeconds))"
                + (wasRecord ? ", your best yet on this size." : ".")).post()
        }
        .accessibilityAddTraits(.isModal)
        // Keyed on the text: the daily is recorded by GameView's own win task,
        // which can land after this appears, and the streak and week seal
        // on the card must be the recorded ones.
        .task(id: game.dailyDay.map(shareText)) {
            guard let day = game.dailyDay else { return }
            let card = DailyShareCard(puzzle: game.puzzle, day: day, seconds: sharedSeconds(day),
                                      streak: sharedStreak(day), weekSealed: weekSealed(day))
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            if let image = renderer.uiImage {
                shareImage = Image(uiImage: image)
            }
        }
    }

    /// The streak this solve belongs to, or nil for a missed day of the week
    /// finished late, which records a time but doesn't extend the chain.
    private func sharedStreak(_ day: DayKey) -> Int? {
        progress.daily.lastCompleted == day ? progress.daily.currentStreak : nil
    }

    /// The time on record for the day. A replay of a finished daily keeps
    /// its first time (`recordDailyCompleted` is idempotent), so the card and
    /// the text share that one, not the replay's.
    private func sharedSeconds(_ day: DayKey) -> Int {
        progress.dailyTime(day) ?? game.elapsedSeconds
    }

    private func weekSealed(_ day: DayKey) -> Bool {
        progress.weeklySeals.contains(ProgressStore.weekKey(of: day))
    }

    private func shareText(_ day: DayKey) -> String {
        DailyShare.text(day: day, size: game.puzzle.size, seconds: sharedSeconds(day),
                        streak: sharedStreak(day), weekSealed: weekSealed(day))
    }

    @ViewBuilder
    private func shareButton(_ day: DayKey) -> some View {
        let text = shareText(day)
        Group {
            if let shareImage {
                ShareLink(item: shareImage, subject: Text("Just Shikaku daily"), message: Text(text),
                          preview: SharePreview("Just Shikaku daily", image: shareImage)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } else {
                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityLabel("Share result")
    }

    private var stamp: some View {
        Text("済")
            .font(.system(size: 64, weight: .bold))
            .foregroundStyle(Theme.onShu)
            .accessibilityHidden(true)
            .frame(width: 110, height: 110)
            .background(Theme.shu, in: Rectangle())
            .overlay(Rectangle().strokeBorder(.black.opacity(0.3), lineWidth: 1))
            .rotationEffect(.degrees(stamped ? -6 : -20))
            .scaleEffect(stamped ? 1.0 : 1.6)
            .opacity(stamped ? 1 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Solved")
    }
}

// MARK: - Formatting

nonisolated enum TimeFormatting {
    /// "3 minutes 12 seconds", for VoiceOver (a clock reads as a ratio).
    static func spoken(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        let minutes = m == 1 ? "1 minute" : "\(m) minutes"
        let secs = s == 1 ? "1 second" : "\(s) seconds"
        return m == 0 ? secs : "\(minutes) \(secs)"
    }

    static func clock(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

}

extension Difficulty {
    var label: String {
        switch self {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .sharp: "Sharp"
        case .deep: "Deep"
        case .severe: "Severe"
        }
    }
}

extension BoardSize {
    var label: String { "\(rawValue)×\(rawValue)" }
}
