import Foundation
import SwiftSoup

struct VercelStatusProvider: StatusProvider {
    private static let statusPageURL = URL(string: "https://www.vercel-status.com/")!
    private static let statusSelector = ".page-status h2.status"
    private static let incidentTitleSelector = ".unresolved-incidents .unresolved-incident .incident-title .actual-title"
    private static let conditions: [String: ServiceCondition] = [
        "All Systems Operational": .operational,
        "Degraded Performance": .degradedPerformance,
        "Partial Outage": .partialOutage,
        "Major Outage": .majorOutage,
        "Maintenance": .maintenance
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .vercel)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.statusPageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let incidentElements = try HTMLStatusPageParser.matchingElements(Self.incidentTitleSelector, in: document)
            if let incidentTitle = try firstNonemptyText(in: incidentElements, selector: Self.incidentTitleSelector) {
                let incident = ServiceIncident(
                    id: nil,
                    title: incidentTitle,
                    status: nil,
                    impact: nil,
                    summary: nil,
                    url: nil,
                    startedAt: nil,
                    updatedAt: nil
                )
                return .observed(
                    ServiceObservation(condition: .partialOutage, activeIncidents: [incident], observedAt: date)
                )
            }

            let statusElements = try HTMLStatusPageParser.matchingElements(Self.statusSelector, in: document)
            guard let statusElement = statusElements.first else {
                throw HTMLParsingFailure.noMatchingElement(Self.statusSelector)
            }
            let statusText = try HTMLStatusPageParser.text(of: statusElement, selectedBy: Self.statusSelector)
            guard let condition = Self.conditions[statusText] else {
                throw VercelProviderFailure.unknownStatusText(statusText)
            }
            return .observed(ServiceObservation(condition: condition, activeIncidents: [], observedAt: date))
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func firstNonemptyText(in elements: [Element], selector: String) throws -> String? {
        guard let element = elements.first else { return nil }
        let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

private enum VercelProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case unknownStatusText(String)

    var errorDescription: String? {
        switch self {
        case .unknownStatusText(let value): "Vercel status text '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .unknownStatusText(let value): .unrecognizedStatus(field: ".page-status h2.status", value: value)
        }
    }
}
