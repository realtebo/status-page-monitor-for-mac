import Foundation
import SwiftSoup

struct CloudwaysStatusProvider: StatusProvider {
    private static let pageURL = URL(string: "https://status.cloudways.com/")!
    private static let incidentSelector = ".unresolved-incidents .unresolved-incident .incident-title .actual-title"
    private static let conditions: [String: ServiceCondition] = [
        "none": .operational,
        "maintenance": .maintenance,
        "minor": .degradedPerformance,
        "major": .majorOutage,
        "critical": .majorOutage
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .cloudways)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.pageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let condition = try overallCondition(in: document)
            let incidents = try activeIncidents(in: document)
            return .observed(ServiceObservation(condition: condition, activeIncidents: incidents, observedAt: date))
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private func overallCondition(in document: Document) throws -> ServiceCondition {
        let body = try HTMLStatusPageParser.exactlyOneElement("body", in: document)
        let classes = try HTMLStatusPageParser.attribute(named: "class", of: body, selectedBy: "body")
        guard let statusClass = classes.split(whereSeparator: \.isWhitespace).first(where: {
            $0.hasPrefix("status-") && $0 != "status-index"
        }) else {
            throw CloudwaysProviderFailure.missingIndicator
        }
        let indicator = String(statusClass.dropFirst("status-".count))
        guard let condition = Self.conditions[indicator] else {
            throw CloudwaysProviderFailure.unknownIndicator(indicator)
        }
        return condition
    }

    private func activeIncidents(in document: Document) throws -> [ServiceIncident] {
        try HTMLStatusPageParser.matchingElements(Self.incidentSelector, in: document).map { title in
            ServiceIncident(
                id: nil,
                title: try HTMLStatusPageParser.text(of: title, selectedBy: Self.incidentSelector),
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

private enum CloudwaysProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case missingIndicator
    case unknownIndicator(String)

    var errorDescription: String? {
        switch self {
        case .missingIndicator: "Cloudways body status class was not found."
        case .unknownIndicator(let value): "Cloudways status indicator '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .missingIndicator: .missingField(name: "body.status-class")
        case .unknownIndicator(let value): .unrecognizedStatus(field: "body.status-class", value: value)
        }
    }
}
