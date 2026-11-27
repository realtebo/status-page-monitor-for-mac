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
