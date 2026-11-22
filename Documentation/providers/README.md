# Provider manifests

The app accepts reviewed provider definitions written with schema version 1. A manifest describes one service and one read-only status-page check. Use the JSON Schema in [`provider-manifest-v1.schema.json`](provider-manifest-v1.schema.json) for editor completion and validation.

## Supported checks

Choose JSON when the status page exposes a stable JSON endpoint. JSON checks use JSON Pointer paths and explicit mappings from source values to app conditions. An optional incident collection reads an array and maps each incident's title and available fields.

Choose HTML when the page exposes stable server-rendered markup. HTML checks use CSS selectors and read either selected text or one named attribute. An optional incident collection selects incident titles and can read IDs, status, impact, summary, and URL attributes. HTML parsing does not run scripts or load a browser engine.

The examples in [`examples/`](examples/) show the complete JSON and HTML shapes. All check URLs use HTTPS and GET. Every condition mapping is explicit; a source value absent from the mapping remains an unrecognized status and must become a failed check at runtime.

## Add a manifest

1. Copy the closer example from `examples/` and give the service a stable lowercase ASCII id that is not already registered.
2. Set `service.statusPageURL` to the human-facing status page and `check.requestURL` to the endpoint or page the provider will read. Keep publisher attribution accurate.
3. Inspect a saved response or HTML fixture. Identify the overall condition field or element, then add an explicit mapping for every supported source value. Do not map missing values to `operational`.
4. If the source exposes incidents, map their collection and title fields. Add optional status, impact, summary, URL, and timestamp fields only when the source supplies them.
5. Validate the file against the schema, then run it through `ProviderManifestDecoder` tests. Add checked-in representative fixtures and focused tests with the contribution.
6. Submit the manifest, fixtures, tests, and a concise technical implementation tutorial together in a pull request.

## Validation and trust boundary

The decoder applies stricter runtime checks in addition to JSON Schema validation: a manifest is at most 65,536 bytes; JSON Pointers have at most 128 segments and 1,024 UTF-8 bytes; selectors are at most 512 characters; mappings contain at most 64 entries; and strings and URLs have bounded lengths. URLs must use HTTPS, cannot include credentials or fragments, and must use a public ASCII DNS hostname (internationalized names should use punycode); IP literals, malformed DNS names, and common local hostnames are rejected. The transport layer must validate redirects and response sizes before requesting a URL from a community definition.

Unknown properties, unsupported schema versions, HTTP methods, response formats, selectors, pointers, and mapped app states are rejected with a field-oriented error. A definition has no extension points for scripts, expressions, custom headers, credentials, or executable code. Add parsing behavior outside this finite schema as a reviewed Swift provider in the official repository.
