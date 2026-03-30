# Space Briefing Performance Pass

## Focus Areas
- Archive browsing in list and grid modes.
- Saved browser search and filter changes.
- Exact-date archive jumps that hydrate detail content.
- Local/offline media rendering inside the APOD reader.

## Changes Shipped
- `NasaCollectionFetcher` now maintains a cached newest-first archive view instead of resorting `apodData` every time `archiveItems` is read.
- `SavedScreenView` now rebuilds saved display items only when favorites, offline media state, locale, filter, or search inputs change.
- `ArchiveScreenView` now materializes filtered display items and month sections once per input change instead of recomputing them during every view recomposition.
- `MediaView` now reuses the preferred media URL for host/badge context instead of recalculating the same source selection twice.

## Expected Wins
- Smoother archive scrolling because list and grid layouts reuse cached section data.
- Lower CPU churn when typing in archive/saved search fields or flipping segmented filters.
- Less repeated sorting and display-model construction when the reader updates the current APOD.

## Remaining Profiling Checklist
- Run Instruments for archive list scrolling with 6+ months of cached APOD data.
- Measure saved filter changes with a mixed offline/preview/source-required library.
- Capture a timeline for exact-date jumps that fetch a not-yet-cached APOD day.
- Inspect image/video reader transitions with local media, remote media, and degraded/offline fallbacks.
