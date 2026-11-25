import Foundation
import Testing
@testable import StatusPageMonitor

@Test func mongodbMapsAnOperationalSummary() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = MongoDBStatusProvider(transport: MongoDBFixtureTransport(response: fixture("mongodb-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func mongodbTreatsOnlyNullResolvedAtAsActive() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let active = MongoDBStatusProvider(transport: MongoDBFixtureTransport(response: fixture("mongodb-active-incident")))
    let resolved = MongoDBStatusProvider(transport: MongoDBFixtureTransport(response: fixture("mongodb-resolved-incident")))
    let activeResult = await active.check(at: date)
    guard case .observed(let observation) = activeResult, let incident = observation.activeIncidents.first else {
        Issue.record("The active MongoDB incident was not returned.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(incident.title == "Atlas connectivity delays")
    #expect(await resolved.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func mongodbRejectsMissingResolutionField() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = MongoDBStatusProvider(transport: MongoDBFixtureTransport(response: fixture("mongodb-missing-resolution")))
    #expect(await provider.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "/incidents/0/resolved_at"), attemptedAt: date)))
}

@Test func mongodbRejectsUnknownIndicatorAndMalformedJSON() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let unknown = MongoDBStatusProvider(transport: MongoDBFixtureTransport(response: fixture("mongodb-unknown-indicator")))
    let malformed = MongoDBStatusProvider(transport: MongoDBFixtureTransport(response: fixture("mongodb-malformed")))
    #expect(await unknown.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "/status/indicator", value: "maintenance-mode"), attemptedAt: date)))
    #expect(await malformed.check(at: date) == .failed(CheckFailure(reason: .invalidResponse(message: "The endpoint did not return valid JSON."), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: MongoDBTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "json")!
    let endpoint = URL(string: "https://status.mongodb.com/api/v2/summary.json")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "application/json", body: try! Data(contentsOf: url))
}

private struct MongoDBFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class MongoDBTestBundleAnchor: NSObject {}
