# Universal Links for `links.medarov.eu`

This project is prepared to use `links.medarov.eu` as the Universal Links host for Space Briefing.

## Why a subdomain
- `medarov.eu` currently behaves like a URL forward instead of a stable HTTPS app-links host.
- `www.medarov.eu` currently fails hostname certificate validation.
- A dedicated `links.medarov.eu` host is the safest setup for Apple Universal Links.

## App-side status
- `NASA New/NASA New.entitlements` now includes `applinks:links.medarov.eu`.
- `AppDeepLink` only accepts `https` public base URLs and still keeps `nasanew://` for internal routing.
- Keep `NASA New/AppConfig.xcconfig` blank in source control until the hosted side is ready.

## Hosted file
- Upload `deployment/links.medarov.eu/.well-known/apple-app-site-association` to:
- `https://links.medarov.eu/.well-known/apple-app-site-association`

Requirements:
- Serve over HTTPS with a valid certificate for `links.medarov.eu`.
- Return `200 OK`.
- Do not redirect.
- Do not add a `.json` extension.
- Serve as `application/json` if possible.

## DNS and hosting checklist
1. Point `links.medarov.eu` to hosting you control.
2. Issue a valid TLS certificate for `links.medarov.eu`.
3. Upload the AASA file exactly as named.
4. Verify:
   - `curl -I https://links.medarov.eu/.well-known/apple-app-site-association`
   - `curl https://links.medarov.eu/.well-known/apple-app-site-association`

## App config after the host is live
Add this only in `LocalSecrets.xcconfig` or CI/release config:

```xcconfig
APOD_PUBLIC_WEB_BASE_URL = https://links.medarov.eu
```

Do not check that value into source control until the hosted domain is confirmed live.

## Paths covered
- `https://links.medarov.eu/today`
- `https://links.medarov.eu/archive?date=YYYY-MM-DD`
- `https://links.medarov.eu/saved?date=YYYY-MM-DD`

## Device verification
1. Install a build with the associated-domains entitlement.
2. Confirm the AASA file is live.
3. Open one of the URLs from Notes, Messages, or Safari.
4. Verify the app opens directly instead of Safari.
5. Verify locked archive dates still present the paywall rather than bypassing access control.
