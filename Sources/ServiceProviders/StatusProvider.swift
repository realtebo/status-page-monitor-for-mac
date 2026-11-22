import Foundation

enum ServiceID: String, CaseIterable, Codable, Sendable, Identifiable {
    case aircall
    case bigcommerce
    case canva
    case cloudflare
    case cloudways
    case github
    case hubspot
    case mongodb
    case monday
    case ngrok
    case openai
    case register
    case paypal
    case slack
    case stripe
    case vercel

    var id: String { rawValue }
}

struct ProviderAttribution: Codable, Equatable, Sendable {
    let publisherName: String
}

struct ServiceDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: ServiceID
    let displayName: String
    let statusPageURL: URL
    let attribution: ProviderAttribution
}

enum ServiceCondition: String, CaseIterable, Codable, Sendable {
    case operational
    case degradedPerformance
    case partialOutage
    case majorOutage
    case maintenance
}

enum IncidentStatus: String, CaseIterable, Codable, Sendable {
    case investigating
    case identified
    case monitoring
    case scheduled
    case inProgress
    case verifying
}

enum IncidentImpact: String, CaseIterable, Codable, Sendable {
    case none
    case minor
    case major
    case critical
    case maintenance
}

struct ServiceIncident: Codable, Equatable, Sendable {
    /// The status page's stable identifier, when it provides one.
    let id: String?
    let title: String
    let status: IncidentStatus
    let impact: IncidentImpact
    let summary: String?
    let url: URL?
    let startedAt: Date?
    let updatedAt: Date?
}

struct ServiceObservation: Codable, Equatable, Sendable {
    let condition: ServiceCondition
    let activeIncidents: [ServiceIncident]
    let observedAt: Date
}

enum CheckFailureReason: Equatable, Sendable {
    case network(message: String)
    case httpStatus(code: Int)
    case invalidResponse(message: String)
    case missingField(name: String)
    case unrecognizedStatus(field: String, value: String)
    case invalidDefinition(message: String)
}

struct CheckFailure: Equatable, Sendable {
    let reason: CheckFailureReason
    let attemptedAt: Date
}

enum ProviderCheckResult: Equatable, Sendable {
    case observed(ServiceObservation)
    case failed(CheckFailure)
}

protocol StatusProvider: Sendable {
    var definition: ServiceDefinition { get }
    func check(at date: Date) async -> ProviderCheckResult
}
