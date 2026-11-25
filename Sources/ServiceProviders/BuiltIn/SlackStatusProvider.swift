import Foundation
import SwiftSoup

struct SlackStatusProvider: StatusProvider {
    private static let statusPageURL = URL(string: "https://slack-status.com/")!
    private static let statusSelector = "h1.text-center"
    private static let operationalText = "Slack is up and running"

    private let transport: any HTTPTransport
    var definition: ServiceDefinition { BuiltInServiceCatalog.definition(for: .slack)! }

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
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(CheckFailure(reason: .invalidResponse(message: error.localizedDescription), attemptedAt: date))
        }
    }
}
