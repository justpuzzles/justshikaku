# Just Shikaku 1.1: submission runbook

State on 2026-10-21: **built and tested locally on branch `release-1.1`;
nothing merged, pushed, uploaded or created in App Store Connect.**
`AppStore/SUBMISSION.md` still holds the record facts and the 1.0 traps.

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
