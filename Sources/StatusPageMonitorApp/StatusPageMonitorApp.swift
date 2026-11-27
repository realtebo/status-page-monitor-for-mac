import AppKit
import Combine
import SwiftUI

enum AppIdentity {
    static let displayName = "Status Page Monitor"
    static let symbolName = "waveform.path.ecg"
    static let dashboardWindowID = "dashboard"
    static let contactEmail = "mirkotebaldi@yahoo.it"
    static let repositoryURL = URL(string: "https://github.com/realtebo/status-page-monitor-for-mac")!
}

@main
struct StatusPageMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appLifecycle
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings", action: appLifecycle.openSettings)
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusMenu: StatusMenuController?
    private(set) var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenuController { [weak self] in self?.openSettings() }
        ServiceNotifications.shared.install()
        MonitoringModel.shared.startChecksAtLaunch()
        UpdateSettingsModel.shared.startAtLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusMenu?.remove()
    }

    func openSettings() {
        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.isRestorable = false
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: SettingsWindowContent())
            window.title = LocalizationManager.shared.localized("Settings")
            window.center()
            window.setFrameAutosaveName(AppIdentity.dashboardWindowID)
            settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct SettingsWindowContent: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        DashboardView()
            .environmentObject(MonitoringModel.shared)
            .environment(\.locale, localization.locale)
    }
}

@MainActor
private final class MonitoringModel: ObservableObject {
    static let shared = MonitoringModel()

