# Implementing the Slack provider

This tutorial ports the Slack checker from the VS Code extension. Its source rule is a strict text comparison: only one exact heading indicates healthy status.

## 1. Identify the status field

The checker requests `https://slack-status.com/`, takes the first element matching `h1.text-center`, trims its text, and compares it with `Slack is up and running`.

## 2. Distinguish outages from failed reads

Implement [`SlackStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/SlackStatusProvider.swift). Reuse `HTTPTransport` and `HTMLStatusPageParser`; select the first match to preserve the source behavior. Map the exact phrase to `operational`. A different nonempty heading means the source checker returned a valid `ok: false` status, so expose its text as an active issue with `partialOutage`. Missing or blank heading text means the status could not be read and is a `missingField` failure.

## 3. Add fixture coverage

Use HTML fixtures for the expected heading, a later matching heading (to verify first-match behavior), a non-operational phrase, missing markup, and blank text. `SlackProviderTests.swift` injects each fixture with a fake transport, so the tests do not contact Slack.

## 4. Wire the app

Register Slack in the built-in catalog and Xcode project, persist its enabled preference, and add its check action to startup and interval scheduling. Add its row to the dashboard and popover with the status page URL for its link.

## 5. Verify

Run the focused suite from the repository root:

```bash
xcodebuild test -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:StatusPageMonitorAppTests/SlackProviderTests
```

The tests verify strict healthy matching, first-match selection, non-operational text as an issue, and missing/blank text as a failed read.
