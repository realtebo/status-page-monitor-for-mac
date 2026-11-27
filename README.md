# Status Page Monitor

A native macOS menu bar app for monitoring third-party service status pages. The dashboard lets you enable any of the 16 built-in providers, set the check interval, and refresh a service individually. Checks run when the app starts and at the selected interval. The menu bar popover groups operational services and gives you quick access to checks and official status pages. Notifications are on the roadmap.

## Developer Setup

### Requirements

- macOS 13.0 or later
- Xcode 27.2 or later
- Swift 6.4 or later

### Clone and open

```bash
git clone https://github.com/realtebo/status-page-monitor-for-mac.git
cd status-page-monitor-for-mac
open StatusPageMonitor.xcodeproj
```

In Xcode, choose the `StatusPageMonitor` scheme and run with **Product → Run**.

### Build and run from the command line

```bash
xcodebuild -resolvePackageDependencies -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -derivedDataPath build -clonedSourcePackagesDirPath build/SourcePackages
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -configuration Debug -destination 'platform=macOS' -derivedDataPath build -clonedSourcePackagesDirPath build/SourcePackages build ONLY_ACTIVE_ARCH=YES
open build/Build/Products/Debug/StatusPageMonitor.app
```

### Run tests

```bash
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -configuration Debug -destination 'platform=macOS' -derivedDataPath build -clonedSourcePackagesDirPath build/SourcePackages test ONLY_ACTIVE_ARCH=YES
```

The checked-in Swift package lockfile pins dependency versions. Package sources and build products are kept under `build/` by these commands.

### Preview releases

Pushing a version tag such as `v0.01` to the official repository runs the macOS preview workflow. It uses the tag as the version shown in the app and publishes the Apple silicon ZIP as a prerelease on GitHub. Preview builds are intended for development and do not carry a Developer ID signature or Apple notarization.

## Project Structure

- `Sources/StatusPageMonitorApp/` — native SwiftUI application and menu bar interface
- `Sources/ServiceProviders/` — shared provider contract, built-in catalog, URL policy, bounded HTTP transport, JSON/HTML parsers, and Swift providers for special cases
- `Resources/ProviderManifests/` — reviewed built-in JSON provider definitions; currently includes Aircall
- `Tests/StatusPageMonitorAppTests/` — app-level tests
- `Tests/ServiceProvidersTests/` — provider contract, catalog, manifest validation, parser, and fixture-based provider tests
- `Documentation/providers/` — manifest schema, examples, authoring notes, and provider tutorials
- `Documentation/architecture/decisions/` — recorded architecture decisions
- `SPEC-*.md` — approved product and module specifications
- `tasks/` — implementation plan and ordered checklist

## Contribution Guide

Provider contributions use the shared provider contract and must include response fixtures, focused tests, and a service-specific implementation tutorial. The guides cover [Aircall with a JSON manifest](Documentation/providers/tutorials/01-aircall.md), [BigCommerce with a Swift provider](Documentation/providers/tutorials/02-bigcommerce.md), [Canva with a Swift provider](Documentation/providers/tutorials/03-canva.md), [Cloudflare with a Swift provider](Documentation/providers/tutorials/04-cloudflare.md), [Cloudways with a Swift provider](Documentation/providers/tutorials/05-cloudways.md), [GitHub with a Swift provider](Documentation/providers/tutorials/06-github.md), [HubSpot with a Swift provider](Documentation/providers/tutorials/07-hubspot.md), [MongoDB with a Swift provider](Documentation/providers/tutorials/08-mongodb.md), [Monday with a Swift provider](Documentation/providers/tutorials/09-monday.md), [ngrok with a Swift provider](Documentation/providers/tutorials/10-ngrok.md), [OpenAI](Documentation/providers/tutorials/11-openai.md), [Register.it](Documentation/providers/tutorials/12-register.md), [PayPal](Documentation/providers/tutorials/13-paypal.md), [Slack](Documentation/providers/tutorials/14-slack.md), [Stripe](Documentation/providers/tutorials/15-stripe.md), and [Vercel](Documentation/providers/tutorials/16-vercel.md). JSON and HTML manifests are described in the [provider manifest guide](Documentation/providers/README.md), with the formal [version 1 JSON Schema](Documentation/providers/provider-manifest-v1.schema.json). See [the provider specification](SPEC-service-providers.md) and [the contribution specification](SPEC-community-contributions.md) for project boundaries.

The maintainers publish and support official release artifacts from the canonical repository. Builds made from forks are not official or supported releases.
