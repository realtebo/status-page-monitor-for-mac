# Implementing the Monday provider

This guide ports the Monday checker from the VS Code extension. It reads one status label and gives unresolved incident titles priority over the summary label.

## 1. Identify the HTML fields

The checker requests `https://status.monday.com/` and reads:

- the overall text from `.page-status .status`;
- incident titles from `.unresolved-incidents .unresolved-incident .incident-title .actual-title`.

Only the exact `All Systems Operational` label is healthy in the source checker. An unresolved title is an active issue even if the overall label still says operational.

## 2. Map known labels

Implement [`MondayStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/MondayStatusProvider.swift) and map recognized text values explicitly:

| Status label | App condition |
| --- | --- |
| `All Systems Operational` | `operational` |
| `Scheduled Maintenance` | `maintenance` |
| `Degraded Performance` | `degradedPerformance` |
| `Partial Outage` | `partialOutage` |
| `Major Outage`, `Critical Outage` | `majorOutage` |

Missing status text is a missing-field check failure. An unmapped label is an unrecognized-status failure so a changed page does not silently look healthy.

## 3. Prioritize incidents

Read all matching incident titles and report them as active issues before interpreting the summary text. The source page exposes only titles through this selector, so do not invent IDs, impact, summaries, links, or timestamps. The app presents the incident as red even if the overall text is healthy.

## 4. Add fixtures and tests

Add representative HTML fixtures for healthy status, an incident over a healthy summary, scheduled maintenance, unknown status text, and missing status markup. `MondayProviderTests.swift` injects each page with a fake `HTTPTransport`; no live request is performed in tests.

## 5. Wire monitoring controls

Persist `monitor.monday.enabled`, check Monday on app launch and at the configured interval, and add its popover and dashboard rows. Keep its manual check on its own dashboard row.

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
  -only-testing:StatusPageMonitorAppTests/MondayProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The four tests cover healthy text, active incident priority, maintenance, and missing or unknown text.
