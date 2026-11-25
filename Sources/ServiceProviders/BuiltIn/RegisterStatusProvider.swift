import Foundation
import SwiftSoup

struct RegisterStatusProvider: StatusProvider {
    private static let statusPageURL = URL(string: "https://status.register.it/")!
    private static let statusSelector = ".page-status .status"
    private static let incidentSelector = ".unresolved-incident"
    private static let statusPrefix = "status-"
    private static let conditionsByIndicator: [String: ServiceCondition] = [
        "none": .operational,
        "maintenance": .maintenance,
        "minor": .degradedPerformance,
        "major": .majorOutage,
        "critical": .majorOutage
    ]
    private static let labelsByIndicator: [String: String] = [
        "none": "All Systems Operational",
        "maintenance": "Scheduled Maintenance",
        "minor": "Minor Service Outage",
        "major": "Major Service Outage",
        "critical": "Critical Service Outage"
    ]
    private static let conditionsByLabel: [String: ServiceCondition] = [
        "All Systems Operational": .operational,
        "Scheduled Maintenance": .maintenance,
        "Minor Service Outage": .degradedPerformance,
        "Major Service Outage": .majorOutage,
        "Critical Service Outage": .majorOutage
    ]

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .register)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.statusPageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let indicator = try statusIndicator(in: document)
            let statusText = try firstText(Self.statusSelector, in: document)
            let fallbackMessage = statusText ?? indicator.flatMap { Self.labelsByIndicator[$0] }

            let incidents = try HTMLStatusPageParser.matchingElements(Self.incidentSelector, in: document)
            let nonMaintenanceIncident = try incidents.first { try !isMaintenance($0) }
            let maintenanceIncident = try incidents.first { try isMaintenance($0) }

            if let incident = nonMaintenanceIncident {
                let title = try incidentTitle(incident) ?? fallbackMessage
                guard let title else { throw RegisterStatusProviderFailure.missingIncidentTitle }
                let currentCondition = try? condition(indicator: indicator, statusText: statusText)
                let issueCondition = currentCondition.flatMap {
                    $0 == .operational || $0 == .maintenance ? nil : $0
                } ?? .partialOutage
                return .observed(
                    ServiceObservation(
                        condition: issueCondition,
                        activeIncidents: [makeIncident(title: title)],
                        observedAt: date,
                        providerReportsHealthy: false
                    )
                )
            }

            if let incident = maintenanceIncident {
                let title = try incidentTitle(incident) ?? fallbackMessage
                guard let title else { throw RegisterStatusProviderFailure.missingIncidentTitle }
                return .observed(
                    ServiceObservation(
                        condition: .maintenance,
                        activeIncidents: [makeIncident(title: title, maintenance: true)],
                        observedAt: date,
                        providerReportsHealthy: true
                    )
                )
            }

            return .observed(
                ServiceObservation(
                    condition: try condition(indicator: indicator, statusText: statusText),
                    activeIncidents: [],
                    observedAt: date,
                    providerReportsHealthy: isHealthyStatus(indicator: indicator, statusText: statusText)
                )
            )
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(
                CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date)
            )
        }
    }

    private func statusIndicator(in document: Document) throws -> String? {
        guard let body = try HTMLStatusPageParser.matchingElements("body", in: document).first else {
            throw RegisterStatusProviderFailure.missingBody
        }
        let classes = body.hasAttr("class")
            ? try HTMLStatusPageParser.attribute(named: "class", of: body, selectedBy: "body")
            : ""
        return classes.split(whereSeparator: \.isWhitespace).first {
            $0.hasPrefix(Self.statusPrefix) && $0 != "status-index"
        }.map { String($0.dropFirst(Self.statusPrefix.count)) }
    }

    private func condition(indicator: String?, statusText: String?) throws -> ServiceCondition {
        if let indicator {
            guard let condition = Self.conditionsByIndicator[indicator] else {
                throw RegisterStatusProviderFailure.unknownIndicator(indicator)
            }
            return condition
        }

        guard let statusText else { throw RegisterStatusProviderFailure.missingStatus }
        guard let condition = Self.conditionsByLabel[statusText] else {
            throw RegisterStatusProviderFailure.unknownStatusText(statusText)
        }
        return condition
    }

    private func isHealthyStatus(indicator: String?, statusText: String?) -> Bool {
        if let indicator {
            return indicator == "none" || indicator == "maintenance"
        }
        return statusText == "All Systems Operational"
    }

    private func firstText(_ selector: String, in document: Document) throws -> String? {
        guard let element = try HTMLStatusPageParser.matchingElements(selector, in: document).first else {
            return nil
        }
        return try? HTMLStatusPageParser.text(of: element, selectedBy: selector)
    }

    private func isMaintenance(_ incident: Element) throws -> Bool {
        if incident.hasClass("impact-maintenance") { return true }
        return try incident.select(".impact-maintenance").first() != nil
    }

    private func incidentTitle(_ incident: Element) throws -> String? {
        for selector in [
            ".incident-title .actual-title",
            ".incident-title",
            ".incident-title a"
        ] {
            guard let element = try incident.select(selector).first(),
                  let title = try? HTMLStatusPageParser.text(of: element, selectedBy: selector) else { continue }
            return title
        }
        return nil
    }

    private func makeIncident(title: String, maintenance: Bool = false) -> ServiceIncident {
        ServiceIncident(
            id: nil,
            title: title,
            status: nil,
            impact: maintenance ? .maintenance : nil,
            summary: nil,
            url: nil,
            startedAt: nil,
            updatedAt: nil
        )
    }

}

private enum RegisterStatusProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case missingBody
    case missingStatus
    case missingIncidentTitle
    case unknownIndicator(String)
    case unknownStatusText(String)

    var errorDescription: String? {
        switch self {
        case .missingBody: "Register.it status page has no body element."
        case .missingStatus: "Register.it status page has neither a status class nor status text."
        case .missingIncidentTitle: "Register.it has an unresolved incident without a readable title or status label."
        case .unknownIndicator(let value): "Register.it status indicator '\(value)' is not mapped."
        case .unknownStatusText(let value): "Register.it status text '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .missingBody: .missingField(name: "body")
        case .missingStatus: .missingField(name: "body.status-* or .page-status .status")
        case .missingIncidentTitle: .missingField(name: ".unresolved-incident .incident-title")
        case .unknownIndicator(let value): .unrecognizedStatus(field: "body.status-*", value: value)
        case .unknownStatusText(let value): .unrecognizedStatus(field: ".page-status .status", value: value)
        }
    }
}
