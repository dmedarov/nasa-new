# Space Briefing Performance Pass

Covers P2-01 through P2-04. Records what changed, the expected wins, and the validation workflow for future profiling runs.

---

## Focus Areas

- Archive browsing in list and grid modes
- Saved browser search and filter changes
- Exact-date archive jumps that hydrate detail content
- Local/offline media rendering inside the APOD reader

---

## Changes Shipped

### P2-01 — Async offline thumbnail pipeline

**File:** `APODOfflineMedia.swift`

`APODLocalMediaThumbnailLoader` replaces synchronous `UIImage(contentsOfFile:)` calls with a two-step async path:

1. `Task.detached(priority: .utility)` runs `downsampledPayload(from:maxPixelSize:)` off the main thread using `CGImageSourceCreateThumbnailAtIndex` (ImageIO). This avoids blocking the main thread for decoding and downsampling.
2. The result is cached in `APODLocalMediaThumbnailCache` (an `NSCache<NSString, UIImage>`) keyed on file URL + spec + display scale. Subsequent hits for the same asset at the same spec return immediately without re-decoding.
3. `APODLocalMediaThumbnailSpec` captures the logical size and display scale so thumbnails are sized to the actual cell dimensions rather than decoded at full resolution.

Library views (`FavoritesSheetView`) now drive thumbnail loading through `APODLocalMediaThumbnailLoader.image(from:spec:displayScale:)` as a `.task` on each cell, meaning cells that scroll off-screen cancel their in-flight decode automatically.

### P2-02 — Archive scrolling performance

**Files:** `FavoritesSheetView.swift`, `LibraryPolicies.swift`

`ArchiveLibraryPolicy.resolve(items:filter:searchQuery:locale:)` materializes filtered items and month sections once per input change. The result is stored as `@State` on the archive screen and recomputed only when `apodData`, favorites, filter, search query, or locale change — not on every view recomposition.

`NasaCollectionFetcher` maintains `archiveItemsByNewestFirst: [NASA]` as a cached `@Published` property (reversed from `apodData` once on mutation at line 191) instead of reversing on every `archiveItems` read. Archive screens bind directly to this property.

Section key and title formatting uses two static `DateFormatter` instances (`archiveAPODDateFormatter`, `archiveSectionKeyFormatter`) with fixed POSIX locales rather than constructing a formatter per item.

### P2-03 — Saved-library scrolling performance

**Files:** `FavoritesSheetView.swift`, `LibraryPolicies.swift`

`SavedLibraryPolicy.filteredItemIDs(items:filter:searchQuery:)` separates filter/search from display-model construction. The saved screen stores `SavedLibraryPolicy.Item` display models as `@State` and only rebuilds them when favorites or offline media state changes, not when unrelated shell state updates.

Saved cell thumbnails go through the same `APODLocalMediaThumbnailLoader` async pipeline from P2-01. Mixed-state libraries (full offline, preview, source-required) therefore don't block the main thread during rapid scroll.

### P2-04 — Reader media transition optimization

**Files:** `APODMediaView.swift`, `APODDetailsView.swift`, `APODReaderMediaSection.swift`, `APODReaderView.swift`, `MainView.swift`, `MainViewPolicies.swift`

`MainViewPolicies` extracts the preferred media URL selection from view bodies so `APODMediaView` and `APODDetailsView` don't recalculate the same source selection on every render. Media identity (URL + type) is evaluated once and passed down as a stable value type.

`APODOfflineMedia.swift` gained additional derived properties so reader views read explicit `.full`/`.preview`/`.sourceRequired`/`.saving`/`.failed` cases rather than interrogating multiple booleans per render. This reduces branching in hot render paths.

Image/video transitions in `APODMediaView` now guard re-layout churn by stabilizing identity across state changes: the media view only replaces its content when the resolved media URL or type actually changes, not on every fetcher update.

---

## Expected Wins

| Surface | Expected improvement |
|---|---|
| Archive list scroll | Eliminates per-frame resort and section rebuild during fast scroll |
| Archive grid scroll | Same section reuse; no per-cell `Date` parsing |
| Archive search typing | Filter runs once per keystroke, not once per visible cell |
| Saved grid/list scroll | Async thumbnail decode removes main-thread stalls for large offline libraries |
| Saved filter toggle | Rebuild cost proportional to library size, not cell count |
| Reader image transition | No redundant source-URL recalculation or offline-state branching on each frame |
| Reader video handoff | Media identity guard prevents unnecessary AVPlayer teardown/rebuild |

---

## Validation Workflow

These are the surfaces to profile in Instruments (Time Profiler + SwiftUI) after any change to archive, library, offline media, or reader rendering paths.

### 1. Archive list scroll — 6+ months of data

- Load the app with ≥ 180 APOD items cached.
- Open Archive, switch to list mode.
- Scroll at high velocity from newest to oldest and back.
- **Pass condition:** No main-thread frame drops visible in the Time Profiler hang detector. `ArchiveLibraryPolicy.resolve` does not appear in hot frames during scroll (only on input changes).

### 2. Archive search typing

- Open Archive with a full cache.
- Type a 5-character query one character at a time, then backspace.
- **Pass condition:** Each keystroke triggers exactly one `ArchiveLibraryPolicy.resolve` call. No sorting or section-building work appears during the scroll that follows.

### 3. Saved filter with mixed offline library

- Build a saved library with at least one item in each `SavedFilter` state (full, preview, source-required).
- Tap each filter segment in succession.
- **Pass condition:** Filter transitions are instant. `SavedLibraryPolicy.filteredItemIDs` appears once per tap in Time Profiler, not repeatedly.

### 4. Saved grid scroll with offline thumbnails

- Save 20+ APOD images to the offline library.
- Open Saved, switch to grid mode.
- Scroll at high velocity.
- **Pass condition:** No `UIImage(contentsOfFile:)` or synchronous disk reads appear on the main thread. `APODLocalMediaThumbnailLoader` decode tasks appear on a background thread at `.utility` priority.

### 5. Exact-date archive jump

- Open Archive, use the date picker to jump to a date not already visible.
- **Pass condition:** The jump scrolls to the correct section without triggering a full re-sort of `apodData`.

### 6. Reader image/video transitions

- Open an image APOD in the reader, then navigate to a video APOD.
- Repeat with local offline media vs. remote media.
- **Pass condition:** No duplicate `AVPlayer` initialization frames. `APODMediaView` body does not redraw between navigations without a media URL change. Offline state reads (`hasStoredLocalMedia`, `localPreviewURL`) do not appear in hot frame stacks.

---

## Known Gaps (Not Yet Measured)

- No before/after Instruments traces are archived. The changes above were validated by code review and unit tests only. Profiling under realistic data volumes should be done before P3 polish work lands.
- `APODLocalMediaThumbnailCache` eviction pressure under large offline libraries has not been stress-tested. `NSCache` cost is set to raw decoded byte count; a device with a small memory budget may evict aggressively during grid scroll.
- Archive section-key parsing uses two static `DateFormatter` instances. These are POSIX-locale formatters and thread-safe for read, but have not been verified under concurrent access from `Task.detached` contexts.
