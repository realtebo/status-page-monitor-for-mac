# Spec: `community-contributions`

## Objective

Make the public repository understandable to developers and provide a predictable contribution path for status-page providers. The community may propose and implement providers through pull requests. Maintainers review and merge changes; maintainers publish and support official release artifacts. Forks and third-party builds may exist but are not official or supported releases. Provide a series of 16 technical, concise, step-by-step tutorials that teach implementation of every built-in provider, one guide at a time.

## Tech Stack

- Git-based public source repository and pull requests.
- English README and developer documentation.
- Development prerequisites: macOS 13.0+, Xcode 27.2+, Swift 6.4+.
- Versioned JSON provider schema for common response patterns.
- Swift provider protocol for special cases; no executable third-party plugins are downloaded or loaded at runtime.

## Commands

The README must publish verified commands for:

```bash
xcodebuild -resolvePackageDependencies -project StatusPageMonitor.xcodeproj
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -configuration Debug build
xcodebuild -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -destination 'platform=macOS' test
```

The README must identify the minimum macOS version, Xcode version, Swift version, and package prerequisites, matching [ADR-001](Documentation/architecture/decisions/ADR-001-platform-and-provider-format.md).

## Project Structure

```text
README.md                     User overview and developer setup guide
CONTRIBUTING.md               Provider contribution steps and review expectations
Documentation/providers/      JSON schema and Swift provider authoring guide
Documentation/providers/tutorials/ Numbered service tutorials and their index
Documentation/architecture/   Module map and provider contract
Sources/                       App, engine, and built-in providers
Tests/                         Unit and fixture tests
```

## Code Style

- Write developer-facing docs in English with copyable commands and expected outcomes.
- Each provider proposal includes the service name, public status URL, parsing approach, representative fixtures, and tests.
- Prefer a JSON definition when the status page matches a documented parser pattern; use Swift when the provider needs service-specific logic.
- Do not put secrets, personal tokens, or runtime code in provider definitions.
- Write guides in English. Make them technically detailed and step-by-step without padding them with repeated background or unrelated Swift/Xcode explanations.
- Write, verify, and review each service guide before starting the next. Keep a numbered index in service-catalog order.

```markdown
# Implementing the Aircall provider

1. Identify the status endpoint and the response fields used by the provider contract.
2. Add the JSON definition or Swift provider, following the service-specific steps.
3. Add a response fixture and a test for the documented status mapping.
4. Run the provider test command and compare its result with the expected output.
```

This is the required tutorial shape; each real guide must use service-specific details and working examples.

## Testing Strategy

- A provider pull request must include fixture-based tests and pass the documented build and test commands.
- Documentation changes must be checked for accurate prerequisites and executable commands.
- Verify each tutorial against the implementation, fixture, and test it describes before beginning the next guide.
- The official release process must build from the official repository and identify the source revision for each published artifact.

## Boundaries

- Always: explain how to run the app, run provider tests, add JSON and Swift providers, report bugs, and submit pull requests; make clear which release artifacts are official.
- Ask first: change contribution permissions, publish through an additional distribution channel, or add a runtime extension mechanism.
- Never: describe third-party forks or builds as official releases; require contributors to add network access or credentials without documenting the need and security impact.

## Success Criteria

- A new developer can find prerequisites, clone the repository, build, launch, and run tests using the README alone.
- A provider contributor can determine when to use JSON versus Swift and follow one documented contribution path.
- Every provider contribution can be reviewed from its fixtures, tests, source page, and stated parsing rules.
- The tutorial index lists 16 service guides in catalog order, each with a complete implementation path and a verification step.
- Each guide is detailed enough to reproduce its provider while avoiding unrelated background and repeated boilerplate.
- Official releases are published by maintainers from the official repository and are distinguishable from fork builds.

## Open Questions

- Which public Git hosting organization/repository will be canonical?
- Which official release channel will maintainers use?
- Which minimum macOS, Xcode, and Swift versions should be documented?
