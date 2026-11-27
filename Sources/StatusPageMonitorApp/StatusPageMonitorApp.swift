import AppKit
import Combine
import SwiftUI

enum AppIdentity {
    static let displayName = "Status Page Monitor"
    static let symbolName = "waveform.path.ecg"
    static let dashboardWindowID = "dashboard"
    static let contactEmail = "mirkotebaldi@yahoo.it"
}

@main
struct StatusPageMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appLifecycle
    @StateObject private var monitor = MonitoringModel.shared
    @StateObject private var localization = LocalizationManager.shared

    var body: some Scene {
        WindowGroup("Settings", id: AppIdentity.dashboardWindowID) {
            DashboardView()
                .environmentObject(monitor)
                .environment(\.locale, localization.locale)
                .background {
                    SettingsDockPresence()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        }

        MenuBarExtra {
            StatusBarMenu()
                .environmentObject(monitor)
                .environment(\.locale, localization.locale)
        } label: {
            StatusBarLabel(nonOKCount: monitor.nonOKServiceCount)
                .environment(\.locale, localization.locale)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct SettingsDockPresence: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowObserver { WindowObserver() }

    func updateNSView(_ nsView: WindowObserver, context: Context) {}

    final class WindowObserver: NSView {
        private static var openSettingsWindows: Set<ObjectIdentifier> = []
        private static let dockIcon = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap { NSImage(contentsOf: $0) }
        private weak var settingsWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard settingsWindow !== window else { return }

            if let settingsWindow {
                NotificationCenter.default.removeObserver(self, name: nil, object: settingsWindow)
                Self.openSettingsWindows.remove(ObjectIdentifier(settingsWindow))
            }

            settingsWindow = window
            if let window {
                NotificationCenter.default.addObserver(
                    self, selector: #selector(windowDidBecomeKey),
                    name: NSWindow.didBecomeKeyNotification, object: window
                )
                NotificationCenter.default.addObserver(
                    self, selector: #selector(windowWillClose),
                    name: NSWindow.willCloseNotification, object: window
                )
                Self.openSettingsWindows.insert(ObjectIdentifier(window))
            }
            Self.scheduleDockUpdate()
        }

        @objc private func windowDidBecomeKey(_ notification: Notification) {
            guard let settingsWindow else { return }
            Self.openSettingsWindows.insert(ObjectIdentifier(settingsWindow))
            Self.scheduleDockUpdate()
        }

        @objc private func windowWillClose(_ notification: Notification) {
            guard let settingsWindow else { return }
            Self.openSettingsWindows.remove(ObjectIdentifier(settingsWindow))
            Self.scheduleDockUpdate()
        }

        static func scheduleDockUpdate() {
            DispatchQueue.main.async {
                Self.updateDockPresence()
            }
        }

        private static func updateDockPresence() {
            let application = NSApplication.shared
            let policy: NSApplication.ActivationPolicy = openSettingsWindows.isEmpty ? .accessory : .regular

            if let icon = dockIcon {
                application.applicationIconImage = icon
            }
            if application.activationPolicy() != policy {
                application.setActivationPolicy(policy)
            }
        }
    }
}

@MainActor
private final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsDockPresence.WindowObserver.scheduleDockUpdate()
        MonitoringModel.shared.startChecksAtLaunch()
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
    private var lastOperationalAt: [String: Date]

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
    private static let lastOperationalAtDefaultsKey = "monitor.lastOperationalAt"
    private static let intervalDefaultsKey = "monitor.intervalMinutes"

    private var didStartAtLaunch = false
    private var scheduleTask: Task<Void, Never>?
    private var lastObservedHealth: [ServiceID: Bool] = [:]
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
        lastOperationalAt = (defaults.dictionary(forKey: Self.lastOperationalAtDefaultsKey) as? [String: Double] ?? [:])
            .mapValues(Date.init(timeIntervalSince1970:))

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
            record(result, for: .aircall)
            aircallResult = result
            return result
        } catch {
            let result = ProviderCheckResult.failed(
                CheckFailure(
                    reason: .invalidDefinition(message: error.localizedDescription),
                    attemptedAt: attemptedAt
                )
            )
            record(result, for: .aircall)
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
        record(result, for: .bigcommerce)
        bigCommerceResult = result
        return result
    }

    @discardableResult
    private func checkCanvaNow() async -> ProviderCheckResult? {
        guard isCanvaEnabled, !isCheckingCanva else { return nil }
        isCheckingCanva = true
        defer { isCheckingCanva = false }
        let result = await CanvaStatusProvider().check(at: Date())
        record(result, for: .canva)
        canvaResult = result
        return result
    }

    @discardableResult
    private func checkCloudflareNow() async -> ProviderCheckResult? {
        guard isCloudflareEnabled, !isCheckingCloudflare else { return nil }
        isCheckingCloudflare = true
        defer { isCheckingCloudflare = false }
        let result = await CloudflareStatusProvider().check(at: Date())
        record(result, for: .cloudflare)
        cloudflareResult = result
        return result
    }

    @discardableResult
    private func checkCloudwaysNow() async -> ProviderCheckResult? {
        guard isCloudwaysEnabled, !isCheckingCloudways else { return nil }
        isCheckingCloudways = true
        defer { isCheckingCloudways = false }
        let result = await CloudwaysStatusProvider().check(at: Date())
        record(result, for: .cloudways)
        cloudwaysResult = result
        return result
    }

    @discardableResult
    private func checkGitHubNow() async -> ProviderCheckResult? {
        guard isGitHubEnabled, !isCheckingGitHub else { return nil }
        isCheckingGitHub = true
        defer { isCheckingGitHub = false }
        let result = await GitHubStatusProvider().check(at: Date())
        record(result, for: .github)
        githubResult = result
        return result
    }

    @discardableResult
    private func checkHubSpotNow() async -> ProviderCheckResult? {
        guard isHubSpotEnabled, !isCheckingHubSpot else { return nil }
        isCheckingHubSpot = true
        defer { isCheckingHubSpot = false }
        let result = await HubSpotStatusProvider().check(at: Date())
        record(result, for: .hubspot)
        hubSpotResult = result
        return result
    }

    @discardableResult
    private func checkMongoDBNow() async -> ProviderCheckResult? {
        guard isMongoDBEnabled, !isCheckingMongoDB else { return nil }
        isCheckingMongoDB = true
        defer { isCheckingMongoDB = false }
        let result = await MongoDBStatusProvider().check(at: Date())
        record(result, for: .mongodb)
        mongoDBResult = result
        return result
    }

    @discardableResult
    private func checkMondayNow() async -> ProviderCheckResult? {
        guard isMondayEnabled, !isCheckingMonday else { return nil }
        isCheckingMonday = true
        defer { isCheckingMonday = false }
        let result = await MondayStatusProvider().check(at: Date())
        record(result, for: .monday)
        mondayResult = result
        return result
    }

    @discardableResult
    private func checkNgrokNow() async -> ProviderCheckResult? {
        guard isNgrokEnabled, !isCheckingNgrok else { return nil }
        isCheckingNgrok = true
        defer { isCheckingNgrok = false }
        let result = await NgrokStatusProvider().check(at: Date())
        record(result, for: .ngrok)
        ngrokResult = result
        return result
    }

    @discardableResult
    private func checkOpenAINow() async -> ProviderCheckResult? {
        guard isOpenAIEnabled, !isCheckingOpenAI else { return nil }
        isCheckingOpenAI = true
        defer { isCheckingOpenAI = false }
        let result = await OpenAIStatusProvider().check(at: Date())
        record(result, for: .openai)
        openAIResult = result
        return result
    }

    @discardableResult
    private func checkRegisterNow() async -> ProviderCheckResult? {
        guard isRegisterEnabled, !isCheckingRegister else { return nil }
        isCheckingRegister = true
        defer { isCheckingRegister = false }
        let result = await RegisterStatusProvider().check(at: Date())
        record(result, for: .register)
        registerResult = result
        return result
    }

    @discardableResult
    private func checkPayPalNow() async -> ProviderCheckResult? {
        guard isPayPalEnabled, !isCheckingPayPal else { return nil }
        isCheckingPayPal = true
        defer { isCheckingPayPal = false }
        let result = await PayPalStatusProvider().check(at: Date())
        record(result, for: .paypal)
        payPalResult = result
        return result
    }

    @discardableResult
    private func checkSlackNow() async -> ProviderCheckResult? {
        guard isSlackEnabled, !isCheckingSlack else { return nil }
        isCheckingSlack = true
        defer { isCheckingSlack = false }
        let result = await SlackStatusProvider().check(at: Date())
        record(result, for: .slack)
        slackResult = result
        return result
    }

    @discardableResult
    private func checkStripeNow() async -> ProviderCheckResult? {
        guard isStripeEnabled, !isCheckingStripe else { return nil }
        isCheckingStripe = true
        defer { isCheckingStripe = false }
        let result = await StripeStatusProvider().check(at: Date())
        record(result, for: .stripe)
        stripeResult = result
        return result
    }

    @discardableResult
    private func checkVercelNow() async -> ProviderCheckResult? {
        guard isVercelEnabled, !isCheckingVercel else { return nil }
        isCheckingVercel = true
        defer { isCheckingVercel = false }
        let result = await VercelStatusProvider().check(at: Date())
        record(result, for: .vercel)
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
            statusMenuService(.ngrok, "ngrok", isNgrokEnabled, isCheckingNgrok, ngrokResult) { await self.checkNgrokNow() },
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
            lastOperationalAt: lastOperationalAt[id.rawValue],
            refresh: refresh
        )
    }

    private func refreshTask(for provider: StatusMenuService) -> Task<ProviderCheckResult?, Never> {
        if let running = activeChecks[provider.id] { return running }
        let task = Task {
            defer { activeChecks[provider.id] = nil }
            return await provider.refresh()
        }
        activeChecks[provider.id] = task
        return task
    }

    func refreshAllManually() async {
        let providers = statusMenuServices
        guard !isRefreshingAll, !providers.isEmpty else { return }
        isRefreshingAll = true
        defer { isRefreshingAll = false }

        let checks = providers.map { refreshTask(for: $0) }
        var operational = 0
        var issues = 0
        var failed = 0
        for check in checks {
            guard let result = await check.value else { continue }
            switch result {
            case .observed(let observation) where observation.isOperational: operational += 1
            case .observed: issues += 1
            case .failed: failed += 1
            }
        }

        let locale = LocalizationManager.shared.locale
        presentRefreshPanel(
            title: String(localized: LocalizedStringResource("Refresh all", locale: locale)),
            message: LocalizedStringResource("Operational: \(operational) · With issues: \(issues) · Failed checks: \(failed)", locale: locale)
        )
    }

    func refreshManually(_ id: ServiceID) async {
        guard let provider = statusMenuServices.first(where: { $0.id == id }),
              !provider.isChecking else { return }

        let previousHealth = lastObservedHealth[id]
        guard let result = await refreshTask(for: provider).value else { return }
        presentRefreshResult(result, for: provider.name, previousHealth: previousHealth)
    }

    private func presentRefreshResult(_ result: ProviderCheckResult, for name: String, previousHealth: Bool?) {
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

        presentRefreshPanel(title: name, message: message)
    }

    private func presentRefreshPanel(title: String, message: LocalizedStringResource) {
        let locale = LocalizationManager.shared.locale
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 105),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView:
            RefreshResultView(message: String(localized: message)) { [weak panel] in
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

    private func record(_ result: ProviderCheckResult, for id: ServiceID) {
        guard case .observed(let observation) = result else { return }
        lastObservedHealth[id] = observation.isOperational
        guard observation.isOperational else { return }
        lastOperationalAt[id.rawValue] = observation.observedAt
        UserDefaults.standard.set(
            lastOperationalAt.mapValues(\.timeIntervalSince1970),
            forKey: Self.lastOperationalAtDefaultsKey
        )
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
            _ = await refreshTask(for: provider).value
        }
    }

    private var hasEnabledProviders: Bool {
        isAircallEnabled || isBigCommerceEnabled || isCanvaEnabled || isCloudflareEnabled ||
        isCloudwaysEnabled || isGitHubEnabled || isHubSpotEnabled || isMongoDBEnabled ||
        isMondayEnabled || isNgrokEnabled || isOpenAIEnabled || isRegisterEnabled ||
        isPayPalEnabled || isSlackEnabled || isStripeEnabled || isVercelEnabled
    }
}

