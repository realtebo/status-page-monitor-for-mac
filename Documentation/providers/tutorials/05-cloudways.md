# Implementing the Cloudways provider

This tutorial ports the Cloudways status checker from the VS Code extension. The public page exposes a Statuspage style HTML summary with a body status class and unresolved incident titles.

## 1. Identify the source fields

The checker requests `https://status.cloudways.com/` and reads:

- the first meaningful `status-*` token on `<body>`;
- the first title under `.unresolved-incidents .unresolved-incident .incident-title .actual-title`.

The overall status is authoritative for the source check's `ok` value: it is healthy only when the suffix is `none`. An incident title supplies context but does not replace the overall status field.

## 2. Add the Swift provider

Implement [`CloudwaysStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/CloudwaysStatusProvider.swift) with the shared `HTTPTransport` and `HTMLStatusPageParser`. Splitting the body class on whitespace matters because it contains layout classes as well as its status token.

| Source suffix | App condition |
| --- | --- |
| `none` | `operational` |
| `maintenance` | `maintenance` |
| `minor` | `degradedPerformance` |
| `major`, `critical` | `majorOutage` |

If the body or status class is missing, return a missing-field check failure. If Cloudways adds a new suffix, return an unrecognized-status failure. Never substitute `none` for missing markup.

## 3. Extract unresolved incident titles

Read all matching incident title nodes and create a minimal `ServiceIncident` for each. The current HTML selector supplies the title but not the other incident fields in the provider contract, so leave IDs, summaries, links, and timestamps absent instead of inventing them.

## 4. Build fixtures

Add fixed HTML responses under [`Tests/ServiceProvidersTests/Fixtures`](../../../Tests/ServiceProvidersTests/Fixtures) for operational status, an active incident, scheduled maintenance, an unknown suffix, and a missing suffix. `CloudwaysProviderTests.swift` injects each response through a fake `HTTPTransport`; it does not issue live requests.

## 5. Add dashboard and popover controls

Persist a separate `monitor.cloudways.enabled` preference. Include Cloudways in the app launch check and recurring schedule, show its result in the dashboard and popover, and keep its manual refresh button on its own dashboard row. Failed network and parsing checks use the shared orange indicator.

## 6. Verify

Run the focused suite from the repository root:

```bash
xcodebuild -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  test \
  -only-testing:StatusPageMonitorAppTests/CloudwaysProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The four tests cover operational state, an incident, maintenance, and missing or unknown status markup.
