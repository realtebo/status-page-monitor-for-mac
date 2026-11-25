# Implementing the Aircall provider

This guide builds the first built-in provider with the version 1 JSON manifest. It covers the source, field mappings, fixture tests, and verification command. The app checks enabled Aircall at launch and on the configured interval; the dashboard and menu bar popover share the latest result.

## 1. Inspect the status source

Aircall publishes a human-readable [status page](https://status.aircall.com/) and a JSON summary at [`/api/v2/summary.json`](https://status.aircall.com/api/v2/summary.json). Inspect the response before writing mappings:

```bash
curl -fsSL https://status.aircall.com/api/v2/summary.json
```

The summary has a top-level `status.indicator` and an `incidents` array. Each incident contains its own `id`, `name`, `status`, `impact`, `incident_updates`, `shortlink`, `created_at`, and `updated_at` fields. Statuspage summaries can also contain a separate `scheduled_maintenances` array; manifest v1 supports one incident collection, so this first integration maps `/incidents` and does not expose that separate array. Supporting both needs a manifest-schema change.

## 2. Declare the service and endpoint

Add [`Resources/ProviderManifests/aircall.json`](../../../Resources/ProviderManifests/aircall.json) and register it as an app resource in the Xcode project. Keep the public page URL separate from the machine-readable endpoint:

```json
{
  "service": {
    "id": "aircall",
    "displayName": "Aircall",
    "statusPageURL": "https://status.aircall.com/",
    "attribution": { "publisherName": "Aircall" }
  },
  "check": {
    "method": "GET",
    "requestURL": "https://status.aircall.com/api/v2/summary.json",
    "format": "json"
  }
}
```

This excerpt shows the service and endpoint fields. The full file also has `schemaVersion` and the `json` mapping shown in the next steps. It must conform to [`provider-manifest-v1.schema.json`](../provider-manifest-v1.schema.json) and contains only declarative fields; it cannot run code or send credentials.

## 3. Map the overall condition explicitly

JSON Pointers are relative to the response document for the overall condition. Aircall's `none`, `minor`, `major`, and `critical` indicators map as follows:

```json
{
  "condition": {
    "pointer": "/status/indicator",
    "values": {
      "none": "operational",
      "minor": "degradedPerformance",
      "major": "majorOutage",
      "critical": "majorOutage"
    }
  }
}
```

Aircall does not distinguish partial from major outage in this indicator. Do not add a `partialOutage` mapping without a source value that supports it. Any absent or unmapped indicator produces a failed check; it is never treated as operational.

## 4. Map incident objects

The `incidents.pointer` selects the array. The remaining pointers are relative to each array item, not the top-level document:

```json
{
  "incidents": {
    "pointer": "/incidents",
    "idPointer": "/id",
    "titlePointer": "/name",
    "status": {
      "pointer": "/status",
      "values": {
        "investigating": "investigating",
        "identified": "identified",
        "monitoring": "monitoring",
        "scheduled": "scheduled",
        "in_progress": "inProgress",
        "verifying": "verifying"
      }
    },
    "impact": {
      "pointer": "/impact",
      "values": {
        "none": "none",
        "minor": "minor",
        "major": "major",
        "critical": "critical"
      }
    },
    "summaryPointer": "/incident_updates/0/body",
    "urlPointer": "/shortlink",
    "startedAtPointer": "/created_at",
    "updatedAtPointer": "/updated_at"
  }
}
```

The update pointer selects the first update's body using array index `0`. The runtime omits source lifecycle values `resolved` and `completed` from active incidents. Every other incident status must match the manifest mapping; an unknown value fails the check instead of disappearing silently.

## 5. Trace the runtime path

`JSONManifestStatusProvider` decodes the manifest, asks the shared `HTTPTransport` for the configured GET, parses the JSON response, then applies the condition and incident pointers. It returns either `.observed(ServiceObservation)` or `.failed(CheckFailure)`. Network, malformed JSON, missing fields, and unknown mappings remain check failures, separate from vendor outages.

`MonitoringModel` loads the bundled `aircall.json` when Aircall is enabled, starts one check from the app launch delegate, then repeats at the saved interval. Enabling Aircall also starts a check immediately; changing the interval reschedules the next check. The menu bar popover and dashboard observe the same model, so they show the same latest condition or check failure.

## 6. Add response fixtures and tests

Add the manifest and fixture files to the test target's resources. The Aircall test uses `FixtureHTTPTransport`, so it exercises the same provider code without making a live network request. The checked-in fixtures cover:

- `aircall-operational.json`: `status.indicator` is `none`, with no incidents.
- `aircall-active-incident.json`: a synthetic major incident with all mapped details. It is test data, not a report of a real Aircall outage.
- `aircall-resolved-incident.json`: `resolved` and `completed` entries are omitted.
- `aircall-unknown-indicator.json`: the unmapped `maintenance-mode` value fails the check.
- `aircall-malformed.json`: invalid JSON fails the check.

The focused tests are in [`AircallProviderTests.swift`](../../../Tests/ServiceProvidersTests/AircallProviderTests.swift). Their expected result is five passing Aircall tests.

## 7. Verify the provider

Run the Aircall test suite from the repository root:

```bash
xcodebuild -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  test \
  -only-testing:StatusPageMonitorAppTests/AircallProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The command exits with status `0` when the five focused tests pass. To run all app and provider tests instead, use the [README test command](../../../README.md#run-tests).

## Common mistakes

- Using `/status/indicator` for an incident field: incident pointers start at each incident object.
- Treating a missing field or a new status string as operational: both are failed checks until the source is inspected and the mapping is deliberately updated.
- Testing with live Aircall data: keep test inputs in fixtures so results are deterministic and do not depend on network access.
- Treating the fixture's active incident as a real event: it is synthetic test data.

For the manifest format and trust boundary, see the [provider manifest guide](../README.md), [Atlassian's public Status API reference](https://status.atlassian.com/api), and [Statuspage's management API reference](https://developer.statuspage.io/).
