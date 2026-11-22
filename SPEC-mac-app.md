# Spec: `mac-app`

## Objective

Provide a native macOS interface for configuring and viewing service monitoring. The app stays available from the menu bar, offers a quick popover, and provides a detail window for the full service list and settings.

## Tech Stack

- SwiftUI for the menu bar experience, popover, onboarding, settings, and detail window.
- AppKit and ServiceManagement only where SwiftUI needs system integration, including login startup.
- UserNotifications for incident and recovery notifications.
- `service-providers` and `monitoring-engine` supply provider data and transition events.
- Minimum supported runtime: macOS 13.0; developer toolchain: Xcode 27.2+ and Swift 6.4+.

## Commands

Expected repository commands after the Xcode project is created:

```bash
open StatusPageMonitor.xcodeproj
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -configuration Debug build
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -destination 'platform=macOS' test
```

The developer README must document prerequisites, cloning, dependency resolution, opening in Xcode, building, running, and testing.

## Project Structure

```text
Sources/StatusPageMonitorApp/        App entry point and menu bar scene
Sources/StatusPageMonitorApp/Views/  Popover, detail window, onboarding, and settings
Sources/StatusPageMonitorApp/State/  UI state and app preferences
Sources/StatusPageMonitorApp/Notifications/ Notification authorization and actions
Resources/                            App assets and built-in service manifests
Tests/StatusPageMonitorAppTests/     View-model and app-flow tests
```

## Code Style

- Use SwiftUI value views and observable state models; keep network work out of view bodies.
- Present provider state consistently: operational, active incident, and check failed are separate states.
- Show service name, useful incident detail, last check time, and a link to the vendor's status page.
- Keep user preferences explicit and persisted; do not infer a selected service when the saved selection is empty.

```swift
struct ServiceRow: View {
    let service: ServiceDefinition
    let outcome: CheckOutcome?

    var body: some View {
        Text(service.displayName)
    }
}
```

## Testing Strategy

- Unit-test onboarding selection, interval validation, and view-model state mapping.
- Test that zero selected services displays an empty selection state and runs no checks.
- Test notification content for incident and recovery transitions, and confirm check failures do not trigger outage notifications.
- Manually verify menu bar behavior, window/popover presentation, login startup toggle, and notification permission behavior on the supported macOS version.

## Boundaries

- Always: run the first-run service selection flow; support independent service toggles; default the interval to 15 minutes; enforce a 15-minute minimum in increments of 5; enable login startup on first install with a setting to turn it off; show a distinct check-failed state.
- Ask first: add analytics, accounts, cloud sync, or additional UI surfaces beyond the menu bar, popover, and detail window.
- Never: mark a service operational because a check failed; force at least one service to stay enabled; silently request or assume notification permission without a user-facing explanation.

## Success Criteria

- The menu bar app remains available when the detail window closes.
- The popover provides a compact aggregate status and quick access to details; the detail window lists all configured services and their current state.
- First launch asks which services to monitor; subsequent launches restore that selection.
- The user can configure a 15-minute-or-greater interval in five-minute increments and independently enable/disable each service.
- The user can enable or disable launch at login.
- Login startup is initially enabled and can be turned off in settings.
- Native notifications identify the affected service and incident details, then report recovery with a detection timestamp.
- Explain notifications after service selection and before the system permission request; declining permission does not stop monitoring.
- Failed checks are visible as check failures and do not generate outage or recovery notifications.
- Selecting a service can open its status page in the default browser.

## Open Questions

No blocking questions. Platform and first-run behavior are recorded in [ADR-001](Documentation/architecture/decisions/ADR-001-platform-and-provider-format.md).
