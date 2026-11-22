# Spec: `service-providers`

## Objective

Define a stable contract between the monitoring engine and integrations that read vendor status pages. Ship a provider for each of the 16 services in the source VS Code extension. Let contributors add common integrations through validated JSON definitions and special integrations through Swift code reviewed into the official repository. Provide one technical, step-by-step implementation guide for each built-in provider; each guide is both a concise tutorial and a working example of the provider contract.

### Built-in providers

| Service id | Status page |
|---|---|
| `aircall` | https://status.aircall.com/ |
| `bigcommerce` | https://status.bigcommerce.com/ |
| `canva` | https://www.canvastatus.com/ |
| `cloudflare` | https://www.cloudflarestatus.com/ |
| `cloudways` | https://status.cloudways.com/ |
| `github` | https://www.githubstatus.com/ |
| `hubspot` | https://status.hubspot.com/ |
| `mongodb` | https://status.mongodb.com/ |
| `monday` | https://status.monday.com/ |
| `ngrok` | https://status.ngrok.com/ |
| `openai` | https://status.openai.com/ |
| `register` | https://status.register.it/ |
| `paypal` | https://paypal-status.com/product/production |
| `slack` | https://slack-status.com/ |
| `stripe` | https://www.stripestatus.com/ |
| `vercel` | https://www.vercel-status.com/ |

## Tech Stack

- Swift and Swift Concurrency for provider implementations.
- Foundation `URLSession` and `JSONDecoder` for HTTP and JSON responses.
- A documented, versioned JSON Schema for supported declarative checks at `Documentation/providers/provider-manifest-v1.schema.json`.
- SwiftSoup 2.14.4 or compatible later 2.x releases for CSS-selector HTML parsing without a browser view in the polling path.
- Provider manifest schema version 1: HTTPS GET, JSON Pointer field extraction and incident collections, or HTML CSS selectors for text/attribute extraction; all status mappings are explicit.
- Provider implementations reject unknown response shapes and states as check failures. Use Swift for service-specific rules outside the finite JSON schema.

## Commands

Expected repository commands after the Xcode project is created:

```bash
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -configuration Debug build
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -destination 'platform=macOS' test
```

Provider development uses the same test command and includes fixtures for each provider.

## Project Structure

```text
Sources/ServiceProviders/        Provider protocol and result types
Sources/ServiceProviders/BuiltIn/ One implementation per built-in service
Sources/ServiceProviders/JSON/   JSON manifest schema, decoder, and validators
Sources/ServiceProviders/HTML/   HTML parsing support for declarative providers
Tests/ServiceProvidersTests/     Fixture-based provider and manifest tests
Documentation/providers/         Provider authoring guide and schema reference
Documentation/providers/tutorials/ Numbered implementation guide for each built-in provider
```

### Tutorial sequence

Write, verify, and review one guide at a time, in the same order as the service catalog:

1. Aircall — `01-aircall.md`
2. BigCommerce — `02-bigcommerce.md`
3. Canva — `03-canva.md`
4. Cloudflare — `04-cloudflare.md`
5. Cloudways — `05-cloudways.md`
6. GitHub — `06-github.md`
7. HubSpot — `07-hubspot.md`
8. MongoDB — `08-mongodb.md`
9. Monday — `09-monday.md`
10. Ngrok — `10-ngrok.md`
11. OpenAI — `11-openai.md`
12. Register.it — `12-register.md`
13. PayPal — `13-paypal.md`
14. Slack — `14-slack.md`
15. Stripe — `15-stripe.md`
16. Vercel — `16-vercel.md`

The tutorial index links to each guide and marks its completion state. Finish and verify each guide before beginning the next.

## Code Style

- Use `UpperCamelCase` for types and `lowerCamelCase` for values and functions.
- Keep each provider responsible for one vendor and keep service-specific interpretation inside that provider.
- Return a typed result instead of converting request, parsing, or unknown-status failures into an outage or a healthy result.
- Validate external payloads at the provider boundary.
- Make each tutorial technically detailed and step-by-step, but concise and free of repeated general material.

Each guide explains the status source and response shape, why the provider uses JSON or Swift, the ordered implementation steps, the relevant code, fixture and test creation, the command to verify it, the expected result, and any service-specific pitfalls.

