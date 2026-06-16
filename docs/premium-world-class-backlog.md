# Premium World-Class App Backlog

This backlog turns the premium upgrade plan into executable work. Estimates are in ideal engineering days for one focused engineer. Owner areas describe responsibility, not strict org boundaries.

## Delivery Rules

- Finish stability and regression coverage before starting premium polish or growth work.
- Prefer small vertical slices that end with test coverage or CI proof.
- Do not start a dependent ticket until the prerequisite ticket is green or explicitly accepted as a known risk.

## Current Status

- Done: `P0-01`, `P0-02`, `P0-03`, `P0-04`, `P0-05`, `P0-06`, `P0-07`, `P0-08`, `P1-01`, `P1-02`, `P1-03`, `P1-04`, `P1-05`, `P1-06`, `P1-07`, `P2-01`, `P2-02`, `P2-03`, `P2-04`, `P2-05`, `P3-01`, `P3-02`, `P3-03`, `P3-04`, `P3-05`
- In progress: `none`
- Next recommended ticket: `P4-01`

## Phase 0: Stabilization Foundation

- `P0-01` Regular shell selection contract hardening
  Owner area: `Core Shell`, `Library UX`
  Estimate: `1.5d`
  Depends on: `none`
  Status: `done`
  Scope: stop implicit reselection after explicit clear, preserve valid routed selections, keep compact and regular shells behaviorally aligned.

- `P0-02` Settings diagnostics accessibility contract stabilization
  Owner area: `Settings`, `QA Automation`
  Estimate: `0.5d`
  Depends on: `none`
  Status: `done`
  Scope: ensure diagnostics values expose stable accessibility identifiers and are reachable in `Form` virtualization scenarios.

- `P0-03` Dynamic simulator resolution in CI
  Owner area: `CI`, `Release Engineering`
  Estimate: `0.5d`
  Depends on: `none`
  Status: `done`
  Scope: resolve available iPhone/iPad simulator IDs at runtime, print helpful destination diagnostics, remove brittle name-pinned destinations.

- `P0-04` Extract Settings network diagnostics into dedicated section component
  Owner area: `Settings`
  Estimate: `0.5d`
  Depends on: `P0-02`
  Status: `done`
  Scope: move network policy and diagnostics presentation out of `SettingsSheetView` into a focused view with explicit inputs and stable accessibility outputs.

- `P0-05` iPad split-shell clear-selection regression guard
  Owner area: `Core Shell`, `QA Automation`
  Estimate: `0.5d`
  Depends on: `P0-01`
  Status: `done`
  Scope: add explicit automation for archive detail back action so clear-selection behavior stays protected in CI.

- `P0-06` Extract archive and saved selection policy helpers from shell
  Owner area: `Core Shell`
  Estimate: `1.0d`
  Depends on: `P0-01`, `P0-05`
  Status: `done`
  Scope: move selection resolution, fallback rules, and explicit-clear semantics out of `AppShellView` into testable policy helpers.

- `P0-07` Settings section decomposition pass
  Owner area: `Settings`
  Estimate: `1.0d`
  Depends on: `P0-04`
  Status: `done`
  Scope: split `SettingsSheetView` into focused sections for appearance, notifications, storage, offline media, and about/source/rights.

- `P0-08` Stabilization smoke matrix refresh
  Owner area: `QA Automation`, `Release Engineering`
  Estimate: `0.5d`
  Depends on: `P0-03`, `P0-05`
  Status: `done`
  Scope: codify minimum iPhone and iPad smoke set for PR confidence and document release-blocking tests.

## Phase 1: Architecture Split

- `P1-01` Create feature folders and ownership boundaries
  Owner area: `Architecture`, `Feature Foundations`
  Estimate: `1.0d`
  Depends on: `P0-06`, `P0-07`
  Status: `done`
  Scope: establish `Today`, `Archive`, `Saved`, `Reader`, `Settings`, `Monetization`, and `Shared UI` organization.

