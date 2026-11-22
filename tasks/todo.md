# Implementation Tasks

Tasks are ordered by dependency. Complete each provider and its tutorial before starting the next provider tutorial.

## Phase 1: Decisions and Foundation

### Task 1: Resolve platform and remaining product decisions — complete

**Description:** Confirm the minimum macOS/toolchain target, HTML parser, JSON manifest scope, first-check timing, login-startup default, notification permission timing, resolved-event retention, canonical repository host, and official artifact channel. Record decisions and rationale in an ADR or the architecture documentation.

**Acceptance criteria:**
- [x] Every open question in `tasks/plan.md` has a recorded decision or an explicit deferral that does not block the next task.
- [x] The selected macOS and Xcode versions support the required menu bar and login-startup APIs.
- [x] The HTML parsing and JSON definition boundaries are documented.

**Verification:** Reviewed ADR-001 against the product specs. The canonical hosting organization and artifact channel are explicitly deferred and do not block app implementation.

**Dependencies:** None.

**Files touched:** `Documentation/architecture/decisions/ADR-001-platform-and-provider-format.md`, `SPEC-mac-app.md`, `SPEC-service-providers.md`, `SPEC-monitoring-engine.md`, `SPEC-community-contributions.md`, `tasks/plan.md`, and this task list.

**Estimated scope:** Medium.

### Task 2: Create the macOS app scaffold and developer README

**Description:** Create the SwiftUI macOS app project, app entry point, menu bar scene shell, repository ignore rules, and English README with prerequisites and the verified local build/run workflow.

**Acceptance criteria:**
- [x] The Xcode project builds a runnable macOS app with the documented Xcode version and minimum deployment target.
- [x] The README states requirements and provides clone, resolve, build, run, and test steps; the repository URL remains an explicit placeholder until its canonical host is selected.
- [x] The app shell defines a menu bar item with a placeholder popover and a separate dashboard window.

**Verification:** `xcodebuild -quiet -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -destination 'platform=macOS' -derivedDataPath build build` and the corresponding `test` command passed. Launched the built app and visually verified the dashboard window. `MenuBarExtra` and the popover compile, but the computer-use interface did not expose the system status item for a click-through check.

**Dependencies:** Task 1.

**Files touched:** `StatusPageMonitor.xcodeproj/`, `Sources/StatusPageMonitorApp/`, `Tests/StatusPageMonitorAppTests/`, `README.md`, `.gitignore`, and this task list.

**Estimated scope:** Medium.

### Task 3: Define the provider contract and service catalog

**Description:** Add stable service identifiers, provider definitions, typed observations, incident data, and a typed distinction between valid observations and check failures. Register all 16 confirmed services.

**Acceptance criteria:**
- [x] The shared contract can express operational state, active incident details, and a failed check separately.
- [x] All 16 service ids and status URLs match `SPEC-service-providers.md` in catalog order.
- [x] Missing fields and unrecognized statuses have explicit failure reasons separate from service conditions.

**Verification:** `xcodebuild -quiet -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -destination 'platform=macOS' -derivedDataPath build test` passed all 8 app and provider-contract tests. The catalog test checks all 16 ids, their order, exact status-page URLs, HTTPS URLs, and provider attribution.

**Dependencies:** Task 2.

**Files touched:** `Sources/ServiceProviders/`, `Tests/ServiceProvidersTests/`, `StatusPageMonitor.xcodeproj/project.pbxproj`, `SPEC-service-providers.md`, `README.md`, and this task list.

**Estimated scope:** Medium.

### Checkpoint: Provider foundation

- [x] App scaffold builds and launches.
- [x] Provider contract and 16-entry catalog are stable.
- [x] Foundation tests pass before parser or service-specific work begins.

### Task 4: Implement and validate versioned JSON provider definitions

**Description:** Define a versioned JSON schema and decoder for the supported declarative check patterns, with clear validation errors for unsupported or incomplete definitions.

**Acceptance criteria:**
- [x] Valid definitions can describe only documented JSON or HTML patterns.
- [x] Invalid versions, URLs, selectors, mappings, and required fields fail validation with actionable errors.
- [x] Definitions cannot execute scripts or arbitrary code.

