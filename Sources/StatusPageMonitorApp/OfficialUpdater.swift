import Combine
import Foundation
import Sparkle

@MainActor
final class OfficialUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = OfficialUpdater()

    @Published private(set) var installationError: String?
    @Published private(set) var isPreparingUpdate = false
    @Published private(set) var isInstalling = false

    private var controller: SPUStandardUpdaterController?
    private var installationEnabled = false
    private var userRequestedInstallation = false
    private var feed: URL?

    private var canInstall: Bool { installationEnabled || userRequestedInstallation }

    var isAvailable: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else { return false }
        return Data(base64Encoded: key)?.count == 32
    }

    func configure(automaticChecks: Bool, automaticInstallation: Bool) {
        installationEnabled = automaticChecks && automaticInstallation && isAvailable
        if !canInstall {
            controller?.updater.automaticallyDownloadsUpdates = false
            installationError = nil
        }
    }

    /// The release checker supplies the official appcast attached to the chosen GitHub tag.
    func installIfEnabled(appcastURL: URL) {
        guard installationEnabled else { return }
        startInstallation(appcastURL: appcastURL, userRequested: false)
    }

    func installNow(appcastURL: URL) {
        startInstallation(appcastURL: appcastURL, userRequested: true)
    }

    private func startInstallation(appcastURL: URL, userRequested: Bool) {
        guard isAvailable, !isPreparingUpdate, !isInstalling,
              controller?.updater.sessionInProgress != true else { return }
        feed = appcastURL
        installationError = nil
        if controller == nil {
            let candidate = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
            do {
                try candidate.updater.start()
                controller = candidate
            } catch {
                installationError = error.localizedDescription
                return
            }
        }
        guard let updater = controller?.updater else { return }
        userRequestedInstallation = userRequested
        isPreparingUpdate = true
        updater.automaticallyDownloadsUpdates = true
        updater.checkForUpdatesInBackground()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        feed?.absoluteString
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard canInstall, let feed else { throw CancellationError() }
        let release = feed.deletingLastPathComponent()
        guard item.fileURL == release.appendingPathComponent("StatusPageMonitor-macOS-arm64.zip"),
              "v" + item.displayVersionString == release.lastPathComponent else {
            throw URLError(.badServerResponse)
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        guard canInstall else { return false }
        isPreparingUpdate = false
        isInstalling = true
        ServiceNotifications.shared.recordPendingInstallation(version: item.displayVersionString)
        immediateInstallHandler()
        return true
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        if canInstall {
            installationError = error.localizedDescription
        }
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        userRequestedInstallation = false
        isPreparingUpdate = false
        isInstalling = false
        if !installationEnabled {
            updater.automaticallyDownloadsUpdates = false
        }
    }
}
