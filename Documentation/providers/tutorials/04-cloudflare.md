# Implementing the Cloudflare provider

This guide ports the Cloudflare checker from the VS Code extension. The extension reads server rendered HTML. Cloudflare's current status page no longer exposes the body status class that checker expects, so the native provider uses Cloudflare's public Statuspage summary endpoint and applies the same incident, maintenance, and component rules to its structured response.

## 1. Inspect the current source contract

The extension requests `https://www.cloudflarestatus.com/` and reads the overall status, unresolved incidents, maintenance impact, and component labels. Cloudflare exposes those same data categories at `https://www.cloudflarestatus.com/api/v2/summary.json` under `status`, `incidents`, `scheduled_maintenances`, and `components`.

## 2. Map the summary condition

Implement [`CloudflareStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/CloudflareStatusProvider.swift). Map the `status.indicator` explicitly:

| API indicator | App condition |
| --- | --- |
| `none` | `operational` |
| `maintenance` | `maintenance` |
| `minor` | `degradedPerformance` |
| `major`, `critical` | `majorOutage` |

Missing fields, malformed JSON, and unknown indicator values fail the check. This avoids treating a changed source format as healthy.

## 3. Extract open incidents and maintenance

Read each record's `name`, `status`, and `impact`; retain the first update body when provided. Filter only `resolved`, `postmortem`, and `completed`, matching the extension's active-record rule. Scheduled maintenance entries are tagged with maintenance impact and are shown as maintenance when there is no active non-maintenance incident.

An open non-maintenance incident remains visible even if the overall indicator is `none`. The shared popover displays such an observation as a red “Active issue” rather than trusting the overall field alone.

## 4. Apply the component rules

The HTML checker normalizes `Partial Outage` to `Re-routed`, `Major Outage` to `Offline`, and most `Under Maintenance` labels to `Partially Re-routed`. Its allowed component labels are operational, re-routed, and partially re-routed. The API equivalents `operational`, `partial_outage`, and `under_maintenance` follow those rules; `major_outage`, `degraded_performance`, and other unmapped states are surfaced as component issues. Preserve the extension's special case: `Cloudflare Sites and Services` under maintenance remains degraded.

If the overall indicator is operational but a component is degraded, report `degradedPerformance` and include the component name and source state in the issue title.

## 5. Add deterministic fixtures

Add API response fixtures under [`Tests/ServiceProvidersTests/Fixtures`](../../../Tests/ServiceProvidersTests/Fixtures) for an all-clear summary, an incident with a `none` indicator, scheduled maintenance, a degraded component, an unknown overall indicator, and the special group maintenance case. `CloudflareProviderTests.swift` uses a fake `HTTPTransport` and never fetches Cloudflare.

## 6. Wire the app

Persist `monitor.cloudflare.enabled`, include Cloudflare in startup and periodic checks, and add its result to the dashboard and popover. Keep manual refresh on Cloudflare's own row. Network, response, and parsing failures use the orange failed-check state.

## 7. Verify

Run the focused tests from the repository root:

```bash
xcodebuild -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  test \
  -only-testing:StatusPageMonitorAppTests/CloudflareProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The six tests cover operational status, open incidents, maintenance, degraded components, an unknown indicator, and the component group exception.
