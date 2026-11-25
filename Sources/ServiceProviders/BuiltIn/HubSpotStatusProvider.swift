import Foundation
import SwiftSoup

struct HubSpotStatusProvider: StatusProvider {
    private static let pageURL = URL(string: "https://status.hubspot.com/")!
    private static let statusSelector = ".page-status .status"
    private static let incidentTitleSelector = ".unresolved-incidents .unresolved-incident .incident-title .actual-title"
    private static let incidentFallbackSelector = ".unresolved-incidents .unresolved-incident .incident-title"
    private static let conditions: [String: ServiceCondition] = [
        "none": .operational,
        "maintenance": .maintenance,
        "minor": .degradedPerformance,
        "major": .majorOutage,
        "critical": .majorOutage
    ]
    private static let statusTexts: [String: ServiceCondition] = [
        "All Systems Operational": .operational,
        "Scheduled Maintenance": .maintenance,
        "Minor Service Outage": .degradedPerformance,
        "Major Service Outage": .majorOutage,
        "Critical Service Outage": .majorOutage
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .hubspot)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.pageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let incidents = try activeIncidents(in: document)
            if !incidents.isEmpty {
                return .observed(
                    ServiceObservation(condition: .partialOutage, activeIncidents: incidents, observedAt: date)
                )
            }

            let statusText = try HTMLStatusPageParser.matchingElements(Self.statusSelector, in: document).first.map {
                try HTMLStatusPageParser.text(of: $0, selectedBy: Self.statusSelector)
            }
            let classCondition = try statusClassCondition(in: document)
            let condition: ServiceCondition
            if let classCondition {
                condition = classCondition
            } else if let statusText, let textCondition = Self.statusTexts[statusText] {
                condition = textCondition
            } else if let statusText {
                throw HubSpotProviderFailure.unknownStatusText(statusText)
            } else {
                throw HubSpotProviderFailure.missingStatus
            }

            return .observed(ServiceObservation(condition: condition, activeIncidents: [], observedAt: date))
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func statusClassCondition(in document: Document) throws -> ServiceCondition? {
        guard let body = try HTMLStatusPageParser.matchingElements("body", in: document).first else { return nil }
        guard let classes = try? HTMLStatusPageParser.attribute(named: "class", of: body, selectedBy: "body") else {
            return nil
        }
        guard let token = classes.split(whereSeparator: \.isWhitespace).first(where: {
            $0.hasPrefix("status-") && $0 != "status-index"
        }) else { return nil }
        let value = String(token.dropFirst("status-".count))
        guard let condition = Self.conditions[value] else {
            throw HubSpotProviderFailure.unknownIndicator(value)
        }
        return condition
    }

    private func activeIncidents(in document: Document) throws -> [ServiceIncident] {
        let primary = try HTMLStatusPageParser.matchingElements(Self.incidentTitleSelector, in: document)
        let fallback = primary.isEmpty
            ? try HTMLStatusPageParser.matchingElements(Self.incidentFallbackSelector, in: document)
            : primary
        return try fallback.prefix(1).map { element in
            ServiceIncident(
                id: nil,
                title: try HTMLStatusPageParser.text(of: element, selectedBy: Self.incidentTitleSelector),
                status: nil,
                impact: nil,
                summary: nil,
                url: nil,
                startedAt: nil,
                updatedAt: nil
            )
        }
    }
}

private enum HubSpotProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case missingStatus
    case unknownIndicator(String)
    case unknownStatusText(String)

    var errorDescription: String? {
        switch self {
        case .missingStatus: "HubSpot status class and status text were not found."
        case .unknownIndicator(let value): "HubSpot status indicator '\(value)' is not mapped."
        case .unknownStatusText(let value): "HubSpot status text '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .missingStatus: .missingField(name: "body.status-class or .page-status .status")
        case .unknownIndicator(let value): .unrecognizedStatus(field: "body.status-class", value: value)
        case .unknownStatusText(let value): .unrecognizedStatus(field: ".page-status .status", value: value)
        }
    }
}