**Verification:** `xcodebuild -quiet -project StatusPageMonitor.xcodeproj -scheme StatusPageMonitor -destination platform=macOS,arch=arm64 -derivedDataPath build -clonedSourcePackagesDirPath build/SourcePackages test ONLY_ACTIVE_ARCH=YES` passed all 18 app and provider tests. Decoder coverage includes JSON and HTML examples, unsupported versions/methods, unsafe and non-HTTPS URLs, missing and explicit-null fields, unknown fields/states, malformed JSON Pointers/selectors, format mismatches, and oversized manifests. `python3 -m json.tool Documentation/providers/provider-manifest-v1.schema.json` and both example manifests parsed successfully.

**Dependencies:** Task 3.

**Files touched:** `Sources/ServiceProviders/JSON/`, `Documentation/providers/`, `Tests/ServiceProvidersTests/`, `StatusPageMonitor.xcodeproj/`, `README.md`, `SPEC-service-providers.md`, and this task list.

**Estimated scope:** Medium.

### Task 5: Add shared HTTP and HTML parsing support

**Description:** Implement bounded HTTP requests, response validation, and the selected HTML parser support used by declarative and Swift providers.

**Acceptance criteria:**
- [ ] HTTP status, timeout, decoding, and parsing failures map to typed check failures.
- [ ] HTML extraction supports the documented selector features without embedding a browser in the check path.
- [ ] Network and parser code can be exercised with deterministic fixtures or fakes.

**Verification:** Run focused transport/parser tests for valid responses, HTTP errors, malformed data, and missing selectors.

**Dependencies:** Tasks 1, 3, and 4.

**Files likely touched:** `Sources/ServiceProviders/HTTP/`, `Sources/ServiceProviders/HTML/`, `Tests/ServiceProvidersTests/`.

**Estimated scope:** Medium.

## Phase 2: Providers and Tutorials, One at a Time

Each task implements the named provider and its tutorial together. Keep each task to the provider definition or implementation, fixture, focused test, and one guide. Update the shared tutorial index after Task 21.

### Task 6: Aircall provider and tutorial 01

**Description:** Implement the Aircall provider using its status endpoint and add the first complete tutorial.

**Acceptance criteria:**
- [ ] Aircall healthy, active-incident, and invalid-response cases are covered by fixtures.
- [ ] `01-aircall.md` gives concise, detailed steps, explains the endpoint and field mapping, and matches the implementation.
- [ ] The guide includes the focused verification command and expected result.

**Verification:** Run Aircall fixture tests and follow the guide from the provider contract to the passing test.

**Dependencies:** Tasks 3–5.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/AircallProvider.swift` or JSON definition, `Tests/ServiceProvidersTests/Fixtures/aircall.*`, `Tests/ServiceProvidersTests/AircallProviderTests.swift`, `Documentation/providers/tutorials/01-aircall.md`.

**Estimated scope:** Medium.

### Task 7: BigCommerce provider and tutorial 02

**Description:** Implement the BigCommerce status-page interpretation and its tutorial.

**Acceptance criteria:**
- [ ] Operational, incident, and unrecognized markup cases have fixtures and focused tests.
- [ ] `02-bigcommerce.md` explains the relevant HTML structure, mapping, and verification steps.
- [ ] The tutorial examples match the tested provider.

**Verification:** Run BigCommerce fixture tests and follow the guide to reproduce the result.

**Dependencies:** Task 6.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/BigCommerceProvider.swift` or JSON definition, BigCommerce fixture, focused test, `Documentation/providers/tutorials/02-bigcommerce.md`.

**Estimated scope:** Medium.

### Task 8: Canva provider and tutorial 03

**Description:** Implement Canva status and active-incident/maintenance interpretation and its tutorial.

**Acceptance criteria:**
- [ ] Healthy, active incident, maintenance, and malformed-response cases are represented in fixtures.
- [ ] `03-canva.md` explains the endpoint fields and status mapping without implying maintenance is an outage if the source behavior says otherwise.
- [ ] Tutorial and tests agree on expected states.

**Verification:** Run Canva fixture tests and follow the guide through its verification command.

