import Foundation
import Testing
@testable import StatusPageMonitor

@Test func builtInCatalogContainsAllSixteenServicesInSourceOrder() {
    #expect(BuiltInServiceCatalog.definitions.map(\.id) == [
        .aircall,
        .bigcommerce,
        .canva,
        .cloudflare,
        .cloudways,
        .github,
        .hubspot,
        .mongodb,
        .monday,
        .ngrok,
        .openai,
        .register,
        .paypal,
        .slack,
        .stripe,
        .vercel
    ])
}

@Test func builtInCatalogUsesTheApprovedStatusPageURLs() {
    let actual = Dictionary(uniqueKeysWithValues: BuiltInServiceCatalog.definitions.map {
        ($0.id, $0.statusPageURL.absoluteString)
    })

    #expect(actual == [
        .aircall: "https://status.aircall.com/",
        .bigcommerce: "https://status.bigcommerce.com/",
        .canva: "https://www.canvastatus.com/",
        .cloudflare: "https://www.cloudflarestatus.com/",
        .cloudways: "https://status.cloudways.com/",
        .github: "https://www.githubstatus.com/",
        .hubspot: "https://status.hubspot.com/",
        .mongodb: "https://status.mongodb.com/",
        .monday: "https://status.monday.com/",
        .ngrok: "https://status.ngrok.com/",
        .openai: "https://status.openai.com/",
        .register: "https://status.register.it/",
        .paypal: "https://paypal-status.com/product/production",
        .slack: "https://slack-status.com/",
        .stripe: "https://www.stripestatus.com/",
        .vercel: "https://www.vercel-status.com/"
    ])
}

@Test func catalogDefinitionsHaveAttributionAndHTTPSStatusPages() {
    #expect(BuiltInServiceCatalog.definitions.allSatisfy { definition in
        definition.statusPageURL.scheme == "https"
            && definition.statusPageURL.host != nil
            && !definition.displayName.isEmpty
            && !definition.attribution.publisherName.isEmpty
    })
}

@Test func providerResultsKeepObservationsAndCheckFailuresSeparate() {
    let timestamp = Date(timeIntervalSince1970: 1_000)
    let observation = ServiceObservation(
        condition: .operational,
        activeIncidents: [],
        observedAt: timestamp
    )
    let observedResult = ProviderCheckResult.observed(observation)
    let failedResult = ProviderCheckResult.failed(
        CheckFailure(reason: .network(message: "DNS lookup failed"), attemptedAt: timestamp)
    )

    if case .observed(let actualObservation) = observedResult {
        #expect(actualObservation == observation)
    } else {
        Issue.record("A valid observation was represented as a failed check.")
    }

    if case .failed(let failure) = failedResult {
        #expect(failure.reason == .network(message: "DNS lookup failed"))
        #expect(failure.attemptedAt == timestamp)
    } else {
        Issue.record("A network failure was represented as a service observation.")
    }
}

@Test func observationCanCarryActiveIncidentDetails() {
    let incident = ServiceIncident(
        id: "incident-17",
        title: "API requests are delayed",
        status: .investigating,
        impact: .major,
        summary: "Some API requests are taking longer than usual.",
        url: URL(string: "https://status.example.com/incidents/17"),
        startedAt: Date(timeIntervalSince1970: 1_000),
        updatedAt: Date(timeIntervalSince1970: 1_100)
    )
    let observation = ServiceObservation(
        condition: .degradedPerformance,
        activeIncidents: [incident],
        observedAt: Date(timeIntervalSince1970: 1_200)
    )

    #expect(observation.activeIncidents == [incident])
}

@Test func missingAndUnrecognizedStatusDataHaveExplicitFailureReasons() {
    #expect(CheckFailureReason.missingField(name: "status") != .invalidResponse(message: ""))
    #expect(
        CheckFailureReason.unrecognizedStatus(field: "status", value: "purple")
            != .invalidResponse(message: "")
    )
}

@Test func providerProtocolCanBeImplementedWithoutChangingTheResultContract() async {
    guard let definition = BuiltInServiceCatalog.definition(for: .aircall) else {
        Issue.record("The built-in catalog is missing Aircall.")
        return
    }

    let provider = StubStatusProvider(definition: definition)
    let timestamp = Date(timeIntervalSince1970: 2_000)

    #expect(provider.definition.id == .aircall)

    let result = await provider.check(at: timestamp)
    if case .failed(let failure) = result {
        #expect(failure.reason == .invalidResponse(message: "Fixture response"))
        #expect(failure.attemptedAt == timestamp)
    } else {
        Issue.record("The fixture provider did not return its typed check result.")
    }
}

private struct StubStatusProvider: StatusProvider {
    let definition: ServiceDefinition

    func check(at date: Date) async -> ProviderCheckResult {
        .failed(
            CheckFailure(reason: .invalidResponse(message: "Fixture response"), attemptedAt: date)
        )
    }
}

@Test func serviceIDsAcceptValidatedCommunitySlugs() {
    #expect(ServiceID(rawValue: "community-status")?.rawValue == "community-status")
    #expect(ServiceID(rawValue: "aircall") == .aircall)
}

@Test func serviceIDsRejectMalformedValuesDuringConstructionAndDecoding() {
    let invalidIDs = ["", "Uppercase", "two words", "-leading", "trailing-"]

    #expect(invalidIDs.allSatisfy { ServiceID(rawValue: $0) == nil })

    let data = Data(#""Uppercase""#.utf8)
    let decodedID = try? JSONDecoder().decode(ServiceID.self, from: data)
    #expect(decodedID == nil)
}
