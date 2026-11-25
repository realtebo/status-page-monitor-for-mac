import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

/// Owns the official Sparkle updater used by the maintainer-distributed app.
///
/// The updater stays unavailable until the app bundle contains a real HTTPS
/// `SUFeedURL` and the public half of its EdDSA signing key. This keeps local
/// builds from starting a misconfigured updater.
@MainActor
final class OfficialUpdater {
    static let shared = OfficialUpdater()

    #if canImport(Sparkle)
    private let controller: SPUStandardUpdaterController?
    #endif

    private init() {
        #if canImport(Sparkle)
        guard Self.hasReleaseConfiguration else {
            controller = nil
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }

    /// Indicates whether Sparkle and valid release-feed metadata are present.
    var isAvailable: Bool {
        #if canImport(Sparkle)
        controller != nil
        #else
        false
        #endif
    }

    /// Indicates whether Sparkle can start a user-requested update check now.
    var canCheckForUpdates: Bool {
        #if canImport(Sparkle)
        controller?.updater.canCheckForUpdates ?? false
        #else
        false
        #endif
    }

    /// Starts a user-requested check when the official updater is configured.
    func checkForUpdates() {
        #if canImport(Sparkle)
        controller?.checkForUpdates(nil)
        #endif
    }

    #if canImport(Sparkle)
    private static var hasReleaseConfiguration: Bool {
        guard
            let feedString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let feed = URLComponents(string: feedString),
            feed.scheme?.lowercased() == "https",
            let host = feed.host,
            !host.isEmpty,
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return true
    }
    #endif
}
