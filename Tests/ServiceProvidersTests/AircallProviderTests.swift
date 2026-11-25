import Foundation
import Testing
@testable import StatusPageMonitor

@Test func aircallManifestMapsAnOperationalSummary() async throws {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = try aircallProvider(using: "aircall-operational")
    let result = await provider.check(at: attemptedAt)

    #expect(
        result == .observed(
            ServiceObservation(condition: .operational, activeIncidents: [], observedAt: attemptedAt)
        )
    )
}

@Test func aircallManifestMapsActiveIncidentDetails() async throws {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = try aircallProvider(using: "aircall-active-incident")
    let result = await provider.check(at: attemptedAt)

    guard case .observed(let observation) = result,
          let incident = observation.activeIncidents.first else {
        Issue.record("The active Aircall incident was not returned as an observation.")
        return
    }

    #expect(observation.condition == .majorOutage)
    #expect(observation.activeIncidents.count == 1)
    #expect(incident.id == "incident-001")
    #expect(incident.title == "AI Voice Agent calls are delayed")
    #expect(incident.status == .investigating)
    #expect(incident.impact == .critical)
    #expect(incident.summary == "We are investigating delayed responses and interrupted calls.")
    #expect(incident.url?.absoluteString == "https://status.aircall.com/incidents/incident-001")
    #expect(incident.startedAt == iso8601("2026-11-18T16:00:00.000Z"))
    #expect(incident.updatedAt == iso8601("2026-11-18T16:55:00.000Z"))
    #expect(observation.observedAt == attemptedAt)
}

@Test func aircallManifestOmitsResolvedAndCompletedIncidents() async throws {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = try aircallProvider(using: "aircall-resolved-incident")
    let result = await provider.check(at: attemptedAt)

    #expect(
        result == .observed(
            ServiceObservation(condition: .operational, activeIncidents: [], observedAt: attemptedAt)
        )
    )
}

@Test func aircallUnknownIndicatorFailsInsteadOfAssumingAnOperationalState() async throws {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = try aircallProvider(using: "aircall-unknown-indicator")
    let result = await provider.check(at: attemptedAt)

    #expect(
        result == .failed(
            CheckFailure(
                reason: .unrecognizedStatus(field: "/status/indicator", value: "maintenance-mode"),
                attemptedAt: attemptedAt
            )
        )
    )
}

@Test func aircallMalformedJSONIsAProviderFailure() async throws {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = try aircallProvider(using: "aircall-malformed")
    let result = await provider.check(at: attemptedAt)

    #expect(
        result == .failed(
            CheckFailure(
                reason: .invalidResponse(message: "The endpoint did not return valid JSON."),
                attemptedAt: attemptedAt
            )
        )
    )
}

private func aircallProvider(using fixtureName: String) throws -> JSONManifestStatusProvider {
    let bundle = Bundle(for: ProviderTestBundleAnchor.self)
    let manifestData = try bundledJSON(named: "aircall", in: bundle)
    let responseData = try bundledJSON(named: fixtureName, in: bundle)
    let endpoint = URL(string: "https://status.aircall.com/api/v2/summary.json")!
    let response = HTTPResponse(
        statusCode: 200,
        finalURL: endpoint,
        mimeType: "application/json",
        body: responseData
    )

    return try JSONManifestStatusProvider(
        manifestData: manifestData,
        transport: FixtureHTTPTransport(expectedURL: endpoint, response: response)
    )
}

private func bundledJSON(named name: String, in bundle: Bundle) throws -> Data {
    guard let url = bundle.url(forResource: name, withExtension: "json") else {
        throw ProviderFixtureError.missingResource(name)
    }
    return try Data(contentsOf: url)
}

private func iso8601(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date
    }

    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

private struct FixtureHTTPTransport: HTTPTransport {
    let expectedURL: URL
    let response: HTTPResponse

    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == expectedURL else {
            throw HTTPTransportFailure.invalidEndpoint
        }
        return response
    }
}

private final class ProviderTestBundleAnchor: NSObject {}

private enum ProviderFixtureError: Error {
    case missingResource(String)
}
