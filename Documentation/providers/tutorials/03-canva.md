# Implementing the Canva provider

This tutorial ports the Canva status check from the VS Code extension. Canva exposes a Statuspage compatible JSON summary endpoint, so its fields can be read directly by a reviewed Swift provider.

## 1. Locate the source contract

The extension reads `https://www.canvastatus.com/api/v2/summary.json`. It examines `/status/indicator`, `/incidents`, and `/scheduled_maintenances`. The indicator is healthy only when it is `none`; records in `resolved`, `postmortem`, or `completed` are no longer active.

## 2. Map the overall condition

Add [`CanvaStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/CanvaStatusProvider.swift). Its explicit mapping is:

| Canva indicator | App condition |
| --- | --- |
| `none` | `operational` |
| `minor` | `degradedPerformance` |
| `major`, `critical` | `majorOutage` |

The provider treats a missing field, malformed response, or unmapped value as a failed check. It never assumes an unknown value means operational.

## 3. Read incidents and maintenance

Require both collections to be arrays. For each record, read `status` and `name`; skip only the three terminal statuses used by the extension. Map active incident lifecycle values (`investigating`, `identified`, `monitoring`, `scheduled`, `in_progress`, and `verifying`) to the app's typed status. Unknown active lifecycle values fail the check so a source change is visible.

An active scheduled maintenance is represented as a `ServiceIncident` with maintenance impact. When the summary indicator is `none`, its presence changes the condition to `maintenance`. The extension only returned a boolean and a message, so the port does not invent timestamps or descriptions.

## 4. Add fixtures and focused tests

Add deterministic summary responses under [`Tests/ServiceProvidersTests/Fixtures`](../../../Tests/ServiceProvidersTests/Fixtures): operational, active incident plus resolved incident (with `indicator: none` to prove open incidents remain visible), ongoing maintenance, and an unknown indicator. `CanvaProviderTests.swift` injects these responses using a fake `HTTPTransport`; tests do not call Canva. The shared popover indicator marks any observation containing an active incident red and labels it “Active issue,” even when the summary indicator says `none`.

## 5. Wire the app controls

Persist a dedicated `monitor.canva.enabled` setting. Include it in startup and periodic scheduling, then expose its result in the dashboard and popover. Keep the refresh button on Canva's dashboard row. The popover status indicator uses the shared status-to-color mapping, including orange for failed checks.

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
  -only-testing:StatusPageMonitorAppTests/CanvaProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The four tests cover operational state, active and resolved incidents, scheduled maintenance, and an unknown overall indicator.
