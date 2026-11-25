import Foundation
import Testing
@testable import StatusPageMonitor

@Test func bigCommerceMapsTheOperationalBodyClass() async {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = BigCommerceStatusProvider(
        transport: BigCommerceFixtureTransport(response: fixture("bigcommerce-operational"))
    )

    #expect(
        await provider.check(at: attemptedAt)
            == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: attemptedAt))
    )
}

@Test func bigCommerceMapsAnIncidentAndItsBodyClass() async {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = BigCommerceStatusProvider(
        transport: BigCommerceFixtureTransport(response: fixture("bigcommerce-active-incident"))
    )
    let result = await provider.check(at: attemptedAt)

    guard case .observed(let observation) = result,
          let incident = observation.activeIncidents.first else {
        Issue.record("The BigCommerce incident fixture did not produce an observation.")
        return
    }

    #expect(observation.condition == .majorOutage)
    #expect(observation.activeIncidents.count == 1)
    #expect(incident.title == "Storefront availability is degraded")
    #expect(observation.observedAt == attemptedAt)
}

@Test func bigCommerceMapsScheduledMaintenanceSeparatelyFromAnOutage() async {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = BigCommerceStatusProvider(
        transport: BigCommerceFixtureTransport(response: fixture("bigcommerce-maintenance"))
    )

    #expect(
        await provider.check(at: attemptedAt)
            == .observed(ServiceObservation(condition: .maintenance, activeIncidents: [], observedAt: attemptedAt))
    )
}

@Test func bigCommerceUnknownOrMissingBodyStatusFailsTheCheck() async {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let unknownProvider = BigCommerceStatusProvider(
        transport: BigCommerceFixtureTransport(response: fixture("bigcommerce-unknown-status"))
    )
    let missingProvider = BigCommerceStatusProvider(
        transport: BigCommerceFixtureTransport(response: fixture("bigcommerce-missing-status"))
    )

    #expect(
        await unknownProvider.check(at: attemptedAt)
            == .failed(
                CheckFailure(
                    reason: .unrecognizedStatus(field: "body.status-class", value: "investigating"),
                    attemptedAt: attemptedAt
                )
            )
    )
    #expect(
        await missingProvider.check(at: attemptedAt)
            == .failed(
                CheckFailure(reason: .missingField(name: "body.status-class"), attemptedAt: attemptedAt)
            )
    )
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: BigCommerceTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "html")!
    let endpoint = URL(string: "https://status.bigcommerce.com/")!
    return HTTPResponse(
        statusCode: 200,
        finalURL: endpoint,
        mimeType: "text/html",
        body: try! Data(contentsOf: url)
    )
}

private struct BigCommerceFixtureTransport: HTTPTransport {
    let response: HTTPResponse

    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class BigCommerceTestBundleAnchor: NSObject {}
