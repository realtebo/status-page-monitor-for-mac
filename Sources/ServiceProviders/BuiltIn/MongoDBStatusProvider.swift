import Foundation

struct MongoDBStatusProvider: StatusProvider {
    private static let summaryURL = URL(string: "https://status.mongodb.com/api/v2/summary.json")!
    private static let conditions: [String: ServiceCondition] = [
        "none": .operational,
        "maintenance": .maintenance,
        "minor": .degradedPerformance,
        "major": .majorOutage,
        "critical": .majorOutage
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .mongodb)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.summaryURL)
            let document = try JSONResponseParser.parse(response.body)
            guard case .object(let root) = document else { throw MongoDBProviderFailure.invalidRoot }
            let status = try object("status", in: root, path: "/status")
            let indicator = try requiredString("indicator", in: status, path: "/status/indicator")
            guard let pageCondition = Self.conditions[indicator] else {
                throw MongoDBProviderFailure.unknownIndicator(indicator)
            }
            let incidents = try activeIncidents(in: root)
            let condition = !incidents.isEmpty && pageCondition == .operational ? .partialOutage : pageCondition
            return .observed(ServiceObservation(condition: condition, activeIncidents: incidents, observedAt: date))
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func activeIncidents(in root: [String: JSONValue]) throws -> [ServiceIncident] {
        guard let value = root["incidents"] else { throw MongoDBProviderFailure.missingField("/incidents") }
        guard case .array(let records) = value else { throw MongoDBProviderFailure.invalidField("/incidents") }
        return try records.enumerated().compactMap { index, record -> ServiceIncident? in
            guard case .object(let fields) = record else {
                throw MongoDBProviderFailure.invalidField("/incidents/\(index)")
            }
            let path = "/incidents/\(index)"
            guard let resolvedAt = fields["resolved_at"] else {
                throw MongoDBProviderFailure.missingField("\(path)/resolved_at")
            }
            switch resolvedAt {
            case .null:
                let title = try requiredString("name", in: fields, path: "\(path)/name")
                return ServiceIncident(
                    id: fields["id"]?.stringValue,
                    title: title,
                    status: nil,
                    impact: nil,
                    summary: nil,
                    url: nil,
                    startedAt: nil,
                    updatedAt: nil
                )
            case .string:
                return nil
            default:
                throw MongoDBProviderFailure.invalidField("\(path)/resolved_at")
            }
        }
    }

    private func object(
        _ key: String,
        in fields: [String: JSONValue],
        path: String
    ) throws -> [String: JSONValue] {
        guard let value = fields[key] else { throw MongoDBProviderFailure.missingField(path) }
        guard case .object(let object) = value else { throw MongoDBProviderFailure.invalidField(path) }
        return object
    }

    private func requiredString(
        _ key: String,
        in fields: [String: JSONValue],
        path: String
    ) throws -> String {
        guard let value = fields[key] else { throw MongoDBProviderFailure.missingField(path) }
        guard let string = value.stringValue, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MongoDBProviderFailure.invalidField(path)
        }
        return string
    }
}

private enum MongoDBProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case invalidRoot
    case missingField(String)
    case invalidField(String)
    case unknownIndicator(String)

    var errorDescription: String? {
        switch self {
        case .invalidRoot: "MongoDB summary must be a JSON object."
        case .missingField(let path): "MongoDB summary is missing '\(path)'."
        case .invalidField(let path): "MongoDB summary field '\(path)' has an invalid type or value."
        case .unknownIndicator(let value): "MongoDB status indicator '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .invalidRoot: .invalidResponse(message: errorDescription ?? "Invalid MongoDB response.")
        case .missingField(let path): .missingField(name: path)
        case .invalidField(let path): .invalidResponse(message: errorDescription ?? "Invalid field \(path).")
        case .unknownIndicator(let value): .unrecognizedStatus(field: "/status/indicator", value: value)
        }
    }
}
