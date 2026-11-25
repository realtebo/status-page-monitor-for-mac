# Implementing the Vercel provider

This guide ports the Vercel checker from the VS Code extension. It gives an unresolved incident title priority over the page summary, then treats one exact summary phrase as healthy.

## 1. Inspect the source selectors

The checker requests `https://www.vercel-status.com/` and reads:

- the first active incident title from `.unresolved-incidents .unresolved-incident .incident-title .actual-title`;
- the first summary label from `.page-status h2.status`.

When a nonempty incident title exists, the checker reports an issue without consulting the summary. The source does not expose an incident ID, impact, timestamp, or URL through these selectors.

## 2. Give incidents precedence

Implement [`VercelStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/VercelStatusProvider.swift). Select the first incident title and report it as an active issue before reading the status label. In fixtures, keep an `All Systems Operational` summary beside an unresolved incident to prove this precedence.

The provider models an incident title as a partial outage because the source checker marks every unresolved incident as not okay. Do not add incident fields that the page selector does not supply.

## 3. Map the summary label

With no nonempty incident title, read the first `.page-status h2.status` element. Map known labels explicitly:

| Vercel label | App condition |
| --- | --- |
| `All Systems Operational` | `operational` |
| `Degraded Performance` | `degradedPerformance` |
| `Partial Outage` | `partialOutage` |
| `Major Outage` | `majorOutage` |
| `Maintenance` | `maintenance` |

Missing or blank status text is a failed check. A changed nonempty label is also a failed check with an `unrecognizedStatus` reason; do not assume it is healthy or guess its severity.

## 4. Add deterministic tests

Create fixtures for an all-clear page, an active incident over an all-clear summary, a known degraded label, missing markup, blank text, and unknown text. `VercelProviderTests.swift` injects each fixture through a fake `HTTPTransport`, so the suite makes no live request.

## 5. Wire the app controls

Persist `monitor.vercel.enabled`, run Vercel during startup and interval checks, and add its entry to the dashboard and menu bar popover. The dashboard refresh action belongs on the Vercel row; the popover row should link to `https://www.vercel-status.com/` and refresh Vercel independently.

## 6. Verify

Run the focused suite from the repository root:

```bash
xcodebuild test -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:StatusPageMonitorAppTests/VercelProviderTests
```

The tests verify exact healthy text, incident precedence, known degraded mapping, and the check-failure behavior for missing, blank, and unrecognized labels.
