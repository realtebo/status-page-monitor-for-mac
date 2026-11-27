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

@MainActor
@Test func notificationPermissionReportsProgressAndAnUndecidedResult() async {
    let notifications = ServiceNotifications()
    var requests = 0
    await notifications.requestAuthorization {
        requests += 1
        #expect(notifications.permissionRequestState == .requesting)
        await notifications.requestAuthorization {
            requests += 1
            return .authorized
        }
        return .notDetermined
    }
    #expect(requests == 1)
    #expect(notifications.permissionRequestState == .undecided)
}

@MainActor
@Test func notificationPermissionShowsSystemErrorsAndAllowsRetry() async {
    let notifications = ServiceNotifications()
    let error = NSError(domain: "NotificationTest", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Permission request failed"])
    await notifications.requestAuthorization { throw error }
    #expect(notifications.permissionRequestState == .failed(error.localizedDescription))

    await notifications.requestAuthorization { .denied }
    #expect(notifications.authorizationStatus == .denied)
    #expect(notifications.permissionRequestState == .idle)
}

@MainActor
@Test func serviceAlertPreferenceSurvivesRelaunchAndRespectsSystemPermission() async {
    let (defaults, suiteName) = makeConfirmedHealthDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = ServiceNotifications(defaults: defaults)
    await first.requestAuthorization { .authorized }
    #expect(first.canPostServiceAlerts)
    first.serviceAlertsEnabled = false
    #expect(!first.canPostServiceAlerts)
    #expect(first.authorizationStatus == .authorized)

    let reopened = ServiceNotifications(defaults: defaults)
    await reopened.requestAuthorization { .provisional }
    #expect(!reopened.serviceAlertsEnabled)
    #expect(!reopened.canPostServiceAlerts)
    reopened.serviceAlertsEnabled = true
    #expect(reopened.canPostServiceAlerts)
    await reopened.requestAuthorization { .denied }
    #expect(!reopened.canPostServiceAlerts)
    #expect(ServiceNotifications(defaults: defaults).serviceAlertsEnabled)
}

@Suite struct ConfirmedServiceHealthTests {
    @Test @MainActor func notificationIdentifiesIncidentAndRecoveryTime() {
        let incident = ServiceIncident(id: "a", title: "Queue delivery delayed", status: .identified,
                                      impact: .minor, summary: nil, url: nil, startedAt: nil, updatedAt: nil)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let locale = Locale(identifier: "it")
        let outage = ServiceObservation(condition: .degradedPerformance, activeIncidents: [incident], observedAt: date)
        let healthy = ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)

        let alert = ServiceNotifications.makeContent(for: .incident, providerID: .cloudflare, providerName: "Cloudflare", observation: outage, locale: locale)
        let recovery = ServiceNotifications.makeContent(for: .recovery, providerID: .cloudflare, providerName: "Cloudflare", observation: healthy, locale: locale)
        #expect(alert.body.contains("Cloudflare"))
        #expect(alert.body.contains(incident.title))
        #expect(recovery.body.contains("Cloudflare"))
        #expect(recovery.body.contains(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale))))
        #expect(alert.title != recovery.title)
        let category = ServiceNotifications.incidentCategory(locale: locale)
        #expect(category.actions.map(\.title) == ["Apri pagina di stato"])
        #expect(ServiceNotifications.incidentCategory(locale: Locale(identifier: "en")).actions.map(\.title)
            == ["Open status page"])
        #expect(alert.categoryIdentifier == category.identifier)
        #expect(recovery.categoryIdentifier.isEmpty)
        let action = category.actions.first?.identifier ?? ""
        #expect(ServiceNotifications.statusPageURL(actionIdentifier: action, userInfo: alert.userInfo)
            == BuiltInServiceCatalog.definition(for: .cloudflare)?.statusPageURL)
        #expect(ServiceNotifications.statusPageURL(actionIdentifier: action, userInfo: recovery.userInfo) == nil)
        #expect(ServiceNotifications.statusPageURL(actionIdentifier: "other-action", userInfo: alert.userInfo) == nil)
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

    @Test func greenStartsAtFirstOKOrLastConfirmedKOAndYellowHidesTheDuration() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var health = ConfirmedServiceHealth(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000)
        let up = confirmedObservedResult(.operational, at: start)
        let sameUp = confirmedObservedResult(.operational, at: start.addingTimeInterval(900))
        let firstKO = start.addingTimeInterval(1_800)
        let down = confirmedObservedResult(.majorOutage, at: firstKO)
        let failed = confirmedUnreachableResult(at: firstKO.addingTimeInterval(300))
        _ = health.record(up, for: .aircall, source: .automatic)
        _ = health.record(failed, for: .github, source: .automatic)
        _ = health.record(sameUp, for: .aircall, source: .manual)
        #expect(health.period(for: .aircall, result: sameUp) == ServiceHealthPeriod(isOperational: true, startedAt: start))
        _ = health.record(down, for: .github, source: .manual)
        _ = health.record(down, for: .aircall, source: .automatic)
        _ = health.record(failed, for: .aircall, source: .automatic)
        #expect(health.period(for: .aircall, result: failed) == nil)
        health = ConfirmedServiceHealth(defaults: defaults)
        let lastKO = firstKO.addingTimeInterval(900)
        let laterKO = confirmedObservedResult(.partialOutage, at: lastKO)
        _ = health.record(laterKO, for: .aircall, source: .manual)
        let expectedKO = ServiceHealthPeriod(isOperational: false, startedAt: firstKO)
        #expect(health.period(for: .github, result: down) == expectedKO)
        #expect(health.period(for: .aircall, result: laterKO) == expectedKO)
        let unavailable = confirmedUnreachableResult(at: lastKO.addingTimeInterval(600))
        _ = health.record(unavailable, for: .aircall, source: .automatic)
        health = ConfirmedServiceHealth(defaults: defaults)
        let back = firstKO.addingTimeInterval(3_600)
        let restored = confirmedObservedResult(.operational, at: back)
        #expect(health.record(restored, for: .aircall, source: .automatic) == .recovery)
        let expectedUp = ServiceHealthPeriod(isOperational: true, startedAt: lastKO)
        #expect(health.period(for: .aircall, result: restored) == expectedUp)
        let stillUp = confirmedObservedResult(.operational, at: back.addingTimeInterval(900))
        _ = health.record(stillUp, for: .aircall, source: .manual)
        #expect(ConfirmedServiceHealth(defaults: defaults).period(for: .aircall, result: stillUp) == expectedUp)
    }

    @Test func observedFirstAndLastDatesSurviveRelaunchAndRecovery() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let start = Date(timeIntervalSince1970: 1_000)
        func date(_ minutes: Int) -> Date { start.addingTimeInterval(Double(minutes) * 60) }
        func record(_ state: ServiceCondition, at minute: Int) {
            var reloaded = ConfirmedServiceHealth(defaults: defaults)
            _ = reloaded.record(confirmedObservedResult(state, at: date(minute)), for: .github, source: .automatic)
        }
        func dates() -> [String: [String: Date]] {
            defaults.dictionary(forKey: "monitor.confirmedHealthPeriods") as? [String: [String: Date]] ?? [:]
        }
        record(.operational, at: 0)
        record(.operational, at: 180)
        record(.majorOutage, at: 200)
        record(.partialOutage, at: 220)
        #expect(dates()["firstOK"]?["github"] == date(0))
        #expect(dates()["lastOK"]?["github"] == date(180))
        record(.operational, at: 240)
        record(.operational, at: 360)
        let saved = dates()
        #expect(saved["firstOK"]?["github"] == date(240))
        #expect(saved["lastOK"]?["github"] == date(360))
        #expect(saved["down"]?["github"] == date(200))
        #expect(saved["lastKO"]?["github"] == date(220))
        var reloaded = ConfirmedServiceHealth(defaults: defaults)
        _ = reloaded.record(confirmedUnreachableResult(at: date(380)), for: .github, source: .manual)
        #expect(dates() == saved)
        record(.partialOutage, at: 400)
        #expect(dates()["down"]?["github"] == date(400))
    }

    @Test func legacyPeriodsUseOnlyObservationsOfTheCurrentConfirmedState() {
        let (defaults, suiteName) = makeConfirmedHealthDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = Date(timeIntervalSince1970: 1_000)
        let lastOK = first.addingTimeInterval(600)
        defaults.set(["github": false, "aircall": false, "stripe": true], forKey: "monitor.confirmedServiceHealth")
        defaults.set(["github": first, "aircall": first], forKey: "monitor.firstObservedIssueAt")
        defaults.set(["aircall": lastOK.timeIntervalSince1970, "stripe": lastOK.timeIntervalSince1970], forKey: "monitor.lastOperationalAt")
        var health = ConfirmedServiceHealth(defaults: defaults)
        let later = first.addingTimeInterval(900)
        let issue = confirmedObservedResult(.majorOutage, at: later)
        #expect(health.period(for: .github, result: issue) == ServiceHealthPeriod(isOperational: false, startedAt: first))
        #expect(health.period(for: .aircall, result: issue) == nil)
        #expect(health.record(issue, for: .aircall, source: .automatic) == nil)
        #expect(health.period(for: .aircall, result: issue) == ServiceHealthPeriod(isOperational: false, startedAt: later))
        #expect(health.period(for: .stripe, result: confirmedObservedResult(.operational)) == ServiceHealthPeriod(isOperational: true, startedAt: lastOK))
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
    let legacyRecords = [release("v0.02"), release("v0.0.3", signed: true), release("v0.01")]
    let legacyBody = try JSONSerialization.data(withJSONObject: legacyRecords)
    let migrated = try await GitHubReleaseCheck(transport: ReleaseTestTransport(body: legacyBody)).latestMacRelease()
    #expect(migrated.tagName == "v0.0.3")
    #expect(GitHubReleaseVersion(tagName: "v0.01") == GitHubReleaseVersion(major: 0, minor: 0, patch: 1))
    #expect(GitHubReleaseVersion(cfBundleShortVersionString: "0.02") == GitHubReleaseVersion(major: 0, minor: 0, patch: 2))
    #expect(GitHubReleaseVersion(tagName: "v0.2") == GitHubReleaseVersion(major: 0, minor: 2))
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

private func testMacRelease(_ tag: String) throws -> GitHubMacRelease {
    GitHubMacRelease(tagName: tag, numericVersion: try #require(GitHubReleaseVersion(tagName: tag)),
                     releaseURL: AppIdentity.repositoryURL, downloadURL: AppIdentity.repositoryURL, appcastURL: nil)
}

@MainActor
@Test func updatePreferencesCheckAtLaunchAndAfterOneHour() async throws {
    let suite = "UpdateSettingsTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = UpdateClockProbe()
    let release = try testMacRelease("v0.0.4")
    let model = UpdateSettingsModel(defaults: defaults, installedVersion: "0.0.3", waitForNextCheck: { duration in
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
        return release
    })
    reopened.startAtLaunch()
    #expect(!reopened.automaticChecks)
}

@MainActor
@Test func manualUpdateCheckWorksWithAutomaticChecksDisabled() async throws {
    let suite = "ManualUpdateTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let release = try testMacRelease("v0.0.3")
    let model = UpdateSettingsModel(defaults: defaults, installedVersion: release.version, releaseChecker: { release })
    #expect(model.installedVersion == "0.0.3")
    #expect(model.lastCheckedAt == nil)
    #expect(model.latestOnlineVersion == nil)
    model.automaticChecks = false

    await model.checkNow()

    #expect(model.didCompleteCheck)
    #expect(!model.isChecking)
    #expect(!model.automaticChecks)
    #expect(model.lastCheckError == nil)
    #expect(model.availableRelease == nil)
    #expect(model.latestOnlineVersion == "0.0.3")
    let checkedAt = try #require(model.lastCheckedAt)

    let reopened = UpdateSettingsModel(defaults: defaults, installedVersion: release.version, releaseChecker: {
        throw URLError(.notConnectedToInternet)
    })
    #expect(reopened.latestOnlineVersion == release.version)
    #expect(reopened.lastCheckedAt == checkedAt)
    await reopened.checkNow()
    #expect(reopened.lastCheckError != nil)
    #expect(reopened.latestOnlineVersion == release.version)
    let retryTime = try #require(reopened.lastCheckedAt)
    #expect(retryTime >= checkedAt)
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
