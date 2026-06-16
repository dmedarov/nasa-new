# Stabilization Smoke Matrix

This matrix defines the minimum automated confidence gate for pull requests and the release-blocking smoke set for Phase 0 stabilization.

## Pull Request Gate

### iPhone Smoke Tests

GitHub Actions job: `iPhone Smoke Tests`

- `NASA NewTests`
  Purpose: keep unit-level contracts green before UI smoke starts.
- `NASANewUITests/testMainScreenCriticalControlsAndSnapshot`
  Purpose: confirm the Today surface launches with the expected critical controls.
- `NASANewUITests/testArchiveSearchAndSelectionFlow`
  Purpose: verify archive discovery and detail navigation on compact layouts.
- `NASANewUITests/testFavoritesSearchAndSwipeDeleteFlow`
  Purpose: verify saved browsing, search, and delete behavior.
- `NASANewUITests/testFreeUserOpeningLockedArchiveEntryShowsPaywall`
  Purpose: protect the core free-tier archive monetization gate.
- `NASANewUITests/testDirectVideoAutoplayPolicyRequiresManualPlaybackOffWiFi`
  Purpose: protect network diagnostics and direct-video autoplay policy behavior.
- `NASANewUITests/testSettingsShowsNotificationGuidanceAndAboutPanel`
  Purpose: confirm the Settings screen can still reveal notification guidance and the about/source panel after section refactors.

### iPad Smoke Tests

GitHub Actions job: `iPad Smoke Tests`

- `NASANewUITests/testIPadSplitShellArchiveSelectionFlow`
- `NASANewUITests/testIPadSplitShellArchiveBackClearsSelection`
- `NASANewUITests/testIPadSavedSelectionUpdatesDetail`
- `NASANewUITests/testIPadPendingArchiveRouteFocusesExactDate`
- `NASANewUITests/testIPadSidebarDestinationPersistsAcrossRelaunch`
- `NASANewUITests/testIPadSplitShellSupportsAccessibilityOverrides`

Purpose: protect split-shell routing, detail synchronization, relaunch persistence, and accessibility behavior on regular-width layouts.

## Release-Blocking Automated Tests

These checks must be green before release signoff:

- GitHub Actions `Localization Parity`
- GitHub Actions `iPhone Smoke Tests`
- GitHub Actions `iPad Smoke Tests`
- Local rerun of the same iPhone smoke command on the chosen release simulator
- Local rerun of the iPad smoke command on the chosen release simulator
- Local Pro purchase and restore validation with `NASA New/SpaceBriefing.storekit`

## Release-Blocking Manual Coverage

Use these alongside the automated jobs:

- [release-checklist.md](/Users/damian/Developer/NASA New/docs/release-checklist.md)
- [localized-qa-signoff.md](/Users/damian/Developer/NASA New/docs/localized-qa-signoff.md)

