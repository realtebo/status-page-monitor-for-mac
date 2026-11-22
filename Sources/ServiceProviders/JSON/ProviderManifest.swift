import Foundation
import SwiftSoup

struct ProviderManifest: Equatable, Sendable {
    let service: ServiceDefinition
    let check: ProviderCheckDefinition
}

enum ProviderCheckDefinition: Equatable, Sendable {
    case json(JSONProviderCheck)
    case html(HTMLProviderCheck)
}

struct JSONProviderCheck: Equatable, Sendable {
    let requestURL: URL
    let condition: JSONValueMapping<ServiceCondition>
    let incidents: JSONIncidentCollection?
}

struct JSONIncidentCollection: Equatable, Sendable {
    let pointer: JSONPointer
    let idPointer: JSONPointer?
    let titlePointer: JSONPointer
    let status: JSONValueMapping<IncidentStatus>?
    let impact: JSONValueMapping<IncidentImpact>?
    let summaryPointer: JSONPointer?
    let urlPointer: JSONPointer?
    let startedAtPointer: JSONPointer?
    let updatedAtPointer: JSONPointer?
}

struct JSONValueMapping<Value: Equatable & Sendable>: Equatable, Sendable {
    let pointer: JSONPointer
    let values: [String: Value]
}

struct JSONPointer: Equatable, Hashable, Sendable {
    let rawValue: String
    let tokens: [String]

    init(validating rawValue: String, field: String) throws {
        guard rawValue.utf8.count <= ProviderManifestDecoder.maximumJSONPointerBytes else {
            throw ProviderManifestError.invalidJSONPointer(field: field, value: rawValue)
        }

        guard rawValue.isEmpty || rawValue.hasPrefix("/") else {
            throw ProviderManifestError.invalidJSONPointer(field: field, value: rawValue)
        }

        let parts = rawValue.isEmpty
            ? []
            : rawValue.dropFirst().split(separator: "/", omittingEmptySubsequences: false)

        guard parts.count <= ProviderManifestDecoder.maximumJSONPointerDepth else {
            throw ProviderManifestError.invalidJSONPointer(field: field, value: rawValue)
        }

        var decodedTokens: [String] = []
        decodedTokens.reserveCapacity(parts.count)

        for part in parts {
            var token = ""
            var characters = part.makeIterator()

            while let character = characters.next() {
                guard character == "~" else {
                    token.append(character)
                    continue
                }

                guard let escape = characters.next() else {
                    throw ProviderManifestError.invalidJSONPointer(field: field, value: rawValue)
                }

                switch escape {
                case "0": token.append("~")
                case "1": token.append("/")
                default:
                    throw ProviderManifestError.invalidJSONPointer(field: field, value: rawValue)
                }
            }

            decodedTokens.append(token)
        }

        self.rawValue = rawValue
        tokens = decodedTokens
    }
}

struct HTMLProviderCheck: Equatable, Sendable {
    let requestURL: URL
    let condition: HTMLValueMapping<ServiceCondition>
    let incidents: HTMLIncidentCollection?
}

struct HTMLValueMapping<Value: Equatable & Sendable>: Equatable, Sendable {
    let selector: String
    let source: HTMLValueSource
    let values: [String: Value]
}

enum HTMLValueSource: Equatable, Sendable {
    case text
    case attribute(String)
}

struct HTMLIncidentCollection: Equatable, Sendable {
    let titleSelector: String
    let idAttribute: String?
    let status: HTMLValueMapping<IncidentStatus>?
    let impact: HTMLValueMapping<IncidentImpact>?
    let summarySelector: String?
    let urlAttribute: String?
}

