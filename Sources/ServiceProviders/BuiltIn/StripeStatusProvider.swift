import Foundation
import SwiftSoup

struct StripeStatusProvider: StatusProvider {
    private static let statusPageURL = URL(string: "https://www.stripestatus.com/")!
    private static let allClearText = "All systems operational"
    private static let allClearIncidentPhrase = "Active incidents All systems operational"
    private static let allClearSelector = ".unresolved-incidents .all-clear"
    private static let summarySelector = ".status-summary, .components-status, body"
    private static let incidentTitleSelector = ".unresolved-incidents .unresolved-incident .incident-title .actual-title"

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .stripe)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.statusPageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let body = try HTMLStatusPageParser.exactlyOneElement("body", in: document)
            let bodyText = try HTMLStatusPageParser.text(of: body, selectedBy: "body")
            let normalizedBodyText = Self.normalizeWhitespace(bodyText).lowercased()

            let allClear = try Self.firstText(Self.allClearSelector, in: document)
            let summaryText = try Self.firstText(Self.summarySelector, in: document) ?? ""
            let firstIncidentTitle = try Self.firstText(Self.incidentTitleSelector, in: document) ?? ""
            let hasIncident = !firstIncidentTitle.isEmpty

            let hasAllSystemsMessage = normalizedBodyText.contains(Self.allClearText.lowercased())
            let summarizedAllClear = summaryText.lowercased().contains(Self.allClearText.lowercased())
            let activeIncidentsButAllClear = normalizedBodyText.contains(Self.allClearIncidentPhrase.lowercased())

            // Preserve the VS Code checker's exact Boolean rule, including its all-clear precedence.
            let isOperational = hasAllSystemsMessage
                || (!hasIncident && !(allClear ?? "").isEmpty)
                || (!hasIncident && summarizedAllClear)
                || activeIncidentsButAllClear

            if isOperational {
                return .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date))
            }

            guard hasIncident else {
                let diagnostic = summaryText.isEmpty ? bodyText : summaryText
                throw StripeProviderFailure.unrecognizedStatus(Self.diagnosticValue(diagnostic))
            }

            let incident = ServiceIncident(
                id: nil,
                title: firstIncidentTitle,
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
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }

    private static func firstText(_ selector: String, in document: Document) throws -> String? {
        guard let element = try HTMLStatusPageParser.matchingElements(selector, in: document).first else {
            return nil
        }

        do {
            return try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw HTMLParsingFailure.malformedDocument
        }
    }

    private static func normalizeWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func diagnosticValue(_ value: String) -> String {
        let normalized = normalizeWhitespace(value)
        return String(normalized.prefix(160))
    }
}

private enum StripeProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case unrecognizedStatus(String)

    var errorDescription: String? {
        switch self {
        case .unrecognizedStatus(let value): "Stripe status page has no recognized all-clear text or incident title ('\(value)')."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .unrecognizedStatus(let value): .unrecognizedStatus(field: "Stripe status summary", value: value)
        }
    }
}
