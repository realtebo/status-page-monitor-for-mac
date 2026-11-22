# Status Page Monitor

A native macOS menu bar app for monitoring third-party service status pages. The project is being built in small steps; the current scaffold provides the menu bar control and dashboard shell while provider monitoring is implemented.

## Developer Setup

### Requirements

- macOS 13.0 or later
- Xcode 27.2 or later
- Swift 6.4 or later

### Clone and open

```bash
git clone <official-repository-url>
cd status-page-monitor-mac
open StatusPageMonitor.xcodeproj
```

Replace `<official-repository-url>` with the canonical repository URL once it is published. In Xcode, choose the `StatusPageMonitor` scheme and run with **Product → Run**.

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

## Project Structure

- `Sources/StatusPageMonitorApp/` — native SwiftUI application and menu bar interface
- `Sources/ServiceProviders/` — shared provider contract, built-in catalog, URL policy, bounded HTTP transport, and JSON/HTML parsers
- `Tests/StatusPageMonitorAppTests/` — app-level tests
- `Tests/ServiceProvidersTests/` — provider contract, catalog, and manifest validation tests
- `Documentation/providers/` — manifest schema, examples, authoring notes, and provider tutorials
- `Documentation/architecture/decisions/` — recorded architecture decisions
- `SPEC-*.md` — approved product and module specifications
- `tasks/` — implementation plan and ordered checklist

## Contribution Guide

Provider contributions use the shared provider contract and must include response fixtures, focused tests, and a service-specific implementation tutorial. JSON and HTML manifests are described in the [provider manifest guide](Documentation/providers/README.md), with the formal [version 1 JSON Schema](Documentation/providers/provider-manifest-v1.schema.json). See [the provider specification](SPEC-service-providers.md) and [the contribution specification](SPEC-community-contributions.md) for project boundaries.

The maintainers publish and support official release artifacts from the canonical repository. Builds made from forks are not official or supported releases.
