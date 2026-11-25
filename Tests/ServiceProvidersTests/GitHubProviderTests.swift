import Foundation
import Testing
@testable import StatusPageMonitor

@Test func githubMapsOperationalSummary() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = GitHubStatusProvider(transport: GitHubFixtureTransport(response: fixture("github-operational")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func githubMapsActiveIncidentAndOmitsItsResolvedRecord() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = GitHubStatusProvider(transport: GitHubFixtureTransport(response: fixture("github-active-incident")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let incident = observation.activeIncidents.first else {
        Issue.record("The GitHub incident was not returned.")
        return
    }
    #expect(observation.condition == .operational)
    #expect(observation.activeIncidents.count == 1)
    #expect(incident.title == "Git operations are delayed")
    #expect(incident.status == .investigating)
    #expect(incident.summary == "We are investigating delayed Git operations.")
}

@Test func githubMapsScheduledMaintenance() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = GitHubStatusProvider(transport: GitHubFixtureTransport(response: fixture("github-maintenance")))
    let result = await provider.check(at: date)
    guard case .observed(let observation) = result, let maintenance = observation.activeIncidents.first else {
        Issue.record("The GitHub maintenance was not returned.")
        return
    }
    #expect(observation.condition == .maintenance)
    #expect(maintenance.impact == .maintenance)
}

@Test func githubOmitsResolvedAndCompletedRecords() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = GitHubStatusProvider(transport: GitHubFixtureTransport(response: fixture("github-resolved-items")))
    #expect(await provider.check(at: date) == .observed(ServiceObservation(condition: .operational, activeIncidents: [], observedAt: date)))
}

@Test func githubRejectsAnUnknownIndicator() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let provider = GitHubStatusProvider(transport: GitHubFixtureTransport(response: fixture("github-unknown-indicator")))
    #expect(await provider.check(at: date) == .failed(CheckFailure(reason: .unrecognizedStatus(field: "/status/indicator", value: "maintenance-mode"), attemptedAt: date)))
}

private func fixture(_ name: String) -> HTTPResponse {
    let bundle = Bundle(for: GitHubTestBundleAnchor.self)
    let url = bundle.url(forResource: name, withExtension: "json")!
    let endpoint = URL(string: "https://www.githubstatus.com/api/v2/summary.json")!
    return HTTPResponse(statusCode: 200, finalURL: endpoint, mimeType: "application/json", body: try! Data(contentsOf: url))
}

private struct GitHubFixtureTransport: HTTPTransport {
    let response: HTTPResponse
    func get(_ url: URL) async throws -> HTTPResponse {
        guard url == response.finalURL else { throw HTTPTransportFailure.invalidEndpoint }
        return response
    }
}

private final class GitHubTestBundleAnchor: NSObject {}
