//
//  SettingsView.swift
//  Shikaku
//
//  Restore lives HERE, unconditionally — not only inside the paywall sheet,
//  which only opens when you hit a wall. Anyone who reinstalled needs a
//  place to restore from.
//

import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements

    var body: some View {
        List {
            Section("Play") {
                Toggle("Haptics", isOn: hapticsBinding)
                Toggle("Show mistakes", isOn: errorFeedbackBinding)
            }
            Section {
                NavigationLink { ModeGuideList() } label: {
                    Text("Ways to play")
                }
            } footer: {
                Text("Every mode, and how each one ends.")
            }
            Section {
                if entitlements.isUnlocked {
                    Label("Full game unlocked", systemImage: "checkmark.seal")
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Button("Restore purchase") {
                        Task { await entitlements.restore() }
                    }
                }
            } footer: {
                Text("The Whole Room is a one-time purchase, shared with your family.")
            }
            Section("More Just Puzzles") {
                ForEach(Self.siblings, id: \.appID) { app in
                    if let url = URL(string: "https://apps.apple.com/app/id\(app.appID)") {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).foregroundStyle(Theme.ink)
                                Text(app.blurb).font(.footnote).foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .accessibilityHint("Opens the App Store")
                    }
                }
            }
            Section {
                LabeledContent("Version", value: Bundle.main.shortVersion)
            }
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Theme.floor)
    }

    /// The other Just Puzzles games on sale. Plain App Store links: no
    /// tracking, no prompt, nothing that interrupts play.
    private static let siblings: [(name: String, blurb: String, appID: String)] = [
        ("Just Kakuro", "Sums in a crossword grid", "6796701026"),
        ("Just Hashi", "Bridges between numbered islands", "6799235188"),
        ("Just Nurikabe", "Shade the sea around numbered islands", "6816718565"),
        ("Numeriqo", "Calcudoku, taught step by step", "6749287069"),
    ]

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { progress.settings.hapticsEnabled },
            set: { newValue in
                progress.settings.hapticsEnabled = newValue
                // Applied on change AND at launch — only-on-change is how a
                // setting ends up doing nothing.
                Haptics.enabled = newValue
            })
    }

    private var errorFeedbackBinding: Binding<Bool> {
        Binding(
            get: { progress.settings.errorFeedback },
            set: { newValue in progress.settings.errorFeedback = newValue })
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
