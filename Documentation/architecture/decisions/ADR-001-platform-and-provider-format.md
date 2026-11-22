# ADR-001: macOS Baseline and Provider Parsing

## Status

Accepted for the first implementation.

## Date

2026-11-22

## Context

The app must behave as a persistent macOS menu bar utility, register itself to start at login, parse both JSON status APIs and HTML pages, and let contributors add providers without executing downloaded code. The VS Code source contains both JSON-based checks and service-specific HTML interpretation.

## Decision

- Set the deployment target to **macOS 13.0**. The product uses SwiftUI `MenuBarExtra` for its persistent menu bar entry and `SMAppService` for login startup; Apple documents `SMAppService` for macOS 13 and later.
- Require **Xcode 27.2 or later** and **Swift 6.4 or later** for development. These versions are available in the implementation environment at the time of this decision.
- Use **SwiftSoup 2.14.4 or compatible later 2.x releases** for HTML parsing. It supports macOS and CSS selectors and can parse saved fixtures without a browser view.
- Define **provider manifest schema version 1** with a deliberately finite feature set:
  - HTTPS GET requests only.
  - JSON responses read through JSON Pointer fields, explicit value-to-state mappings, and declared incident collections/status fields.
  - HTML responses read through CSS selectors, selecting text or a named attribute, with explicit value mappings and declared incident-title selectors.
  - Reject unsupported expressions, invalid manifests, missing required fields, and unrecognized service states as check failures.
  - Use a Swift provider for vendor-specific logic beyond this set. Never execute code from a manifest.
- Run an initial check after onboarding completes and on each app launch, then continue at the configured interval.
- Enable login startup on first install, with a user setting to turn it off.
- Explain notification use after service selection and before requesting macOS notification permission. If permission is denied, keep monitoring and show status in the app.
- Persist the current observation and most recent incident/recovery transition per service so alerts remain deduplicated across relaunches. Do not add a long-term incident-history feature in the first release.
- Defer the canonical public hosting organization and exact official artifact channel to the release-documentation task; this does not block app implementation.

## Alternatives Considered

### WebKit for all HTML checks

- Rejected because status extraction needs static DOM parsing, while embedding a browser in a scheduled polling path adds lifecycle and resource complexity.

### JSON manifests only

- Rejected because some existing providers have vendor-specific maintenance and incident rules that do not fit a small declarative format.

### Downloaded executable plugins

- Rejected because the public contribution goal can be served with reviewed JSON definitions and Swift providers in the repository without loading arbitrary third-party code at runtime.

## Consequences

- macOS 13 is the minimum supported runtime; APIs that require a later version need an explicit availability decision.
- HTML providers can share CSS-selector parsing and fixture tests.
- The JSON schema remains reviewable and safe to validate; unusual parsing remains ordinary, testable Swift code.
- Contributors need the documented Xcode/Swift toolchain to build and run the app.
- Hosting and release artifact publication can be selected independently before release preparation.

## References

- [Apple: MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Apple: SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [SwiftSoup repository and API examples](https://github.com/scinfu/SwiftSoup)
- [SwiftSoup releases](https://github.com/scinfu/SwiftSoup/releases)
