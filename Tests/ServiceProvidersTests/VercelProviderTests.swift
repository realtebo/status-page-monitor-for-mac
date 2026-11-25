import Foundation
import Testing
@testable import StatusPageMonitor

@Test func vercelRecognizesExactOperationalStatusText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = VercelStatusProvider(transport: VercelFixtureTransport(response: fixture("vercel-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func vercelPrioritizesTheFirstActiveIncidentTitle() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = VercelStatusProvider(transport: VercelFixtureTransport(response: fixture("vercel-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The unresolved Vercel incident was not returned.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(observation.activeIncidents.count == 1)
    #expect(incident.title == "Builds are delayed in iad1")
}

@Test func vercelMapsKnownDegradedStatusText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = VercelStatusProvider(transport: VercelFixtureTransport(response: fixture("vercel-degraded")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .degradedPerformance, activeIncidents: [], observedAt: date)))
}

@Test func vercelRejectsMissingBlankOrUnknownStatusText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let missing = VercelStatusProvider(transport: VercelFixtureTransport(response: fixture("vercel-missing-status")))
    let blank = VercelStatusProvider(transport: VercelFixtureTransport(response: fixture("vercel-blank-status")))
    let unknown = VercelStatusProvider(transport: VercelFixtureTransport(response: fixture("vercel-unknown-status")))
    #expect(await missing.check(at: date) == .failed(CheckFailure(reason: .missingField(name: ".page-status h2.status"), attemptedAt: date)))
    #expect(await blank.check(at: date) == .failed(CheckFailure(reason: .missingField(name: ".page-status h2.status"), attemptedAt: date)))
    #expect(await unknown.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: ".page-status h2.status", value: "Service state changed"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: VercelTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://www.vercel-status.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct VercelFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class VercelTestBundleAnchor: NSObject {}
