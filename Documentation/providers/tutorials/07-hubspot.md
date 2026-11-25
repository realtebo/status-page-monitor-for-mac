# Implementing the HubSpot provider

This tutorial ports the HubSpot checker from the VS Code extension. Unlike a simple status-class parser, it checks open incidents first, then reads the overall status class or a known status label.

## 1. Identify the selectors

The checker requests `https://status.hubspot.com/` and reads:

- incident titles from `.unresolved-incidents .unresolved-incident .incident-title .actual-title`;
- a fallback incident title from `.unresolved-incidents .unresolved-incident .incident-title`;
- the overall label from `.page-status .status`;
- a status suffix from the `<body>` class list.

If an incident title exists, it takes precedence over summary state and is reported as an active issue.

## 2. Map status values

Add [`HubSpotStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/HubSpotStatusProvider.swift). The explicit suffix mapping is:

| Body suffix | App condition |
| --- | --- |
| `none` | `operational` |
| `maintenance` | `maintenance` |
| `minor` | `degradedPerformance` |
| `major`, `critical` | `majorOutage` |

When the status class is absent, the source checker recognizes its exact `All Systems Operational` text as operational. The provider also accepts the other known status labels. Missing both signals or seeing an unknown value fails the check; do not infer health from an empty page.

## 3. Keep incident details honest

Read the first available incident title, matching the source check. Represent it as an active `ServiceIncident` and use `partialOutage` when the page has not supplied a separate summary condition. Do not invent an incident ID, impact, update, or timestamp.

## 4. Add fixtures and tests

Add fixed HTML fixtures for the normal class path, an open incident, the known text fallback, unknown status text, and an unknown body indicator. `HubSpotProviderTests.swift` uses a fake transport so these cases do not depend on HubSpot being online.

## 5. Add configuration and refresh

Persist the independent `monitor.hubspot.enabled` preference. Include HubSpot in startup and interval checks; show its status in the popover and dashboard, with the refresh control aligned on its dashboard row.

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
  -only-testing:StatusPageMonitorAppTests/HubSpotProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The four tests cover the class mapping, incident precedence, the text fallback, and unknown status data.