enum ProviderManifestError: Error, Equatable, LocalizedError, Sendable {
    case documentTooLarge(maximumBytes: Int)
    case malformedJSON
    case missingRequiredField(path: String)
    case invalidField(path: String)
    case unknownField(path: String)
    case unsupportedSchemaVersion(Int)
    case invalidServiceID(String)
    case invalidURL(field: String)
    case unsafeURLHost(field: String)
    case unsupportedMethod(String)
    case unsupportedFormat(String)
    case missingFormatDefinition(format: String)
    case unexpectedFormatDefinition(format: String)
    case invalidJSONPointer(field: String, value: String)
    case invalidCSSSelector(field: String)
    case emptyValueMapping(field: String)
    case tooManyMappingValues(field: String, maximum: Int)
    case emptyMappingKey(field: String)
    case unknownMappingValue(field: String, value: String)
    case emptySelector(field: String)
    case unsupportedHTMLValueSource(String)
    case missingHTMLAttributeName(field: String)
    case unexpectedHTMLAttributeName(field: String)
    case invalidAttributeName(field: String)
    case stringTooLong(field: String, maximum: Int)

    var errorDescription: String? {
        switch self {
        case .documentTooLarge(let maximumBytes):
            return "The manifest exceeds the \(maximumBytes)-byte size limit."
        case .malformedJSON:
            return "The manifest is not valid JSON."
        case .missingRequiredField(let path):
            return "Required field '\(path)' is missing."
        case .invalidField(let path):
            return "Field '\(path)' has an invalid value or type."
        case .unknownField(let path):
            return "Field '\(path)' is not supported by schema version 1."
        case .unsupportedSchemaVersion(let version):
            return "Schema version \(version) is not supported; this app supports version 1."
        case .invalidServiceID:
            return "Service ids must be lowercase ASCII slugs of at most 64 characters."
        case .invalidURL(let field):
            return "Field '\(field)' must be an absolute HTTPS URL without user information or a fragment."
        case .unsafeURLHost(let field):
            return "Field '\(field)' must use a public DNS hostname, not an IP literal or local hostname."
        case .unsupportedMethod(let method):
            return "HTTP method '\(method)' is unsupported; provider manifests can use GET only."
        case .unsupportedFormat(let format):
            return "Response format '\(format)' is unsupported; use 'json' or 'html'."
        case .missingFormatDefinition(let format):
            return "The check is marked '\(format)' but has no matching '\(format)' definition."
        case .unexpectedFormatDefinition(let format):
            return "The check includes an unused '\(format)' definition."
        case .invalidJSONPointer(let field, _):
            return "Field '\(field)' is not a valid JSON Pointer."
        case .invalidCSSSelector(let field):
            return "Field '\(field)' is not a valid CSS selector."
        case .emptyValueMapping(let field):
            return "Field '\(field)' must contain at least one explicit value mapping."
        case .tooManyMappingValues(let field, let maximum):
            return "Field '\(field)' contains more than the allowed \(maximum) mappings."
        case .emptyMappingKey(let field):
            return "Field '\(field)' contains an empty source value."
        case .unknownMappingValue(let field, let value):
            return "Value '\(value)' in '\(field)' is not a supported service state."
        case .emptySelector(let field):
            return "Field '\(field)' must contain a CSS selector."
        case .unsupportedHTMLValueSource(let source):
            return "HTML value source '\(source)' is unsupported; use 'text' or 'attribute'."
        case .missingHTMLAttributeName(let field):
            return "Field '\(field).name' is required when the source type is 'attribute'."
        case .unexpectedHTMLAttributeName(let field):
            return "Field '\(field).name' is only valid when the source type is 'attribute'."
        case .invalidAttributeName(let field):
            return "Field '\(field)' is not a valid HTML attribute name."
        case .stringTooLong(let field, let maximum):
            return "Field '\(field)' exceeds the \(maximum)-character limit."
        }
    }
}

enum ProviderManifestDecoder {
    static let maximumDocumentBytes = 65_536
    static let maximumJSONPointerBytes = 1_024
    static let maximumJSONPointerDepth = 128
    private static let maximumDisplayTextLength = 80
    private static let maximumURLLength = 2_048
    private static let maximumSelectorLength = 512
    private static let maximumAttributeNameLength = 128
    private static let maximumMappingValues = 64

