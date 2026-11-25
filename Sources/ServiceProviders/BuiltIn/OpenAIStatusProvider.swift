import Foundation
import SwiftSoup

struct OpenAIStatusProvider: StatusProvider {
    private static let statusPageURL = URL(string: "https://status.openai.com/")!
    private static let statusSelector = #"[data-testid="heads-up"] > div > div:first-child"#
    private static let operationalText = "We’re fully operational"
    private static let issueText = "We’re currently experiencing issues"

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .openai)! }

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        do {
            let response = try await transport.get(Self.statusPageURL)
            let document = try HTMLStatusPageParser.parse(response.body, baseURL: response.finalURL)
            let elements = try HTMLStatusPageParser.matchingElements(Self.statusSelector, in: document)
            guard let statusElement = elements.first else {
                throw HTMLParsingFailure.noMatchingElement(Self.statusSelector)
            }
            let statusText = try HTMLStatusPageParser.text(of: statusElement, selectedBy: Self.statusSelector)

            if statusText == Self.operationalText {
                return .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date))
            }

            if statusText == Self.issueText {
                let issue = ServiceIncident(
                    id: nil,
                    title: statusText,
                    status: nil,
                    impact: nil,
                    summary: nil,
                    url: nil,
                    startedAt: nil,
                    updatedAt: nil
                )
                return .observed(
                    ServiceObservation(condition: .partialOutage, activeIncidents: [issue], observedAt: date)
                )
            }

            throw OpenAIProviderFailure.unknownStatusText(statusText)
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }
}

private enum OpenAIProviderFailure: Error, LocalizedError, ProviderFailure, Sendable {
    case unknownStatusText(String)

    var errorDescription: String? {
        switch self {
        case .unknownStatusText(let value): "OpenAI status text '\(value)' is not mapped."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .unknownStatusText(let value): .unrecognizedStatus(field: Self.statusSelectorPath, value: value)
        }
    }

    private static let statusSelectorPath = #"[data-testid="heads-up"] > div > div:first-child"#
}
