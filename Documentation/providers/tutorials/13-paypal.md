# Implementing the PayPal provider

This tutorial ports the PayPal production-events check. It requests the events API rather than scraping the user-facing status page; an event is an outage only while it is open, belongs to production, and falls inside its date window.

## 1. Read the source request and response

The extension calls `https://paypal-status.com/api/v1/events?s=true`. The JSON response stores the event list in `result`. Each event can contain `environment`, `state`, `summary`, `startDate`, and `endDate`.

The source reports `All Production Systems Operational` when no event passes its production/open/time-window filter. Otherwise it reports the first active event's summary. The app preserves the same filtering and displays each matching event from the endpoint.

## 2. Apply the active-event rule

Implement [`PayPalStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/PayPalStatusProvider.swift):

1. Require a JSON object containing a `result` array. Missing or wrongly typed event data is a check failure; it must not imply that PayPal is healthy.
2. For each event, require `environment`. Ignore non-`production` environments, as the source checker does.
3. For production events, require `state`. Ignore any state other than the exact `open` value; resolved events are not current incidents.
4. Parse optional `startDate` and `endDate` values. An absent, null, or empty bound is unbounded, matching the source check. A supplied but malformed timestamp fails the check instead of silently removing the bound.
5. Include the event when `startDate` is absent or at/before the check time and `endDate` is absent or at/after the check time. Both comparisons are inclusive.
6. Require a non-empty `summary` on each active event and expose it as the incident title. Active events map to `partialOutage`; an empty active-event list maps to `operational`.

## 3. Add fixtures and focused tests

Add fixtures for an empty event list, an active production event, resolved/future/ended and sandbox events, an event exactly on both time boundaries, missing response fields, an invalid timestamp, and malformed JSON. `PayPalProviderTests.swift` uses a fake `HTTPTransport`, so test outcomes are deterministic and do not depend on PayPal.

## 4. Wire monitoring controls

Persist `monitor.paypal.enabled`, invoke the provider at launch and at the configured interval, and add PayPal to the dashboard, detailed result, and menu-bar popover. The row-level refresh should call `checkPayPalNow()` and use the catalog's PayPal status-page URL for its external link.

## 5. Verify

Run the focused suite from the repository root:

```bash
xcodebuild test -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:StatusPageMonitorAppTests/PayPalProviderTests
```

The suite verifies event filtering, inclusive bounds, event summaries, required-field failures, and malformed source data.