    static func decode(_ data: Data) throws -> ProviderManifest {
        guard data.count <= maximumDocumentBytes else {
            throw ProviderManifestError.documentTooLarge(maximumBytes: maximumDocumentBytes)
        }

        guard let object = try jsonObject(from: data) as? [String: Any] else {
            throw ProviderManifestError.invalidField(path: "$")
        }

        try rejectUnknownFields(in: object)
        let document = try decodeDocument(data)

        guard document.schemaVersion == 1 else {
            throw ProviderManifestError.unsupportedSchemaVersion(document.schemaVersion)
        }

        let service = try makeServiceDefinition(from: document.service)
        let check = try makeCheckDefinition(from: document.check)
        return ProviderManifest(service: service, check: check)
    }

    private static func jsonObject(from data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ProviderManifestError.malformedJSON
        }
    }

    private static func decodeDocument(_ data: Data) throws -> RawProviderManifest {
        do {
            return try JSONDecoder().decode(RawProviderManifest.self, from: data)
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch {
            throw ProviderManifestError.malformedJSON
        }
    }

    private static func mapDecodingError(_ error: DecodingError) -> ProviderManifestError {
        switch error {
        case .keyNotFound(let key, let context):
            return .missingRequiredField(path: codingPath(context.codingPath + [key]))
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return .invalidField(path: codingPath(context.codingPath))
        case .dataCorrupted(let context):
            return .invalidField(path: codingPath(context.codingPath))
        @unknown default:
            return .malformedJSON
        }
    }

    private static func codingPath(_ path: [CodingKey]) -> String {
        path.map(\.stringValue).joined(separator: ".")
    }

    private static func makeServiceDefinition(from raw: RawServiceDefinition) throws -> ServiceDefinition {
        guard let id = ServiceID(rawValue: raw.id) else {
            throw ProviderManifestError.invalidServiceID(raw.id)
        }

        try validateDisplayText(raw.displayName, field: "service.displayName")
        try validateDisplayText(raw.attribution.publisherName, field: "service.attribution.publisherName")

        return ServiceDefinition(
            id: id,
            displayName: raw.displayName,
            statusPageURL: try validatedHTTPSURL(raw.statusPageURL, field: "service.statusPageURL"),
            attribution: ProviderAttribution(publisherName: raw.attribution.publisherName)
        )
    }

    private static func makeCheckDefinition(from raw: RawCheckDefinition) throws -> ProviderCheckDefinition {
        guard raw.method == "GET" else {
            throw ProviderManifestError.unsupportedMethod(raw.method)
        }

        let requestURL = try validatedHTTPSURL(raw.requestURL, field: "check.requestURL")

        switch raw.format {
        case "json":
            guard let json = raw.json else {
                throw ProviderManifestError.missingFormatDefinition(format: "json")
            }
            guard raw.html == nil else {
                throw ProviderManifestError.unexpectedFormatDefinition(format: "html")
            }
            return .json(try makeJSONCheck(from: json, requestURL: requestURL))
        case "html":
            guard let html = raw.html else {
                throw ProviderManifestError.missingFormatDefinition(format: "html")
            }
            guard raw.json == nil else {
                throw ProviderManifestError.unexpectedFormatDefinition(format: "json")
            }
            return .html(try makeHTMLCheck(from: html, requestURL: requestURL))
        default:
            throw ProviderManifestError.unsupportedFormat(raw.format)
        }
    }

    private static func makeJSONCheck(
        from raw: RawJSONCheckDefinition,
        requestURL: URL
    ) throws -> JSONProviderCheck {
        let condition = try makeJSONValueMapping(
            from: raw.condition,
            field: "check.json.condition",
            transform: ServiceCondition.init(rawValue:)
        )

        let incidents = try raw.incidents.map { try makeJSONIncidents(from: $0) }
        return JSONProviderCheck(requestURL: requestURL, condition: condition, incidents: incidents)
    }

    private static func makeJSONIncidents(from raw: RawJSONIncidentCollection) throws -> JSONIncidentCollection {
        let pointer = try JSONPointer(validating: raw.pointer, field: "check.json.incidents.pointer")
        let idPointer = try raw.idPointer.map {
            try JSONPointer(validating: $0, field: "check.json.incidents.idPointer")
        }
        let titlePointer = try JSONPointer(
            validating: raw.titlePointer,
            field: "check.json.incidents.titlePointer"
        )
        let status = try raw.status.map {
            try makeJSONValueMapping(
                from: $0,
                field: "check.json.incidents.status",
                transform: IncidentStatus.init(rawValue:)
            )
        }
        let impact = try raw.impact.map {
            try makeJSONValueMapping(
                from: $0,
                field: "check.json.incidents.impact",
                transform: IncidentImpact.init(rawValue:)
            )
        }
        let summaryPointer = try raw.summaryPointer.map {
            try JSONPointer(validating: $0, field: "check.json.incidents.summaryPointer")
        }
        let urlPointer = try raw.urlPointer.map {
            try JSONPointer(validating: $0, field: "check.json.incidents.urlPointer")
        }
        let startedAtPointer = try raw.startedAtPointer.map {
            try JSONPointer(validating: $0, field: "check.json.incidents.startedAtPointer")
        }
        let updatedAtPointer = try raw.updatedAtPointer.map {
            try JSONPointer(validating: $0, field: "check.json.incidents.updatedAtPointer")
        }

        return JSONIncidentCollection(
            pointer: pointer,
            idPointer: idPointer,
            titlePointer: titlePointer,
            status: status,
            impact: impact,
            summaryPointer: summaryPointer,
            urlPointer: urlPointer,
            startedAtPointer: startedAtPointer,
            updatedAtPointer: updatedAtPointer
        )
    }

    private static func makeJSONValueMapping<Value: Equatable & Sendable>(
        from raw: RawJSONValueMapping,
        field: String,
        transform: (String) -> Value?
    ) throws -> JSONValueMapping<Value> {
        let pointer = try JSONPointer(validating: raw.pointer, field: "\(field).pointer")
        let values = try makeValues(raw.values, field: "\(field).values", transform: transform)
        return JSONValueMapping(pointer: pointer, values: values)
    }

    private static func makeHTMLCheck(
        from raw: RawHTMLCheckDefinition,
        requestURL: URL
    ) throws -> HTMLProviderCheck {
        let condition = try makeHTMLValueMapping(
            from: raw.condition,
            field: "check.html.condition",
            transform: ServiceCondition.init(rawValue:)
        )
        let incidents = try raw.incidents.map { try makeHTMLIncidents(from: $0) }

        return HTMLProviderCheck(requestURL: requestURL, condition: condition, incidents: incidents)
    }

    private static func makeHTMLIncidents(from raw: RawHTMLIncidentCollection) throws -> HTMLIncidentCollection {
        let titleSelector = try validatedSelector(
            raw.titleSelector,
            field: "check.html.incidents.titleSelector"
        )
        let idAttribute = try raw.idAttribute.map {
            try validatedAttributeName($0, field: "check.html.incidents.idAttribute")
        }
        let status = try raw.status.map {
            try makeHTMLValueMapping(
                from: $0,
                field: "check.html.incidents.status",
                transform: IncidentStatus.init(rawValue:)
            )
        }
        let impact = try raw.impact.map {
            try makeHTMLValueMapping(
                from: $0,
                field: "check.html.incidents.impact",
                transform: IncidentImpact.init(rawValue:)
            )
        }
        let summarySelector = try raw.summarySelector.map {
            try validatedSelector($0, field: "check.html.incidents.summarySelector")
        }
        let urlAttribute = try raw.urlAttribute.map {
            try validatedAttributeName($0, field: "check.html.incidents.urlAttribute")
        }

        return HTMLIncidentCollection(
            titleSelector: titleSelector,
            idAttribute: idAttribute,
            status: status,
            impact: impact,
            summarySelector: summarySelector,
            urlAttribute: urlAttribute
        )
    }

    private static func makeHTMLValueMapping<Value: Equatable & Sendable>(
        from raw: RawHTMLValueMapping,
        field: String,
        transform: (String) -> Value?
    ) throws -> HTMLValueMapping<Value> {
        let selector = try validatedSelector(raw.selector, field: "\(field).selector")
        let source = try validatedHTMLValueSource(raw.source, field: "\(field).source")
        let values = try makeValues(raw.values, field: "\(field).values", transform: transform)

        return HTMLValueMapping(selector: selector, source: source, values: values)
    }

    private static func validatedHTMLValueSource(
        _ raw: RawHTMLValueSource,
        field: String
    ) throws -> HTMLValueSource {
        switch raw.type {
        case "text":
            guard raw.name == nil else {
                throw ProviderManifestError.unexpectedHTMLAttributeName(field: field)
            }
            return .text
        case "attribute":
            guard let name = raw.name else {
                throw ProviderManifestError.missingHTMLAttributeName(field: field)
            }
            return .attribute(try validatedAttributeName(name, field: "\(field).name"))
        default:
            throw ProviderManifestError.unsupportedHTMLValueSource(raw.type)
        }
    }

    private static func makeValues<Value>(
        _ raw: [String: String],
        field: String,
        transform: (String) -> Value?
    ) throws -> [String: Value] {
        guard !raw.isEmpty else {
            throw ProviderManifestError.emptyValueMapping(field: field)
        }
        guard raw.count <= maximumMappingValues else {
            throw ProviderManifestError.tooManyMappingValues(field: field, maximum: maximumMappingValues)
        }

        var values: [String: Value] = [:]
        values.reserveCapacity(raw.count)

        for (sourceValue, mappedValue) in raw {
            guard !sourceValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProviderManifestError.emptyMappingKey(field: field)
            }
            guard let value = transform(mappedValue) else {
                throw ProviderManifestError.unknownMappingValue(field: field, value: mappedValue)
            }
            values[sourceValue] = value
        }

        return values
    }

    private static func validateDisplayText(_ value: String, field: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderManifestError.invalidField(path: field)
        }
        guard value.count <= maximumDisplayTextLength else {
            throw ProviderManifestError.stringTooLong(field: field, maximum: maximumDisplayTextLength)
        }
    }

    private static func validatedHTTPSURL(_ value: String, field: String) throws -> URL {
        guard value.utf8.count <= maximumURLLength,
              let components = URLComponents(string: value),
              let url = components.url,
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              host.contains("."),
              components.user == nil,
              components.password == nil,
              components.fragment == nil else {
            throw ProviderManifestError.invalidURL(field: field)
        }

        guard !isUnsafeHost(host) else {
            throw ProviderManifestError.unsafeURLHost(field: field)
        }

        return url
    }

    private static func isUnsafeHost(_ host: String) -> Bool {
        let normalizedHost = host.hasSuffix(".") ? String(host.dropLast()) : host
        let localSuffixes = [".localhost", ".local", ".internal", ".lan", ".home.arpa"]

        if normalizedHost == "localhost"
            || normalizedHost.contains(":")
            || normalizedHost.utf8.count > 253 {
            return true
        }
        if localSuffixes.contains(where: normalizedHost.hasSuffix) {
            return true
        }

        let labels = normalizedHost.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy(isValidDNSLabel),
              let topLevelLabel = labels.last,
              topLevelLabel.utf8.contains(where: isASCIILetter) else {
            return true
        }

        return false
    }

    private static func isValidDNSLabel(_ label: Substring) -> Bool {
        let bytes = Array(label.utf8)
        guard (1...63).contains(bytes.count),
              let first = bytes.first,
              let last = bytes.last,
              isASCIILetter(first) || isASCIIDigit(first),
              isASCIILetter(last) || isASCIIDigit(last) else {
            return false
        }

        return bytes.allSatisfy { isASCIILetter($0) || isASCIIDigit($0) || $0 == 45 }
    }

    private static func isASCIILetter(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte)
    }

    private static func isASCIIDigit(_ byte: UInt8) -> Bool {
        (48...57).contains(byte)
    }

    private static func validatedSelector(_ value: String, field: String) throws -> String {
        let selector = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selector.isEmpty else {
            throw ProviderManifestError.emptySelector(field: field)
        }
        guard selector.count <= maximumSelectorLength else {
            throw ProviderManifestError.stringTooLong(field: field, maximum: maximumSelectorLength)
        }

        do {
            let document = try SwiftSoup.parseHTML("<html><body></body></html>")
            _ = try document.select(selector)
        } catch {
            throw ProviderManifestError.invalidCSSSelector(field: field)
        }

        return selector
    }

    private static func validatedAttributeName(_ value: String, field: String) throws -> String {
        guard !value.isEmpty, value.count <= maximumAttributeNameLength else {
            throw ProviderManifestError.invalidAttributeName(field: field)
        }

        let bytes = Array(value.utf8)
        guard let first = bytes.first,
              isASCIIAttributeNameStart(first),
              bytes.dropFirst().allSatisfy(isASCIIAttributeNameContinuation) else {
            throw ProviderManifestError.invalidAttributeName(field: field)
        }

        return value
    }

    private static func isASCIIAttributeNameStart(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte) || byte == 95 || byte == 58
    }

    private static func isASCIIAttributeNameContinuation(_ byte: UInt8) -> Bool {
        isASCIIAttributeNameStart(byte) || (48...57).contains(byte) || byte == 45 || byte == 46
    }

    private static func rejectUnknownFields(in root: [String: Any]) throws {
        try rejectUnknownFields(root, allowed: ["schemaVersion", "service", "check"], path: "")

        if let service = root["service"] as? [String: Any] {
            try rejectUnknownFields(
                service,
                allowed: ["id", "displayName", "statusPageURL", "attribution"],
                path: "service"
            )
            if let attribution = service["attribution"] as? [String: Any] {
                try rejectUnknownFields(attribution, allowed: ["publisherName"], path: "service.attribution")
            }
        }

        if let check = root["check"] as? [String: Any] {
            try rejectNullOptionalFields(check, fields: ["json", "html"], path: "check")
            try rejectUnknownFields(
                check,
                allowed: ["method", "requestURL", "format", "json", "html"],
                path: "check"
            )
            if let json = check["json"] as? [String: Any] {
                try rejectNullOptionalFields(json, fields: ["incidents"], path: "check.json")
                try rejectUnknownFields(json, allowed: ["condition", "incidents"], path: "check.json")
                if let condition = json["condition"] as? [String: Any] {
                    try rejectUnknownFields(
                        condition,
                        allowed: ["pointer", "values"],
                        path: "check.json.condition"
                    )
                }
                if let incidents = json["incidents"] as? [String: Any] {
                    try rejectNullOptionalFields(
                        incidents,
                        fields: [
                            "idPointer", "status", "impact", "summaryPointer", "urlPointer",
                            "startedAtPointer", "updatedAtPointer"
                        ],
                        path: "check.json.incidents"
                    )
                    try rejectUnknownFields(
                        incidents,
                        allowed: [
                            "pointer", "idPointer", "titlePointer", "status", "impact",
                            "summaryPointer", "urlPointer", "startedAtPointer", "updatedAtPointer"
                        ],
                        path: "check.json.incidents"
                    )
                    try rejectUnknownFieldsInJSONIncidentMapping(incidents["status"], path: "check.json.incidents.status")
                    try rejectUnknownFieldsInJSONIncidentMapping(incidents["impact"], path: "check.json.incidents.impact")
                }
            }
            if let html = check["html"] as? [String: Any] {
                try rejectNullOptionalFields(html, fields: ["incidents"], path: "check.html")
                try rejectUnknownFields(html, allowed: ["condition", "incidents"], path: "check.html")
                if let condition = html["condition"] as? [String: Any] {
                    try rejectUnknownFields(
                        condition,
                        allowed: ["selector", "source", "values"],
                        path: "check.html.condition"
                    )
                    if let source = condition["source"] as? [String: Any] {
                        try rejectNullOptionalFields(source, fields: ["name"], path: "check.html.condition.source")
                        try rejectUnknownFields(source, allowed: ["type", "name"], path: "check.html.condition.source")
                    }
                }
                if let incidents = html["incidents"] as? [String: Any] {
                    try rejectNullOptionalFields(
                        incidents,
                        fields: ["idAttribute", "status", "impact", "summarySelector", "urlAttribute"],
                        path: "check.html.incidents"
                    )
                    try rejectUnknownFields(
                        incidents,
                        allowed: ["titleSelector", "idAttribute", "status", "impact", "summarySelector", "urlAttribute"],
                        path: "check.html.incidents"
                    )
                    try rejectUnknownFieldsInHTMLIncidentMapping(incidents["status"], path: "check.html.incidents.status")
                    try rejectUnknownFieldsInHTMLIncidentMapping(incidents["impact"], path: "check.html.incidents.impact")
                }
            }
        }
    }

    private static func rejectUnknownFieldsInJSONIncidentMapping(_ value: Any?, path: String) throws {
        guard let value = value as? [String: Any] else { return }
        try rejectUnknownFields(value, allowed: ["pointer", "values"], path: path)
    }

    private static func rejectUnknownFieldsInHTMLIncidentMapping(_ value: Any?, path: String) throws {
        guard let value = value as? [String: Any] else { return }
        try rejectNullOptionalFields(value, fields: ["source"], path: path)
        try rejectUnknownFields(value, allowed: ["selector", "source", "values"], path: path)
        if let source = value["source"] as? [String: Any] {
            try rejectNullOptionalFields(source, fields: ["name"], path: "\(path).source")
            try rejectUnknownFields(source, allowed: ["type", "name"], path: "\(path).source")
        }
    }

    private static func rejectNullOptionalFields(
        _ object: [String: Any],
        fields: Set<String>,
        path: String
    ) throws {
        guard let field = fields.sorted().first(where: { object[$0] is NSNull }) else { return }
        throw ProviderManifestError.invalidField(path: "\(path).\(field)")
    }

    private static func rejectUnknownFields(
        _ object: [String: Any],
        allowed: Set<String>,
        path: String
    ) throws {
        guard let unknown = object.keys.sorted().first(where: { !allowed.contains($0) }) else { return }
        let fieldPath = path.isEmpty ? unknown : "\(path).\(unknown)"
        throw ProviderManifestError.unknownField(path: fieldPath)
    }
}

