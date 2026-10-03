# Accessibility audit — Just Shikaku (iOS)

Audit and fixes on branch `a11y-audit`, 2026-10-03. The live 1.0 is tagged
`v1.0-live`. Nothing here has been uploaded.

## Method

The method follows the `apple-skills:ios` accessibility-audit module (WWDC23
10035, WWDC25 224). Repeat it for each sibling app.

1. **Common tasks.**
   - First launch, then the rules lesson.
   - Lay out a room and solve it.
   - Ask for a hint.
   - Daily room, lessons, statistics, settings.
   - The purchase sheet.
2. **Automated.** `ShikakuUITests/AccessibilityAuditTests.swift` runs
   `performAccessibilityAudit()` (all audit types) once per screen. It runs
   at the default text size and again on Home at the largest accessibility
   size. Each issue is printed as an `AUDIT |` line in the test log.
3. **Contrast.** WCAG ratios were computed for every text/background pair
   in `Design/Theme.swift`, using the dark values (the app is dark-only) and
   compositing any opacity. Targets: 4.5:1 for body text, 3:1 for large text
   (14 pt bold and up, or 18 pt and up) and for non-text UI.
4. **Dynamic Type.** Screenshots at `accessibility-extra-extra-extra-large`
   (`simctl ui content_size`) of Home, Settings, Statistics and Learn.
5. **VoiceOver order and labels.** The element tree was read with
   `studio/idb-venv/bin/idb ui describe-all` on Home, the new-room sheet and
   the board.
6. **Code review** for Reduce Motion, colour-only state, touch targets and
   announcements.

This Mac has no Simulator.app, so everything ran on the headless simulator
(iPhone 16 Pro, iOS 18.5).

## Findings

Severity follows the skill: 🔴 blocks a common task, 🟠 puts a feature claim
at risk, 🟡 friction, 🟢 polish.

| # | Sev | Finding | Status |
|---|---|---|---|
| 1 | 🔴 | **The board could only be played by dragging.** VoiceOver saw one element per placed mat and per clue, with no positions and no actions. A VoiceOver, Switch Control or Voice Control user could not place a rectangle. | **Fixed.** Every cell is an element: "Row 3, column 5, clue 6, in a 2 by 3 rectangle for the 6". Double-tap sets the first corner (drawn as a dashed outline); double-tap a second cell to place the rectangle between them, using the same rules as a drag. Custom actions: Remove this rectangle, Place the only rectangle that fits, Cancel. `Game/BoardAccessibility.swift`, `ShikakuGame.assistive*`. |
| 2 | 🔴 | Nothing spoken when a mat was placed, removed or rejected, or on the win. Only hints were announced (the docs claimed otherwise). | **Fixed.** Each assistive action is confirmed aloud ("2 by 3 rectangle placed for the 6"; "No rectangle: those cells hold 2 clues…"). The win is announced with its time and record. |
| 3 | 🟠 | Hint text refers to drawn marks ("the marked cell", "the struck rectangle") without positions. A deeper hint rung was not re-announced. | **Fixed.** `BoardSpeech.spokenHint` adds "Marked: row r, column c", the placement's corners and the wrong rectangle's corners. It is announced on every rung (`onChange`). |
| 4 | 🟠 | Text did not follow Dynamic Type: timers, counters, the hint trend, the size chips and the time on the win screen all used fixed sizes. | **Fixed.** `.numberFont(_:)` (`Design/ScaledType.swift`) scales with `@ScaledMetric`. Digits drawn inside fixed shapes (seal numbers, week letters, the board) keep fixed sizes; see Accepted. |
| 5 | 🟠 | At AX5, Home cards kept the glyph, text and arrow in one row, which squeezed the text to a word per line. | **Fixed.** `CardRow` stacks the card at accessibility sizes. |
| 6 | 🟠 | Statistics' best-times row (size plus five times) broke "5×5" over two lines at AX5. | **Fixed.** At accessibility sizes there is one line per difficulty. |
| 7 | 🟠 | Touch targets under 44 pt: week days (30), technique seals (34), purchase-sheet close (~29), size and difficulty chips (~32–34), and the text-only buttons "Drill it", Drill "Done", hint "Apply", "Restore purchases" and "Show the argument again". | **Fixed.** Week slots and seals are 44 pt buttons around a 34/38 pt drawing. Chips, Primary/Secondary/Quiet button styles and the text buttons all get `minHeight: 44`. |
| 8 | 🟠 | Contrast failures: future week letters 2.5:1; unseen seal numbers 3.2:1; the 週 seal 3.9:1 at 13 pt; the purchase failure message in vermilion, 4.0:1. | **Fixed.** Future days are dimmed by an empty, dashed slot instead of a faded letter. Unseen numbers use plain `inkSoft` (8.2:1). 週 is 15 pt bold (large text, needs 3:1). The failure message is bone text with a vermilion icon. |
| 9 | 🟡 | The hint's vermilion focus outline is 1.7:1 against a mat. | **Fixed.** A bone inner ring (6.8:1) inside the vermilion. |
| 10 | 🟡 | Colour-only state: a finished day differed only by its green fill. | **Fixed.** A tick on finished days. |
| 11 | 🟡 | Labels without state: seals didn't say their stage; size chips didn't say which was selected; the hint trend always said "down". | **Fixed.** Seals say "not started / lesson done / practising / learned". Chips carry the `.isSelected` trait. The trend says down, up or steady. |
| 12 | 🟡 | Kanji glyphs (学, 段, 今, 済) were read aloud at the start of card labels. | **Fixed.** Hidden from accessibility; the card text carries the meaning. |
| 13 | 🟡 | Reduce Motion: the hint banner slid in; the win stamp still swung and scaled, just faster. | **Fixed.** The banner fades; the stamp appears in place. Opacity fades elsewhere are allowed under Reduce Motion and stay. |
| 14 | 🟢 | A mat that was the wrong rectangle but the right size read "holds 6 cells but its clue needs 6". | **Fixed.** Mats are no longer separate elements. The cell label says "which is not part of the answer" (only with Show mistakes on). |
| 15 | — | Shikaku no longer built with Xcode 27 (Swift 6.4 isolation check on `Shape` conformances). | **Fixed.** The `Shape` structs are `nonisolated`. |