- `P1-02` Extract archive filtering and section-building policies
  Owner area: `Library UX`
  Estimate: `1.5d`
  Depends on: `P1-01`
  Status: `done`
  Scope: move archive search, filter, and section derivation out of view bodies into pure helpers with unit tests.

- `P1-03` Extract saved-library filtering and layout policies
  Owner area: `Library UX`
  Estimate: `1.0d`
  Depends on: `P1-01`
  Status: `done`
  Scope: remove saved grid/list/filter policy churn from giant view files and make it independently testable.

- `P1-04` Unify reader composition between today and detail flows
  Owner area: `Reader Experience`
  Estimate: `2.0d`
  Depends on: `P1-01`
  Status: `done`
  Scope: reduce duplication between `MainView` and `APODReaderView`, especially media, source, and explanation presentation.

- `P1-05` Extract reusable shell stage primitives
  Owner area: `Core Shell`, `Shared UI`
  Estimate: `1.0d`
  Depends on: `P0-06`, `P1-01`
  Status: `done`
  Scope: strengthen shell stage, placeholder, and library/detail composition primitives so feature views stay small.

- `P1-06` Formalize route-to-selection synchronization contract
  Owner area: `Routing`
  Estimate: `1.5d`
  Depends on: `P0-06`, `P1-04`
  Status: `done`
  Scope: define how route, pending deep link, explicit selection, and clear-selection interact across archive and saved flows.

- `P1-07` Offline media state model extraction
  Owner area: `Offline Media`
  Estimate: `2.0d`
  Depends on: `P1-01`
  Status: `done`
  Scope: move user-visible offline states toward explicit derived state instead of scattered booleans.

## Phase 2: Performance and Rendering

- `P2-01` Async offline thumbnail pipeline
  Owner area: `Media Performance`
  Estimate: `2.0d`
  Depends on: `P1-03`, `P1-07`
  Status: `done`
  Scope: replace synchronous `UIImage(contentsOfFile:)` style loading in library surfaces with async decode/downsample flow.

- `P2-02` Archive scrolling performance pass
  Owner area: `Library Performance`
  Estimate: `1.0d`
  Depends on: `P2-01`
  Status: `done`
  Scope: reduce main-thread work and view invalidation during archive search, jump-to-date, and grid/list rendering.

- `P2-03` Saved-library scrolling performance pass
  Owner area: `Library Performance`
  Estimate: `1.0d`
  Depends on: `P2-01`
  Status: `done`
  Scope: improve saved grid/list scrolling, selection responsiveness, and offline badge rendering.

- `P2-04` Reader media transition optimization
  Owner area: `Reader Experience`, `Media Performance`
  Estimate: `1.5d`
  Depends on: `P1-04`
  Status: `done`
  Scope: smooth image/video transitions, reduce re-layout churn, and minimize blocking work during detail presentation.

- `P2-05` Performance baseline documentation
  Owner area: `Engineering Excellence`
  Estimate: `0.5d`
  Depends on: `P2-02`, `P2-03`, `P2-04`
  Status: `done`
  Scope: capture before/after notes, target surfaces, and validation workflow in repo docs.

## Phase 3: Premium Product Experience

- `P3-01` Today screen editorial hierarchy pass
  Owner area: `Product Design`, `Reader Experience`
  Estimate: `1.5d`
  Depends on: `P1-04`, `P2-04`
  Status: `done`
  Scope: tune rhythm, hierarchy, and source trust presentation for the landing experience.

- `P3-02` Premium empty/loading/error state system
  Owner area: `Shared UI`, `Product Design`
  Estimate: `1.5d`
  Depends on: `P1-05`
  Status: `done`
  Scope: unify empty, offline, loading, and recoverable error states across today, archive, saved, and settings.

- `P3-03` Paywall narrative and trigger polish
  Owner area: `Monetization`
  Estimate: `1.5d`
  Depends on: `P1-06`
  Status: `done`
  Scope: improve value framing, trigger timing, dismissal recovery, and perceived generosity.

