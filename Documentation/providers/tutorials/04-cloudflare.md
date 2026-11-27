# Implementing the Cloudflare provider

## 1. Select the incident feed

Cloudflare provides a dedicated JSON endpoint for the **Active incidents** section of its status page. Request `GET /api/v2/incidents/unresolved.json` through the injected `HTTPTransport`. The page-wide summary also includes maintenance and component health, which are outside this provider's scope. [Cloudflare Status API](https://www.cloudflarestatus.com/api)

## 2. Parse one record per incident

In [CloudflareStatusProvider.swift](../../../Sources/ServiceProviders/BuiltIn/CloudflareStatusProvider.swift), require a top-level `incidents` array. Keep records in the investigating, identified, and monitoring states. Map each name to one menu entry, keeping its ID, impact, status, and newest update body when available. Ignore terminal and maintenance records. Unknown lifecycle or impact values and missing required fields produce a failed check.

## 3. Determine the monitoring state

An empty array means operational. Any open incident raises an issue, even when Cloudflare rates its impact as `none`. Minor impact maps to degraded performance and major or critical impact maps to major outage. With multiple open incidents, use the highest reported severity. When the last incident disappears, the next successful check reports recovery.

## 4. Verify the provider

The [fixture tests](../../../Tests/ServiceProvidersTests/CloudflareProviderTests.swift) check the requested URL, incident titles, lifecycle states, and malformed responses. Fixtures with maintenance or degraded components verify that these records cannot create an alert on their own.

```bash
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -only-testing:StatusPageMonitorAppTests/CloudflareProviderTests test ONLY_ACTIVE_ARCH=YES
```