**Dependencies:** Task 7.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/CanvaProvider.swift` or JSON definition, Canva fixture, focused test, `Documentation/providers/tutorials/03-canva.md`.

**Estimated scope:** Medium.

### Checkpoint: Providers 01–03

- [ ] Aircall, BigCommerce, and Canva fixture tests pass.
- [ ] Each completed tutorial reproduces its provider interpretation.
- [ ] Do not start Cloudflare until the three guides and providers are reviewed.

### Task 9: Cloudflare provider and tutorial 04

**Description:** Implement Cloudflare status interpretation, including its maintenance and component behavior, and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover all-clear, active incident, maintenance, degraded component, and malformed data.
- [ ] `04-cloudflare.md` explains the source fields and the rule that distinguishes maintenance from an outage.
- [ ] The test result matches the guide's expected output.

**Verification:** Run Cloudflare fixture tests and follow the guide end to end.

**Dependencies:** Task 8.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/CloudflareProvider.swift`, Cloudflare fixtures, focused test, `Documentation/providers/tutorials/04-cloudflare.md`.

**Estimated scope:** Medium.

### Task 10: Cloudways provider and tutorial 05

**Description:** Implement Cloudways status parsing and its tutorial.

**Acceptance criteria:**
- [ ] Operational, incident, and unrecognized status cases have fixtures and tests.
- [ ] `05-cloudways.md` explains the status mapping and required HTML/API fields.
- [ ] The tutorial is reproducible from the shared provider contract.

**Verification:** Run Cloudways fixture tests and follow the guide's verification steps.

**Dependencies:** Task 9.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/CloudwaysProvider.swift` or JSON definition, Cloudways fixture, focused test, `Documentation/providers/tutorials/05-cloudways.md`.

**Estimated scope:** Medium.

### Task 11: GitHub provider and tutorial 06

**Description:** Implement GitHub summary and active-incident interpretation and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover all-clear, active incident, scheduled maintenance, and invalid payload.
- [ ] `06-github.md` shows how the response fields become provider results.
- [ ] The guide and fixture tests agree on the status mapping.

**Verification:** Run GitHub provider tests and follow the guide to reproduce the expected outputs.

**Dependencies:** Task 10.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/GitHubProvider.swift` or JSON definition, GitHub fixture, focused test, `Documentation/providers/tutorials/06-github.md`.

**Estimated scope:** Medium.

### Checkpoint: Providers 04–06

- [ ] Cloudflare, Cloudways, and GitHub fixture tests pass.
- [ ] Maintenance, incident, and invalid-data behavior is explicit in each completed guide.
- [ ] Do not start HubSpot until the three guides and providers are reviewed.

### Task 12: HubSpot provider and tutorial 07

**Description:** Implement HubSpot status parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover active incident, operational status, and missing/unrecognized status.
- [ ] `07-hubspot.md` explains how the provider reads its status and incident fields.
- [ ] The guide is verified against the focused tests.

**Verification:** Run HubSpot provider tests and follow the guide's steps.

**Dependencies:** Task 11.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/HubSpotProvider.swift` or JSON definition, HubSpot fixture, focused test, `Documentation/providers/tutorials/07-hubspot.md`.

**Estimated scope:** Medium.

### Task 13: MongoDB provider and tutorial 08

**Description:** Implement MongoDB Atlas status and unresolved-incident interpretation and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover all-clear, unresolved incident, resolved incident, and malformed payload.
- [ ] `08-mongodb.md` explains the incident fields and resolution rule.
- [ ] Tests confirm that missing required fields are check failures.

**Verification:** Run MongoDB provider tests and follow the guide through its expected results.

**Dependencies:** Task 12.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/MongoDBProvider.swift` or JSON definition, MongoDB fixture, focused test, `Documentation/providers/tutorials/08-mongodb.md`.

**Estimated scope:** Medium.

### Task 14: Monday provider and tutorial 09

**Description:** Implement Monday status and incident parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover operational text, active incident, and absent/unrecognized status.
- [ ] `09-monday.md` explains the source selectors and result mapping.
- [ ] Tutorial examples match the focused provider tests.

**Verification:** Run Monday provider tests and follow the tutorial verification command.