### Accepted, with reasons

- **The wordmark** ("Just Shikaku") and the **kanji seals** (学 段 今 済 週)
  are fixed-size drawings. The seals are hidden from VoiceOver, and the card
  text says the same thing in words. The audit test filters them by label.
- **One "potentially inaccessible text" on the new-room sheet**, reported with
  no element. Every string visible on the sheet is in the element tree
  (`idb ui describe-all`). It is filtered on that screen only, and only
  without an element.
- **Board digits, seal numbers and week letters** are drawn at sizes tied to
  their cells and shapes. VoiceOver reads every cell and seal in full, and the
  board itself is as large as the screen allows.
- **System List screens** (Settings, Statistics, Learn): the audit reports
  Dynamic Type and clipping issues on standard rows and footers. The AX5
  screenshots show these rows scaling and wrapping. The two audit types are
  filtered on those three screens only.
- **Board cells at 12×12 are 31 pt** on iPhone 16 Pro, under 44 pt. The board
  can't grow, and the 14 pt band around it accepts and clamps touches. The
  VoiceOver cells are just as big and can be reached by swiping.

### Strengths (kept)

- Text styles throughout the main copy, and `fixedSize(vertical:)` wherever
  text should grow.
- Errors drawn as hatching, not colour; "teaching" is the one vermilion.
- Body and secondary text contrast well above 4.5:1 (ink 15.8:1, inkSoft 9.4:1
  on the floor).
- Haptics have a visual counterpart for every event.

## Result

`xcodebuild test` (iPhone 16 Pro, iOS 18.5), 2026-10-03: 54 unit tests and 9
audit screens pass with the filters above.

## Accessibility Nutrition Labels (for App Store Connect)

These can be claimed once branch `a11y-audit` ships:
- **VoiceOver:** yes. Every common task can now be done without sight,
  including solving a room.
- **Voice Control:** yes. Cells have spoken names, and the actions can be
  reached with "Show actions".
- **Larger Text:** yes, with the board digits accepted above.
- **Sufficient Contrast:** yes.
- **Dark Interface:** yes (the app is dark-only).
- **Reduced Motion:** yes.
- **Differentiate Without Color Alone:** yes.

Not applicable (no media in the app): Captions, Audio Descriptions.

## Repeating for the siblings

1. Run the contrast script on the app's `Theme.swift`.
2. Add the same UI-test target (`ruby` + `xcodeproj` gem, then patch in the
   synchronized group; see the commit on this branch).
3. Check that the board has per-cell VoiceOver elements with actions.
   Takegaki, Masyu and Ginga already do; check whether their actions can
   complete a solve.
