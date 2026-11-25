import Foundation

struct GitHubStatusProvider: StatusProvider {
    private static let summaryURL = URL(string: "https://www.githubstatus.com/api/v2/summary.json")!
    private static let terminalStatuses: Set<String> = ["resolved", "postmortem", "completed"]
    private static let conditions: [String: ServiceCondition] = [
        "none": .operational,
        "maintenance": .maintenance,
        "minor": .degradedPerformance,
        "major": .majorOutage,
        "critical": .majorOutage
    ]
    private static let incidentStatuses: [String: IncidentStatus] = [
        "investigating": .investigating,
        "identified": .identified,
        "monitoring": .monitoring,
        "scheduled": .scheduled,
        "in_progress": .inProgress,
        "verifying": .verifying
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .github)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.summaryURL)
            let document = try JSONResponseParser.parse(response.body)
            guard case .object(let root) = document else { throw GitHubProviderFailure.invalidRoot }
            let status = try object("status", in: root, path: "/status")
            let indicator = try requiredString("indicator", in: status, path: "/status/indicator")
            guard var condition = Self.conditions[indicator] else {
                throw GitHubProviderFailure.unknownValue(path: "/status/indicator", value: indicator)
            }

            let incidents = try activeRecords("incidents", in: root, maintenance: false)
            let maintenances = try activeRecords("scheduled_maintenances", in: root, maintenance: true)
            if condition == .operational && !maintenances.isEmpty { condition = .maintenance }

            return .observed(
                ServiceObservation(
                    condition: condition,
                    activeIncidents: incidents + maintenances,
                    observedAt: date
                )
            )
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func activeRecords(
        _ key: String,
        in root: [String: JSONValue],
        maintenance: Bool
    ) throws -> [ServiceIncident] {
        let values = try array(key, in: root, path: "/\(key)")
        return try values.enumerated().compactMap { index, value -> ServiceIncident? in
            guard case .object(let fields) = value else {
                throw GitHubProviderFailure.invalidField("/\(key)/\(index)")
            }
            let path = "/\(key)/\(index)"
            let lifecycle = try requiredString("status", in: fields, path: "\(path)/status")
            if Self.terminalStatuses.contains(lifecycle) { return nil }
            guard let incidentStatus = Self.incidentStatuses[lifecycle] else {
                throw GitHubProviderFailure.unknownValue(path: "\(path)/status", value: lifecycle)
            }
            let title = try requiredString("name", in: fields, path: "\(path)/name")
            let impact: IncidentImpact?
            switch fields["impact"]?.stringValue {
            case "none": impact = .some(.none)
            case "minor": impact = .some(.minor)
            case "major": impact = .some(.major)
            case "critical": impact = .some(.critical)
            case "maintenance": impact = .some(.maintenance)
            default: impact = nil
            }

            return ServiceIncident(
                id: fields["id"]?.stringValue,
                title: title,
                status: incidentStatus,
                impact: maintenance ? .maintenance : impact,
                summary: firstUpdateBody(fields["incident_updates"]),
                url: nil,
                startedAt: nil,
                updatedAt: nil
            )
        }
    }

    private func firstUpdateBody(_ value: JSONValue?) -> String? {
        guard case .array(let updates) = value,
              let first = updates.first,
              case .object(let fields) = first else { return nil }
        return fields["body"]?.stringValue
    }

    private func object(
        _ key: String,
        in fields: [String: JSONValue],
        path: String
    ) throws -> [String: JSONValue] {
        guard let value = fields[key] else { throw GitHubProviderFailure.missingField(path) }
        guard case .object(let object) = value else { throw GitHubProviderFailure.invalidField(path) }
        return object
    }

    private func array(_ key: String, in fields: [String: JSONValue], path: String) throws -> [JSONValue] {
        guard let value = fields[key] else { throw GitHubProviderFailure.missingField(path) }
        guard case .array(let array) = value else { throw GitHubProviderFailure.invalidField(path) }
        return array
    }

    private func requiredString(
        _ key: String,
        in fields: [String: JSONValue],
        path: String
    ) throws -> String {
        guard let value = fields[key] else { throw GitHubProviderFailure.missingField(path) }
        guard let string = value.stringValue, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitHubProviderFailure.invalidField(path)
        }
        return string
    }
}

private enum GitHubProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case invalidRoot
    case missingField(String)
    case invalidField(String)
    case unknownValue(path: String, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidRoot: "GitHub summary must be a JSON object."
        case .missingField(let path): "GitHub summary is missing '\(path)'."
        case .invalidField(let path): "GitHub summary field '\(path)' has an invalid type or value."
        case .unknownValue(let path, let value): "GitHub value '\(value)' at '\(path)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .invalidRoot: .invalidResponse(message: errorDescription ?? "Invalid GitHub response.")
        case .missingField(let path): .missingField(name: path)
        case .invalidField(let path): .invalidResponse(message: errorDescription ?? "Invalid field \(path).")
        case .unknownValue(let path, let value): .unrecognizedStatus(field: path, value: value)
        }
    }
}