private struct RawProviderManifest: Decodable {
    let schemaVersion: Int
    let service: RawServiceDefinition
    let check: RawCheckDefinition
}

private struct RawServiceDefinition: Decodable {
    let id: String
    let displayName: String
    let statusPageURL: String
    let attribution: RawProviderAttribution
}

private struct RawProviderAttribution: Decodable {
    let publisherName: String
}

private struct RawCheckDefinition: Decodable {
    let method: String
    let requestURL: String
    let format: String
    let json: RawJSONCheckDefinition?
    let html: RawHTMLCheckDefinition?
}

private struct RawJSONCheckDefinition: Decodable {
    let condition: RawJSONValueMapping
    let incidents: RawJSONIncidentCollection?
}

private struct RawJSONValueMapping: Decodable {
    let pointer: String
    let values: [String: String]
}

private struct RawJSONIncidentCollection: Decodable {
    let pointer: String
    let idPointer: String?
    let titlePointer: String
    let status: RawJSONValueMapping?
    let impact: RawJSONValueMapping?
    let summaryPointer: String?
    let urlPointer: String?
    let startedAtPointer: String?
    let updatedAtPointer: String?
}

private struct RawHTMLCheckDefinition: Decodable {
    let condition: RawHTMLValueMapping
    let incidents: RawHTMLIncidentCollection?
}

private struct RawHTMLValueMapping: Decodable {
    let selector: String
    let source: RawHTMLValueSource
    let values: [String: String]
}

private struct RawHTMLValueSource: Decodable {
    let type: String
    let name: String?
}

private struct RawHTMLIncidentCollection: Decodable {
    let titleSelector: String
    let idAttribute: String?
    let status: RawHTMLValueMapping?
    let impact: RawHTMLValueMapping?
    let summarySelector: String?
    let urlAttribute: String?
}