**Dependencies:** Task 13.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/MondayProvider.swift` or JSON definition, Monday fixture, focused test, `Documentation/providers/tutorials/09-monday.md`.

**Estimated scope:** Medium.

### Checkpoint: Providers 07–09

- [ ] HubSpot, MongoDB, and Monday fixture tests pass.
- [ ] Each guide explains its source-specific fields and check-failure behavior.
- [ ] Do not start Ngrok until these three guides and providers are reviewed.

### Task 15: Ngrok provider and tutorial 10

**Description:** Implement Ngrok status parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover operational, non-operational, and missing status text.
- [ ] `10-ngrok.md` teaches the supported declarative or Swift provider path with exact status matching behavior.
- [ ] The documented output is confirmed by focused tests.

**Verification:** Run Ngrok provider tests and follow the guide's steps.

**Dependencies:** Task 14.

**Files likely touched:** Ngrok provider definition or implementation, Ngrok fixture, focused test, `Documentation/providers/tutorials/10-ngrok.md`.

**Estimated scope:** Medium.

### Task 16: OpenAI provider and tutorial 11

**Description:** Implement OpenAI status parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover operational, non-operational, and changed/missing response structure.
- [ ] `11-openai.md` explains the relevant response selector/fields and parsing limits.
- [ ] Tests verify both expected status and check-failure behavior.

**Verification:** Run OpenAI provider tests and follow the tutorial verification command.

**Dependencies:** Task 15.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/OpenAIProvider.swift` or JSON definition, OpenAI fixture, focused test, `Documentation/providers/tutorials/11-openai.md`.

**Estimated scope:** Medium.

### Task 17: Register.it provider and tutorial 12

**Description:** Implement Register.it status and maintenance/incident interpretation and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover operational, maintenance, outage, and invalid status data.
- [ ] `12-register.md` explains the service-specific maintenance and incident rules.
- [ ] Tests and guide agree on user-visible status.

**Verification:** Run Register.it provider tests and follow the tutorial.

**Dependencies:** Task 16.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/RegisterProvider.swift`, Register.it fixtures, focused test, `Documentation/providers/tutorials/12-register.md`.

**Estimated scope:** Medium.

### Checkpoint: Providers 10–12

- [ ] Ngrok, OpenAI, and Register.it fixture tests pass.
- [ ] The tutorials explain when their provider is declarative and when service-specific logic is required.
- [ ] Do not start PayPal until the three guides and providers are reviewed.

### Task 18: PayPal provider and tutorial 13

**Description:** Implement PayPal production-event parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover open production events, non-production events, and start/end time boundaries.
- [ ] `13-paypal.md` explains event filtering and time interpretation with concrete test examples.
- [ ] Tests use a deterministic clock for date-boundary cases.

**Verification:** Run PayPal provider tests and follow the guide's verification command.

**Dependencies:** Task 17.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/PayPalProvider.swift`, PayPal fixtures, focused test, `Documentation/providers/tutorials/13-paypal.md`.

**Estimated scope:** Medium.

### Task 19: Slack provider and tutorial 14

**Description:** Implement Slack status parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover the operational phrase, non-operational text, and missing status text.
- [ ] `14-slack.md` explains the source page and exact status interpretation.
- [ ] Tests confirm that missing text is a check failure rather than all-clear.

**Verification:** Run Slack provider tests and follow the tutorial's expected output.

**Dependencies:** Task 18.

**Files likely touched:** Slack provider definition or implementation, Slack fixture, focused test, `Documentation/providers/tutorials/14-slack.md`.

**Estimated scope:** Medium.

### Task 20: Stripe provider and tutorial 15

**Description:** Implement Stripe all-clear and unresolved-incident parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover all-clear, active incident, unusual all-clear wording, and malformed/missing content.
- [ ] `15-stripe.md` explains the source-specific all-clear and incident checks.
- [ ] Tests verify the mapping without relying on live page content.

**Verification:** Run Stripe provider tests and follow the tutorial verification command.

**Dependencies:** Task 19.

**Files likely touched:** `Sources/ServiceProviders/BuiltIn/StripeProvider.swift`, Stripe fixtures, focused test, `Documentation/providers/tutorials/15-stripe.md`.

