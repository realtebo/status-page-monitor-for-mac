import AppKit
import Foundation
import Testing
@testable import StatusPageMonitor

@Test func issueDraftPreservesCategoryAndTextInGitHubForm() throws {
    for category in IssueReportCategory.allCases {
        let draft = IssueReportDraft(category: category, title: "C++ & macOS", description: "È al 50%\n#1 + #2")
        let url = try IssueReportURLBuilder.makeURL(for: draft, repositoryURL: AppIdentity.repositoryURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "github.com")
        #expect(components.path == "/realtebo/status-page-monitor-for-mac/issues/new")
        #expect(components.percentEncodedQuery?.contains("+") == false)
        #expect(components.queryItems == [
            URLQueryItem(name: "title", value: "\(category.rawValue) C++ & macOS"),
            URLQueryItem(name: "body", value: draft.description)
        ])
    }
}

@Test func issueDraftRejectsBlankInputAndOversizedLinks() {
    var draft = IssueReportDraft(category: .bug, title: " ", description: "Description")
    #expect(throws: IssueReportValidationError.emptyTitle) {
        try IssueReportURLBuilder.makeURL(for: draft, repositoryURL: AppIdentity.repositoryURL)
    }
    draft.title = "Title"
    draft.description = "\n "
    #expect(throws: IssueReportValidationError.emptyDescription) {
        try IssueReportURLBuilder.makeURL(for: draft, repositoryURL: AppIdentity.repositoryURL)
    }
    draft.description = String(repeating: "é", count: IssueReportURLBuilder.maximumURLLength)
    #expect(throws: IssueReportValidationError.issueURLTooLong) {
        try IssueReportURLBuilder.makeURL(for: draft, repositoryURL: AppIdentity.repositoryURL)
    }
}

@Test func appUsesTheStatusPageMonitorProductName() {
    #expect(AppIdentity.displayName == "Status Page Monitor")
}

@Suite struct ConfirmedServiceHealthTests {
    @Test @MainActor func notificationIdentifiesIncidentAndRecoveryTime() {
        let incident = ServiceIncident(id: "a", title: "Queue delivery delayed", status: .identified,
                                      impact: .minor, summary: nil, url: nil, startedAt: nil, updatedAt: nil)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let locale = Locale(identifier: "it")
        let outage = ServiceObservation(condition: .degradedPerformance, activeIncidents: [incident], observedAt: date)
        let healthy = ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)

        let alert = ServiceNotifications.makeContent(for: .incident, providerName: "Cloudflare", observation: outage, locale: locale)
        let recovery = ServiceNotifications.makeContent(for: .recovery, providerName: "Cloudflare", observation: healthy, locale: locale)
        #expect(alert.body.contains("Cloudflare"))
        #expect(alert.body.contains(incident.title))
        #expect(recovery.body.contains("Cloudflare"))
        #expect(recovery.body.contains(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale))))
        #expect(alert.title != recovery.title)
    }

    @Test func confirmedHealthUsesTheFirstResultAsItsBaseline() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var health = ConfirmedServiceHealth(defaults: defaults)

        #expect(health.isOperational(.aircall) == nil)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .aircall, source: .automatic) == nil)
        #expect(health.isOperational(.aircall) == false)
        #expect(health.record(confirmedObservedResult(.operational), for: .github, source: .automatic) == nil)
        #expect(health.isOperational(.github) == true)
    }

    @Test func confirmedHealthTransitionsOnlyAcrossObservedHealthChanges() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var health = ConfirmedServiceHealth(defaults: defaults)

        #expect(health.record(confirmedObservedResult(.operational), for: .aircall, source: .automatic) == nil)
        #expect(health.record(confirmedUnreachableResult(), for: .aircall, source: .automatic) == nil)
        #expect(health.isOperational(.aircall) == true)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .aircall, source: .automatic) == .incident)
        #expect(health.isOperational(.aircall) == false)
        #expect(health.record(confirmedUnreachableResult(), for: .aircall, source: .automatic) == nil)
        #expect(health.isOperational(.aircall) == false)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .aircall, source: .automatic) == nil)
        #expect(health.record(confirmedObservedResult(.operational), for: .aircall, source: .automatic) == .recovery)
        #expect(health.isOperational(.aircall) == true)
    }

    @Test func confirmedHealthDoesNotReportTransitionsForUnchangedObservations() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var health = ConfirmedServiceHealth(defaults: defaults)

        #expect(health.record(confirmedObservedResult(.operational), for: .aircall, source: .automatic) == nil)
        #expect(health.record(confirmedObservedResult(.operational), for: .aircall, source: .automatic) == nil)
        #expect(health.record(confirmedObservedResult(.partialOutage), for: .aircall, source: .automatic) == .incident)
        #expect(health.record(confirmedObservedResult(.partialOutage), for: .aircall, source: .automatic) == nil)
    }

    @Test func manualChecksUpdateConfirmedHealthWithoutReportingTransitions() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var health = ConfirmedServiceHealth(defaults: defaults)

        #expect(health.record(confirmedObservedResult(.operational), for: .aircall, source: .automatic) == nil)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .aircall, source: .manual) == nil)
        #expect(health.isOperational(.aircall) == false)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .aircall, source: .automatic) == nil)
        #expect(health.record(confirmedObservedResult(.operational), for: .aircall, source: .automatic) == .recovery)
    }

    @Test func confirmedHealthSurvivesReloadFromUserDefaults() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var health = ConfirmedServiceHealth(defaults: defaults)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .aircall, source: .automatic) == nil)

        let reloadedHealth = ConfirmedServiceHealth(defaults: defaults)

        #expect(reloadedHealth.isOperational(.aircall) == false)
    }

    @Test func confirmedHealthPersistsProviderBaselinesIndependently() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var health = ConfirmedServiceHealth(defaults: defaults)

        #expect(health.record(confirmedObservedResult(.operational), for: .aircall, source: .automatic) == nil)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .github, source: .automatic) == nil)
        #expect(health.isOperational(.aircall) == true)
        #expect(health.isOperational(.github) == false)
        #expect(health.record(confirmedObservedResult(.majorOutage), for: .aircall, source: .automatic) == .incident)
        #expect(health.isOperational(.github) == false)
    }
}

