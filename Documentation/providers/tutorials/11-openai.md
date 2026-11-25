# Implementing the OpenAI provider

This tutorial ports the VS Code checker that reads a single banner on OpenAI’s status page. The source checker selects the first matching element, compares its trimmed text with an exact healthy phrase, and exposes other text to the caller.

## 1. Locate the source field

The source requests `https://status.openai.com/` and uses this selector:

```css
[data-testid="heads-up"] > div > div:first-child
```

The exact healthy text is `We’re fully operational`. The first matching node matters because the source uses `.first()`.

## 2. Parse with the shared HTML tools

Implement [`OpenAIStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/OpenAIStatusProvider.swift). Fetch through `HTTPTransport`, parse with `HTMLStatusPageParser`, and take the first matching element. Do not select another banner when this one is absent, or infer health from an empty response.

Map the exact healthy phrase to `operational`. The known banner `We’re currently experiencing issues` is mapped to `partialOutage` and shown as an active issue. If the selector is missing or empty, return a `missingField` failure. If a nonempty banner changes to unrecognized text, return an `unrecognizedStatus` failure so it is shown as a check problem, not as a provider outage or a healthy result.

## 3. Add fixtures and tests

Create HTML fixtures for the exact healthy banner, the known issue banner, two matching banners (to prove first-match behavior), missing markup, blank text, and an unknown label. `OpenAIProviderTests.swift` supplies each fixture through a fake transport, so the tests never depend on the live page.

## 4. Wire monitoring

Persist `monitor.openai.enabled`, call the provider at launch and on the configured interval, and include the service in the dashboard and menu bar popover. Its manual refresh belongs on its dashboard row. Keep status parsing in this provider; do not add JavaScript or remote code execution.

## 5. Verify

Run the focused suite from the repository root:

```bash
xcodebuild test -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:StatusPageMonitorAppTests/OpenAIProviderTests
```

The suite checks exact healthy matching, the mapped issue banner, first-match behavior, and missing, empty, or changed text.
