import Foundation
import Testing
@testable import StatusPageMonitor

@Test func openAIRecognizesOnlyTheExactOperationalBanner() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = OpenAIStatusProvider(transport: OpenAIFixtureTransport(response: fixture("openai-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func openAIMapsKnownIssueBannerToAnActiveIssue() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = OpenAIStatusProvider(transport: OpenAIFixtureTransport(response: fixture("openai-active-issue")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The known OpenAI issue banner was not returned as an active issue.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(incident.title == "We’re currently experiencing issues")
}

@Test func openAIUsesTheFirstMatchingBannerLikeTheSourceChecker() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = OpenAIStatusProvider(transport: OpenAIFixtureTransport(response: fixture("openai-first-banner")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func openAIFailsWhenTheBannerIsMissingBlankOrUnrecognized() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let missing = OpenAIStatusProvider(transport: OpenAIFixtureTransport(response: fixture("openai-missing-banner")))
    let blank = OpenAIStatusProvider(transport: OpenAIFixtureTransport(response: fixture("openai-blank-banner")))
    let unknown = OpenAIStatusProvider(transport: OpenAIFixtureTransport(response: fixture("openai-unknown-banner")))
    #expect(await missing.check(at: date) == .failed(CheckFailure(reason: .missingField(name: #"[data-testid="heads-up"] > div > div:first-child"#), attemptedAt: date)))
    #expect(await blank.check(at: date) == .failed(CheckFailure(reason: .missingField(name: #"[data-testid="heads-up"] > div > div:first-child"#), attemptedAt: date)))
    #expect(await unknown.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: #"[data-testid="heads-up"] > div > div:first-child"#, value: "Status text changed"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: OpenAITestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://status.openai.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct OpenAIFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class OpenAITestBundleAnchor: NSObject {}