private func makeConfirmedHealthDefaults() -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "ConfirmedServiceHealthTests.\(UUID().uuidString)"
    return (UserDefaults(suiteName: suiteName)!, suiteName)
}

private func confirmedObservedResult(
    _ condition: ServiceCondition,
    at date: Date = Date(timeIntervalSince1970: 1_000)
) -> ProviderCheckResult {
    .observed(ServiceObservation(condition: condition, activeIncidents: [], observedAt: date))
}

private func confirmedUnreachableResult(
    at date: Date = Date(timeIntervalSince1970: 1_000)
) -> ProviderCheckResult {
    .failed(CheckFailure(reason: .network(message: "Fixture failure"), attemptedAt: date))
}

@Suite @MainActor struct SettingsWindowLifecycleTests {
    @Test func settingsOpenOnlyOnRequestAndCloseBackToTheMenuBar() throws {
        let lifecycle = AppLifecycleDelegate()
        lifecycle.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        #expect(lifecycle.settingsWindow == nil)

        lifecycle.openSettings()
        let window = try #require(lifecycle.settingsWindow)
        #expect(window.isVisible)
        #expect(!window.isRestorable)
        lifecycle.openSettings()
        #expect(lifecycle.settingsWindow === window)
        window.close()
        #expect(lifecycle.settingsWindow == nil)
        #expect(NSApp.activationPolicy() == .accessory)
    }
}

@Test func releaseCheckFindsNewestPublicMacVersionIncludingPreviews() async throws {
    let base = "https://github.com/realtebo/status-page-monitor-for-mac/releases/download"
    func release(_ tag: String, draft: Bool = false, signed: Bool = false) -> [String: Any] {
        let assets = (signed ? [GitHubReleaseCheck.archiveAssetName, "appcast.xml"] : [GitHubReleaseCheck.archiveAssetName])
            .map { ["name": $0, "browser_download_url": "\(base)/\(tag)/\($0)"] }
        return ["tag_name": tag, "draft": draft, "prerelease": true, "assets": assets]
    }
    let records = [release("v0.02"), release("v2.0", draft: true), release("v0.10.1", signed: true), release("nightly")]
    let body = try JSONSerialization.data(withJSONObject: records)
    let found = try await GitHubReleaseCheck(transport: ReleaseTestTransport(body: body)).latestMacRelease()
    #expect(found.tagName == "v0.10.1")
    #expect(found.appcastURL?.absoluteString == "\(base)/v0.10.1/appcast.xml")
    #expect(GitHubReleaseVersion(tagName: "v0.02") == GitHubReleaseVersion(cfBundleShortVersionString: "0.2.0"))
    #expect(GitHubReleaseVersion(tagName: "v1.0-beta") == nil)
}

private struct ReleaseTestTransport: HTTPTransport {
    let body: Data

    func get(_ url: URL) async throws -> HTTPResponse {
        #expect(url.host == "api.github.com")
        #expect(url.path == "/repos/realtebo/status-page-monitor-for-mac/releases")
        return HTTPResponse(statusCode: 200, finalURL: url, mimeType: "application/json", body: body)
    }
}

@MainActor
@Test func updatePreferencesCheckAtLaunchAndAfterOneHour() async throws {
    let suite = "UpdateSettingsTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = UpdateClockProbe()
    let release = UpdateRelease(version: "0.03", releaseURL: AppIdentity.repositoryURL, appcastURL: nil)
    let model = UpdateSettingsModel(defaults: defaults, waitForNextCheck: { duration in
        try await probe.wait(duration)
    }, releaseChecker: {
        await probe.checked()
        return release
    })
    #expect(model.automaticChecks)
    #expect(!model.notifyWhenUpdatesAreAvailable)
    #expect(!model.automaticInstallation)
    model.startAtLaunch()
    model.startAtLaunch()
    for _ in 0..<100 where await probe.checks < 2 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(await probe.checks == 2)
    #expect(await probe.intervals == [.seconds(3600), .seconds(3600)])
    #expect(model.availableRelease == release)
    model.automaticChecks = false
    let reopened = UpdateSettingsModel(defaults: defaults, releaseChecker: {
        Issue.record("The disabled release check ran at launch")
        return nil
    })
    reopened.startAtLaunch()
    #expect(!reopened.automaticChecks)
}

private actor UpdateClockProbe {
    private(set) var checks = 0
    private(set) var intervals: [Duration] = []

    func checked() { checks += 1 }

    func wait(_ interval: Duration) throws {
        intervals.append(interval)
        if intervals.count == 2 { throw CancellationError() }
    }
}
