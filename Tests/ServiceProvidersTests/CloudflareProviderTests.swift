import Foundation
import Testing
@testable import StatusPageMonitor

@Test func cloudflareMapsAnOperationalSummary() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func cloudflareKeepsAnOpenIncidentVisibleEvenWhenTheIndicatorIsNone() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The Cloudflare incident was not returned.")
        return
    }
    #expect(observation.condition == .operational)
    #expect(observation.activeIncidents.count == 1)
    #expect(incident.title == "Dashboard access is degraded")
    #expect(incident.summary == "We are investigating dashboard access issues.")
}

@Test func cloudflareMapsOngoingMaintenance() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-maintenance")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let maintenance = observation.activeIncidents.first else {
        Issue.record("The Cloudflare maintenance was not returned.")
        return
    }
    #expect(observation.condition == .maintenance)
    #expect(maintenance.impact == .maintenance)
}

@Test func cloudflareMapsADegradedComponent() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-component-outage")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result else {
        Issue.record("A degraded component should produce an observation.")
        return
    }
    #expect(observation.condition == .degradedPerformance)
    #expect(observation.activeIncidents.first?.title == "Edge Network: major outage")
}

@Test func cloudflareRejectsAnUnknownOverallIndicator() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-unknown-status")))
    #expect(await provider.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "/status/indicator", value: "investigating"), attemptedAt: date)))
}

@Test func cloudflareKeepsTheSpecialServicesGroupMaintenanceDegraded() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-services-group-maintenance")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result else {
        Issue.record("The special Cloudflare group state should produce an observation.")
        return
    }
    #expect(observation.condition == .degradedPerformance)
    #expect(observation.activeIncidents.first?.title == "Cloudflare Sites and Services: under maintenance")
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: CloudflareTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "json")!
    let endpoint = URL(string: "https://www.cloudflarestatus.com/api/v2/summary.json")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "application/json", body: try! Data(contentsOf: url))
}

private struct CloudflareFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class CloudflareTestBundleAnchor: NSObject {}
