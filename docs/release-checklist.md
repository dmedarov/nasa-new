# Space Briefing Release Checklist

## Automated Gate
- [ ] `.github/workflows/ios-tests.yml` is green for both the iPhone suite and the iPad smoke job.
- [ ] Local `xcodebuild test` passes on the target iPhone simulator.
- [ ] Local iPad split-shell smoke tests pass on the target iPad simulator.
- [ ] Local Pro purchase + restore flows pass with the `NASA New/SpaceBriefing.storekit` scheme configuration.

## Release Config
- [ ] `LocalSecrets.xcconfig` or CI release overrides provide a real `NASA_API_KEY` for release builds.
- [ ] Release/TestFlight/App Store builds no longer rely on `DEMO_KEY`.
- [ ] `APOD_PUBLIC_WEB_BASE_URL` stays empty unless Associated Domains and `apple-app-site-association` are already configured.
- [ ] Public web links and internal `nasanew://` routes were sanity-checked after the final config values were applied.

## Core Flows
- [ ] Open today's briefing, then move backward and forward across APOD dates.
- [ ] Open Archive, search by title and date, and jump to a specific archived day.
- [ ] Open Saved, confirm saved/offline badges, and verify saved-only browsing still opens the correct APOD.
- [ ] Verify widget taps, app shortcuts, and deep links all land on the exact APOD date.
- [ ] Verify locked archive access, the 11th favorite attempt, and `Save to Photos` all present the Lifetime paywall for free users.
- [ ] Verify Pro entitlement unlocks full archive, unlimited favorites, and original image save without regressions.

## Reliability
- [ ] Confirm the app shows the refreshed `DEMO_KEY` guidance when `NASA_API_KEY` is missing.
- [ ] Trigger offline and rate-limited states and confirm the new degraded-state copy is visible.
- [ ] Verify offline media still opens from local storage when available and falls back cleanly when only previews exist.
- [ ] Confirm daily notification scheduling clamps invalid times and updates the next scheduled reminder correctly.

## Widget
- [ ] Confirm the widget prefers locally available imagery before fetching remote media.
- [ ] Verify widget fallback states distinguish current on-device snapshots from stale offline snapshots.
- [ ] Check widget refresh after saving a favorite, opening a different APOD date, and returning online.

## iPad Coverage
- [ ] Verify split-shell sidebar selection keeps detail content in sync for Today, Archive, and Saved.
- [ ] Confirm an exact-date route into Archive lands on the requested APOD day in the split-shell detail column.
- [ ] Confirm the last selected split-shell destination restores after relaunch.

## Localization and Signoff
- [ ] Complete the manual matrix in `docs/localized-qa-signoff.md`.
- [ ] Recheck large Dynamic Type, reduced motion, and increased contrast on both iPhone and iPad.
- [ ] Review the latest notes in `docs/performance-pass.md` before release signoff.
- [ ] Reconfirm paywall strings, restore copy, and save-to-Photos messaging in `en`, `bg`, and `es`.