```swift
protocol StatusProvider: Sendable {
    var definition: ServiceDefinition { get }
    func check(at date: Date) async -> ProviderCheckResult
}
```

### Version 1 provider manifests

The manifest decoder accepts only the fields documented in the checked-in schema. Each file declares `schemaVersion`, service identity and attribution, then a GET check with one response format. JSON manifests select values with RFC 6901 JSON Pointers. HTML manifests select elements with CSS and read either text or a named attribute. Optional incident collections use the same explicit field mappings. JSON and HTML blocks cannot be mixed in one check.

`ServiceID` is a validated lowercase ASCII slug of at most 64 bytes, so community providers can use new stable ids without editing a closed enum. The built-in catalog still defines the 16 ids listed above. The decoder rejects unknown fields and explicit `null` for optional properties, unsupported mappings, invalid selectors, malformed or local URLs, and manifests larger than 65,536 bytes. JSON Pointers are limited to 128 segments and 1,024 UTF-8 bytes; selectors to 512 characters; mappings to 64 entries. See the [manifest authoring guide](Documentation/providers/README.md) and its [JSON example](Documentation/providers/examples/json-status-provider.json) and [HTML example](Documentation/providers/examples/html-status-provider.json).

The manifest is data only. It has no script, expression, custom-header, credential, or arbitrary-code fields. Transport code must apply response-size and redirect checks before requesting its configured endpoint. A page-specific rule outside the finite schema belongs in reviewed Swift provider code.

`ProviderCheckResult` distinguishes a valid service observation from a failed check. A valid observation contains the overall condition and active incidents; a failed check contains a typed reason and timestamp. Missing or unrecognized required fields are check failures, never an implicit healthy state.

### Typed result model

- `ServiceID` is a stable, lowercase identifier. The built-in catalog uses the 16 ids in the order listed above.
- `ServiceDefinition` contains the id, display name, HTTPS status-page URL, and publisher name used for source attribution.
- `ServiceObservation` contains a known `ServiceCondition`, the active incidents, and the time the response was observed. Conditions are `operational`, `degradedPerformance`, `partialOutage`, `majorOutage`, and `maintenance`; there is no `unknown` condition.
- Each `ServiceIncident` carries its title, active lifecycle status, impact, optional summary, source URL, and source timestamps. Its source id is optional because some status pages do not publish one. Resolved incidents are omitted from `activeIncidents`; the monitoring engine detects recovery when a previously active incident is no longer present.
- `ProviderCheckResult` is either `.observed(ServiceObservation)` or `.failed(CheckFailure)`. Failure reasons distinguish network errors, HTTP status errors, invalid responses, missing fields, unrecognized status values, and invalid definitions. Each failure includes the attempted time.
- `StatusProvider.check(at:)` receives the attempt time and returns this result without throwing an outage status for transport or parsing failures.

## Testing Strategy

- Unit-test JSON manifest validation and each parser against checked-in response fixtures.
- Include healthy, active-incident, maintenance, malformed-response, and unrecognized-status examples where applicable.
- Test that provider failures remain distinct from valid service incidents.
- Do not make routine tests depend on live vendor pages; live checks are a manual diagnostic only.

## Boundaries

- Always: use unique stable service ids; include display name, status page URL, and provider attribution in definitions; validate remote data; include representative fixtures and tests with each provider contribution.
- Ask first: add a new manifest expression, new parser dependency, authenticated checks, or a provider that requires credentials.
- Never: execute JavaScript, shell commands, downloaded code, or third-party binaries from provider definitions; infer `operational` from absent or invalid status data.

## Success Criteria

- The registry contains all 16 services listed above.
- Each provider returns an observation or a typed check failure through the same interface.
- Active incident details can be surfaced to the UI, and unrecognized or missing status data cannot be mistaken for an all-clear state.
- A contributor can implement a supported check using a versioned JSON definition or add a Swift provider through a reviewed pull request.
- Every built-in provider has fixture coverage for its primary status interpretation.
- There is one numbered, standalone implementation guide for each of the 16 built-in providers.
- Each guide's code and explanation match its provider implementation and fixture tests.
- Guides are authored and reviewed sequentially, and the index distinguishes completed guides from those not yet written.

## Open Questions

No blocking questions. Platform and parser decisions are recorded in [ADR-001](Documentation/architecture/decisions/ADR-001-platform-and-provider-format.md).
