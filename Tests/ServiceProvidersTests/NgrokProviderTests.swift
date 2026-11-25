import Foundation
import Testing
@testable import StatusPageMonitor

@Test func ngrokRecognizesExactOperationalText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = NgrokStatusProvider(transport: NgrokFixtureTransport(response: fixture("ngrok-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func ngrokMapsNonOperationalTextToMajorOutage() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = NgrokStatusProvider(transport: NgrokFixtureTransport(response: fixture("ngrok-non-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .partialOutage, activeIncidents: [], observedAt: date)))
}

@Test func ngrokMapsKnownMaintenanceText() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = NgrokStatusProvider(transport: NgrokFixtureTransport(response: fixture("ngrok-maintenance")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .maintenance, activeIncidents: [], observedAt: date)))
}

@Test func ngrokFailsWhenStatusTextIsMissingOrBlank() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let missing = NgrokStatusProvider(transport: NgrokFixtureTransport(response: fixture("ngrok-missing-status")))
    let blank = NgrokStatusProvider(transport: NgrokFixtureTransport(response: fixture("ngrok-blank-status")))
    let unknown = NgrokStatusProvider(transport: NgrokFixtureTransport(response: fixture("ngrok-unknown-status")))
    #expect(await missing.check(at: date) == .failed(CheckFailure(reason: .missingField(name: ".page-status h2.status"), attemptedAt: date)))
    #expect(await blank.check(at: date) == .failed(CheckFailure(reason: .missingField(name: ".page-status h2.status"), attemptedAt: date)))
    #expect(await unknown.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: ".page-status h2.status", value: "Service state changed"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: NgrokTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://status.ngrok.com/")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "text/html", body: try! Data(contentsOf: url))
}

private struct NgrokFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class NgrokTestBundleAnchor: NSObject {}
