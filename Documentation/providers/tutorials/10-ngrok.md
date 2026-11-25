# Implementing the ngrok provider

This tutorial ports the VS Code check that treats one exact status label as healthy. Keep the comparison strict so a changed status page cannot be mistaken for recovery.

## 1. Find the source rule

The extension requests `https://status.ngrok.com/`, selects `.page-status h2.status`, and compares its text with `All Systems Operational`. Any other nonempty text means the source checker is not healthy.

## 2. Read the selected text

Implement [`NgrokStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/NgrokStatusProvider.swift). Use the shared bounded HTTP transport and HTML parser, and require exactly one matching status element. The provider maps the exact operational phrase to `operational`; known `Partial System Outage`, `Major System Outage`, `Degraded Performance`, and `Scheduled Maintenance` labels map to their corresponding conditions. Unknown nonempty text is an unrecognized-status check failure. An absent selector or blank text is a missing-field check failure, not an outage or a healthy response.

## 3. Add fixtures and focused tests

Create fixtures for the exact operational phrase, known outage and maintenance labels, unknown text, a missing selector, and an empty element. `NgrokProviderTests.swift` injects those responses through a fake transport. The cases verify both the strict match and the distinction between known service conditions and unreadable or changed page data.

## 4. Wire app controls

Persist `monitor.ngrok.enabled`, invoke the provider during startup and interval checks, and add the row to the popover, dashboard, and detailed result section. Keep the manual refresh control on the ngrok dashboard row.

## 5. Verify

Run the focused suite from the repository root:

```bash
xcodebuild test -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:StatusPageMonitorAppTests/NgrokProviderTests
```

Then build and run the app. Enable ngrok in the dashboard and confirm its row and popover show the same result as the provider test mapping.
