# Space Briefing Release Checklist

## Core Flows
- Open today's briefing, then move backward and forward across APOD dates.
- Open Archive, search by title and date, and jump to a specific archived day.
- Open Saved, confirm saved/offline badges, and verify saved-only browsing still opens the correct APOD.
- Verify widget taps, app shortcuts, and deep links all land on the exact APOD date.

## Reliability
- Confirm the app shows the refreshed `DEMO_KEY` guidance when `NASA_API_KEY` is missing.
- Trigger offline and rate-limited states and confirm the new degraded-state copy is visible.
- Verify offline media still opens from local storage when available and falls back cleanly when only previews exist.
- Confirm daily notification scheduling clamps invalid times and updates the next scheduled reminder correctly.

## Widget
- Confirm the widget prefers locally available imagery before fetching remote media.
- Verify widget fallback states distinguish current on-device snapshots from stale offline snapshots.
- Check widget refresh after saving a favorite, opening a different APOD date, and returning online.

## Localization
- Review the main flows in `en`, `bg`, and `es`.
- Confirm saved/archive filter labels, widget fallback states, and degraded-state banners fit without truncation.
- Recheck large Dynamic Type, reduced motion, and increased contrast in at least one localized run.

## Ship Gate
- Ensure `.github/workflows/ios-tests.yml` passes on the branch.
- Run `xcodebuild test` locally on the target simulator before release.
