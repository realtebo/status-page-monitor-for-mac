import Foundation
import Testing
@testable import StatusPageMonitor

@Test func canvaMapsAnOperationalSummary() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CanvaStatusProvider(transport: CanvaFixtureTransport(response: fixture("canva-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func canvaMapsActiveIncidentsAndOmitsResolvedRecords() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CanvaStatusProvider(transport: CanvaFixtureTransport(response: fixture("canva-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The active Canva incident did not produce an observation.")
        return
    }
    #expect(observation.condition == .operational)
    #expect(observation.activeIncidents.count == 1)
    #expect(incident.title == "Uploads are delayed")
    #expect(incident.status == .investigating)
    #expect(incident.impact == .major)
}

@Test func canvaMapsOngoingScheduledMaintenance() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CanvaStatusProvider(transport: CanvaFixtureTransport(response: fixture("canva-maintenance")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let maintenance = observation.activeIncidents.first else {
        Issue.record("The active Canva maintenance did not produce an observation.")
        return
    }
    #expect(observation.condition == .maintenance)
    #expect(maintenance.title == "Planned editor maintenance")
    #expect(maintenance.impact == .maintenance)
}

@Test func canvaRejectsUnknownIndicator() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = CanvaStatusProvider(transport: CanvaFixtureTransport(response: fixture("canva-unknown-indicator")))
    #expect(await provider.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "/status/indicator", value: "maintenance-mode"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: CanvaTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "json")!
    let endpoint = URL(string: "https://www.canvastatus.com/api/v2/summary.json")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "application/json", body: try! Data(contentsOf: url))
}

private struct CanvaFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class CanvaTestBundleAnchor: NSObject {}