- `P3-04` iPad premium shell visual refinement
  Owner area: `Product Design`, `Core Shell`
  Estimate: `1.0d`
  Depends on: `P1-05`, `P3-01`
  Status: `done`
  Scope: make split-shell feel intentionally designed instead of simply adaptive.

- `P3-05` Motion and haptics polish pass
  Owner area: `Interaction Design`
  Estimate: `1.0d`
  Depends on: `P3-01`, `P3-04`
  Status: `done`
  Scope: add meaningful transitions and tactile feedback without introducing visual noise.

## Phase 4: World-Class Quality System

- `P4-01` Routing and selection unit test expansion
  Owner area: `QA Automation`
  Estimate: `1.0d`
  Depends on: `P1-06`
  Status: `pending`
  Scope: cover route resolution, explicit clear, fallback prevention, and deep-link restoration.

- `P4-02` Offline and media state transition coverage
  Owner area: `QA Automation`, `Offline Media`
  Estimate: `1.0d`
  Depends on: `P1-07`, `P2-01`
  Status: `pending`
  Scope: add tests for degraded, saving, failed, rebuilt, and source-required offline states.

- `P4-03` Snapshot and accessibility regression gate
  Owner area: `QA Automation`
  Estimate: `1.5d`
  Depends on: `P3-02`, `P3-04`
  Status: `pending`
  Scope: establish snapshot coverage for critical screens and accessibility-sensitive states.

- `P4-04` Release checklist hardening
  Owner area: `Release Engineering`
  Estimate: `0.5d`
  Depends on: `P0-08`, `P4-03`
  Status: `pending`
  Scope: refresh release checklist with exact gates for localization, smoke, premium flows, and performance.

- `P4-05` PR review checklist update
  Owner area: `Engineering Excellence`
  Estimate: `0.5d`
  Depends on: `P4-04`
  Status: `pending`
  Scope: extend review criteria for performance, accessibility, localization, and premium-state completeness.

## Phase 5: Premium Expansion and Growth

- `P5-01` Curated collections and themes discovery layer
  Owner area: `Discovery`, `Product Design`
  Estimate: `2.0d`
  Depends on: `P3-01`, `P3-02`, `P4-03`
  Status: `pending`
  Scope: move beyond date-only exploration with curated entry points that feel editorial and premium.

- `P5-02` Advanced widget and ambient surfaces pass
  Owner area: `Platform Experience`
  Estimate: `1.5d`
  Depends on: `P3-01`, `P4-04`
  Status: `pending`
  Scope: enrich widgets and ambient entry points with consistent premium presentation.

- `P5-03` Reading mode personalization
  Owner area: `Reader Experience`
  Estimate: `1.5d`
  Depends on: `P1-04`, `P3-05`
  Status: `pending`
  Scope: add tasteful personalization without compromising editorial calm.

- `P5-04` Premium library tooling
  Owner area: `Library UX`, `Monetization`
  Estimate: `1.5d`
  Depends on: `P1-03`, `P3-03`
  Status: `pending`
  Scope: build Pro-grade save, organize, revisit, and archive workflows that justify subscription value.

## Critical Path Dependency Order

1. `P0-04`
2. `P0-06`
3. `P0-07`
4. `P0-08`
5. `P1-01`
6. `P1-02`, `P1-03`, `P1-05`, `P1-07`
7. `P1-04`
8. `P1-06`
9. `P2-01`
10. `P2-02`, `P2-03`, `P2-04`
11. `P2-05`
12. `P3-01`, `P3-02`, `P3-03`, `P3-04`
13. `P3-05`
14. `P4-01`, `P4-02`
15. `P4-03`
16. `P4-04`
17. `P4-05`
18. `P5-01`, `P5-02`, `P5-03`, `P5-04`

## Suggested Next Three Tickets

- `P2-05` because the performance baseline doc should lock in validation and before/after notes immediately after the full P2 performance pass is green.
- `P3-01` because the Today editorial pass becomes the highest-value premium surface now that the reader transition work is green.
- `P3-02` because a unified premium state system is the next broad product-quality multiplier once the core reading surfaces are fast and stable.