    @Published var isAircallEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAircallEnabled, forKey: Self.enabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isAircallEnabled)
        }
    }

    @Published var isBigCommerceEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBigCommerceEnabled, forKey: Self.bigCommerceEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isBigCommerceEnabled)
        }
    }

    @Published var isCanvaEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCanvaEnabled, forKey: Self.canvaEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isCanvaEnabled)
        }
    }

    @Published var isCloudflareEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCloudflareEnabled, forKey: Self.cloudflareEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isCloudflareEnabled)
        }
    }

    @Published var isCloudwaysEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCloudwaysEnabled, forKey: Self.cloudwaysEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isCloudwaysEnabled)
        }
    }

    @Published var isGitHubEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isGitHubEnabled, forKey: Self.githubEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isGitHubEnabled)
        }
    }

    @Published var isHubSpotEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHubSpotEnabled, forKey: Self.hubSpotEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isHubSpotEnabled)
        }
    }

    @Published var isMongoDBEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMongoDBEnabled, forKey: Self.mongoDBEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isMongoDBEnabled)
        }
    }

    @Published var isMondayEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMondayEnabled, forKey: Self.mondayEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isMondayEnabled)
        }
    }

    @Published var isNgrokEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isNgrokEnabled, forKey: Self.ngrokEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isNgrokEnabled)
        }
    }

    @Published var isOpenAIEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isOpenAIEnabled, forKey: Self.openAIEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isOpenAIEnabled)
        }
    }

    @Published var isRegisterEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isRegisterEnabled, forKey: Self.registerEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isRegisterEnabled)
        }
    }

    @Published var isPayPalEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPayPalEnabled, forKey: Self.payPalEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isPayPalEnabled)
        }
    }

    @Published var isSlackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSlackEnabled, forKey: Self.slackEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isSlackEnabled)
        }
    }

    @Published var isStripeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isStripeEnabled, forKey: Self.stripeEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isStripeEnabled)
        }
    }

    @Published var isVercelEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isVercelEnabled, forKey: Self.vercelEnabledDefaultsKey)
            restartProviderSchedule(checkImmediately: isVercelEnabled)
        }
    }

    @Published var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Self.intervalDefaultsKey)
            restartProviderSchedule(checkImmediately: false)
        }
    }

    @Published private(set) var aircallResult: ProviderCheckResult?
    @Published private(set) var bigCommerceResult: ProviderCheckResult?
    @Published private(set) var canvaResult: ProviderCheckResult?
    @Published private(set) var cloudflareResult: ProviderCheckResult?
    @Published private(set) var cloudwaysResult: ProviderCheckResult?
    @Published private(set) var githubResult: ProviderCheckResult?
    @Published private(set) var hubSpotResult: ProviderCheckResult?
    @Published private(set) var mongoDBResult: ProviderCheckResult?
    @Published private(set) var mondayResult: ProviderCheckResult?
    @Published private(set) var ngrokResult: ProviderCheckResult?
    @Published private(set) var openAIResult: ProviderCheckResult?
    @Published private(set) var registerResult: ProviderCheckResult?
    @Published private(set) var payPalResult: ProviderCheckResult?
    @Published private(set) var slackResult: ProviderCheckResult?
    @Published private(set) var stripeResult: ProviderCheckResult?
    @Published private(set) var vercelResult: ProviderCheckResult?
    @Published private(set) var isCheckingAircall = false
    @Published private(set) var isCheckingBigCommerce = false
    @Published private(set) var isCheckingCanva = false
    @Published private(set) var isCheckingCloudflare = false
    @Published private(set) var isCheckingCloudways = false
    @Published private(set) var isCheckingGitHub = false
    @Published private(set) var isCheckingHubSpot = false
    @Published private(set) var isCheckingMongoDB = false
    @Published private(set) var isCheckingMonday = false
    @Published private(set) var isCheckingNgrok = false
    @Published private(set) var isCheckingOpenAI = false
    @Published private(set) var isCheckingRegister = false
    @Published private(set) var isCheckingPayPal = false
    @Published private(set) var isCheckingSlack = false
    @Published private(set) var isCheckingStripe = false
    @Published private(set) var isCheckingVercel = false

    private static let enabledDefaultsKey = "monitor.aircall.enabled"
    private static let bigCommerceEnabledDefaultsKey = "monitor.bigcommerce.enabled"
    private static let canvaEnabledDefaultsKey = "monitor.canva.enabled"
    private static let cloudflareEnabledDefaultsKey = "monitor.cloudflare.enabled"
    private static let cloudwaysEnabledDefaultsKey = "monitor.cloudways.enabled"
    private static let githubEnabledDefaultsKey = "monitor.github.enabled"
    private static let hubSpotEnabledDefaultsKey = "monitor.hubspot.enabled"
    private static let mongoDBEnabledDefaultsKey = "monitor.mongodb.enabled"
    private static let mondayEnabledDefaultsKey = "monitor.monday.enabled"
    private static let ngrokEnabledDefaultsKey = "monitor.ngrok.enabled"
    private static let openAIEnabledDefaultsKey = "monitor.openai.enabled"
    private static let registerEnabledDefaultsKey = "monitor.register.enabled"
    private static let payPalEnabledDefaultsKey = "monitor.paypal.enabled"
    private static let slackEnabledDefaultsKey = "monitor.slack.enabled"
    private static let stripeEnabledDefaultsKey = "monitor.stripe.enabled"
    private static let vercelEnabledDefaultsKey = "monitor.vercel.enabled"
    private static let intervalDefaultsKey = "monitor.intervalMinutes"

    private var didStartAtLaunch = false
    private var scheduleTask: Task<Void, Never>?
    private var confirmedHealth = ConfirmedServiceHealth(defaults: .standard)
    @Published private(set) var isRefreshingAll = false
    private var activeChecks: [ServiceID: Task<ProviderCheckResult?, Never>] = [:]
    private var pendingRefreshAlerts: [NSPanel] = []
    private var isPresentingRefreshAlert = false

    private init() {
        let defaults = UserDefaults.standard
        isAircallEnabled = defaults.object(forKey: Self.enabledDefaultsKey) as? Bool ?? false
        isBigCommerceEnabled = defaults.object(forKey: Self.bigCommerceEnabledDefaultsKey) as? Bool ?? false
        isCanvaEnabled = defaults.object(forKey: Self.canvaEnabledDefaultsKey) as? Bool ?? false
        isCloudflareEnabled = defaults.object(forKey: Self.cloudflareEnabledDefaultsKey) as? Bool ?? false
        isCloudwaysEnabled = defaults.object(forKey: Self.cloudwaysEnabledDefaultsKey) as? Bool ?? false
        isGitHubEnabled = defaults.object(forKey: Self.githubEnabledDefaultsKey) as? Bool ?? false
        isHubSpotEnabled = defaults.object(forKey: Self.hubSpotEnabledDefaultsKey) as? Bool ?? false
        isMongoDBEnabled = defaults.object(forKey: Self.mongoDBEnabledDefaultsKey) as? Bool ?? false
        isMondayEnabled = defaults.object(forKey: Self.mondayEnabledDefaultsKey) as? Bool ?? false
        isNgrokEnabled = defaults.object(forKey: Self.ngrokEnabledDefaultsKey) as? Bool ?? false
        isOpenAIEnabled = defaults.object(forKey: Self.openAIEnabledDefaultsKey) as? Bool ?? false
        isRegisterEnabled = defaults.object(forKey: Self.registerEnabledDefaultsKey) as? Bool ?? false
        isPayPalEnabled = defaults.object(forKey: Self.payPalEnabledDefaultsKey) as? Bool ?? false
        isSlackEnabled = defaults.object(forKey: Self.slackEnabledDefaultsKey) as? Bool ?? false
        isStripeEnabled = defaults.object(forKey: Self.stripeEnabledDefaultsKey) as? Bool ?? false
        isVercelEnabled = defaults.object(forKey: Self.vercelEnabledDefaultsKey) as? Bool ?? false
        let savedInterval = defaults.object(forKey: Self.intervalDefaultsKey) as? Int ?? 15
        intervalMinutes = savedInterval >= 15 && savedInterval.isMultiple(of: 5) ? savedInterval : 15
    }

    func startChecksAtLaunch() {
        guard !didStartAtLaunch else { return }
        didStartAtLaunch = true
        if hasEnabledProviders {
            restartProviderSchedule(checkImmediately: true)
        }
    }

    @discardableResult
    private func checkAircallNow() async -> ProviderCheckResult? {
        guard isAircallEnabled, !isCheckingAircall else { return nil }
        isCheckingAircall = true
        defer { isCheckingAircall = false }

        let attemptedAt = Date()
        do {
            guard let manifestURL = Bundle.main.url(forResource: "aircall", withExtension: "json") else {
                throw AircallSetupError.missingManifest
            }
            let manifestData = try Data(contentsOf: manifestURL)
            let provider = try JSONManifestStatusProvider(
                manifestData: manifestData,
                transport: URLSessionHTTPTransport()
            )
            let result = await provider.check(at: attemptedAt)
            aircallResult = result
            return result
        } catch {
            let result = ProviderCheckResult.failed(
                CheckFailure(
                    reason: .invalidDefinition(message: error.localizedDescription),
                    attemptedAt: attemptedAt
                )
            )
            aircallResult = result
            return result
        }
    }

    @discardableResult
    private func checkBigCommerceNow() async -> ProviderCheckResult? {
        guard isBigCommerceEnabled, !isCheckingBigCommerce else { return nil }
        isCheckingBigCommerce = true
        defer { isCheckingBigCommerce = false }

        let attemptedAt = Date()
        let result = await BigCommerceStatusProvider().check(at: attemptedAt)
        bigCommerceResult = result
        return result
    }

    @discardableResult
    private func checkCanvaNow() async -> ProviderCheckResult? {
        guard isCanvaEnabled, !isCheckingCanva else { return nil }
        isCheckingCanva = true
        defer { isCheckingCanva = false }
        let result = await CanvaStatusProvider().check(at: Date())
        canvaResult = result
        return result
    }

    @discardableResult
    private func checkCloudflareNow() async -> ProviderCheckResult? {
        guard isCloudflareEnabled, !isCheckingCloudflare else { return nil }
        isCheckingCloudflare = true
        defer { isCheckingCloudflare = false }
        let result = await CloudflareStatusProvider().check(at: Date())
        cloudflareResult = result
        return result
    }

    @discardableResult
    private func checkCloudwaysNow() async -> ProviderCheckResult? {
        guard isCloudwaysEnabled, !isCheckingCloudways else { return nil }
        isCheckingCloudways = true
        defer { isCheckingCloudways = false }
        let result = await CloudwaysStatusProvider().check(at: Date())
        cloudwaysResult = result
        return result
    }

    @discardableResult
    private func checkGitHubNow() async -> ProviderCheckResult? {
        guard isGitHubEnabled, !isCheckingGitHub else { return nil }
        isCheckingGitHub = true
        defer { isCheckingGitHub = false }
        let result = await GitHubStatusProvider().check(at: Date())
        githubResult = result
        return result
    }

    @discardableResult
    private func checkHubSpotNow() async -> ProviderCheckResult? {
        guard isHubSpotEnabled, !isCheckingHubSpot else { return nil }
        isCheckingHubSpot = true
        defer { isCheckingHubSpot = false }
        let result = await HubSpotStatusProvider().check(at: Date())
        hubSpotResult = result
        return result
    }

    @discardableResult
    private func checkMongoDBNow() async -> ProviderCheckResult? {
        guard isMongoDBEnabled, !isCheckingMongoDB else { return nil }
        isCheckingMongoDB = true
        defer { isCheckingMongoDB = false }
        let result = await MongoDBStatusProvider().check(at: Date())
        mongoDBResult = result
        return result
    }

    @discardableResult
    private func checkMondayNow() async -> ProviderCheckResult? {
        guard isMondayEnabled, !isCheckingMonday else { return nil }
        isCheckingMonday = true
        defer { isCheckingMonday = false }
        let result = await MondayStatusProvider().check(at: Date())
        mondayResult = result
        return result
    }

    @discardableResult
    private func checkNgrokNow() async -> ProviderCheckResult? {
        guard isNgrokEnabled, !isCheckingNgrok else { return nil }
        isCheckingNgrok = true
        defer { isCheckingNgrok = false }
        let result = await NgrokStatusProvider().check(at: Date())
        ngrokResult = result
        return result
    }

    @discardableResult
    private func checkOpenAINow() async -> ProviderCheckResult? {
        guard isOpenAIEnabled, !isCheckingOpenAI else { return nil }
        isCheckingOpenAI = true
        defer { isCheckingOpenAI = false }
        let result = await OpenAIStatusProvider().check(at: Date())
        openAIResult = result
        return result
    }

    @discardableResult
    private func checkRegisterNow() async -> ProviderCheckResult? {
        guard isRegisterEnabled, !isCheckingRegister else { return nil }
        isCheckingRegister = true
        defer { isCheckingRegister = false }
        let result = await RegisterStatusProvider().check(at: Date())
        registerResult = result
        return result
    }

    @discardableResult
    private func checkPayPalNow() async -> ProviderCheckResult? {
        guard isPayPalEnabled, !isCheckingPayPal else { return nil }
        isCheckingPayPal = true
        defer { isCheckingPayPal = false }
        let result = await PayPalStatusProvider().check(at: Date())
        payPalResult = result
        return result
    }

    @discardableResult
    private func checkSlackNow() async -> ProviderCheckResult? {
        guard isSlackEnabled, !isCheckingSlack else { return nil }
        isCheckingSlack = true
        defer { isCheckingSlack = false }
        let result = await SlackStatusProvider().check(at: Date())
        slackResult = result
        return result
    }

    @discardableResult
    private func checkStripeNow() async -> ProviderCheckResult? {
        guard isStripeEnabled, !isCheckingStripe else { return nil }
        isCheckingStripe = true
        defer { isCheckingStripe = false }
        let result = await StripeStatusProvider().check(at: Date())
        stripeResult = result
        return result
    }

    @discardableResult
    private func checkVercelNow() async -> ProviderCheckResult? {
        guard isVercelEnabled, !isCheckingVercel else { return nil }
        isCheckingVercel = true
        defer { isCheckingVercel = false }
        let result = await VercelStatusProvider().check(at: Date())
        vercelResult = result
        return result
    }

    var statusMenuServices: [StatusMenuService] {
        [
            statusMenuService(.aircall, "Aircall", isAircallEnabled, isCheckingAircall, aircallResult) { await self.checkAircallNow() },
            statusMenuService(.bigcommerce, "BigCommerce", isBigCommerceEnabled, isCheckingBigCommerce, bigCommerceResult) { await self.checkBigCommerceNow() },
            statusMenuService(.canva, "Canva", isCanvaEnabled, isCheckingCanva, canvaResult) { await self.checkCanvaNow() },
            statusMenuService(.cloudflare, "Cloudflare", isCloudflareEnabled, isCheckingCloudflare, cloudflareResult) { await self.checkCloudflareNow() },
            statusMenuService(.cloudways, "Cloudways", isCloudwaysEnabled, isCheckingCloudways, cloudwaysResult) { await self.checkCloudwaysNow() },
            statusMenuService(.github, "GitHub", isGitHubEnabled, isCheckingGitHub, githubResult) { await self.checkGitHubNow() },
            statusMenuService(.hubspot, "HubSpot", isHubSpotEnabled, isCheckingHubSpot, hubSpotResult) { await self.checkHubSpotNow() },
            statusMenuService(.mongodb, "MongoDB", isMongoDBEnabled, isCheckingMongoDB, mongoDBResult) { await self.checkMongoDBNow() },
            statusMenuService(.monday, "Monday", isMondayEnabled, isCheckingMonday, mondayResult) { await self.checkMondayNow() },
            statusMenuService(.ngrok, "Ngrok", isNgrokEnabled, isCheckingNgrok, ngrokResult) { await self.checkNgrokNow() },
            statusMenuService(.openai, "OpenAI", isOpenAIEnabled, isCheckingOpenAI, openAIResult) { await self.checkOpenAINow() },
            statusMenuService(.register, "Register.it", isRegisterEnabled, isCheckingRegister, registerResult) { await self.checkRegisterNow() },
            statusMenuService(.paypal, "PayPal", isPayPalEnabled, isCheckingPayPal, payPalResult) { await self.checkPayPalNow() },
            statusMenuService(.slack, "Slack", isSlackEnabled, isCheckingSlack, slackResult) { await self.checkSlackNow() },
            statusMenuService(.stripe, "Stripe", isStripeEnabled, isCheckingStripe, stripeResult) { await self.checkStripeNow() },
            statusMenuService(.vercel, "Vercel", isVercelEnabled, isCheckingVercel, vercelResult) { await self.checkVercelNow() }
        ].filter(\.isEnabled)
    }

    var nonOKServiceCount: Int {
        statusMenuServices.count { $0.result != nil && !$0.isOperational }
    }

    private func statusMenuService(
        _ id: ServiceID,
        _ name: String,
        _ enabled: Bool,
        _ checking: Bool,
        _ result: ProviderCheckResult?,
        refresh: @escaping @MainActor () async -> ProviderCheckResult?
    ) -> StatusMenuService {
        StatusMenuService(
            id: id,
            name: name,
            statusPageURL: BuiltInServiceCatalog.definition(for: id)!.statusPageURL,
            isEnabled: enabled,
            isChecking: checking,
            result: result,
            timing: result.flatMap { confirmedHealth.period(for: id, result: $0) },
            refresh: refresh
        )
    }

    private func refreshTask(for provider: StatusMenuService, source: CheckSource) -> Task<ProviderCheckResult?, Never> {
        if let running = activeChecks[provider.id] { return running }
        let task = Task {
            defer { activeChecks[provider.id] = nil }
            let result = await provider.refresh()
            if let result, statusMenuServices.contains(where: { $0.id == provider.id }) {
                await record(result, for: provider, source: source)
            }
            return result
        }
        activeChecks[provider.id] = task
        return task
    }

    func refreshAllManually() async {
        let providers = statusMenuServices
        guard !isRefreshingAll, !providers.isEmpty else { return }
        isRefreshingAll = true
        defer { isRefreshingAll = false }

        let checks = providers.map { refreshTask(for: $0, source: .manual) }
        var operational = 0
        var issues = 0
        var failed = 0
        var details: [RefreshDetails] = []
        for (provider, check) in zip(providers, checks) {
            guard let result = await check.value else { continue }
            if let detail = RefreshDetails(result, providerName: provider.name, timing: confirmedHealth.period(for: provider.id, result: result)) {
                details.append(detail)
            }
            switch result {
            case .observed(let observation) where observation.isOperational: operational += 1
            case .observed: issues += 1
            case .failed: failed += 1
            }
        }

        let locale = LocalizationManager.shared.locale
        presentRefreshPanel(
            title: String(localized: LocalizedStringResource("Refresh all", locale: locale)),
            message: LocalizedStringResource("Operational: \(operational) · With issues: \(issues) · Failed checks: \(failed)", locale: locale),
            details: details
        )
    }

    func refreshManually(_ id: ServiceID) async {
        guard let provider = statusMenuServices.first(where: { $0.id == id }),
              !provider.isChecking else { return }

        let previousHealth = confirmedHealth.isOperational(id)
        guard let result = await refreshTask(for: provider, source: .manual).value else { return }
        presentRefreshResult(result, for: provider, previousHealth: previousHealth)
    }

    private func presentRefreshResult(_ result: ProviderCheckResult, for provider: StatusMenuService, previousHealth: Bool?) {
        let locale = LocalizationManager.shared.locale
        let message: LocalizedStringResource

        switch result {
        case .observed(let observation) where observation.isOperational:
            message = switch previousHealth {
            case true?: LocalizedStringResource("The service is still operational.", locale: locale)
            case false?: LocalizedStringResource("The service is operational again.", locale: locale)
            case nil: LocalizedStringResource("The service is operational.", locale: locale)
            }
        case .observed:
            message = previousHealth == false
                ? LocalizedStringResource("The service still has issues.", locale: locale)
                : LocalizedStringResource("The service has an ongoing issue.", locale: locale)
        case .failed:
            message = LocalizedStringResource("Could not verify the service status.", locale: locale)
        }

        let timing = confirmedHealth.period(for: provider.id, result: result)
        let details = RefreshDetails(result, timing: timing)
        presentRefreshPanel(title: provider.name, message: message, details: details.map { [$0] } ?? [],
                            summaryTiming: details == nil ? timing : nil)
    }

    private func presentRefreshPanel(title: String, message: LocalizedStringResource, details: [RefreshDetails], summaryTiming: ServiceHealthPeriod? = nil) {
        let locale = LocalizationManager.shared.locale
        let panelSize = details.isEmpty ? NSSize(width: 350, height: summaryTiming == nil ? 105 : 130)
            : NSSize(width: 500, height: details.count > 1 ? 350 : 300)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView:
            RefreshResultView(message: String(localized: message), details: details, summaryTiming: summaryTiming) { [weak panel] in
                NSApplication.shared.stopModal()
                panel?.orderOut(nil)
            }
            .environment(\.locale, locale)
        )
        pendingRefreshAlerts.append(panel)

        guard !isPresentingRefreshAlert else { return }
        isPresentingRefreshAlert = true
        defer { isPresentingRefreshAlert = false }
        while !pendingRefreshAlerts.isEmpty {
            let next = pendingRefreshAlerts.removeFirst()
            NSApplication.shared.activate(ignoringOtherApps: true)
            next.center()
            NSApplication.shared.runModal(for: next)
        }
    }

    private func record(_ result: ProviderCheckResult, for provider: StatusMenuService, source: CheckSource) async {
        let transition = confirmedHealth.record(result, for: provider.id, source: source)
        guard case .observed(let observation) = result else { return }
        if let transition {
            await ServiceNotifications.shared.post(
                transition, providerID: provider.id, providerName: provider.name, observation: observation
            )
        }
    }

    private func restartProviderSchedule(checkImmediately: Bool) {
        scheduleTask?.cancel()
        guard hasEnabledProviders else {
            scheduleTask = nil
            return
        }

        scheduleTask = Task { [weak self] in
            guard let self else { return }
            if checkImmediately {
                await checkEnabledProviders()
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(intervalMinutes * 60))
                } catch {
                    return
                }
                guard !Task.isCancelled, hasEnabledProviders else { continue }
                await checkEnabledProviders()
            }
        }
    }

    private func checkEnabledProviders() async {
        for provider in statusMenuServices {
            guard !Task.isCancelled, !isRefreshingAll else { return }
            _ = await refreshTask(for: provider, source: .automatic).value
        }
    }

    private var hasEnabledProviders: Bool {
        isAircallEnabled || isBigCommerceEnabled || isCanvaEnabled || isCloudflareEnabled ||
        isCloudwaysEnabled || isGitHubEnabled || isHubSpotEnabled || isMongoDBEnabled ||
        isMondayEnabled || isNgrokEnabled || isOpenAIEnabled || isRegisterEnabled ||
        isPayPalEnabled || isSlackEnabled || isStripeEnabled || isVercelEnabled
    }
}