**Estimated scope:** Medium.

### Task 21: Vercel provider and tutorial 16

**Description:** Implement Vercel status and incident parsing and its tutorial.

**Acceptance criteria:**
- [ ] Fixtures cover all-clear, active incident, and missing/unrecognized status.
- [ ] `16-vercel.md` explains the source fields and provider result mapping.
- [ ] The last tutorial follows the same concise, detailed structure as the earlier guides.

**Verification:** Run Vercel provider tests and follow the tutorial through the expected result.

**Dependencies:** Task 20.

**Files likely touched:** Vercel provider definition or implementation, Vercel fixture, focused test, `Documentation/providers/tutorials/16-vercel.md`.

**Estimated scope:** Medium.

### Checkpoint: All providers and tutorials

- [ ] All 16 providers have fixture tests.
- [ ] All 16 numbered tutorials are complete, accurate, and reviewed in sequence.
- [ ] The service catalog and provider registry contain the same 16 service ids.

## Phase 3: Monitoring Engine

### Task 22: Implement scheduling and check orchestration

**Description:** Run enabled providers immediately or on the schedule selected in Task 1, enforce the 15-minute minimum and five-minute increments, and reschedule when settings change.

**Acceptance criteria:**
- [ ] Only enabled providers run; zero selected providers runs zero checks.
- [ ] Interval validation accepts only values at or above 15 in increments of 5.
- [ ] Provider failures remain separate from valid service observations.

**Verification:** Run deterministic scheduler/orchestration tests using fake providers and a test clock.

**Dependencies:** Task 21.

**Files likely touched:** `Sources/MonitoringEngine/`, `Tests/MonitoringEngineTests/`.

**Estimated scope:** Medium.

### Task 23: Persist observations and incident transitions

**Description:** Persist selected services, interval, last observations, and the incident state needed to notify once on issue and once on recovery across relaunches.

**Acceptance criteria:**
- [ ] Persisted state restores without interpreting invalid or missing data as operational.
- [ ] A newly observed incident and its later recovery receive explicit timestamps.
- [ ] Relaunching with an ongoing incident does not emit a duplicate new-incident event.

**Verification:** Run storage and transition tests for first detection, repeated incident checks, recovery, and relaunch.

**Dependencies:** Task 22.

**Files likely touched:** `Sources/MonitoringEngine/Storage/`, `Sources/MonitoringEngine/Models/`, `Tests/MonitoringEngineTests/`.

**Estimated scope:** Medium.

### Task 24: Integrate all providers with the monitoring engine

**Description:** Connect the complete provider catalog to the scheduler and aggregate results for the app layer.

**Acceptance criteria:**
- [ ] Every catalog service is available through the same provider contract.
- [ ] Mixed outcomes include operational, incident, and check-failed states without conflating them.
- [ ] A run cannot overlap itself or leave stale results presented as current.

**Verification:** Run engine integration tests with representative providers and all 16 registry entries.

**Dependencies:** Task 23.

**Files likely touched:** `Sources/MonitoringEngine/`, provider registry, `Tests/MonitoringEngineTests/`.

**Estimated scope:** Medium.

### Checkpoint: Monitoring engine

- [ ] Scheduling, state persistence, incident/recovery transitions, and all-disabled behavior pass focused tests.
- [ ] Network or parser failures never create outage events.

## Phase 4: Native App Experience

### Task 25: Build the menu bar, popover, and detail dashboard

**Description:** Connect engine state to the SwiftUI menu bar item, quick popover, service list, aggregate status, last-check time, and status-page links.

**Acceptance criteria:**
- [ ] The menu bar remains available when the detail window closes.
- [ ] The popover gives a compact summary and route to the detail window.
- [ ] The detail window shows each service's operational, incident, or check-failed state and last check time.

**Verification:** Build and manually inspect the menu bar, popover, dashboard, and status-page link behavior.

**Dependencies:** Task 24.

**Files likely touched:** `Sources/StatusPageMonitorApp/Views/`, `Sources/StatusPageMonitorApp/State/`.

**Estimated scope:** Medium.

