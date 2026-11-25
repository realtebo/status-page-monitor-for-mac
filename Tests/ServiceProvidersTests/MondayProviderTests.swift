import Foundation
import Testing
@testable import StatusPageMonitor

@Test func mondayMapsTheExactOperationalStatusText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = MondayStatusProvider(transport: MondayFixtureTransport(response: fixture("monday-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func mondayPrioritizesAnActiveIncidentOverTheSummaryText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = MondayStatusProvider(transport: MondayFixtureTransport(response: fixture("monday-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The Monday incident was not returned.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(incident.title == "API latency is elevated")
}

@Test func mondayMapsScheduledMaintenance() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = MondayStatusProvider(transport: MondayFixtureTransport(response: fixture("monday-maintenance")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .maintenance, activeIncidents: [], observedAt: date)))
}

@Test func mondayRejectsMissingOrUnknownStatusText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let missing = MondayStatusProvider(transport: MondayFixtureTransport(response: fixture("monday-missing-status")))
    let unknown = MondayStatusProvider(transport: MondayFixtureTransport(response: fixture("monday-unknown-status")))
    #expect(await missing.check(at: date) == .failed(CheckFailure(reason: .missingField(name: ".page-status .status"), attemptedAt: date)))
    #expect(await unknown.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: ".page-status .status", value: "Service state changed"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: MondayTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://status.monday.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct MondayFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class MondayTestBundleAnchor: NSObject {}