private struct RefreshDetails {
    let providerName: String?
    let result: ProviderCheckResult

    let timing: ServiceHealthPeriod?

    var isFailedCheck: Bool {
        if case .failed = result { return true }
        return false
    }

    init?(_ result: ProviderCheckResult, providerName: String? = nil, timing: ServiceHealthPeriod?) {
        self.timing = timing
        if case .observed(let observation) = result, observation.isOperational { return nil }
        self.providerName = providerName
        self.result = result
    }
}

private struct RefreshResultView: View {
    let message: String
    let details: [RefreshDetails]
    let summaryTiming: ServiceHealthPeriod?
    let dismiss: () -> Void

    @Environment(\.locale) private var locale
    @State private var hasMoreBelow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: message)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let summaryTiming {
                HealthDurationLabel(period: summaryTiming).foregroundStyle(.secondary)
            }

            if !details.isEmpty {
                if details.first?.providerName != nil {
                    Text(listHeading)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                }
                GeometryReader { viewport in
                    let viewportHeight = viewport.size.height
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(details.indices, id: \.self) { index in
                                if index > 0 { Divider() }
                                detailRow(details[index])
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .onGeometryChange(for: Bool.self) { content in
                            content.frame(in: .named("refreshViewport")).maxY > viewportHeight + 1
                        } action: { hasMoreBelow = $0 }
                    }
                    .coordinateSpace(name: "refreshViewport")
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.quaternary)
                            .allowsHitTesting(false)
                    }
                }
            }

            HStack {
                if hasMoreBelow {
                    Text("Scroll for more details")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("OK", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .onExitCommand(perform: dismiss)
    }

    private var listHeading: LocalizedStringKey {
        if details.allSatisfy(\.isFailedCheck) { return "Services with failed checks" }
        if details.contains(where: \.isFailedCheck) { return "Services with issues or failed checks" }
        return "Services with ongoing issues"
    }

    private func detailRow(_ detail: RefreshDetails) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            switch detail.result {
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel(Text("Check failed"))
            case .observed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel(Text("Active issue"))
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    if let name = detail.providerName {
                        Text(verbatim: name).font(.headline)
                        Spacer(minLength: 8)
                    }
                    if let timing = detail.timing {
                        HealthDurationLabel(period: timing)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                switch detail.result {
                case .failed(let failure):
                    Text(failureDescription(failure.reason))
                case .observed(let observation):
                    if observation.activeIncidents.isEmpty {
                        if observation.condition == .operational { Text("No active incidents.") }
                        else { Text(conditionName(observation.condition, locale: locale)) }
                    }
                    ForEach(observation.activeIncidents.indices, id: \.self) { index in
                        let incident = observation.activeIncidents[index]
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: incident.title).fontWeight(.medium)
                            if let summary = incident.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !summary.isEmpty, summary != incident.title {
                                Text(verbatim: summary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }
}

private struct HealthDurationLabel: View {
    let period: ServiceHealthPeriod
    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.periodic(from: period.startedAt, by: 60)) { context in
            let seconds = context.date.timeIntervalSince(period.startedAt)
            if seconds < 60 {
                period.isOperational ? Text("Up for less than a minute") : Text("Down for less than a minute")
            } else {
                let time = Duration.seconds(seconds).formatted(
                    .units(allowed: [.days, .hours, .minutes], width: .abbreviated, maximumUnitCount: 2,
                           fractionalPart: .hide(rounded: .towardZero)).locale(locale)
                )
                period.isOperational ? Text("Up for \(time)") : Text("Down for \(time)")
            }
        }
    }
}

/// AppKit tracks the cascading menus. Only the read-only rows use hosted views.
@MainActor
private final class StatusMenuController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let root = NSMenu()
    private let openSettings: () -> Void
    private let monitor = MonitoringModel.shared
    private let language = LocalizationManager.shared
    private var observations: Set<AnyCancellable> = []

    init(openSettings: @escaping () -> Void) {
        self.openSettings = openSettings
        super.init()
        root.autoenablesItems = false
        root.delegate = self
        item.menu = root
        item.button?.image = NSImage(systemSymbolName: AppIdentity.symbolName, accessibilityDescription: nil)
        item.button?.imagePosition = .imageLeading
        Publishers.Merge(monitor.objectWillChange, language.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateStatusButton() }
            .store(in: &observations)
        updateStatusButton()
    }

    func remove() { NSStatusBar.system.removeStatusItem(item) }

    private func string(_ value: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(value, locale: language.locale))
    }

    private func updateStatusButton() {
        let count = monitor.nonOKServiceCount
        item.button?.attributedTitle = NSAttributedString(string: count > 0 ? " \(count)" : "",
            attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)])
        item.button?.setAccessibilityLabel(count > 0 ? string("Status Page Monitor: \(count) services not OK") : AppIdentity.displayName)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let submenu = menu as? ProviderSubmenu {
            if let provider = monitor.statusMenuServices.first(where: { $0.id == submenu.providerID }) {
                populate(submenu, for: provider)
            }
            return
        }
        let providers = monitor.statusMenuServices
        let healthy = providers.filter(\.isOperational)
        let others = providers.filter { !$0.isOperational }
        let group = menu.addItem(withTitle: string(healthy.isEmpty ? "\(healthy.count) servizi ok" : "🟢 \(healthy.count) servizi ok"),
                                 action: nil, keyEquivalent: "")
        group.isEnabled = !healthy.isEmpty
        if !healthy.isEmpty {
            let list = NSMenu()
            list.autoenablesItems = false
            for provider in healthy { addProvider(provider, to: list) }
            group.submenu = list
        }
        if !others.isEmpty { menu.addItem(.separator()) }
        for provider in others { addProvider(provider, to: menu) }
        if providers.isEmpty {
            menu.addItem(withTitle: string("No services enabled"), action: nil, keyEquivalent: "").isEnabled = false
        }
        menu.addItem(.separator())
        let refresh = MenuCommand(string(monitor.isRefreshingAll ? "Refreshing all…" : "Refresh all")) {
            Task { await MonitoringModel.shared.refreshAllManually() }
        }
        refresh.isEnabled = !providers.isEmpty && !monitor.isRefreshingAll
        menu.addItem(refresh)
        let updates = UpdateSettingsModel.shared
        if updates.automaticChecks, let version = updates.availableVersion, let url = updates.availableReleaseURL {
            menu.addItem(MenuCommand(string("Version \(version) is available")) { NSWorkspace.shared.open(url) })
        }
        menu.addItem(MenuCommand(string("Settings"), perform: openSettings))
        menu.addItem(MenuCommand(string("Quit Status Page Monitor"), key: "q") { NSApp.terminate(nil) })
    }

    private func addProvider(_ provider: StatusMenuService, to menu: NSMenu) {
        let marker: String
        var suffix: String?
        switch provider.result {
        case .observed(let observation):
            marker = observation.isOperational ? "🟢 " : "🔴 "
            if !observation.isOperational && observation.activeIncidents.isEmpty {
                suffix = String(localized: conditionName(observation.condition, locale: language.locale))
            }
        case .failed:
            marker = "🟠 "
            suffix = string("Check failed")
        case nil:
            marker = ""
            suffix = string("Waiting")
        }
        if provider.isChecking && !provider.isOperational { suffix = string("Checking") }
        let row = menu.addItem(withTitle: marker + provider.name + (suffix.map { " · " + $0 } ?? ""),
                               action: nil, keyEquivalent: "")
        if case .observed(let observation) = provider.result, !observation.isOperational, suffix == nil {
            row.setAccessibilityLabel(provider.name + " · " + string("Active issue"))
        }
        let submenu = ProviderSubmenu(providerID: provider.id, title: provider.name)
        submenu.autoenablesItems = false
        submenu.delegate = self
        row.submenu = submenu
    }

    private func populate(_ menu: NSMenu, for provider: StatusMenuService) {
        if let result = provider.result {
            addProviderDetails(result, for: provider, to: menu)
        }
        if let period = provider.timing {
            addInformation(HealthDurationLabel(period: period)
                .font(.callout)
                .foregroundStyle(.secondary), to: menu)
        }
        if let updated = provider.lastUpdatedAt {
            let style = Date.FormatStyle(date: .abbreviated,
                                         time: .shortened, locale: language.locale)
            addInformation(Text("Last checked \(updated.formatted(style))")
                .font(.callout)
                .foregroundStyle(.secondary), to: menu)
            menu.addItem(.separator())
        }
        let refresh = MenuCommand(string("Refresh now"), symbol: "arrow.clockwise") {
            Task { await MonitoringModel.shared.refreshManually(provider.id) }
        }
        refresh.isEnabled = !provider.isChecking
        menu.addItem(refresh)
        menu.addItem(MenuCommand(string("Open status page"), symbol: "arrow.up.right.square") {
            NSWorkspace.shared.open(provider.statusPageURL)
        })
    }

    private func addProviderDetails(_ result: ProviderCheckResult, for provider: StatusMenuService, to menu: NSMenu) {
        let symbol: String
        let color: Color
        let status: LocalizedStringKey
        switch result {
        case .failed:
            (symbol, color, status) = ("exclamationmark.triangle.fill", .orange, "Check failed")
        case .observed(let observation) where observation.isOperational:
            (symbol, color, status) = ("circle.fill", .green, "Operational")
        case .observed:
            (symbol, color, status) = ("circle.fill", .red, "Active issue")
        }
        addInformation(HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.caption)
                .accessibilityLabel(Text(status))
            Text(verbatim: provider.name).font(.headline)
        }.padding(.top, 3), to: menu)

        switch result {
        case .observed(let observation):
            guard !observation.isOperational else { return }
            if observation.activeIncidents.isEmpty {
                addInformation(Text(conditionName(observation.condition, locale: language.locale)), to: menu)
                addInformation(Text("No active incidents."), to: menu)
            }
            for incident in observation.activeIncidents {
                addInformation(Text(verbatim: incident.title).fontWeight(.medium), to: menu)
            }
        case .failed(let failure):
            addInformation(Text(failureDescription(failure.reason)), to: menu)
        }
    }

    private func addInformation(_ content: some View, to menu: NSMenu) {
        let host = NSHostingView(rootView: content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15).padding(.vertical, 3)
            .frame(width: 310).fixedSize(horizontal: false, vertical: true)
            .environment(\.locale, language.locale))
        host.frame.size = host.fittingSize
        let row = NSMenuItem()
        row.view = host
        menu.addItem(row)
    }
}

