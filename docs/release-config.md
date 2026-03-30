# Space Briefing Release Config

Use `NASA New/AppConfig.xcconfig` for checked-in defaults and keep local or CI-only secrets in `LocalSecrets.xcconfig`.

## Local Development
- Leave `NASA_API_KEY` blank if you intentionally want the app to fall back to `DEMO_KEY`.
- Keep `APOD_PUBLIC_WEB_BASE_URL` blank unless you are actively testing public web sharing links.
- The shared `NASA New/SpaceBriefing.storekit` file is attached to the shared Run scheme for local Pro Lifetime purchase and restore testing.

## Release Builds
- Override `NASA_API_KEY` with a real personal or production key before TestFlight or App Store distribution.
- Treat `DEMO_KEY` as development-only. If Settings still shows `No (Using DEMO_KEY)`, the build is not release-ready.
- Only set `APOD_PUBLIC_WEB_BASE_URL` when the hosted domain already serves a valid `apple-app-site-association` file and the app has matching Associated Domains entitlements.
- If universal links are not configured, leave `APOD_PUBLIC_WEB_BASE_URL` empty and rely on `nasanew://` for widgets, shortcuts, and internal navigation.

## Local StoreKit Testing
- Run the app with the shared `NASA New` scheme in Debug; it now points to `NASA New/SpaceBriefing.storekit`.
- Use the local `Pro Lifetime` product to exercise purchase, restore, paywall dismissal, and entitlement refresh without App Store Connect setup.
- Keep the product identifier in `SpaceBriefing.storekit` aligned with the shipping StoreKit product ID in code: `eu.medarov.spacebriefing.pro.lifetime`.
