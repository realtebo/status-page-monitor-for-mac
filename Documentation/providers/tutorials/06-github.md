# Implementing the GitHub provider

This guide ports the GitHub checker from the VS Code extension. GitHub exposes a Statuspage compatible summary response, with one overall indicator and separate arrays for active incidents and scheduled maintenance.

## 1. Identify the endpoint and fields

The source requests `https://www.githubstatus.com/api/v2/summary.json` and reads:

- `/status/indicator` and `/status/description`;
- `/incidents` for active incidents;
- `/scheduled_maintenances` for current or announced maintenance.

The extension treats only `resolved`, `postmortem`, and `completed` records as inactive. A service is fully healthy only when the indicator is `none` and neither collection has an active record.

## 2. Map the overall condition

Add [`GitHubStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/GitHubStatusProvider.swift). Map the indicator values explicitly:

| GitHub indicator | App condition |
| --- | --- |
| `none` | `operational` |
| `maintenance` | `maintenance` |
| `minor` | `degradedPerformance` |
| `major`, `critical` | `majorOutage` |

Missing summary fields, malformed JSON, and unknown indicator values produce a failed check, which the UI presents separately from a service outage.

## 3. Extract active records

For each incident and maintenance record, map its lifecycle status, title from `name`, optional `id`, and the first update body when present. Skip only the three terminal states from the source checker. Maintenance records receive maintenance impact; when the overall status is `none`, an active maintenance changes the condition to `maintenance`.

An open incident remains present even when the overall indicator is `none`; the shared popover marks that observation as a red “Active issue.” This mirrors the source check's requirement that both the indicator and record lists be clear for a fully healthy result.

## 4. Add fixtures

Add summary JSON fixtures under [`Tests/ServiceProvidersTests/Fixtures`](../../../Tests/ServiceProvidersTests/Fixtures) for operational state, an active incident, resolved/completed items, scheduled maintenance, and an unknown indicator. `GitHubProviderTests.swift` supplies a fake `HTTPTransport`; no test calls GitHub.

## 5. Add app controls

Persist `monitor.github.enabled`, include GitHub in launch and interval checks, display its status in the dashboard and popover, and place its manual refresh button on its own dashboard row. The enabled setting is independent of the other providers.

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
  -only-testing:StatusPageMonitorAppTests/GitHubProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The five tests cover operational state, active and terminal incident records, scheduled maintenance, and an unknown indicator.
