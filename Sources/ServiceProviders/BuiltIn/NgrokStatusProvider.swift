import Foundation
import SwiftSoup

struct NgrokStatusProvider: StatusProvider {
    private static let statusPageURL = URL(string: "https://status.ngrok.com/")!
    private static let statusSelector = ".page-status h2.status"
    private static let knownConditions: [String: ServiceCondition] = [
        "Partial System Outage": .partialOutage,
        "Major System Outage": .majorOutage,
        "Degraded Performance": .degradedPerformance,
        "Scheduled Maintenance": .maintenance
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .ngrok)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.statusPageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let statusElement = try HTMLStatusPageParser.exactlyOneElement(Self.statusSelector, in: document)
            let statusText = try HTMLStatusPageParser.text(of: statusElement, selectedBy: Self.statusSelector)

            if statusText == "All Systems Operational" {
                return .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date))
            }
            guard let condition = Self.knownConditions[statusText] else {
                throw NgrokProviderFailure.unknownStatusText(statusText)
            }
            return .observed(ServiceObservation(condition: condition, activeIncidents: [], observedAt: date))
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }
}

private enum NgrokProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case unknownStatusText(String)

    var errorDescription: String? {
        switch self {
        case .unknownStatusText(let value): "ngrok status text '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .unknownStatusText(let value): .unrecognizedStatus(field: ".page-status h2.status", value: value)
        }
    }
}
