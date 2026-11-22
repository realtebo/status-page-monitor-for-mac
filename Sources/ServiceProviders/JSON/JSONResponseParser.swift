import Foundation

enum JSONValue: Decodable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if container.decodeNil() {
                self = .null
                return
            }
            if let value = try? container.decode(Bool.self) {
                self = .boolean(value)
                return
            }
            if let value = try? container.decode(String.self) {
                self = .string(value)
                return
            }
            if let value = try? container.decode(Double.self) {
                self = .number(value)
                return
            }
        }

        if let container = try? decoder.container(keyedBy: DynamicJSONCodingKey.self) {
            var object: [String: JSONValue] = [:]
            object.reserveCapacity(container.allKeys.count)
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var array: [JSONValue] = []
            while !container.isAtEnd {
                array.append(try container.decode(JSONValue.self))
            }
            self = .array(array)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value.")
        )
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }
}

enum JSONResponseParserError: Error, Equatable, LocalizedError, ProviderFailure, Sendable {
    case malformedJSON
    case responseTooLarge(maximumBytes: Int)

    var errorDescription: String? {
        switch self {
        case .malformedJSON:
            return "The endpoint did not return valid JSON."
        case .responseTooLarge(let maximumBytes):
            return "The JSON response exceeded the \(maximumBytes)-byte limit."
        }
    }

    var checkFailureReason: CheckFailureReason {
        .invalidResponse(message: errorDescription ?? "Invalid JSON response.")
    }
}

enum JSONResponseParser {
    static func parse(_ data: Data) throws -> JSONValue {
        guard data.count <= HTTPResponseLimits.maximumBodyBytes else {
            throw JSONResponseParserError.responseTooLarge(
                maximumBytes: HTTPResponseLimits.maximumBodyBytes
            )
        }

        do {
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw JSONResponseParserError.malformedJSON
        }
    }
}

extension JSONPointer {
    func value(in document: JSONValue) -> JSONValue? {
        tokens.reduce(Optional(document)) { current, token in
            guard let current else { return nil }

            switch current {
            case .object(let object):
                return object[token]
            case .array(let array):
                guard let index = arrayIndex(for: token), array.indices.contains(index) else { return nil }
                return array[index]
            case .string, .number, .boolean, .null:
                return nil
            }
        }
    }

    private func arrayIndex(for token: String) -> Int? {
        let bytes = Array(token.utf8)
        guard !bytes.isEmpty,
              bytes.allSatisfy({ (48...57).contains($0) }),
              bytes.count == 1 || bytes.first != 48,
              let index = Int(token) else {
            return nil
        }

        return index
    }
}

extension JSONValueMapping {
    func mappedValue(in document: JSONValue) -> Value? {
        guard let sourceValue = pointer.value(in: document)?.stringValue else { return nil }
        return values[sourceValue]
    }
}

private struct DynamicJSONCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
