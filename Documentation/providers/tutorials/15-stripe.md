# Implementing the Stripe provider

This tutorial ports the Stripe checker from the VS Code extension. Its source rule combines three signals: the page body, an optional `.all-clear` message, and the first unresolved incident title. Keep the precedence explicit because an all-clear phrase in the body wins even if an incident title is also present.

## 1. Identify the source selectors

The checker requests `https://www.stripestatus.com/` and reads:

- `.unresolved-incidents .all-clear` for an optional all-clear message;
- the first of `.status-summary, .components-status, body` for the summary text;
- the first `.unresolved-incidents .unresolved-incident .incident-title .actual-title` for an incident title;
- the normalized text of the whole `body` for the phrase `All systems operational`.

Whitespace is collapsed and body matching is case-insensitive. The all-clear element and summary checks use trimmed text.

## 2. Port the exact all-clear rule

Implement [`StripeStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/StripeStatusProvider.swift) with the shared bounded HTTP transport and HTML parser. The source reports operational when any of these is true:

1. `All systems operational` occurs anywhere in the normalized body text;
2. there is no incident title and `.all-clear` has nonempty text;
3. there is no incident title and the selected summary contains `All systems operational`;
4. the body contains `Active incidents All systems operational`.

That last phrase also includes the general all-systems phrase, so preserve the source expression instead of simplifying its behavior around incidents. When an all-clear condition wins, return an operational observation without incidents, matching the source result's `ok` and `message` behavior.

## 3. Represent a non-operational result

If no all-clear condition wins and the first unresolved title exists, return a `partialOutage` observation with that title. The source provides no incident identifier, impact, status, URL, or timestamp, so leave those fields absent.

If no all-clear condition wins and no incident title is available, the source returns `ok: false` but its message falls back to `All systems operational`. The native provider reports an `unrecognizedStatus` check failure for this contradictory, unclassifiable page state. This keeps it orange as a read/interpretation failure instead of presenting the fallback text as an outage title or treating it as healthy.

## 4. Add fixtures and tests

Add HTML fixtures for an `.all-clear` element, an unresolved incident without an all-clear signal, a body all-clear phrase alongside an incident title, and an unrecognized summary without an incident title. `StripeProviderTests.swift` uses a fake transport to test these rules without a live request.

## 5. Wire app controls

Persist `monitor.stripe.enabled`, check Stripe at launch and on the configured interval, and add its refresh action to the Stripe dashboard row. Include the same result in the menu bar popover and latest-result details.

## 6. Verify

Run the focused suite from the repository root:

```bash
xcodebuild test -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:StatusPageMonitorAppTests/StripeProviderTests
```

The tests cover the source's all-clear selector, first unresolved title, all-clear precedence, and the failure path for a page that cannot be classified.
