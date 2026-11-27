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

### Releases

A maintainer starts a release by pushing an annotated version tag to the official repository. GitHub Actions uses the tag version in the app and publishes the Apple silicon ZIP as a regular GitHub release. Ordinary pushes to `main` only update the source.

Before tagging, review the changes since the previous release. Ask the release owner for the changelog text or draft it from the changes being shipped. Describe what users can now do, what changed, and which bugs were fixed. Put the final Markdown in the tag message. GitHub uses it as the release notes.

For example, when releasing `v0.03`, run the following commands at the commit you intend to ship. The first command opens your Git editor for the changelog. The second publishes that specific tag.

```bash
git tag -a v0.03
git push origin refs/tags/v0.03
```

Configure the Sparkle signing key before tagging the first update-enabled release. Users of v0.01 and v0.02 install that release manually. See [update signing and setup](Documentation/updates.md).

Release builds use ad hoc macOS signing.

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
