import Foundation

struct JSONManifestStatusProvider: StatusProvider {
    private let manifest: ProviderManifest
    private let check: JSONProviderCheck
    private let transport: any HTTPTransport

    var definition: ServiceDefinition { manifest.service }

    init(manifestData: Data, transport: any HTTPTransport) throws {
        try self.init(manifest: ProviderManifestDecoder.decode(manifestData), transport: transport)
    }

    init(manifest: ProviderManifest, transport: any HTTPTransport) throws {
        guard case .json(let check) = manifest.check else {
            throw JSONManifestEvaluationFailure.requiresJSONCheck
        }

        self.manifest = manifest
        self.check = check
        self.transport = transport
    }

    func check(at date: Date) async -> ProviderCheckResult {
        let response: HTTPResponse
        do {
            response = try await transport.get(check.requestURL)
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(
                CheckFailure(
                    reason: .network(message: error.localizedDescription),
                    attemptedAt: date
                )
            )
        }

        do {
            let document = try JSONResponseParser.parse(response.body)
            let condition = try mappedValue(
                check.condition,
                in: document,
                field: "check.json.condition"
            )
            let incidents = try activeIncidents(from: check.incidents, in: document)

            return .observed(
                ServiceObservation(
                    condition: condition,
                    activeIncidents: incidents,
                    observedAt: date
                )
            )
        } catch let failure as any ProviderFailure {
            return .failed(failure.checkFailure(at: date))
        } catch {
            return .failed(
                CheckFailure(
                    reason: .invalidResponse(message: error.localizedDescription),
                    attemptedAt: date
                )
            )
        }
    }

    private func activeIncidents(
        from collection: JSONIncidentCollection?,
        in document: JSONValue
    ) throws -> [ServiceIncident] {
        guard let collection else { return [] }

        let field = "check.json.incidents.pointer (\(collection.pointer.rawValue))"
        guard let value = collection.pointer.value(in: document) else {
            throw JSONManifestEvaluationFailure.missingField(field)
        }
        guard case .array(let values) = value else {
            throw JSONManifestEvaluationFailure.invalidField(field)
        }

        return try values.enumerated().compactMap { index, value in
            if try isTerminalIncident(value, collection: collection, index: index) {
                return nil
            }
            return try activeIncident(from: value, collection: collection, index: index)
        }
    }

    private func isTerminalIncident(
        _ value: JSONValue,
        collection: JSONIncidentCollection,
        index: Int
    ) throws -> Bool {
        guard let statusMapping = collection.status else { return false }
        let status = try requiredString(
            at: statusMapping.pointer,
            in: value,
            field: "check.json.incidents[\(index)].status"
        )

        return status == "resolved" || status == "completed"
    }

    private func activeIncident(
        from value: JSONValue,
        collection: JSONIncidentCollection,
        index: Int
    ) throws -> ServiceIncident {
        let prefix = "check.json.incidents[\(index)]"
        let id = try optionalString(
            at: collection.idPointer,
            in: value,
            field: "\(prefix).idPointer"
        )
        let title = try requiredString(
            at: collection.titlePointer,
            in: value,
            field: "\(prefix).titlePointer"
        )
        let status = try optionalMappedValue(
            collection.status,
            in: value,
            field: "\(prefix).status"
        )
        let impact = try optionalMappedValue(
            collection.impact,
            in: value,
            field: "\(prefix).impact"
        )
        let summary = try optionalString(
            at: collection.summaryPointer,
            in: value,
            field: "\(prefix).summaryPointer"
        )
        let url = try incidentURL(
            at: collection.urlPointer,
            in: value,
            field: "\(prefix).urlPointer"
        )
        let startedAt = try incidentDate(
            at: collection.startedAtPointer,
            in: value,
            field: "\(prefix).startedAtPointer"
        )
        let updatedAt = try incidentDate(
            at: collection.updatedAtPointer,
            in: value,
            field: "\(prefix).updatedAtPointer"
        )

        return ServiceIncident(
            id: id,
            title: title,
            status: status,
            impact: impact,
            summary: summary,
            url: url,
            startedAt: startedAt,
            updatedAt: updatedAt
        )
    }

    private func mappedValue<Value: Equatable & Sendable>(
        _ mapping: JSONValueMapping<Value>,
        in document: JSONValue,
        field: String
    ) throws -> Value {
        let sourceValue = try requiredString(
            at: mapping.pointer,
            in: document,
            field: "\(field).pointer (\(mapping.pointer.rawValue))"
        )
        guard let mappedValue = mapping.values[sourceValue] else {
            throw JSONManifestEvaluationFailure.unrecognizedStatus(
                field: mapping.pointer.rawValue,
                value: sourceValue
            )
        }

        return mappedValue
    }

    private func optionalMappedValue<Value: Equatable & Sendable>(
        _ mapping: JSONValueMapping<Value>?,
        in document: JSONValue,
        field: String
    ) throws -> Value? {
        guard let mapping else { return nil }
        return try mappedValue(mapping, in: document, field: field)
    }

    private func requiredString(
        at pointer: JSONPointer,
        in document: JSONValue,
        field: String
    ) throws -> String {
        guard let value = pointer.value(in: document) else {
            throw JSONManifestEvaluationFailure.missingField(field)
        }
        guard let string = value.stringValue else {
            throw JSONManifestEvaluationFailure.invalidField(field)
        }
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JSONManifestEvaluationFailure.invalidField(field)
        }

        return string
    }

    private func optionalString(
        at pointer: JSONPointer?,
        in document: JSONValue,
        field: String
    ) throws -> String? {
        guard let pointer else { return nil }
        return try requiredString(at: pointer, in: document, field: field)
    }

    private func incidentURL(
        at pointer: JSONPointer?,
        in document: JSONValue,
        field: String
    ) throws -> URL? {
        guard let rawURL = try optionalString(at: pointer, in: document, field: field) else { return nil }
        guard let url = URL(string: rawURL), ProviderURLPolicy.isAllowedHTTPSURL(url) else {
            throw JSONManifestEvaluationFailure.invalidField(field)
        }

        return url
    }

    private func incidentDate(
        at pointer: JSONPointer?,
        in document: JSONValue,
        field: String
    ) throws -> Date? {
        guard let rawDate = try optionalString(at: pointer, in: document, field: field) else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: rawDate) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: rawDate) else {
            throw JSONManifestEvaluationFailure.invalidField(field)
        }

        return date
    }
}

private enum JSONManifestEvaluationFailure: Error, Equatable, LocalizedError, ProviderFailure, Sendable {
    case requiresJSONCheck
    case missingField(String)
    case invalidField(String)
    case unrecognizedStatus(field: String, value: String)

    var errorDescription: String? {
        switch self {
        case .requiresJSONCheck:
            return "This provider requires a JSON manifest check."
        case .missingField(let field):
            return "The response is missing required field '\(field)'."
        case .invalidField(let field):
            return "The response field '\(field)' has an invalid value or type."
        case .unrecognizedStatus(let field, let value):
            return "The status value '\(value)' at '\(field)' is not mapped by the manifest."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .requiresJSONCheck:
            return .invalidDefinition(message: errorDescription ?? "A JSON check is required.")
        case .missingField(let field):
            return .missingField(name: field)
        case .invalidField(let field):
            return .invalidResponse(message: errorDescription ?? "Invalid response field '\(field)'.")
        case .unrecognizedStatus(let field, let value):
            return .unrecognizedStatus(field: field, value: value)
        }
    }
}
