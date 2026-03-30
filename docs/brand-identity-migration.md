# Brand Identity Migration Notes

Space Briefing is the product name, but several runtime identifiers still use the older NASA New namespace.

## Intentionally Frozen Runtime Identifiers

- Bundle identifier: `eu.medarov.NASA-New`
- Shared app group: `group.eu.medarov.nasa-new.shared`
- Custom URL scheme: `nasanew`
- Widget kind: `NASA_New_Widget`
- User activity types:
  - `eu.medarov.nasa-new.today`
  - `eu.medarov.nasa-new.archive`
  - `eu.medarov.nasa-new.saved`
  - `eu.medarov.nasa-new.apod`

These values are still integration points for installed apps, widgets, shared storage, routing restoration, and discovery handoff. They should not change without an explicit migration release.

## Safe Repo Cleanup Completed

- App entry symbol renamed from `NASA_NewApp` to `SpaceBriefingApp`
- Widget entry symbol renamed from `NASA_New_Widget` to `SpaceBriefingWidget`
- Internal user-activity symbol renamed to `SpaceBriefingUserActivityType`
- Shared app-group constants renamed to role-based names in code
- Non-critical URL type label updated to `eu.medarov.spacebriefing.deeplink`

## Future Controlled Migration

1. Decide whether installed-app continuity is more important than namespace cleanup.
2. If continuity wins, keep the runtime identifiers above and only continue cleaning code/documentation names.
3. If a full migration is required, coordinate:
   - bundle/app-group identifier changes
   - shared-container data migration
   - widget re-registration
   - deep-link and universal-link validation
   - App Store Connect, entitlements, and provisioning updates
4. Only rename widget kind or user activity values in the same release where restore, handoff, search indexing, and widget taps are revalidated end to end.