private final class MenuCommand: NSMenuItem {
    private let perform: () -> Void

    init(_ title: String, symbol: String? = nil, key: String = "", perform: @escaping () -> Void) {
        self.perform = perform
        super.init(title: title, action: #selector(invoke), keyEquivalent: key)
        target = self
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    required init(coder: NSCoder) { fatalError("MenuCommand is created programmatically") }
    @objc private func invoke() { perform() }
}

private final class ProviderSubmenu: NSMenu {
    let providerID: ServiceID

    init(providerID: ServiceID, title: String) {
        self.providerID = providerID
        super.init(title: title)
    }

    required init(coder: NSCoder) { fatalError("ProviderSubmenu is created programmatically") }
}

private struct DashboardView: View {
    private enum SettingsSection: CaseIterable {
        case interface
        case providers
        case schedule
        case newIssue
        case updates
        case about

        var title: LocalizedStringKey {
            switch self {
            case .interface: "User interface"
            case .providers: "Online service providers"
            case .schedule: "Schedule"
            case .newIssue: "Contact us"
            case .updates: "Updates"
            case .about: "About"
            }
        }

        var icon: String {
            switch self {
            case .interface: "macwindow"
            case .providers: "switch.2"
            case .schedule: "clock"
            case .newIssue: "square.and.pencil"
            case .updates: "arrow.down.circle"
            case .about: "info.circle"
            }
        }
    }

    @EnvironmentObject private var monitor: MonitoringModel
    @State private var selectedSection: SettingsSection? = .providers
    @State private var providerSearch = ""
    @State private var issueDraft = IssueReportDraft(category: .feature, title: "", description: "")

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 270)
        } detail: {
            if selectedSection == .providers {
                providerSettings
                    .navigationTitle("Settings")
            } else {
                otherSettings
                    .navigationTitle("Settings")
            }
        }
        .frame(minWidth: 720, minHeight: 420)
    }

    private var otherSettings: some View {
        Form {
            switch selectedSection {
            case .interface:
                Section {
                    LanguageSettingsView()
                } header: {
                    Label("User interface", systemImage: "macwindow")
                }
            case .schedule:
                Section {
                    Stepper(value: $monitor.intervalMinutes, in: 15...1440, step: 5) {
                        LabeledContent("Check interval", value: "\(monitor.intervalMinutes) minutes")
                    }
                    Text("Minimum 15 minutes, in 5-minute steps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Schedule", systemImage: "clock")
                }
                NotificationPermissionSection()
            case .newIssue:
                IssueReportView(draft: $issueDraft, repositoryURL: AppIdentity.repositoryURL)
            case .updates:
                UpdatesSettingsView()
            case .about:
                Section {
                    Text(verbatim: AppIdentity.displayName)
                    Text("Created by Mirko Tebaldi")
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        LabeledContent {
                            Text(verbatim: version)
                                .textSelection(.enabled)
                        } label: {
                            Text("Version")
                        }
                    }
                } header: {
                    Label(SettingsSection.about.title, systemImage: SettingsSection.about.icon)
                }

                Section {
                    Link(destination: URL(string: "mailto:\(AppIdentity.contactEmail)")!) {
                        Text(verbatim: AppIdentity.contactEmail)
                    }
                    Link("GitHub repository", destination: AppIdentity.repositoryURL)
                    Link("Issues", destination: AppIdentity.repositoryURL.appendingPathComponent("issues"))
                } header: {
                    Label("Contact", systemImage: "envelope")
                } footer: {
                    Text("You can prefill a new issue from the [Contact us](settings://contact-us) tab.")
                        .environment(\.openURL, OpenURLAction { url in
                            guard url.absoluteString == "settings://contact-us" else { return .discarded }
                            selectedSection = .newIssue
                            return .handled
                        })
                }
            case .providers, nil:
                Text("Select a settings section")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var providerSettings: some View {
        VStack(spacing: 0) {
            providerHeading
                .padding(.horizontal, 26)
                .padding(.top, 16)
            Form {
                Section {
                    let rows = filteredProviderRows
                    if rows.isEmpty {
                        Text("No matching providers")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rows, id: \.serviceID) { row in
                            row
                        }
                    }
                    Text("The enabled provider is checked as soon as the app starts and then at the selected interval.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }

    private var providerHeading: some View {
        HStack(spacing: 12) {
            Label("Online service providers", systemImage: "switch.2")
                .font(.headline)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(
                    "Search providers",
                    text: $providerSearch,
                    prompt: Text("Search providers").foregroundColor(.secondary)
                )
                .labelsHidden()
                .textFieldStyle(.plain)
                if !providerSearch.isEmpty {
                    Button {
                        providerSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear search")
                }
            }
            .font(.body)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.quaternary)
                    .allowsHitTesting(false)
            }
            .frame(width: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filteredProviderRows: [ProviderConfigurationRow] {
        let query = providerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return providerRows.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
    }

    private var providerRows: [ProviderConfigurationRow] {
        [
            ProviderConfigurationRow(
                serviceID: .aircall,
                isEnabled: $monitor.isAircallEnabled,
                isChecking: monitor.isCheckingAircall,
                checkNow: { Task { await monitor.refreshManually(.aircall) } }
            ),
            ProviderConfigurationRow(
                serviceID: .bigcommerce,
                isEnabled: $monitor.isBigCommerceEnabled,
                isChecking: monitor.isCheckingBigCommerce,
                checkNow: { Task { await monitor.refreshManually(.bigcommerce) } }
            ),
            ProviderConfigurationRow(
                serviceID: .canva,
                isEnabled: $monitor.isCanvaEnabled,
                isChecking: monitor.isCheckingCanva,
                checkNow: { Task { await monitor.refreshManually(.canva) } }
            ),
            ProviderConfigurationRow(
                serviceID: .cloudflare,
                isEnabled: $monitor.isCloudflareEnabled,
                isChecking: monitor.isCheckingCloudflare,
                checkNow: { Task { await monitor.refreshManually(.cloudflare) } }
            ),
            ProviderConfigurationRow(
                serviceID: .cloudways,
                isEnabled: $monitor.isCloudwaysEnabled,
                isChecking: monitor.isCheckingCloudways,
                checkNow: { Task { await monitor.refreshManually(.cloudways) } }
            ),
            ProviderConfigurationRow(
                serviceID: .github,
                isEnabled: $monitor.isGitHubEnabled,
                isChecking: monitor.isCheckingGitHub,
                checkNow: { Task { await monitor.refreshManually(.github) } }
            ),
            ProviderConfigurationRow(
                serviceID: .hubspot,
                isEnabled: $monitor.isHubSpotEnabled,
                isChecking: monitor.isCheckingHubSpot,
                checkNow: { Task { await monitor.refreshManually(.hubspot) } }
            ),
            ProviderConfigurationRow(
                serviceID: .mongodb,
                isEnabled: $monitor.isMongoDBEnabled,
                isChecking: monitor.isCheckingMongoDB,
                checkNow: { Task { await monitor.refreshManually(.mongodb) } }
            ),
            ProviderConfigurationRow(
                serviceID: .monday,
                isEnabled: $monitor.isMondayEnabled,
                isChecking: monitor.isCheckingMonday,
                checkNow: { Task { await monitor.refreshManually(.monday) } }
            ),
            ProviderConfigurationRow(
                serviceID: .ngrok,
                isEnabled: $monitor.isNgrokEnabled,
                isChecking: monitor.isCheckingNgrok,
                checkNow: { Task { await monitor.refreshManually(.ngrok) } }
            ),
            ProviderConfigurationRow(
                serviceID: .openai,
                isEnabled: $monitor.isOpenAIEnabled,
                isChecking: monitor.isCheckingOpenAI,
                checkNow: { Task { await monitor.refreshManually(.openai) } }
            ),
            ProviderConfigurationRow(
                serviceID: .register,
                isEnabled: $monitor.isRegisterEnabled,
                isChecking: monitor.isCheckingRegister,
                checkNow: { Task { await monitor.refreshManually(.register) } }
            ),
            ProviderConfigurationRow(
                serviceID: .paypal,
                isEnabled: $monitor.isPayPalEnabled,
                isChecking: monitor.isCheckingPayPal,
                checkNow: { Task { await monitor.refreshManually(.paypal) } }
            ),
            ProviderConfigurationRow(
                serviceID: .slack,
                isEnabled: $monitor.isSlackEnabled,
                isChecking: monitor.isCheckingSlack,
                checkNow: { Task { await monitor.refreshManually(.slack) } }
            ),
            ProviderConfigurationRow(
                serviceID: .stripe,
                isEnabled: $monitor.isStripeEnabled,
                isChecking: monitor.isCheckingStripe,
                checkNow: { Task { await monitor.refreshManually(.stripe) } }
            ),
            ProviderConfigurationRow(
                serviceID: .vercel,
                isEnabled: $monitor.isVercelEnabled,
                isChecking: monitor.isCheckingVercel,
                checkNow: { Task { await monitor.refreshManually(.vercel) } }
            )
        ]
    }
}

@MainActor
private struct StatusMenuService: Identifiable {
    let id: ServiceID
    let name: String
    let statusPageURL: URL
    let isEnabled: Bool
    let isChecking: Bool
    let result: ProviderCheckResult?
    let timing: ServiceHealthPeriod?
    let refresh: @MainActor () async -> ProviderCheckResult?

    var isOperational: Bool {
        guard case .observed(let observation) = result else { return false }
        return observation.isOperational
    }

    var lastUpdatedAt: Date? {
        switch result {
        case .observed(let observation): observation.observedAt
        case .failed(let failure): failure.attemptedAt
        case nil: nil
        }
    }
}

private struct ProviderConfigurationRow: View {
    let serviceID: ServiceID
    @Binding var isEnabled: Bool
    let isChecking: Bool
    let checkNow: () -> Void

    var name: String { service.displayName }

    private var service: ServiceDefinition {
        BuiltInServiceCatalog.definition(for: serviceID)!
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle(name, isOn: $isEnabled)
            Spacer(minLength: 12)
            Button(action: checkNow) {
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24, height: 24)
                        .accessibilityLabel("Checking \(name)")
                } else {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.bordered)
            .help("Check \(name) now")
            .accessibilityLabel("Check \(name) now")
            .disabled(!isEnabled || isChecking)

            Link(destination: service.statusPageURL) {
                Image(systemName: "arrow.up.right.square")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .help("Open \(name) status page")
            .accessibilityLabel("Open \(name) status page")
        }
    }
}

private func conditionName(_ condition: ServiceCondition, locale: Locale) -> LocalizedStringResource {
    switch condition {
    case .operational: LocalizedStringResource("Operational", locale: locale)
    case .degradedPerformance: LocalizedStringResource("Degraded performance", locale: locale)
    case .partialOutage: LocalizedStringResource("Partial outage", locale: locale)
    case .majorOutage: LocalizedStringResource("Major outage", locale: locale)
    case .maintenance: LocalizedStringResource("Maintenance", locale: locale)
    }
}

private func failureDescription(_ reason: CheckFailureReason) -> LocalizedStringKey {
    switch reason {
    case .network(let message): "Connection failed: \(message)"
    case .httpStatus(let code): "HTTP \(code) response."
    case .invalidResponse(let message): "Invalid response: \(message)"
    case .missingField(let field): "Required field missing: \(field)"
    case .unrecognizedStatus(let field, let value): "Unrecognized value '\(value)' at \(field)."
    case .invalidDefinition(let message): "Provider configuration error: \(message)"
    }
}

private enum AircallSetupError: LocalizedError {
    case missingManifest

    var errorDescription: String? {
        "The bundled Aircall configuration could not be found."
    }
}
