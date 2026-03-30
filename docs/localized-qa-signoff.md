# Space Briefing Localized QA Signoff

Use this sheet for the final manual release pass across `en`, `bg`, and `es`.

String key parity note: `bg` and `es` now match the checked-in `en` key set. The remaining work here is manual fit, truncation, and accessibility verification on device.

## Signoff Gate
- [ ] GitHub Actions `iOS Tests` workflow is green for the release branch.
- [ ] Local `xcodebuild test` passes on the release simulator target.
- [ ] iPad smoke coverage passes on the split-shell simulator target.

## Locale Matrix
| Scenario | en | bg | es | Notes |
| --- | --- | --- | --- | --- |
| Today screen loads and share/settings/archive/saved controls remain visible | [ ] | [ ] | [ ] | |
| Archive filter labels fit in segmented control and search works | [ ] | [ ] | [ ] | |
| Saved filter labels fit and saved/offline badges remain readable | [ ] | [ ] | [ ] | |
| Offline banner and rate-limit banner fit without truncation | [ ] | [ ] | [ ] | |
| Widget stale/offline copy fits on small and medium widgets | [ ] | [ ] | [ ] | |
| Settings education copy about `DEMO_KEY`, offline media, and notifications fits | [ ] | [ ] | [ ] | |

## Device and Accessibility Matrix
| Scenario | iPhone | iPad | Notes |
| --- | --- | --- | --- |
| Large Dynamic Type (`AX3` or larger) keeps archive and saved controls reachable | [ ] | [ ] | |
| Reduced Motion + Reduced Transparency keeps layout readable | [ ] | [ ] | |
| Increased Contrast / Differentiate Without Color keeps badges understandable | [ ] | [ ] | |
| Split-shell sidebar selection and detail landing remain stable | n/a | [ ] | |

## Feature Verification
- [ ] Widget tap opens the exact APOD date in the app.
- [ ] App shortcut for a chosen date lands on that exact APOD date.
- [ ] Deep link routing to `today`, `archive`, and `saved` still resolves correctly.
- [ ] Daily notification scheduling clamps invalid reminder times.
- [ ] Saved items with offline media open locally and preview-only items fall back gracefully.
- [ ] Archive jump-to-date opens the requested editorial entry without drifting to a neighboring day.
