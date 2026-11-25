import Foundation

struct CanvaStatusProvider: StatusProvider {
    private static let summaryURL = URL(string: "https://www.canvastatus.com/api/v2/summary.json")!
    private static let inactiveStatuses: Set<String> = ["resolved", "postmortem", "completed"]
    private static let conditions: [String: ServiceCondition] = [
        "none": .operational,
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

    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .canva)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.summaryURL)
            let document = try JSONResponseParser.parse(response.body)
            guard case .object(let root) = document else { throw CanvaProviderFailure.invalidRoot }
            let status = try object(at: "status", in: root)
            let indicator = try requiredString("indicator", in: status, path: "/status/indicator")
            guard var condition = Self.conditions[indicator] else {
                throw CanvaProviderFailure.unrecognizedIndicator(indicator)
            }

            let incidents = try activeRecords(at: "incidents", in: root, maintenance: false)
            let maintenances = try activeRecords(at: "scheduled_maintenances", in: root, maintenance: true)
            if condition == .operational && !maintenances.isEmpty { condition = .maintenance }

            return .observed(
                ServiceObservation(condition: condition, activeIncidents: incidents + maintenances, observedAt: date)
            )
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func activeRecords(
        at key: String,
        in root: [String: JSONValue],
        maintenance: Bool
    ) throws -> [ServiceIncident] {
        guard let value = root[key] else { throw CanvaProviderFailure.missingField("/\(key)") }
        guard case .array(let records) = value else { throw CanvaProviderFailure.invalidField("/\(key)") }

        return try records.enumerated().compactMap { index, record -> ServiceIncident? in
            guard case .object(let fields) = record else {
                throw CanvaProviderFailure.invalidField("/\(key)/\(index)")
            }
            let status = try requiredString("status", in: fields, path: "/\(key)/\(index)/status")
            if Self.inactiveStatuses.contains(status) { return nil }
            guard let mappedStatus = Self.incidentStatuses[status] else {
                throw CanvaProviderFailure.unrecognizedRecordStatus(path: "/\(key)/\(index)/status", value: status)
            }
            let title = try requiredString("name", in: fields, path: "/\(key)/\(index)/name")
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
                status: mappedStatus,
                impact: maintenance ? .maintenance : impact,
                summary: nil,
                url: nil,
                startedAt: nil,
                updatedAt: nil
            )
        }
    }

    private func object(at key: String, in fields: [String: JSONValue]) throws -> [String: JSONValue] {
        guard let value = fields[key] else { throw CanvaProviderFailure.missingField("/\(key)") }
        guard case .object(let object) = value else { throw CanvaProviderFailure.invalidField("/\(key)") }
        return object
    }

    private func requiredString(_ key: String, in fields: [String: JSONValue], path: String) throws -> String {
        guard let value = fields[key] else { throw CanvaProviderFailure.missingField(path) }
        guard let string = value.stringValue, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CanvaProviderFailure.invalidField(path)
        }
        return string
    }
}

private enum CanvaProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case invalidRoot
    case missingField(String)
    case invalidField(String)
    case unrecognizedIndicator(String)
    case unrecognizedRecordStatus(path: String, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidRoot: "Canva summary response must be a JSON object."
        case .missingField(let path): "Canva summary is missing '\(path)'."
        case .invalidField(let path): "Canva summary field '\(path)' has an invalid type or value."
        case .unrecognizedIndicator(let value): "Canva status indicator '\(value)' is not mapped."
        case .unrecognizedRecordStatus(let path, let value): "Canva status '\(value)' at '\(path)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .invalidRoot: .invalidResponse(message: errorDescription ?? "Invalid Canva response.")
        case .missingField(let path): .missingField(name: path)
        case .invalidField(let path): .invalidResponse(message: errorDescription ?? "Invalid field \(path).")
        case .unrecognizedIndicator(let value): .unrecognizedStatus(field: "/status/indicator", value: value)
        case .unrecognizedRecordStatus(let path, let value): .unrecognizedStatus(field: path, value: value)
        }
    }
}