### Task 26: Add onboarding and persistent service/interval settings

**Description:** Present first-run service selection and controls for service toggles and the refresh interval.

**Acceptance criteria:**
- [ ] First launch asks the user which services to monitor.
- [ ] Each service can be independently enabled or disabled; disabling all is valid.
- [ ] The selected services and 15-minute-or-greater interval persist across relaunches.

**Verification:** Test onboarding and settings state; manually verify the all-disabled screen and interval controls.

**Dependencies:** Task 25.

**Files likely touched:** `Sources/StatusPageMonitorApp/Views/Onboarding/`, `Sources/StatusPageMonitorApp/Views/Settings/`, app state, focused tests.

**Estimated scope:** Medium.

### Task 27: Add login startup and native incident/recovery notifications

**Description:** Implement the login-startup preference and macOS notifications for newly observed incidents and their resolution.

**Acceptance criteria:**
- [ ] Login startup matches the decision recorded in Task 1 and can be changed from settings.
- [ ] Incident notifications include service, issue detail, and detection time; recovery notifications include resolution detection time.
- [ ] Check failures do not create outage/recovery notifications, and notification actions can open the relevant status page.

**Verification:** Manually test startup preference and notification permission on the supported macOS version; run notification event mapping tests.

**Dependencies:** Task 26.

**Files likely touched:** `Sources/StatusPageMonitorApp/Notifications/`, `Sources/StatusPageMonitorApp/Views/Settings/`, app state, focused tests.

**Estimated scope:** Medium.

### Checkpoint: Native app flow

- [ ] First-run setup, service settings, menu bar, dashboard, launch-at-login, and notifications work together.
- [ ] Incident and recovery notifications do not fire for check failures or duplicate persistent incidents.

## Phase 5: Public Developer and Release Documentation

### Task 28: Add the provider tutorial index and contribution guide

**Description:** Add the numbered index for all 16 guides, explain JSON versus Swift providers, document the pull-request path, and state how maintainers identify official releases.

**Acceptance criteria:**
- [ ] Index links to all 16 tutorials in catalog order and reports only verified completion.
- [ ] Contribution instructions include provider source, fixtures, tests, focused commands, and review expectations.
- [ ] Documentation distinguishes official artifacts from builds produced by forks.

**Verification:** Check every link and follow the contribution instructions using one completed provider tutorial.

**Dependencies:** Task 27.

**Files likely touched:** `Documentation/providers/tutorials/README.md`, `CONTRIBUTING.md`, `README.md`.

**Estimated scope:** Medium.

### Task 29: Complete the README and official release instructions

**Description:** Finalize English user/developer README content and describe the maintainer-owned process for preparing official release artifacts from the canonical repository.

**Acceptance criteria:**
- [ ] README lists verified macOS, Xcode, and Swift prerequisites and clean-checkout build/run/test steps.
- [ ] README links architecture, contribution, and tutorial documentation.
- [ ] Release instructions identify how official builds are distinguished and which source revision they contain.

**Verification:** Follow the README from a clean checkout and verify all listed commands and links.

**Dependencies:** Task 28.

**Files likely touched:** `README.md`, `Documentation/releasing.md`.

**Estimated scope:** Small.

### Task 30: Final end-to-end verification and documentation review

**Description:** Verify the complete app, all providers, tutorial sequence, and public developer workflow against the approved specs.

**Acceptance criteria:**
- [ ] All functional success criteria in the four module specs are met.
- [ ] All 16 provider tutorials match implementation, fixtures, and focused tests.
- [ ] Documentation contains no stale commands, missing guide links, or unsupported claims.

**Verification:** Run the full documented build/test commands and manually check onboarding, all-disabled state, incident/recovery notifications, and official release labeling.

**Dependencies:** Task 29.

**Files likely touched:** None during verification. Route any required correction back to its owning task rather than expanding this review task.

**Estimated scope:** Medium.

### Final Checkpoint: Ready for review

- [ ] Clean checkout builds and the documented tests pass.
- [ ] All 16 services and tutorials are present.
- [ ] The user can select services, set the interval, see check failures separately, and receive incident and recovery notifications.
- [ ] Official release and contributor instructions match the approved product direction.
