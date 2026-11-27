import Combine
import Foundation
import SwiftUI
@preconcurrency import UserNotifications

struct UpdateRelease: Equatable, Sendable {
    let version: String
    let releaseURL: URL
    let appcastURL: URL?
}

private enum UpdateSettingsError: LocalizedError, Sendable {
    case invalidInstalledVersion
    case unsupportedArchitecture

    var errorDescription: String? {
        switch self {
        case .invalidInstalledVersion:
            String(localized: "The installed app version is invalid.")
        case .unsupportedArchitecture:
            String(localized: "The published updates require Apple silicon.")
        }
    }
}

@MainActor
final class UpdateSettingsModel: ObservableObject {
    static let shared = UpdateSettingsModel()

    typealias ReleaseChecker = @Sendable () async throws -> UpdateRelease?

    @Published var automaticChecks: Bool {
        didSet {
            guard automaticChecks != oldValue else { return }
            defaults.set(automaticChecks, forKey: Self.automaticChecksKey)
            applyUpdaterConfiguration()
            restartSchedule()
        }
    }

    @Published var notifyWhenUpdatesAreAvailable: Bool {
        didSet {
            guard notifyWhenUpdatesAreAvailable != oldValue else { return }
            defaults.set(notifyWhenUpdatesAreAvailable, forKey: Self.notificationPreferenceKey)
            if automaticChecks && notifyWhenUpdatesAreAvailable {
                Task {
                    await ServiceNotifications.shared.requestAuthorization()
                }
            }
        }
    }

    @Published var automaticInstallation: Bool {
        didSet {
            guard automaticInstallation != oldValue else { return }
            defaults.set(automaticInstallation, forKey: Self.automaticInstallationKey)
            applyUpdaterConfiguration()
            if automaticInstallation {
                installKnownReleaseIfPossible()
            }
        }
    }

    @Published private(set) var availableRelease: UpdateRelease?
    var availableVersion: String? { availableRelease?.version }
    var availableReleaseURL: URL? { availableRelease?.releaseURL }

    private enum CheckSource: Equatable {
        case manual
        case scheduled(Int)
    }

    @Published private var activeCheck: CheckSource?
    var isChecking: Bool { activeCheck != nil }

    func checkNow() async {
        await performCheck(from: .manual)
    }

    @Published private(set) var lastCheckError: String?

    @Published private(set) var didCompleteCheck = false

    private static let automaticChecksKey = "updates.automaticChecks"
    private static let notificationPreferenceKey = "updates.notifyWhenAvailable"
    private static let automaticInstallationKey = "updates.automaticInstallation"
    private static let lastNotifiedVersionKey = "updates.lastNotifiedVersion"

    private let defaults: UserDefaults
    private let releaseChecker: ReleaseChecker
    private var scheduleTask: Task<Void, Never>?
    private var scheduleGeneration = 0
    private let waitForNextCheck: @Sendable (Duration) async throws -> Void
    private var didStartAtLaunch = false

    init(
        defaults: UserDefaults = .standard,
        waitForNextCheck: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        releaseChecker: @escaping ReleaseChecker = UpdateSettingsModel.checkGitHubReleases
    ) {
        self.defaults = defaults
        self.waitForNextCheck = waitForNextCheck
        self.releaseChecker = releaseChecker
        automaticChecks = defaults.object(forKey: Self.automaticChecksKey) as? Bool ?? true
        notifyWhenUpdatesAreAvailable = defaults.object(forKey: Self.notificationPreferenceKey) as? Bool ?? false

        let savedInstallation = defaults.object(forKey: Self.automaticInstallationKey) as? Bool ?? false
        automaticInstallation = savedInstallation && OfficialUpdater.shared.isAvailable
    }

    func startAtLaunch() {
        guard !didStartAtLaunch else { return }
        didStartAtLaunch = true
        applyUpdaterConfiguration()
        restartSchedule()
    }

    nonisolated private static func checkGitHubReleases() async throws -> UpdateRelease? {
        guard let currentValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let currentVersion = GitHubReleaseVersion(cfBundleShortVersionString: currentValue)
        else { throw UpdateSettingsError.invalidInstalledVersion }

        #if !arch(arm64)
        throw UpdateSettingsError.unsupportedArchitecture
        #else
        let release = try await GitHubReleaseCheck().latestMacRelease()
        guard release.numericVersion > currentVersion else { return nil }

        return UpdateRelease(
            version: release.version,
            releaseURL: release.releaseURL,
            appcastURL: release.appcastURL
        )
        #endif
    }

