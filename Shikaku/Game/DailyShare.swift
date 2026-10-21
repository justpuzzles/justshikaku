import SwiftUI

/// What a finished daily shares: a line of text and a card image. Neither gives
/// anything away. The card draws the bare grid with a dot where each clue sits,
/// and no numbers and no mats, so a friend who hasn't played today's room
/// learns nothing from it. Ported from Just Hashi 1.1.
nonisolated enum DailyShare {
    static let siteURL = "kaikunze.de/justshikaku/"

    /// `streak` is nil when the solve didn't extend the chain (a missed day of
    /// the week finished late): the text then leaves the streak out rather
    /// than claim the current one.
    static func text(day: DayKey, size: Int, seconds: Int, streak: Int?, weekSealed: Bool) -> String {
        var second = "\(size)×\(size) in \(TimeFormatting.clock(seconds))"
        if let streak, streak > 1 { second += " · \(streak) day streak" }
        if weekSealed { second += " · week sealed" }
        return "Just Shikaku daily, \(dateLabel(day))\n\(second)\n\(siteURL)"
    }

    /// "20 Oct 2026", fixed to English and the Gregorian calendar so the text
    /// reads the same wherever it is pasted.
    static func dateLabel(_ day: DayKey) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let month = (1...12).contains(day.month) ? months[day.month - 1] : "?"
        return "\(day.day) \(month) \(day.year)"
    }
}

/// The share image. Rendered off screen by `ImageRenderer`, so it takes fixed
/// sizes, not Dynamic Type.
struct DailyShareCard: View {
    let puzzle: Puzzle
    let day: DayKey
    let seconds: Int
    let streak: Int?
    let weekSealed: Bool

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Just Shikaku")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(DailyShare.dateLabel(day))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            silhouette
                .frame(width: 300, height: 300)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TimeFormatting.clock(seconds))
                        .font(Theme.numberFont(size: 40))
                        .foregroundStyle(Theme.ink)
                    if let streak, streak > 1 {
                        Text("\(streak) day streak")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                    if weekSealed {
                        Text("Week sealed")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.shu)
                    }
                }
                Spacer()
                Text("済")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.onShu)
                    .frame(width: 48, height: 48)
                    .background(Theme.shu, in: Rectangle())
                    .rotationEffect(.degrees(-6))
            }
            Text(DailyShare.siteURL)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(28)
        .frame(width: 380)
        .background(Theme.floor)
    }

    private var silhouette: some View {
        Canvas { context, size in
            let n = CGFloat(puzzle.size)
            let cell = (min(size.width, size.height) / n).rounded(.down)
            let side = cell * n
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            context.fill(Path(CGRect(origin: origin, size: CGSize(width: side, height: side))),
                         with: .color(Theme.frame))
            var lattice = Path()
            for i in 0...puzzle.size {
                let offset = CGFloat(i) * cell
                lattice.move(to: CGPoint(x: origin.x + offset, y: origin.y))
                lattice.addLine(to: CGPoint(x: origin.x + offset, y: origin.y + side))
                lattice.move(to: CGPoint(x: origin.x, y: origin.y + offset))
                lattice.addLine(to: CGPoint(x: origin.x + side, y: origin.y + offset))
            }
            context.stroke(lattice, with: .color(Theme.hairline), lineWidth: 1)
            let radius = cell * 0.18
            for clue in puzzle.clues {
                let center = CGPoint(x: origin.x + (CGFloat(clue.cell.col) + 0.5) * cell,
                                     y: origin.y + (CGFloat(clue.cell.row) + 0.5) * cell)
                context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                    width: radius * 2, height: radius * 2)),
                             with: .color(Theme.ink))
            }
        }
    }
}
