import Foundation
import Testing
@testable import StatusPageMonitor

@Test func stripeRecognizesTheAllClearElementWithoutAnIncidentTitle() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = StripeStatusProvider(transport: StripeFixtureTransport(response: fixture("stripe-all-clear-element")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func stripeUsesTheFirstUnresolvedIncidentTitleWhenNoAllClearSignalExists() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = StripeStatusProvider(transport: StripeFixtureTransport(response: fixture("stripe-active-incidents")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The Stripe unresolved incident did not produce an observation.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(observation.activeIncidents.count == 1)
    #expect(incident.title == "Card authorizations are delayed")
}

@Test func stripePreservesTheSourceCheckAllClearPrecedence() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = StripeStatusProvider(transport: StripeFixtureTransport(response: fixture("stripe-body-all-clear-with-incident")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func stripeFailsWhenItCannotFindAnAllClearSignalOrIncidentTitle() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = StripeStatusProvider(transport: StripeFixtureTransport(response: fixture("stripe-unrecognized-summary")))
    #expect(await provider.check(at: date) == .failed(CheckFailure(
        reason: .unrecognizedStatus(field: "Stripe status summary", value: "Some services may be unavailable"),
        attemptedAt: date
    )))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: StripeTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://www.stripestatus.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct StripeFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class StripeTestBundleAnchor: NSObject {}
