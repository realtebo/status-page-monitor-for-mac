# Capability Map: Status Page Monitor for macOS

## Purpose

Build a native macOS app that monitors third-party status pages, reports active incidents and their resolution, and gives contributors a documented way to add providers.

## Confirmed product direction

- The first release includes all 16 services currently implemented in the VS Code extension.
- The repository is public and accepts community contributions and forks.
- Maintainers publish and support official release artifacts. Forks may produce their own builds.
- The app is a native SwiftUI menu bar app with a quick popover and a separate detail window.
- On first launch, the user chooses which services to monitor. No selected services means no checks are run.
- The app can remain in the menu bar after its window closes and can start at login; login startup is user-configurable.
- The initial refresh interval is 15 minutes. The minimum is 15 minutes, in increments of 5 minutes.
- Network and parsing failures are shown separately from service incidents and do not produce outage notifications.
- README and developer instructions are written in English.
- Community providers use versioned JSON definitions for supported patterns or Swift implementations for special cases. The app does not load third-party executable code at runtime.
- Provide one technical, concise, step-by-step tutorial for each built-in service; write and verify the 16 guides sequentially, using each as both an implementation walkthrough and an example.

## Capability map

| Module id | Responsibility | Depends on |
|---|---|---|
| `service-providers` | Shared provider contract, the 16 built-in integrations, and the declarative JSON format for common page patterns | — |
| `monitoring-engine` | Scheduling checks, storing observations, identifying incident and recovery transitions, and emitting events for the app | `service-providers` |
| `mac-app` | Menu bar, popover, detail window, onboarding, settings, login startup, and macOS notifications | `monitoring-engine`, `service-providers` |
| `community-contributions` | Public contribution workflow, provider authoring guide, 16 sequential service tutorials, validation expectations, and official release process | `service-providers`, `mac-app` |

Build order: `service-providers` → `monitoring-engine` → `mac-app` → `community-contributions`.

## Scope boundaries

- Always: treat status page responses as untrusted input; represent check failures separately from provider incidents; preserve the user's selected services and interval across relaunches.
- Ask before: adding runtime executable plugin support, cloud synchronization, accounts, or monitoring services outside the 16 confirmed providers.
- Never: silently interpret missing or unrecognized status data as operational; silently re-enable services after the user disables them all.
