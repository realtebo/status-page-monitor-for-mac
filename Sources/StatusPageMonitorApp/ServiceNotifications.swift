import AppKit
import SwiftUI
@preconcurrency import UserNotifications

/// Presents service status transitions as macOS notifications and manages notification permission.
@MainActor
final class ServiceNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ServiceNotifications()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    enum PermissionRequestState: Equatable {
        case idle, requesting, undecided
        case failed(String)
    }

    @Published private(set) var permissionRequestState: PermissionRequestState = .idle

    private static let serviceAlertsKey = "notifications.serviceAlertsEnabled"
    private static let pendingUpdateVersionKey = "updates.pendingInstallationVersion"
    private nonisolated static let incidentCategoryID = "service-incident"
    private nonisolated static let openStatusPageActionID = "open-service-status-page"
    private nonisolated static let providerIDKey = "service-provider-id"
    private nonisolated static let updateInstalledCategoryID = "update-installed"
    private nonisolated static let openReleaseNotesActionID = "open-release-notes"
    private nonisolated static let installedVersionKey = "installed-update-version"
    private let defaults: UserDefaults
    @Published var serviceAlertsEnabled: Bool {
        didSet { defaults.set(serviceAlertsEnabled, forKey: Self.serviceAlertsKey) }
    }

    var canPostServiceAlerts: Bool {
        serviceAlertsEnabled && (authorizationStatus == .authorized || authorizationStatus == .provisional)
    }

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        defaults.register(defaults: [Self.serviceAlertsKey: true])
        self.serviceAlertsEnabled = defaults.bool(forKey: Self.serviceAlertsKey)
        super.init()
    }

    /// Installs the foreground presentation delegate and reads the current system permission.
    func install() {
        center.delegate = self
        registerCategories(locale: LocalizationManager.shared.locale)
        let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let completedUpdate = takeCompletedInstallation(installedVersion: installedVersion)
        Task {
            await refreshAuthorizationStatus()
            if let completedUpdate {
                await postInstalledUpdate(version: completedUpdate)
            }
        }
    }

    func recordPendingInstallation(version: String) {
        defaults.set(version, forKey: Self.pendingUpdateVersionKey)
    }

    func takeCompletedInstallation(installedVersion: String?) -> String? {
        guard let pendingVersion = defaults.string(forKey: Self.pendingUpdateVersionKey) else { return nil }
        defaults.removeObject(forKey: Self.pendingUpdateVersionKey)
        return pendingVersion == installedVersion ? pendingVersion : nil
    }

    private func postInstalledUpdate(version: String) async {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        let locale = LocalizationManager.shared.locale
        let content = Self.makeInstalledUpdateContent(version: version, locale: locale)
        do {
            try await center.add(UNNotificationRequest(identifier: "update.installed.\(version)", content: content, trigger: nil))
        } catch {
            NSLog("Could not post an installation confirmation: %@", String(describing: error))
        }
    }

    /// Refreshes the permission state after returning from System Settings.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if authorizationStatus != .notDetermined && permissionRequestState != .requesting {
            permissionRequestState = .idle
        }
    }

    /// Requests permission after the user selects Enable notifications.
    func requestAuthorization() async {
        await requestAuthorization {
            _ = try await self.center.requestAuthorization(options: [.alert, .sound])
            return await self.center.notificationSettings().authorizationStatus
        }
    }

    func requestAuthorization(using request: () async throws -> UNAuthorizationStatus) async {
        guard permissionRequestState != .requesting else { return }
        permissionRequestState = .requesting
        do {
            authorizationStatus = try await request()
            permissionRequestState = authorizationStatus == .notDetermined ? .undecided : .idle
        } catch {
            permissionRequestState = .failed(error.localizedDescription)
        }
    }

    /// Posts a verified service status transition when notification permission is available.
    func post(
        _ transition: HealthTransition,
        providerID: ServiceID,
        providerName: String,
        observation: ServiceObservation
    ) async {
        guard serviceAlertsEnabled else { return }
        await refreshAuthorizationStatus()
        guard canPostServiceAlerts else { return }

        let locale = LocalizationManager.shared.locale
        let content = Self.makeContent(
            for: transition,
            providerID: providerID,
            providerName: providerName,
            observation: observation,
            locale: locale
        )
        if transition == .incident {
            registerCategories(locale: locale)
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            NSLog("Could not post a service status notification: %@", String(describing: error))
        }
    }

    /// Creates localized notification content, with an injectable locale for deterministic review.
    static func makeContent(
        for transition: HealthTransition,
        providerID: ServiceID,
        providerName: String,
        observation: ServiceObservation,
        locale: Locale
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch transition {
        case .incident:
            content.categoryIdentifier = incidentCategoryID
            content.userInfo = [providerIDKey: providerID.rawValue]
            content.title = String(localized: "Service issue detected", locale: locale)
            let incidentTitles = observation.activeIncidents
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")

            if incidentTitles.isEmpty {
                let format = String(localized: "%1$@ has an active issue.", locale: locale)
                content.body = String(format: format, locale: locale, arguments: [providerName])
            } else {
                let format = String(localized: "%1$@ has an active issue: %2$@", locale: locale)
                content.body = String(
                    format: format,
                    locale: locale,
                    arguments: [providerName, incidentTitles]
                )
            }

        case .recovery:
            content.title = String(localized: "Service recovered", locale: locale)
            let timestamp = observation.observedAt.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)
            )
            let format = String(localized: "%1$@ is operational again. Recovered at %2$@.", locale: locale)
            content.body = String(
                format: format,
                locale: locale,
                arguments: [providerName, timestamp]
            )
        }

        return content
    }

    static func incidentCategory(locale: Locale) -> UNNotificationCategory {
        let openStatusPage = UNNotificationAction(
            identifier: openStatusPageActionID,
            title: String(localized: LocalizedStringResource("Open status page", locale: locale))
        )
        return UNNotificationCategory(
            identifier: incidentCategoryID,
            actions: [openStatusPage],
            intentIdentifiers: []
        )
    }

    static func makeInstalledUpdateContent(version: String, locale: Locale) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: LocalizedStringResource("Update installed", locale: locale))
        content.body = String(localized: LocalizedStringResource("Status Page Monitor updated to version \(version).", locale: locale))
        content.categoryIdentifier = updateInstalledCategoryID
        content.userInfo = [installedVersionKey: version]
        content.sound = .default
        return content
    }

    static func updateInstalledCategory(locale: Locale) -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: updateInstalledCategoryID,
            actions: [UNNotificationAction(
                identifier: openReleaseNotesActionID,
                title: String(localized: LocalizedStringResource("View release notes", locale: locale))
            )],
            intentIdentifiers: []
        )
    }

    private func registerCategories(locale: Locale) {
        center.setNotificationCategories([
            Self.incidentCategory(locale: locale),
            Self.updateInstalledCategory(locale: locale)
        ])
    }

    nonisolated static func releaseNotesURL(actionIdentifier: String, userInfo: [AnyHashable: Any]) -> URL? {
        guard actionIdentifier == openReleaseNotesActionID || actionIdentifier == UNNotificationDefaultActionIdentifier,
              let version = userInfo[installedVersionKey] as? String,
              GitHubReleaseVersion(tagName: "v\(version)") != nil else { return nil }
        return AppIdentity.repositoryURL.appendingPathComponent("releases/tag/v\(version)")
    }

    nonisolated static func statusPageURL(actionIdentifier: String, userInfo: [AnyHashable: Any]) -> URL? {
        guard actionIdentifier == openStatusPageActionID,
              let rawID = userInfo[providerIDKey] as? String,
              let providerID = ServiceID(rawValue: rawID) else { return nil }
        return BuiltInServiceCatalog.definition(for: providerID)?.statusPageURL
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        guard let url = Self.statusPageURL(actionIdentifier: action, userInfo: userInfo)
            ?? Self.releaseNotesURL(actionIdentifier: action, userInfo: userInfo) else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

/// Shows and refreshes notification authorization in the Schedule settings.
struct NotificationPermissionSection: View {
    @ObservedObject private var notifications: ServiceNotifications

    init(notifications: ServiceNotifications = .shared) {
        self.notifications = notifications
    }

    var body: some View {
        Section {
            Toggle("Notify me about incidents and recoveries", isOn: $notifications.serviceAlertsEnabled)
                .toggleStyle(.switch)

            if notifications.serviceAlertsEnabled {
                permissionContent
            }
        } header: {
            Label("Service notifications", systemImage: "bell")
        }
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await notifications.refreshAuthorizationStatus()
            }
        }
    }

    @ViewBuilder
    private var permissionContent: some View {
        switch notifications.permissionRequestState {
        case .requesting:
            HStack {
                ProgressView().controlSize(.small)
                Text("Waiting for macOS notification permission…")
            }
        case .failed(let reason):
            Label("macOS could not enable notifications.", systemImage: "exclamationmark.triangle")
            Text(verbatim: reason).foregroundStyle(.secondary)
            permissionActions
        case .undecided:
            Text("macOS has not confirmed notification permission.")
            permissionActions
        case .idle:
            switch notifications.authorizationStatus {
            case .notDetermined:
                requestButton
            case .denied:
                Label(
                    "Notifications are turned off. To receive alerts, enable notifications for Status Page Monitor in System Settings.",
                    systemImage: "bell.slash"
                )
                .foregroundStyle(.secondary)
                settingsLink
            case .authorized, .provisional:
                EmptyView()
            @unknown default:
                Label("Notification permission status is unavailable.", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
                settingsLink
            }
        }
    }

    private var requestButton: some View {
        Button("Enable notifications") {
            Task { await notifications.requestAuthorization() }
        }
    }

    private var settingsLink: some View {
        Link("Open notification settings",
             destination: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }

    private var permissionActions: some View {
        HStack {
            requestButton
            settingsLink
        }
    }
}
