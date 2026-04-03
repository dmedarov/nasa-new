# Engineering Playbook

This playbook captures the recurring lessons from recent Space Briefing work. It is intentionally short, opinionated, and tuned to this repository.

## 1. Architecture Before Growth

Rule:
Before adding feature logic, decide which layer owns it: routing, state, service, or presentation.

Why this matters here:
- Router and shell files are easy places to "just put one more thing."
- That usually feels fast for one PR and expensive for the next two.

Apply it when:
- adding monetization or entitlement checks
- adding deep-link behavior
- adding feature-gated navigation
- adding app-wide presentation like paywalls or alerts

Repository standard:
- `AppRouter.swift` owns route translation and route effects.
- `PurchaseManager.swift` owns entitlement state and purchase flows.
- view files own composition, not business-policy branching.
- logging belongs in dedicated helpers like `MonetizationLogger.swift`, not in shells.

Boundary sketch checklist:
- What input enters the system?
- Which type owns the source of truth?
- Is this route logic, app state, service behavior, or UI presentation?
- Can this be tested without rendering a screen?
- If I removed SwiftUI, where would this logic live?

PR smell:
- A shell or router file grows because it is "the easiest place" to wire a feature.

## 2. Extract Shared Screen Primitives Early

Rule:
When the second screen repeats a layout pattern, stop and extract a primitive.

Why this matters here:
- `Today`, `Archive`, and `Saved` repeatedly drifted in width, chrome, spacing, and filter/search treatment.
- Visual consistency is much cheaper to preserve than to restore.

Apply it when:
- a second screen gets the same top-panel structure
- a second screen gets the same search and filter shell
- width, padding, or section rhythm starts being copy-pasted
- iPhone and iPad start using the same concept with slightly different wrappers

Repository standard:
- screen containers belong in `ScreenPrimitives.swift`
- spacing, width, corner radius, and typography tokens belong in `MainViewPolicies.swift`
- ad hoc per-screen padding should be treated as temporary

Shared-primitive checklist:
- Is this the second use of the same pattern?
- Can the primitive express intent, not just styling?
- Does the primitive reduce repeated spacing and width math?
- Does it improve both iPhone and iPad consistency?
- Can the next screen adopt it without special-case hacks?

PR smell:
- A visual cleanup PR revisits the same three view files to re-align spacing or widths.

## 3. Model Offline and Media State Explicitly

Rule:
If a user-facing state changes behavior, name it explicitly in the domain model.

Why this matters here:
- Offline media UX gets complex fast: remote-only, preview-only, full local, syncing, failed, source-required.
- A pile of booleans always looks simple until UI and QA start combining them.

Apply it when:
- building saved-media experiences
- showing source-required messaging
- supporting degraded offline playback
- adding retry, rebuild, or clear-storage features

Repository standard:
- prefer explicit derived states over scattered availability flags
- state names should map directly to what the user sees
- tests should assert state transitions, not just incidental labels

State-model checklist:
- What are the exact user-visible states?
- What transitions are allowed?
- Which state owns retry or fallback behavior?
- Can a row, card, and detail view all render from the same state vocabulary?
- Do tests cover transitions into and out of failure states?

Suggested shape:
- `remoteOnly`
- `preview`
- `full`
- `saving`
- `failed`
- `sourceRequired`

PR smell:
- UI code asks three different flags to decide one badge or one action.

## 4. Localization Is a Release Gate

Rule:
Localization parity is part of feature completeness, not a cleanup pass.

Why this matters here:
- `en` grows first, then `bg` and `es` lag, then visual regressions show up late in QA.
- That pattern creates avoidable review churn and release risk.

Apply it when:
- adding new user-facing strings
- changing filter labels, segmented controls, or badges
- changing settings copy
- adding new onboarding, paywall, or splash messaging

Repository standard:
- every new user-facing key lands in `en`, `bg`, and `es`
- `scripts/check_localizations.py` must pass before merge
- fit-sensitive copy should be reviewed on actual UI, not just in strings files

Localization checklist:
- Did all three locale files get the new keys?
- Are there duplicate or malformed entries?
- Will the copy still fit in segmented controls, badges, and compact rows?
- Did the feature PR update the QA matrix if manual checks are needed?
- Would a reviewer know this feature is localization-complete?

PR smell:
- "We'll backfill translations in a follow-up."

## PR Review Checklists

### A. CI and Release Hardening
- Does the workflow discover simulators dynamically instead of pinning brittle names?
- Are build, unit, and smoke jobs separated clearly?
- Do failures print useful destination and environment diagnostics?
- Does CI fail before expensive work when setup is obviously wrong?
- Is the change safe against runner-image drift?

### B. SwiftUI Screen Work
- Did this PR add a repeated pattern without extracting a primitive?
- Did it introduce one-off padding or width math in multiple screens?
- Does it preserve consistent iPhone and iPad hierarchy?
- Is content getting more space than chrome?
- Would a future visual pass become easier because of this change?

### C. Offline and Media UX
- Are states explicit?
- Are fallback and failure transitions obvious?
- Does the UI copy match the actual domain state?
- Can saved, archive, and detail surfaces all render the same state consistently?
- Are there tests for degraded and recovery paths?

### D. Localization and QA
- Are all new strings present in `en`, `bg`, and `es`?
- Did the parity script run?
- Does the UI still look correct under longer translations?
- Did this PR quietly add hard-coded English?
- Is manual locale signoff needed for this surface?

## PR Smells To Watch

### Smell 1: "One More Thing in the Router"
Symptom:
Feature work lands in a shell or router because it is convenient.

Typical fix:
Move logic into a manager, service, or policy type before feature growth continues.

### Smell 2: "Visual Cleanup Again"
Symptom:
Multiple PRs keep re-aligning the same screens instead of codifying the layout system.

Typical fix:
Extract or strengthen primitives and tokens immediately.

### Smell 3: "Boolean Pileup"
Symptom:
A single surface depends on multiple flags that together imply a hidden state machine.

Typical fix:
Replace the flag combination with an explicit domain state and transition tests.

### Smell 4: "Translation Catch-up"
Symptom:
Feature PR merges with English only and locale parity is deferred.

Typical fix:
Treat localization and fit review as part of definition of done.

## Definition of Done Reminder

For high-surface-area changes in this repository, "done" usually means:
- architecture boundary is still clear
- shared screen primitives got stronger, not weaker
- offline/media state is explicit
- localization parity passes
- CI and smoke coverage are stable

If one of those is missing, the work is probably not actually finished yet.