    private func restartSchedule() {
        scheduleTask?.cancel()
        scheduleTask = nil
        scheduleGeneration += 1
        if case .scheduled = activeCheck { activeCheck = nil }
        guard automaticChecks else { return }
        let generation = scheduleGeneration
        let wait = waitForNextCheck
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performCheck(from: .scheduled(generation))
                do {
                    try await wait(.seconds(3_600))
                } catch {
                    return
                }
            }
        }
    }

    private func performCheck(from source: CheckSource) async {
        guard activeCheck == nil else { return }
        if case .scheduled(let generation) = source {
            guard automaticChecks, generation == scheduleGeneration else { return }
        }
        activeCheck = source
        defer {
            if activeCheck == source { activeCheck = nil }
        }
        do {
            let release = try await releaseChecker()
            guard activeCheck == source else { return }
            didCompleteCheck = true
            lastCheckError = nil
            availableRelease = release
            if case .scheduled(let generation) = source, let release {
                installKnownReleaseIfPossible()
                await notifyIfNeeded(for: release, generation: generation)
            }
        } catch {
            guard activeCheck == source else { return }
            lastCheckError = error.localizedDescription
        }
    }

    private func applyUpdaterConfiguration() {
        let canInstall = automaticChecks && automaticInstallation && OfficialUpdater.shared.isAvailable
        OfficialUpdater.shared.configure(
            automaticChecks: automaticChecks,
            automaticInstallation: canInstall
        )
    }

    private func installKnownReleaseIfPossible() {
        guard automaticChecks,
              automaticInstallation,
              OfficialUpdater.shared.isAvailable,
              let appcastURL = availableRelease?.appcastURL
        else { return }

        OfficialUpdater.shared.installIfEnabled(appcastURL: appcastURL)
    }

    private func notifyIfNeeded(for release: UpdateRelease, generation: Int) async {
        guard notifyWhenUpdatesAreAvailable else { return }

        await ServiceNotifications.shared.refreshAuthorizationStatus()
        guard automaticChecks,
              notifyWhenUpdatesAreAvailable,
              generation == scheduleGeneration
        else { return }
        let permission = ServiceNotifications.shared.authorizationStatus
        guard permission == .authorized || permission == .provisional else { return }

        guard defaults.string(forKey: Self.lastNotifiedVersionKey) != release.version else { return }

        let locale = LocalizationManager.shared.locale
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Update available", locale: locale)
        let bodyFormat = String(localized: "Status Page Monitor version %@ is available.", locale: locale)
        content.body = String(format: bodyFormat, locale: locale, arguments: [release.version])
        content.sound = .default

        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(
                    identifier: "update.available",
                    content: content,
                    trigger: nil
                )
            )
            defaults.set(release.version, forKey: Self.lastNotifiedVersionKey)
        } catch {
            NSLog("Could not post an update notification: %@", String(describing: error))
        }
    }
}

@MainActor
struct UpdatesSettingsView: View {
    @ObservedObject private var model: UpdateSettingsModel
    @ObservedObject private var updater: OfficialUpdater

    init(
        model: UpdateSettingsModel = .shared,
        updater: OfficialUpdater = .shared
    ) {
        self.model = model
        self.updater = updater
    }

    var body: some View {
        Section {
            Toggle(isOn: $model.automaticChecks) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Check for updates automatically")
                    Text("Automatic checks run when the app starts and once per hour while enabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle("Notify me when updates are available", isOn: $model.notifyWhenUpdatesAreAvailable)
                .disabled(!model.automaticChecks)

            Toggle("Install updates automatically", isOn: automaticInstallationBinding)
                .disabled(!model.automaticChecks || !updater.isAvailable)

            Button("Check now") {
                Task { await model.checkNow() }
            }
            .disabled(model.isChecking)

            updateStatus
        } header: {
            Label("Updates", systemImage: "arrow.down.circle")
        }
    }

    private var automaticInstallationBinding: Binding<Bool> {
        Binding(
            get: { model.automaticInstallation && updater.isAvailable },
            set: { model.automaticInstallation = $0 }
        )
    }

    @ViewBuilder
    private var updateStatus: some View {
        if model.isChecking {
            Label("Checking for updates…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        } else if let version = model.availableVersion {
            VStack(alignment: .leading, spacing: 6) {
                Label("Version \(version) is available", systemImage: "arrow.down.circle.fill")
                if let releaseURL = model.availableReleaseURL {
                    Link("View release notes", destination: releaseURL)
                }
                if model.availableRelease?.appcastURL == nil {
                    Label(
                        "This release cannot be installed automatically.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if updater.readyOnQuit {
                    Label(
                        "Update ready. It will be installed when you quit the app.",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if let error = updater.installationError {
                    Text("Automatic installation failed: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if let error = model.lastCheckError {
                    Text("Could not check for updates: \(error)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let error = model.lastCheckError {
            Label("Could not check for updates: \(error)", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
        } else if model.didCompleteCheck {
            Label("No updates available.", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}
