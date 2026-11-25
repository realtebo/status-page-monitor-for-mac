import Foundation
import SwiftSoup

struct BigCommerceStatusProvider: StatusProvider {
    private static let statusPageURL = URL(string: "https://status.bigcommerce.com/")!
    private static let incidentTitleSelector = ".unresolved-incidents .unresolved-incident .incident-title .actual-title"
    private static let statusClassPrefix = "status-"
    private static let conditions: [String: ServiceCondition] = [
        "none": .operational,
        "maintenance": .maintenance,
        "minor": .degradedPerformance,
        "major": .majorOutage,
        "critical": .majorOutage
    ]

    private let transport: any HTTPTransport

    var definition: ServiceDefinition {
        BuiltInServiceCatalog.definition(for: .bigcommerce)!
    }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.statusPageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let condition = try overallCondition(in: document)
            let incidents = try activeIncidents(in: document)

            return .observed(
                ServiceObservation(condition: condition, activeIncidents: incidents, observedAt: date)
            )
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(
                CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date)
            )
        }
    }

    private func overallCondition(in document: Document) throws -> ServiceCondition {
        let body = try HTMLStatusPageParser.exactlyOneElement("body", in: document)
        let classes = try HTMLStatusPageParser.attribute(named: "class", of: body, selectedBy: "body")
        guard let statusClass = classes.split(whereSeparator: \.isWhitespace).first(where: {
            $0.hasPrefix(Self.statusClassPrefix) && $0 != "status" && $0 != "status-index"
        }) else {
            throw BigCommerceProviderFailure.missingStatusClass
        }

        let indicator = String(statusClass.dropFirst(Self.statusClassPrefix.count))
        guard let condition = Self.conditions[indicator] else {
            throw BigCommerceProviderFailure.unrecognizedIndicator(indicator)
        }

        return condition
    }

    private func activeIncidents(in document: Document) throws -> [ServiceIncident] {
        try HTMLStatusPageParser.matchingElements(Self.incidentTitleSelector, in: document).map { element in
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

private enum BigCommerceProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case missingStatusClass
    case unrecognizedIndicator(String)

    var errorDescription: String? {
        switch self {
        case .missingStatusClass:
            "BigCommerce status class was not found on the page body."
        case .unrecognizedIndicator(let value):
            "BigCommerce status indicator '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .missingStatusClass:
            .missingField(name: "body.status-class")
        case .unrecognizedIndicator(let value):
            .unrecognizedStatus(field: "body.status-class", value: value)
        }
    }
}
