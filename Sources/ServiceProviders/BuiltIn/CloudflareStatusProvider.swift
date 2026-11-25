import Foundation

struct CloudflareStatusProvider: StatusProvider {
    private static let summaryURL = URL(string: "https://www.cloudflarestatus.com/api/v2/summary.json")!
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
    private static let allowedComponentStatuses: Set<String> = [
        "operational", "partial_outage", "under_maintenance"
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .cloudflare)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.summaryURL)
            let document = try JSONResponseParser.parse(response.body)
            guard case .object(let root) = document else { throw CloudflareProviderFailure.invalidRoot }

            let status = try object("status", in: root, path: "/status")
            let indicator = try requiredString("indicator", in: status, path: "/status/indicator")
            guard let pageCondition = Self.conditions[indicator] else {
                throw CloudflareProviderFailure.unknownValue(path: "/status/indicator", value: indicator)
            }

            let incidents = try activeRecords("incidents", in: root, maintenance: false)
            let maintenances = try activeRecords("scheduled_maintenances", in: root, maintenance: true)
            let componentIssues = try degradedComponents(in: root)
            let hasOutage = !incidents.isEmpty
            let hasMaintenance = !maintenances.isEmpty

            let condition: ServiceCondition
            if hasMaintenance && !hasOutage {
                condition = .maintenance
            } else if hasOutage && pageCondition == .operational {
                condition = .partialOutage
            } else if !componentIssues.isEmpty && pageCondition == .operational {
                condition = .degradedPerformance
            } else {
                condition = pageCondition
            }

            return .observed(
                ServiceObservation(
                    condition: condition,
                    activeIncidents: incidents + maintenances + componentIssues,
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
                throw CloudflareProviderFailure.invalidField("/\(key)/\(index)")
            }
            let path = "/\(key)/\(index)"
            let lifecycle = try requiredString("status", in: fields, path: "\(path)/status")
            if Self.terminalStatuses.contains(lifecycle) { return nil }
            guard let incidentStatus = Self.incidentStatuses[lifecycle] else {
                throw CloudflareProviderFailure.unknownValue(path: "\(path)/status", value: lifecycle)
            }
            let title = try requiredString("name", in: fields, path: "\(path)/name")
            let sourceImpact = try requiredString("impact", in: fields, path: "\(path)/impact")
            let impact = try mappedImpact(sourceImpact, path: "\(path)/impact")
            let mappedImpact: IncidentImpact = maintenance ? .maintenance : impact

            return ServiceIncident(
                id: fields["id"]?.stringValue,
                title: title,
                status: incidentStatus,
                impact: mappedImpact,
                summary: firstIncidentUpdateBody(fields["incident_updates"]),
                url: nil,
                startedAt: nil,
                updatedAt: nil
            )
        }
    }

    private func degradedComponents(in root: [String: JSONValue]) throws -> [ServiceIncident] {
        let values = try array("components", in: root, path: "/components")
        return try values.enumerated().compactMap { index, value -> ServiceIncident? in
            guard case .object(let fields) = value else {
                throw CloudflareProviderFailure.invalidField("/components/\(index)")
            }
            let path = "/components/\(index)"
            let name = try requiredString("name", in: fields, path: "\(path)/name")
            let sourceStatus = try requiredString("status", in: fields, path: "\(path)/status")
            let isSpecialServicesGroup = name == "Cloudflare Sites and Services"
            if Self.allowedComponentStatuses.contains(sourceStatus),
               !(sourceStatus == "under_maintenance" && isSpecialServicesGroup) {
                return nil
            }

            return ServiceIncident(
                id: fields["id"]?.stringValue,
                title: "\(name): \(sourceStatus.replacingOccurrences(of: "_", with: " "))",
                status: nil,
                impact: componentImpact(sourceStatus),
                summary: nil,
                url: nil,
                startedAt: nil,
                updatedAt: nil
            )
        }
    }

    private func firstIncidentUpdateBody(_ value: JSONValue?) -> String? {
        guard case .array(let updates) = value,
              let first = updates.first,
              case .object(let fields) = first else { return nil }
        return fields["body"]?.stringValue
    }

    private func mappedImpact(_ value: String, path: String) throws -> IncidentImpact {
        switch value {
        case "none": .none
        case "minor": .minor
        case "major": .major
        case "critical": .critical
        case "maintenance": .maintenance
        default: throw CloudflareProviderFailure.unknownValue(path: path, value: value)
        }
    }

    private func componentImpact(_ value: String) -> IncidentImpact? {
        switch value {
        case "degraded_performance": .minor
        case "partial_outage": .major
        case "major_outage": .critical
        case "under_maintenance": .maintenance
        default: nil
        }
    }

    private func object(
        _ key: String,
        in fields: [String: JSONValue],
        path: String
    ) throws -> [String: JSONValue] {
        guard let value = fields[key] else { throw CloudflareProviderFailure.missingField(path) }
        guard case .object(let object) = value else { throw CloudflareProviderFailure.invalidField(path) }
        return object
    }

    private func array(_ key: String, in fields: [String: JSONValue], path: String) throws -> [JSONValue] {
        guard let value = fields[key] else { throw CloudflareProviderFailure.missingField(path) }
        guard case .array(let array) = value else { throw CloudflareProviderFailure.invalidField(path) }
        return array
    }

    private func requiredString(
        _ key: String,
        in fields: [String: JSONValue],
        path: String
    ) throws -> String {
        guard let value = fields[key] else { throw CloudflareProviderFailure.missingField(path) }
        guard let string = value.stringValue, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudflareProviderFailure.invalidField(path)
        }
        return string
    }
}

private enum CloudflareProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case invalidRoot
    case missingField(String)
    case invalidField(String)
    case unknownValue(path: String, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidRoot: "Cloudflare summary must be a JSON object."
        case .missingField(let path): "Cloudflare summary is missing '\(path)'."
        case .invalidField(let path): "Cloudflare summary field '\(path)' has an invalid type or value."
        case .unknownValue(let path, let value): "Cloudflare value '\(value)' at '\(path)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .invalidRoot: .invalidResponse(message: errorDescription ?? "Invalid Cloudflare response.")
        case .missingField(let path): .missingField(name: path)
        case .invalidField(let path): .invalidResponse(message: errorDescription ?? "Invalid field \(path).")
        case .unknownValue(let path, let value): .unrecognizedStatus(field: path, value: value)
        }
    }
}