private struct RefreshResultView: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            Text(verbatim: message)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("OK", action: dismiss)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .onExitCommand(perform: dismiss)
    }
}

private struct StatusBarLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    let nonOKCount: Int

    var body: some View {
        Group {
            if nonOKCount > 0 {
                if let image = renderedLabel {
                    Image(nsImage: image)
                }
            } else {
                Image(systemName: AppIdentity.symbolName)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nonOKCount > 0
            ? Text("Status Page Monitor: \(nonOKCount) services not OK")
            : Text(verbatim: AppIdentity.displayName))
    }

    private var renderedLabel: NSImage? {
        // Render the icon and count together so the native status item retains the red text.
        let renderer = ImageRenderer(content:
            HStack(spacing: 4) {
                Image(systemName: AppIdentity.symbolName)
                    .foregroundStyle(.primary)
                Text(nonOKCount, format: .number)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            .font(.system(size: 14))
            .frame(height: 18)
            .fixedSize()
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, locale)
        )
        renderer.scale = displayScale
        let image = renderer.nsImage
        image?.isTemplate = false
        return image
    }
}

private struct StatusBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var monitor: MonitoringModel

    var body: some View {
        let providers = monitor.statusMenuServices
        let operationalProviders = providers.filter(\.isOperational)
        let nonOperationalProviders = providers.filter { !$0.isOperational }

        Menu {
            ForEach(operationalProviders) { provider in
                ServiceMenu(provider: provider)
            }
        } label: {
            if operationalProviders.isEmpty {
                Text("\(operationalProviders.count) servizi ok")
            } else {
                Text("🟢 \(operationalProviders.count) servizi ok")
            }
        }
        .disabled(operationalProviders.isEmpty)

        if !nonOperationalProviders.isEmpty {
            Divider()
        }

        ForEach(nonOperationalProviders) { provider in
            ServiceMenu(provider: provider)
        }

        if providers.isEmpty {
            Text("No services enabled")
        }

        Divider()

        Button {
            Task { await monitor.refreshAllManually() }
        } label: {
            if monitor.isRefreshingAll {
                Text("Refreshing all…")
            } else {
                Text("Refresh all")
            }
        }
        .disabled(providers.isEmpty || monitor.isRefreshingAll)

        Button("Settings") {
            openWindow(id: AppIdentity.dashboardWindowID)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Button("Quit Status Page Monitor") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

private struct DashboardView: View {
    private enum SettingsSection: CaseIterable {
        case interface
        case providers
        case schedule
        case about

        var title: LocalizedStringKey {
            switch self {
            case .interface: "User interface"
            case .providers: "Online service providers"
            case .schedule: "Schedule"
            case .about: "About"
            }
        }

        var icon: String {
            switch self {
            case .interface: "macwindow"
            case .providers: "switch.2"
            case .schedule: "clock"
            case .about: "info.circle"
            }
        }
    }

    @EnvironmentObject private var monitor: MonitoringModel
    @State private var selectedSection: SettingsSection? = .providers
    @State private var providerSearch = ""

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
                } header: {
                    Label("Contact", systemImage: "envelope")
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
    let lastOperationalAt: Date?
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

private struct ServiceMenu: View {
    @EnvironmentObject private var monitor: MonitoringModel
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    let provider: StatusMenuService

    var body: some View {
        Menu {
            Button("Refresh \(provider.name)") {
                Task { await monitor.refreshManually(provider.id) }
            }
            .disabled(provider.isChecking)

            Button("Open \(provider.name) status page") {
                openURL(provider.statusPageURL)
            }

            if provider.lastUpdatedAt != nil || provider.lastOperationalAt != nil {
                Divider()
                if let updated = provider.lastUpdatedAt {
                    Text("Last updated \(updated.formatted(timestampStyle))")
                }
                if let healthy = provider.lastOperationalAt {
                    Text("Last OK \(healthy.formatted(timestampStyle))")
                } else {
                    Text("Last OK not recorded")
                }
            }

            if !provider.isOperational, let result = provider.result {
                Divider()
                switch result {
                case .observed(let observation):
                    if observation.activeIncidents.isEmpty {
                        Text("No active incidents.")
                    }
                    ForEach(observation.activeIncidents.indices, id: \.self) { index in
                        Text(verbatim: observation.activeIncidents[index].title)
                    }
                case .failed(let failure):
                    Text(failureDescription(failure.reason))
                }
            }
        } label: {
            if provider.isOperational {
                Text(verbatim: "\(statusMarker)\(provider.name)")
            } else {
                Text("\(statusMarker)\(provider.name) · \(Text(statusLabel))")
            }
        }
    }

    private var timestampStyle: Date.FormatStyle {
        .dateTime.year().month(.abbreviated).day().hour().minute().locale(locale)
    }

    private var statusLabel: LocalizedStringKey {
        if provider.isChecking { return "Checking" }
        switch provider.result {
        case .observed(let observation):
            if !observation.activeIncidents.isEmpty { return "Active issue" }
            return switch observation.condition {
            case .operational: "Operational"
            case .degradedPerformance: "Degraded performance"
            case .partialOutage: "Partial outage"
            case .majorOutage: "Major outage"
            case .maintenance: "Maintenance"
            }
        case .failed: return "Check failed"
        case nil: return "Waiting"
        }
    }

    // Native menu titles display these dots in color alongside the status text.
    private var statusMarker: String {
        switch provider.result {
        case .observed(let observation): observation.isOperational ? "🟢 " : "🔴 "
        case .failed: "🟠 "
        case nil: ""
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
