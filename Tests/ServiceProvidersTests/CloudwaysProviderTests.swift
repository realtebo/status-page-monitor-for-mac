import Foundation
import Testing
@testable import StatusPageMonitor

@Test func cloudwaysMapsOperationalState() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudwaysStatusProvider(transport: CloudwaysFixtureTransport(response: fixture("cloudways-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func cloudwaysMapsActiveIncident() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudwaysStatusProvider(transport: CloudwaysFixtureTransport(response: fixture("cloudways-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The Cloudways incident was not returned.")
        return
    }
    #expect(observation.condition == .majorOutage)
    #expect(incident.title == "Database connectivity is degraded")
}

@Test func cloudwaysMapsMaintenance() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CloudwaysStatusProvider(transport: CloudwaysFixtureTransport(response: fixture("cloudways-maintenance")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .maintenance, activeIncidents: [], observedAt: date)))
}

@Test func cloudwaysUnknownOrMissingIndicatorFailsTheCheck() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let unknown = CloudwaysStatusProvider(transport: CloudwaysFixtureTransport(response: fixture("cloudways-unknown-status")))
    let missing = CloudwaysStatusProvider(transport: CloudwaysFixtureTransport(response: fixture("cloudways-missing-status")))
    #expect(await unknown.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "body.status-class", value: "investigating"), attemptedAt: date)))
    #expect(await missing.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "body.status-class"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: CloudwaysTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://status.cloudways.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct CloudwaysFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class CloudwaysTestBundleAnchor: NSObject {}
