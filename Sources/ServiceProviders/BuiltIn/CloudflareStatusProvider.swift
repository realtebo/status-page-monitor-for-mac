import Foundation

struct CloudflareStatusProvider: StatusProvider {
    private static let incidentsURL = URL(string: "https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json")!
    private static let incidentStatuses: [String: IncidentStatus] = [
        "investigating": .investigating,
        "identified": .identified,
        "monitoring": .monitoring
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .cloudflare)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.incidentsURL)
            let document = try JSONResponseParser.parse(response.body)
            guard case .object(let root) = document else { throw CloudflareProviderFailure.invalidRoot }

            let incidents = try activeIncidents(in: root)
            let condition: ServiceCondition
            if incidents.contains(where: { $0.impact == .major || $0.impact == .critical }) {
                condition = .majorOutage
            } else if incidents.contains(where: { $0.impact == .minor }) {
                condition = .degradedPerformance
            } else {
                condition = .operational
            }
            return .observed(
                ServiceObservation(
                    condition: condition,
                    activeIncidents: incidents,
                    observedAt: date
                )
            )
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func activeIncidents(in root: [String: JSONValue]) throws -> [ServiceIncident] {
        let values = try array("incidents", in: root, path: "/incidents")
        return try values.enumerated().compactMap { index, value in
            let path = "/incidents/\(index)"
            guard case .object(let fields) = value else { throw CloudflareProviderFailure.invalidField(path) }
            let lifecycle = try requiredString("status", in: fields, path: "\(path)/status")
            if ["resolved", "postmortem", "scheduled", "in_progress", "verifying", "completed"].contains(lifecycle) { return nil }
            guard let incidentStatus = Self.incidentStatuses[lifecycle] else {
                throw CloudflareProviderFailure.unknownValue(path: "\(path)/status", value: lifecycle)
            }
            let title = try requiredString("name", in: fields, path: "\(path)/name")
            let sourceImpact = try requiredString("impact", in: fields, path: "\(path)/impact")
            let impact = try mappedImpact(sourceImpact, path: "\(path)/impact")
            guard impact != .maintenance else { return nil }

            return ServiceIncident(
                id: fields["id"]?.stringValue,
                title: title,
                status: incidentStatus,
                impact: impact,
                summary: firstIncidentUpdateBody(fields["incident_updates"]),
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
        case .invalidRoot: "Cloudflare incidents response must be a JSON object."
        case .missingField(let path): "Cloudflare incidents response is missing '\(path)'."
        case .invalidField(let path): "Cloudflare incidents response field '\(path)' has an invalid type or value."
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
