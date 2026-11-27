import Foundation

enum CheckSource {
    case automatic, manual
}

enum HealthTransition {
    case incident, recovery
}

struct ServiceHealthPeriod: Equatable {
    let isOperational: Bool
    let startedAt: Date
}

/// A failed check cannot start or end a confirmed health period.
struct ConfirmedServiceHealth {
    private static let periodsKey = "monitor.confirmedHealthPeriods"
    private let defaults: UserDefaults
    private let legacyHealth: [String: Bool]
    // The menu uses the last KO as the recovery boundary. Store actual OK checks separately.
    private var up: [String: Date]
    private var firstOK: [String: Date]
    private var lastOK: [String: Date]
    private var firstKO: [String: Date]
    private var lastKO: [String: Date]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        legacyHealth = defaults.dictionary(forKey: "monitor.confirmedServiceHealth") as? [String: Bool] ?? [:]
        let legacyOK = defaults.dictionary(forKey: "monitor.lastOperationalAt") as? [String: Double] ?? [:]
        lastOK = legacyOK.mapValues(Date.init(timeIntervalSince1970:))
        firstOK = [:]
        if let saved = defaults.dictionary(forKey: Self.periodsKey) as? [String: [String: Date]] {
            up = saved["up"] ?? [:]
            firstKO = saved["down"] ?? [:]
            lastKO = saved["lastKO"] ?? [:]
            firstOK = saved["firstOK"] ?? [:]
            if let savedOK = saved["lastOK"] { lastOK = savedOK }
        } else {
            let legacyIssue = defaults.dictionary(forKey: "monitor.firstObservedIssueAt") as? [String: Date] ?? [:]
            up = [:]
            firstKO = [:]
            lastKO = [:]
            for (key, operational) in legacyHealth {
                let knownOK = lastOK[key]
                if operational {
                    up[key] = knownOK
                    firstOK[key] = knownOK
                } else if let issue = legacyIssue[key], knownOK.map({ $0 < issue }) != false {
                    // A recovery after this incident invalidates its old start date.
                    firstKO[key] = issue
                }
            }
        }
    }

    func isOperational(_ id: ServiceID) -> Bool? {
        if up[id.rawValue] != nil { return true }
        if firstKO[id.rawValue] != nil { return false }
        return legacyHealth[id.rawValue]
    }

    func period(for id: ServiceID, result: ProviderCheckResult) -> ServiceHealthPeriod? {
        guard case .observed(let observation) = result else { return nil }
        let operational = observation.isOperational
        guard operational == isOperational(id),
              let start = (operational ? up : firstKO)[id.rawValue] else { return nil }
        return ServiceHealthPeriod(isOperational: operational, startedAt: start)
    }

    mutating func record(_ result: ProviderCheckResult, for id: ServiceID, source: CheckSource) -> HealthTransition? {
        guard case .observed(let observation) = result else { return nil }
        let key = id.rawValue
        let operational = observation.isOperational
        let previous = isOperational(id)
        if operational {
            if up[key] == nil {
                up[key] = lastKO[key] ?? observation.observedAt
                firstOK[key] = observation.observedAt
            } else if firstOK[key] == nil {
                // Older builds only stored the display boundary, which could be a KO.
                firstOK[key] = observation.observedAt
            }
            lastOK[key] = observation.observedAt
        } else {
            if previous != false || firstKO[key] == nil { firstKO[key] = observation.observedAt }
            up.removeValue(forKey: key)
            lastKO[key] = observation.observedAt
        }
        defaults.set(["up": up, "firstOK": firstOK, "lastOK": lastOK, "down": firstKO, "lastKO": lastKO], forKey: Self.periodsKey)
        guard source == .automatic, let previous, previous != operational else { return nil }
        return operational ? .recovery : .incident
    }
}
