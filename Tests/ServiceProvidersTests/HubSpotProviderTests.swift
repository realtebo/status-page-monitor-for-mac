import Foundation
import Testing
@testable import StatusPageMonitor

@Test func hubspotMapsOperationalStatusClass() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = HubSpotStatusProvider(transport: HubSpotFixtureTransport(response: fixture("hubspot-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func hubspotPrioritizesAnOpenIncident() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = HubSpotStatusProvider(transport: HubSpotFixtureTransport(response: fixture("hubspot-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The HubSpot incident was not returned.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(incident.title == "Email delivery is delayed")
}

@Test func hubspotUsesKnownStatusTextWhenTheBodyClassIsMissing() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = HubSpotStatusProvider(transport: HubSpotFixtureTransport(response: fixture("hubspot-text-fallback")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func hubspotRejectsUnknownStatusTextOrIndicator() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let unknownText = HubSpotStatusProvider(transport: HubSpotFixtureTransport(response: fixture("hubspot-unknown-status")))
    let unknownIndicator = HubSpotStatusProvider(transport: HubSpotFixtureTransport(response: fixture("hubspot-unknown-indicator")))
    #expect(await unknownText.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: ".page-status .status", value: "Service state changed"), attemptedAt: date)))
    #expect(await unknownIndicator.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "body.status-class", value: "investigating"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: HubSpotTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://status.hubspot.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct HubSpotFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class HubSpotTestBundleAnchor: NSObject {}
