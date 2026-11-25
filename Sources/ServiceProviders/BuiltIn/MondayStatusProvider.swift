import Foundation
import SwiftSoup

struct MondayStatusProvider: StatusProvider {
    private static let pageURL = URL(string: "https://status.monday.com/")!
    private static let statusSelector = ".page-status .status"
    private static let incidentSelector = ".unresolved-incidents .unresolved-incident .incident-title .actual-title"
    private static let conditions: [String: ServiceCondition] = [
        "All Systems Operational": .operational,
        "Scheduled Maintenance": .maintenance,
        "Degraded Performance": .degradedPerformance,
        "Partial Outage": .partialOutage,
        "Major Outage": .majorOutage,
        "Critical Outage": .majorOutage
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .monday)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.pageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let incidents = try HTMLStatusPageParser.matchingElements(Self.incidentSelector, in: document).map { element in
                ServiceIncident(
                    id: nil,
                    title: try HTMLStatusPageParser.text(of: element, selectedBy: Self.incidentSelector),
                    status: nil,
                    impact: nil,
                    summary: nil,
                    url: nil,
                    startedAt: nil,
                    updatedAt: nil
                )
            }
            if !incidents.isEmpty {
                return .observed(
                    ServiceObservation(condition: .partialOutage, activeIncidents: incidents, observedAt: date)
                )
            }

            let statusElement = try HTMLStatusPageParser.exactlyOneElement(Self.statusSelector, in: document)
            let statusText = try HTMLStatusPageParser.text(of: statusElement, selectedBy: Self.statusSelector)
            guard let condition = Self.conditions[statusText] else {
                throw MondayProviderFailure.unknownStatusText(statusText)
            }
            return .observed(ServiceObservation(condition: condition, activeIncidents: [], observedAt: date))
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }
}

private enum MondayProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case unknownStatusText(String)

    var errorDescription: String? {
        switch self {
        case .unknownStatusText(let value): "Monday status text '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .unknownStatusText(let value): .unrecognizedStatus(field: ".page-status .status", value: value)
        }
    }
}
