import AppKit
import SwiftUI
@preconcurrency import UserNotifications

/// Presents service status transitions as macOS notifications and manages notification permission.
@MainActor
final class ServiceNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ServiceNotifications()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
    }

    /// Installs the foreground presentation delegate and reads the current system permission.
    func install() {
        center.delegate = self
        Task {
            await refreshAuthorizationStatus()
        }
    }

    /// Refreshes the permission state after returning from System Settings.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Requests permission after the user selects Enable notifications.
    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            NSLog("Could not request notification permission: %@", String(describing: error))
        }
        await refreshAuthorizationStatus()
    }

    /// Posts a verified service status transition when notification permission is available.
    func post(
        _ transition: HealthTransition,
        providerName: String,
        observation: ServiceObservation
    ) async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        let content = Self.makeContent(
            for: transition,
            providerName: providerName,
            observation: observation,
            locale: LocalizationManager.shared.locale
        )
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
        providerName: String,
        observation: ServiceObservation,
        locale: Locale
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch transition {
        case .incident:
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
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var notifications: ServiceNotifications

    init(notifications: ServiceNotifications = .shared) {
        self.notifications = notifications
    }

    var body: some View {
        Section {
            Text("Allow notifications to receive alerts about incidents and service recovery.")
                .foregroundStyle(.secondary)

            permissionContent
        } header: {
            Label("Service notifications", systemImage: "bell")
        }
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                await notifications.refreshAuthorizationStatus()
            }
        }
    }

    @ViewBuilder
    private var permissionContent: some View {
        switch notifications.authorizationStatus {
        case .notDetermined:
            Button("Enable notifications") {
                Task {
                    await notifications.requestAuthorization()
                }
            }
        case .denied:
            Label(
                "Notifications are turned off. To receive alerts, enable notifications for Status Page Monitor in System Settings.",
                systemImage: "bell.slash"
            )
            .foregroundStyle(.secondary)
        case .authorized, .provisional:
            Label("Notifications are enabled.", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        @unknown default:
            Label("Notification permission status is unavailable.", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}
