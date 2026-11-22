# Spec: `monitoring-engine`

## Objective

Run checks for enabled providers on a configurable schedule, persist the latest observations, and emit distinct incident and recovery events. The engine must distinguish vendor status from failures to reach or parse a status page.

## Tech Stack

- Swift Concurrency for asynchronous provider checks and scheduling.
- Foundation for dates, persistence encoding, and cancellation.
- A versioned local persistence format for user preferences, latest observations, and incident transitions.
- macOS UserNotifications integration is owned by `mac-app`; the engine emits events and does not present UI.
- Run the initial check after onboarding and on app launch; continue on the configured interval.
- Persist the current observation and latest incident/recovery transition per service for deduplication and latest-state display. Long-term incident history is outside first-release scope.

## Commands

Expected repository commands after the Xcode project is created:

```bash
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -configuration Debug build
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -destination 'platform=macOS' test
```

## Project Structure

```text
Sources/MonitoringEngine/       Scheduler, check orchestration, and state transitions
Sources/MonitoringEngine/Models/ Observation and incident event types
Sources/MonitoringEngine/Storage/ Local state persistence
Tests/MonitoringEngineTests/    Scheduling, persistence, and transition tests
```

## Code Style

- Model provider status and check execution as separate typed states.
- Keep scheduling, state comparison, persistence, and notification presentation behind narrow interfaces.
- Make event timestamps explicit and use `Date` values in the domain model.
- Avoid hidden retries or status substitutions; surface the last check failure with its timestamp.

```swift
enum CheckOutcome: Sendable {
    case observed(ServiceSnapshot)
    case failed(CheckFailure, attemptedAt: Date)
}
```

## Testing Strategy

- Unit-test interval validation, service selection, and schedule rescheduling after settings changes.
- Test transitions from operational to incident and incident to resolved, including app relaunch with persisted state.
- Test that network, DNS, HTTP, and parsing failures produce a check-failed state and no outage event.
- Test the all-services-disabled case: run zero provider checks and do not restore a default selection.
- Use deterministic clocks and fake providers; do not require live network access in routine tests.

## Boundaries

- Always: start with a 15-minute interval; require an interval of at least 15 minutes in increments of 5; persist the user's choice; allow zero enabled services; keep check failures separate from service incidents.
- Ask first: add cloud state synchronization, a check history retention policy beyond current state and transitions, or a configurable retry policy.
- Never: generate outage notifications from a network or parser failure; replace a failed check with an older observation as if it were current; silently enable services.

## Success Criteria

- Enabled providers are checked on the configured schedule, and the schedule updates when the interval changes.
- The initial interval is 15 minutes; invalid values are rejected at the settings boundary rather than silently replaced.
- The engine records the first observed time of an incident and the time it detects recovery.
- The latest incident or recovery timestamp remains available after relaunch until a later transition replaces it.
- An incident transition and its recovery each produce a single event; a failed check does not produce either event.
- State survives app relaunch so persistent incidents do not create duplicate “new incident” notifications.
- Disabling every service results in zero checks.

## Open Questions

No blocking questions. Scheduling and transition persistence decisions are recorded in [ADR-001](Documentation/architecture/decisions/ADR-001-platform-and-provider-format.md).
