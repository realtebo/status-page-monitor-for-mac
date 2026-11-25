# Implementing the Register.it provider

This tutorial ports the Register.it checker from the VS Code extension. Register.it exposes two overall-status signals (a `status-*` body class and visible status text) plus unresolved incident elements. Incident priority changes the result, so read these signals in a deliberate order.

## 1. Find the source fields

The checker requests `https://status.register.it/` and reads:

- the first body class beginning with `status-`, except `status-index`;
- the first `.page-status .status` text;
- all `.unresolved-incident` elements;
- maintenance markers on an incident or one of its descendants using `.impact-maintenance`;
- incident titles through `.incident-title .actual-title`, then `.incident-title`, then `.incident-title a`.

The checker uses the body indicator when present. Only when that class is absent does exact status text decide the state.

## 2. Map only documented indicators

Implement [`RegisterStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/RegisterStatusProvider.swift). The extension declares this mapping:

| `body.status-*` suffix | Display label | App condition |
| --- | --- | --- |
| `none` | `All Systems Operational` | `operational` |
| `maintenance` | `Scheduled Maintenance` | `maintenance` |
| `minor` | `Minor Service Outage` | `degradedPerformance` |
| `major` | `Major Service Outage` | `majorOutage` |
| `critical` | `Critical Service Outage` | `majorOutage` |

When the body indicator is absent, exact known status text supplies the condition. Missing both signals is a failed check. An unknown indicator or unknown text is an unrecognized-status failure; do not infer health from the absence of an incident.

## 3. Apply incident precedence

The source checker selects the first unresolved incident that is not marked `.impact-maintenance`. If it finds one, return it as an active issue even when the overall indicator says `none` or `maintenance`. If all unresolved incidents are maintenance incidents, select the first maintenance incident. The source checker considers that case okay; represent it as the app’s `maintenance` condition and retain the incident title and maintenance impact. The shared UI should preserve the distinction between scheduled maintenance and an outage.

Use only the selected incident, matching the source checker’s `.find()` behavior. Do not fabricate an ID, summary, URL, or timestamp. When a title is missing, the source checker falls back to the current status text or its known indicator label; if neither exists, the provider reports a missing title instead of constructing one.

## 4. Add fixtures and tests

Add representative HTML for operational class, maintenance class, maintenance incident, a non-maintenance incident alongside a maintenance incident, text-only operational fallback, unknown indicator, unknown text, and missing status. `RegisterProviderTests.swift` uses a fake `HTTPTransport`, so the suite never depends on the live page.

Register `RegisterStatusProvider.swift` in the app target, the test file in the test target, and each fixture in test resources in `StatusPageMonitor.xcodeproj/project.pbxproj`. Then add the provider to startup and interval checks, its persisted enabled preference, dashboard row, popover entry, and latest-result view.

## 5. Verify

Run the focused suite from the repository root after registering the new test source and fixtures:

```bash
xcodebuild test -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:StatusPageMonitorAppTests/RegisterProviderTests
```

The tests verify indicator mapping, the text-only operational fallback, maintenance, incident priority, and typed failures for unknown or missing status data.
