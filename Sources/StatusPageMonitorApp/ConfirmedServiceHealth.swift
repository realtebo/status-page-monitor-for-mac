import Foundation

enum CheckSource {
    case automatic, manual
}

enum HealthTransition {
    case incident, recovery
}

/// The last confirmed health of each provider, independent of the latest check attempt.
struct ConfirmedServiceHealth {
    private static let defaultsKey = "monitor.confirmedServiceHealth"
    private let defaults: UserDefaults
    private var health: [String: Bool]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        health = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Bool] ?? [:]
    }

    func isOperational(_ id: ServiceID) -> Bool? {
        health[id.rawValue]
    }

    mutating func record(_ result: ProviderCheckResult, for id: ServiceID, source: CheckSource) -> HealthTransition? {
        guard case .observed(let observation) = result else { return nil }
        let operational = observation.isOperational
        let previous = isOperational(id)
        guard previous != operational else { return nil }

        health[id.rawValue] = operational
        defaults.set(health, forKey: Self.defaultsKey)
        guard source == .automatic, previous != nil else { return nil }
        return operational ? .recovery : .incident
    }
}
