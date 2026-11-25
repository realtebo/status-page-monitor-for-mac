# Implementing the MongoDB provider

This tutorial ports the MongoDB status checker from the VS Code extension. It reads the Statuspage summary JSON and uses each incident's `resolved_at` field to tell an open incident from a resolved one.

## 1. Read the response fields

The checker requests `https://status.mongodb.com/api/v2/summary.json` and reads `/status/indicator`, `/status/description`, and `/incidents`. In the source checker, an incident is active only when `resolved_at` is explicitly `null`; a timestamp means it is resolved.

## 2. Map the overall status

Implement [`MongoDBStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/MongoDBStatusProvider.swift) and map the indicator:

| MongoDB indicator | App condition |
| --- | --- |
| `none` | `operational` |
| `maintenance` | `maintenance` |
| `minor` | `degradedPerformance` |
| `major`, `critical` | `majorOutage` |

The provider requires the summary status and incident array. An absent `resolved_at` is treated as malformed source data and fails the check, rather than guessing whether the incident is open.

## 3. Extract active incidents

Keep records whose `resolved_at` is `null`, and include their `name` in the app result. Resolved records are omitted. If an active record exists while the overall indicator says `none`, expose it as an active issue so the popover still turns red; the app does not invent an impact or incident timestamp.

## 4. Add fixtures

Add summary fixtures for all-clear, active (`resolved_at: null`), resolved (timestamp), missing resolution data, unknown indicator, and malformed JSON. `MongoDBProviderTests.swift` uses the fake transport to exercise these cases without a live request.

## 5. Connect the app controls

Persist `monitor.mongodb.enabled` independently from the other providers. Add MongoDB to initial and periodic checks, show it in the popover and dashboard, and keep its refresh control on the MongoDB row.

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
  -only-testing:StatusPageMonitorAppTests/MongoDBProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The four tests cover all-clear, active and resolved incidents, missing resolution data, and unknown or malformed responses.
