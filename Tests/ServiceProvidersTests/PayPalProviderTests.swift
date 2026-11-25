import Foundation
import Testing
@testable import StatusPageMonitor

@Test func paypalTreatsAnEmptyEventListAsOperational() async {
    let date = Date(timeIntervalSince1970: 1_750_000_000)
    let provider = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func paypalReportsOnlyOpenProductionEventsWithinTheirDateWindow() async {
    let date = Date(timeIntervalSince1970: 1_750_000_000)
    let provider = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-active-events")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let event = observation.activeIncidents.first else {
        Issue.record("The active PayPal production event was not returned.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(observation.activeIncidents.count == 1)
    #expect(event.title == "Production payments are delayed")
    #expect(event.summary == "Production payments are delayed")
    #expect(event.startedAt == Date(timeIntervalSince1970: 1_735_689_600))
}

@Test func paypalIgnoresResolvedFutureAndEndedEvents() async {
    let date = Date(timeIntervalSince1970: 1_750_000_000)
    let provider = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-inactive-events")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func paypalAppliesInclusiveStartAndEndBoundaries() async {
    let date = Date(timeIntervalSince1970: 1_750_000_000)
    let provider = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-boundary-event")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result else {
        Issue.record("The PayPal boundary event should be an observation.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(observation.activeIncidents.count == 1)
}

@Test func paypalFailsOnMissingRequiredEventData() async {
    let date = Date(timeIntervalSince1970: 1_750_000_000)
    let missingResult = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-missing-result")))
    let missingEnvironment = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-missing-environment")))
    let missingSummary = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-missing-summary")))
    #expect(await missingResult.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "/result"), attemptedAt: date)))
    #expect(await missingEnvironment.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "/result/0/environment"), attemptedAt: date)))
    #expect(await missingSummary.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "/result/0/summary"), attemptedAt: date)))
}

@Test func paypalFailsOnInvalidDatesAndMalformedJSON() async {
    let date = Date(timeIntervalSince1970: 1_750_000_000)
    let invalidDate = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-invalid-date")))
    let malformed = PayPalStatusProvider(transport: PayPalFixtureTransport(response: fixture("paypal-malformed")))
    #expect(await invalidDate.check(at: date) == .failed(CheckFailure(reason: .invalidResponse(message: "PayPal events field '/result/0/startDate' has an invalid type or value."), attemptedAt: date)))
    #expect(await malformed.check(at: date) == .failed(CheckFailure(reason: .invalidResponse(message: "The endpoint did not return valid JSON."), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: PayPalTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "json")!
    let endpoint = URL(string: "https://paypal-status.com/api/v1/events?s=true")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "application/json", body: try! Data(contentsOf: url))
}

private struct PayPalFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class PayPalTestBundleAnchor: NSObject {}
