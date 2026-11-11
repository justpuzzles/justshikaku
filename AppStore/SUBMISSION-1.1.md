# Just Shikaku 1.1: submission runbook

State on 2026-11-06: **1.1 (7) on branch `fix/1.1-polish` (release-1.1 plus
53837fe and c5e10ea), not merged to `main`. iOS 1.1 version created in ASC:
`f8110b35-e7ac-4d9b-bf54-ecf17d55082b`, en-US localization
`0da76ce1-5bbc-410e-a756-2808561459a8`, review detail
`22f93a47-75c1-4d59-af06-4ddceeeedeee`, release AFTER_APPROVAL. Description,
What's New and review notes pushed and read back. Screenshots: the 1.0 iPhone
set (6, carried over) plus a new iPad set (6, `AppStore/screenshots/ipad/`).
Build 7 (`83aad5d7-34e0-411a-b327-dcc2771c5139`, VALID) attached; Apple's
readiness gate passed; review submission
`079b3f72-c64b-4b94-a8d5-1773436b6c4e` holds the version and is a DRAFT,
not submitted. To submit: `PATCH reviewSubmissions/079b3f72-…` with
`attributes.submitted = true`, or Submit for Review in the web UI.**
`AppStore/SUBMISSION.md` still holds the record facts and the 1.0 traps.

Build 7 adds, on top of build 6 (the Gregorian day key):

- **The daily has its own save slot** (`ProgressStore.DailySave`, keyed by
  day). Leaving today's room used to lose the board and reset its clock;
  it now resumes where it was left, and the slot is cleared on the win and
  ignored once the day is finished.
- `GameView.persist` is one path for the three save moments; free play
  writes the Continue slot only once a mat is down (or when it is the saved
  game), so laying out a room and backing out cannot erase it.
- `DailyCard` and `WeekView` keep today in state and refresh at midnight and
  on return to the foreground.
- Settings' Restore purchase shows a spinner and the store's note or error
  in the footer instead of finishing in silence.
- A replayed daily shares its first recorded time, not the replay's.
- The mastery-path pitch no longer sells best times, which are free.
- Not changed: the IAP record (APPROVED, no review note); editing it would
  re-review it, so 15x15 on iPad is named in the description and review notes.

iPad screenshots: `capture_screenshots.py` is iPhone-only and idb hangs on the
iPad. What worked: a throwaway XCUITest (`ShikakuUITests/ScreenshotCaptureTests`,
deleted after the run) that navigates with the audit tests' labels and adds
each `XCUIScreen.main.screenshot()` as an `XCTAttachment` with
`lifetime = .keepAlways`; run with `-resultBundlePath`, then
`xcrun xcresulttool export attachments --path X.xcresult --output-path DIR`
and rename by `manifest.json`. Writing files from the test runner does not
reach the host (`TEST_RUNNER_` env vars never arrived either). Shut the
simulator down first, set the status bar, and use the iPad Pro 12.9 6th gen
on iOS 18.5 (`6BAA0686-…`) for 2048×2732.

## What 1.1 is

- **iPad.** `TARGETED_DEVICE_FAMILY = "1,2"` (all four iPad orientations were
  already declared). The board already capped its cells at 96pt for iPad;
  Home keeps its 560pt column.
- **15×15, iPad only, paid** (`largerBoards`). `BoardSize.offered(onPad:)`
  hides it on iPhone, in the size sheet and in Stats. Generation gets a 2.4M
  node budget for this size only (`ShikakuGenerator.nodeBudget(for:)`): at the
  stock 400k, 17 of 20 Severe requests came back Deep; at 2.4M, 6 of 20, p90
  2.4 s on an M-series Mac. Off-band boards show their real grade, as before.
  A baked 15×15 fallback (seed 424242) passes the harness.
- **Share card** on the daily win: the empty room with clue dots, date, time,
  streak and "Week sealed". `Shikaku/Game/DailyShare.swift`.
- **Streak fix.** Finishing a missed day of the week after a later one reset
  the streak to 1 (the Hashi bug); the WeekView makes that path common here.
- **Accessibility pass** (the `a11y-audit` branch, 2026-10-03, now included).
- **More Just Puzzles** links in Settings.
- **Seal contrast fix** (`Theme.onShu`): text on vermilion seals (finished 今,
  週, win 済, learned technique numbers) was light-mode ink at 2.8:1, now
  bone at 4.6:1 / 3.9:1. Two iPad-only audit false positives accepted after
  measuring the pixels; see `docs/ACCESSIBILITY.md` § iPad.
- Tested: engine harness 3760 checks; 63 unit tests + 9 accessibility audits
  green on iPhone 16 Pro and iPad Pro 11" (M4), both iOS 18.5. iPad layouts
  checked by screenshot: Home, size sheet, 15×15 portrait and landscape.
- Version 1.1 (5). The daily schedule and seeds are untouched (shipped API).

## Left

- [ ] Kai: try iPad and a 15×15 room on a device.
- [ ] **iPad screenshots are required** before an iPad build can be submitted
      (`APP_IPAD_PRO_3GEN_129`, 2048×2732, per the family's trap list).
      `capture_screenshots.py` drives the iPhone only.
- [ ] Description: mention iPad and 15×15. IAP display copy if it lists sizes.
- [ ] Merge `release-1.1` into `main`, push to kkai/justshikaku.
- [ ] Create the iOS 1.1 version in ASC; What's New from `metadata/whatsnew-1.1.txt`.
- [ ] Build 1.1 (5), upload, attach (`SUBMISSION.md` build section).
