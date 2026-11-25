# Implementing the BigCommerce provider

This guide ports the BigCommerce parser from the VS Code extension to a native Swift provider. The page encodes its summary state in a class on `<body>` and lists unresolved incidents in a separate HTML section, so a reviewed Swift provider is clearer than a JSON manifest.

## 1. Identify the source fields

The public page is [status.bigcommerce.com](https://status.bigcommerce.com/). The source extension reads the page HTML at `https://status.bigcommerce.com/` and extracts:

- a `status-*` token from the `<body>` class list, excluding the generic `status` and `status-index` classes;
- incident titles from `.unresolved-incidents .unresolved-incident .incident-title .actual-title`.

The indicator values used by the source extension are `none`, `maintenance`, `minor`, `major`, and `critical`. The provider maps them explicitly to the app's typed conditions.

## 2. Implement `StatusProvider`

Add [`BigCommerceStatusProvider.swift`](../../../Sources/ServiceProviders/BuiltIn/BigCommerceStatusProvider.swift). Keep the page URL and the field rules inside this provider. The shared `URLSessionHTTPTransport` performs a bounded HTTPS GET; `HTMLStatusPageParser` uses SwiftSoup to parse the returned bytes.

The `<body>` class attribute contains several tokens, for example `status status-none status-index`. Split it on whitespace, then select the first token that starts with `status-` and is not one of the excluded generic tokens. Remove the prefix to get the source indicator. Map:

| Source token | App condition |
| --- | --- |
| `none` | `operational` |
| `maintenance` | `maintenance` |
| `minor` | `degradedPerformance` |
| `major`, `critical` | `majorOutage` |

If the body or status token is missing, return a typed missing-field failure. If the token is new, return `unrecognizedStatus`. Do not infer operational status from an absent token.

## 3. Extract open incidents

Select every element matching the unresolved-incident title selector and trim its text. Each title becomes a `ServiceIncident` in `activeIncidents`. A page with no matching title elements yields an empty incident list; the overall body status is still required and controls the service condition.

The existing page markup does not provide the incident detail fields used by the JSON provider, so this integration includes the title only. Do not fabricate IDs, impact, summary text, or timestamps.

## 4. Add deterministic fixtures

Add the BigCommerce HTML files under [`Tests/ServiceProvidersTests/Fixtures`](../../../Tests/ServiceProvidersTests/Fixtures):

- `bigcommerce-operational.html` — `status-none`, no open incident.
- `bigcommerce-active-incident.html` — `status-major` and one unresolved title.
- `bigcommerce-maintenance.html` — `status-maintenance`, which maps to maintenance rather than an outage.
- `bigcommerce-unknown-status.html` — an unmapped status token, which must fail.
- `bigcommerce-missing-status.html` — no `status-*` token, which must fail as a missing field.

`BigCommerceProviderTests.swift` supplies a fake `HTTPTransport`; tests never fetch the live page.

## 5. Verify the provider

From the repository root, run:

```bash
xcodebuild -quiet \
  -project StatusPageMonitor.xcodeproj \
  -scheme StatusPageMonitor \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  test \
  -only-testing:StatusPageMonitorAppTests/BigCommerceProviderTests \
  ONLY_ACTIVE_ARCH=YES
```

The expected result is four passing BigCommerce tests covering operational state, an active incident, maintenance, and missing or unknown status classes.

## Common mistakes

- Comparing the entire `<body class>` string: it contains unrelated classes that vary with page state.
- Treating `status-index` as the indicator: it identifies the page layout, not service health.
- Treating an unknown `status-*` token as operational: the provider returns a check failure so the popover can show the orange error state.
- Adding HTML extraction to a JSON manifest: this source requires selector logic and class-token parsing, so it belongs in reviewed Swift code.
