# Implementation Plan: Status Page Monitor for macOS

## Overview

Build a native SwiftUI menu bar app that checks the 16 status providers from the VS Code extension, reports incident and recovery transitions, and offers English developer documentation. Each provider will be implemented and verified in its own slice, paired with a concise, detailed, step-by-step tutorial. Community contributions enter through the public repository; maintainers publish and support official releases.

## Architecture Decisions

- **Native app:** SwiftUI menu bar app with a quick popover and a separate detail window; use system frameworks for notifications and login startup.
- **Platform baseline:** macOS 13.0+, Xcode 27.2+, Swift 6.4+; SwiftSoup 2.14.4+ (2.x) parses HTML fixtures and pages. Rationale and provider schema limits are in ADR-001.
- **Provider boundary:** define the provider contract before the engine. Use versioned JSON definitions for supported common patterns and Swift providers for special parsing. Do not execute downloaded or third-party code at runtime.
- **Check semantics:** valid provider observations and check failures are separate types. A network, HTTP, or parsing failure is not an outage and cannot be converted to an operational result.
- **User configuration:** first-run service selection; allow all services to be disabled; start with a 15-minute interval and allow values no lower than 15 in increments of 5.
- **Startup and alerts:** check after onboarding and app launch; login startup is enabled initially but user-configurable; explain notification permission before prompting; retain the latest incident/recovery transition per service.
- **Tutorials:** one guide per built-in service, written and verified sequentially in the same order as the provider catalog. Each guide must match the actual implementation, fixture, and test.
- **Official releases:** maintainers publish and support artifacts from the canonical repository. Forks may produce other builds; they are not official or supported.

## Dependency Graph

```text
Platform and parser decisions
          ↓
Xcode app scaffold
          ↓
Provider contract → JSON manifest support → shared HTTP/HTML support
          ↓
Aircall provider + tutorial → BigCommerce → Canva → Cloudflare → Cloudways
          → GitHub → HubSpot → MongoDB → Monday → Ngrok → OpenAI
          → Register.it → PayPal → Slack → Stripe → Vercel
          ↓
Monitoring engine and persisted incident transitions
          ↓
Menu bar app, onboarding, settings, login startup, notifications
          ↓
Contribution docs, tutorial index, official release documentation
```

Each service step implements the provider, adds representative fixtures and tests, and writes its tutorial before moving to the next provider. The shared tutorial index is updated after the sequence so each individual slice stays small.

## Task List

The ordered checklist, acceptance criteria, verification commands, dependencies, and expected files are in [`todo.md`](todo.md).

## Verification Checkpoints

- **Foundation:** provider contract, manifest validation, and shared transport build and pass focused tests.
- **Provider sequence:** after every three providers, all completed providers and tutorials still pass their focused checks; the next guide has not started until the current one is reviewed.
- **Engine:** interval scheduling, persisted state, incident transitions, and recovery events pass deterministic tests.
- **App flow:** first-run service selection, all-disabled state, menu bar, settings, login startup, and notification behaviors are checked in the supported macOS environment.
- **Release readiness:** documented developer commands work from a clean checkout; all 16 providers and their guides are present; official release instructions identify the source revision.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Status pages change markup or API shapes | A provider can report a check failure or misread a new state | Validate response shapes; keep fixture tests; represent unknown data as check failure; document the source and interpretation in each guide |
| A shared JSON format cannot express a vendor's special rules | Community definitions become complex or inaccurate | Keep JSON limited to documented patterns and implement special cases with reviewed Swift providers |
| macOS background scheduling does not run like a continuously active server timer | Checks may be delayed while the system sleeps or the app is suspended | Define scheduling behavior against macOS lifecycle APIs and display actual check timestamps |
| Notification permission is declined | Incidents remain visible in the UI but no native alerts are delivered | Explain permission in the app and keep current status visible in the menu bar and detail window |
| Tutorial prose drifts from the code | Contributors learn an implementation that no longer matches the app | Build and test each provider with its guide, fixture, and expected result in the same slice |

## Deferred Decisions

- Canonical public Git hosting organization and exact official artifact channel. Resolve these during release documentation; they do not block implementation.
