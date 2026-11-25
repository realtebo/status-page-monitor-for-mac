import Foundation
import Testing
@testable import StatusPageMonitor

@Test func slackRecognizesOnlyTheExactOperationalText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = SlackStatusProvider(transport: SlackFixtureTransport(response: fixture("slack-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func slackReadsTheFirstMatchingHeadingLikeTheSourceChecker() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = SlackStatusProvider(transport: SlackFixtureTransport(response: fixture("slack-first-heading")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func slackFailsWhenTheHeadingIsMissingOrBlank() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let missing = SlackStatusProvider(transport: SlackFixtureTransport(response: fixture("slack-missing-heading")))
    let blank = SlackStatusProvider(transport: SlackFixtureTransport(response: fixture("slack-blank-heading")))
    #expect(await missing.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "h1.text-center"), attemptedAt: date)))
    #expect(await blank.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "h1.text-center"), attemptedAt: date)))
}

@Test func slackReportsANonOperationalHeadingAsAnActiveIssue() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = SlackStatusProvider(transport: SlackFixtureTransport(response: fixture("slack-non-operational")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let issue = observation.activeIncidents.first else {
        Issue.record("The non-operational Slack heading was not returned as an active issue.")
        return
    }

    #expect(observation.condition == .partialOutage)
    #expect(issue.title == "Slack is experiencing issues")
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: SlackTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://slack-status.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct SlackFixtureTransport: HTTPTransport {
    let response: HTTPResponse

    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class SlackTestBundleAnchor: NSObject {}
