import Foundation

struct ServiceID: Codable, Hashable, Identifiable, RawRepresentable, Sendable {
    let rawValue: String
    var id: String { rawValue }

    init?(rawValue: String) {
        let bytes = Array(rawValue.utf8)
        guard bytes.count <= 64,
              let first = bytes.first,
              let last = bytes.last,
              Self.isLowercaseASCII(first),
              Self.isLowercaseASCII(last) || Self.isDigit(last),
              bytes.allSatisfy({ Self.isLowercaseASCII($0) || Self.isDigit($0) || $0 == 45 }) else {
            return nil
        }

        self.rawValue = rawValue
    }

    private init(validatedRawValue: String) {
        rawValue = validatedRawValue
    }

    static let aircall = Self(validatedRawValue: "aircall")
    static let bigcommerce = Self(validatedRawValue: "bigcommerce")
    static let canva = Self(validatedRawValue: "canva")
    static let cloudflare = Self(validatedRawValue: "cloudflare")
    static let cloudways = Self(validatedRawValue: "cloudways")
    static let github = Self(validatedRawValue: "github")
    static let hubspot = Self(validatedRawValue: "hubspot")
    static let mongodb = Self(validatedRawValue: "mongodb")
    static let monday = Self(validatedRawValue: "monday")
    static let ngrok = Self(validatedRawValue: "ngrok")
    static let openai = Self(validatedRawValue: "openai")
    static let register = Self(validatedRawValue: "register")
    static let paypal = Self(validatedRawValue: "paypal")
    static let slack = Self(validatedRawValue: "slack")
    static let stripe = Self(validatedRawValue: "stripe")
    static let vercel = Self(validatedRawValue: "vercel")

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let serviceID = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Service ids must be lowercase ASCII slugs of at most 64 characters."
            )
        }

        self = serviceID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func isLowercaseASCII(_ byte: UInt8) -> Bool {
        (97...122).contains(byte)
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        (48...57).contains(byte)
    }
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
    let status: IncidentStatus?
    let impact: IncidentImpact?
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
