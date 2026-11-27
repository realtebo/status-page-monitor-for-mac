import Foundation
import Testing
@testable import StatusPageMonitor

@Suite struct CloudflareProviderTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: ["cloudflare-operational", "cloudflare-component-outage", "cloudflare-maintenance", "cloudflare-services-group-maintenance"])
    func noActiveIncidentsMeansOperational(_ name: String) async {
        let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture(name)))
        #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
    }

    @Test func menuShowsOnlyActiveIncidentTitles() async {
        let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-active-incident")))
        guard case .observed(let result) = await provider.check(at: date) else {
            Issue.record("Expected an observation from the unresolved incidents endpoint.")
            return
        }
        #expect(!result.isOperational)
        #expect(result.activeIncidents.map(\.title) == ["Workers event subscriptions", "Dashboard access", "API latency"])
        #expect(result.activeIncidents.map(\.status) == [.identified, .investigating, .monitoring])
        #expect(result.activeIncidents.first?.summary == "A fix is being implemented.")
    }

    @Test func reportsUnknownIncidentStatusAsCheckFailure() async {
        let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: fixture("cloudflare-unknown-status")))
        #expect(await provider.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "/incidents/0/status", value: "unexpected"), attemptedAt: date)))
    }

    @Test func missingListIsACheckFailure() async {
        let response = HTTPResponse(statusCode: 200, finalURL: URL(string: "https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json")!, mimeType: "application/json", body: Data("{}".utf8))
        let provider = CloudflareStatusProvider(transport: CloudflareFixtureTransport(response: response))
        #expect(await provider.check(at: date) == .failed(CheckFailure(reason: .missingField(name: "/incidents"), attemptedAt: date)))
    }
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: CloudflareTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "json")!
    let endpoint = URL(string: "https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json")!
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
