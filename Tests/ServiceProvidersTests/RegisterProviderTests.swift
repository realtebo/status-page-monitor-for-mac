import Foundation
import Testing
@testable import StatusPageMonitor

@Test func registerMapsOperationalStatusClass() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func registerUsesStatusTextWhenBodyIndicatorIsAbsent() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-text-fallback")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func registerMapsScheduledMaintenanceAndKeepsItsIncident() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let classProvider = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-class-maintenance")))
    let incidentProvider = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-maintenance-incident")))
    #expect(await classProvider.check(at: date) == .observed(ServiceObservation(condition: .maintenance, activeIncidents: [], observedAt: date)))

    let result = await incidentProvider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The scheduled Register.it maintenance was not returned.")
        return
    }
    #expect(observation.condition == .maintenance)
    #expect(incident.title == "Network maintenance window")
    #expect(incident.impact == .maintenance)
}

@Test func registerPrefersNonMaintenanceIncidentOverMaintenance() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The Register.it service incident was not returned.")
        return
    }
    #expect(observation.condition == .partialOutage)
    #expect(incident.title == "Email delivery is delayed")
    #expect(observation.activeIncidents.count == 1)
}

@Test func registerFailsForUnknownIndicatorTextAndMissingStatus() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let unknownIndicator = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-unknown-indicator")))
    let unknownText = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-unknown-text")))
    let missing = RegisterStatusProvider(transport: RegisterFixtureTransport(response: fixture("register-missing-status")))
    #expect(await unknownIndicator.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "body.status-*", value: "warming-up"), attemptedAt: date)))
    #expect(await unknownText.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: ".page-status .status", value: "Systems are being checked"), attemptedAt: date)))
    #expect(await missing.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "body.status-* or .page-status .status"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: RegisterTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://status.register.it/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct RegisterFixtureTransport: HTTPTransport {
    let response: HTTPResponse

    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class RegisterTestBundleAnchor: NSObject {}
