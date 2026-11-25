import Foundation

struct PayPalStatusProvider: StatusProvider {
    private static let eventsURL = URL(string: "https://paypal-status.com/api/v1/events?s=true")!
    private static let operationalMessage = "All Production Systems Operational"

    private let transport: any HTTPTransport

    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .paypal)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.eventsURL)
            let document = try JSONResponseParser.parse(response.body)
            guard case .object(let root) = document else { throw PayPalProviderFailure.invalidRoot }
            let events = try eventArray(in: root)
            let activeEvents = try activeProductionEvents(in: events, at: date)

            guard !activeEvents.isEmpty else {
                return .observed(
                    ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)
                )
            }

            return .observed(
                ServiceObservation(
                    condition: .partialOutage,
                    activeIncidents: activeEvents,
                    observedAt: date
                )
            )
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func eventArray(in root: [String: JSONValue]) throws -> [JSONValue] {
        guard let value = root["result"] else { throw PayPalProviderFailure.missingField("/result") }
        guard case .array(let events) = value else { throw PayPalProviderFailure.invalidField("/result") }
        return events
    }

    private func activeProductionEvents(in events: [JSONValue], at date: Date) throws -> [ServiceIncident] {
        try events.enumerated().compactMap { index, value -> ServiceIncident? in
            let path = "/result/\(index)"
            guard case .object(let event) = value else {
                throw PayPalProviderFailure.invalidField(path)
            }

            let environment = try requiredString("environment", in: event, path: "\(path)/environment")
            guard environment == "production" else { return nil }

            let state = try requiredString("state", in: event, path: "\(path)/state")
            guard state == "open" else { return nil }

            let startDate = try optionalDate("startDate", in: event, path: "\(path)/startDate")
            let endDate = try optionalDate("endDate", in: event, path: "\(path)/endDate")
            let hasStarted = startDate.map { $0 <= date } ?? true
            let hasNotEnded = endDate.map { $0 >= date } ?? true
            guard hasStarted && hasNotEnded else { return nil }

            let summary = try requiredString("summary", in: event, path: "\(path)/summary")
            return ServiceIncident(
                id: nil,
                title: summary,
                status: nil,
                impact: nil,
                summary: summary,
                url: nil,
                startedAt: startDate,
                updatedAt: nil
            )
        }
    }

    private func requiredString(
        _ key: String,
        in event: [String: JSONValue],
        path: String
    ) throws -> String {
        guard let value = event[key] else { throw PayPalProviderFailure.missingField(path) }
        guard case .string(let string) = value,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PayPalProviderFailure.invalidField(path)
        }
        return string
    }

    /// Parses the ISO date forms returned by the PayPal events endpoint.
    private func optionalDate(
        _ key: String,
        in event: [String: JSONValue],
        path: String
    ) throws -> Date? {
        guard let value = event[key] else { return nil }
        switch value {
        case .null:
            return nil
        case .string(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard let date = parseISODate(trimmed) else { throw PayPalProviderFailure.invalidField(path) }
            return date
        default:
            throw PayPalProviderFailure.invalidField(path)
        }
    }

    private func parseISODate(_ value: String) -> Date? {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = timestampFormatter.date(from: value) { return date }

        timestampFormatter.formatOptions = [.withInternetDateTime]
        if let date = timestampFormatter.date(from: value) { return date }

        timestampFormatter.formatOptions = [.withFullDate]
        return timestampFormatter.date(from: value)
    }
}

private enum PayPalProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case invalidRoot
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .invalidRoot: "PayPal events response must be a JSON object."
        case .missingField(let path): "PayPal events response is missing '\(path)'."
        case .invalidField(let path): "PayPal events field '\(path)' has an invalid type or value."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .invalidRoot: .invalidResponse(message: errorDescription ?? "Invalid PayPal response.")
        case .missingField(let path): .missingField(name: path)
        case .invalidField(let path): .invalidResponse(message: errorDescription ?? "Invalid field \(path).")
        }
    }
}
