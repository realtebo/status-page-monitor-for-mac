import Foundation
import SwiftSoup

enum HTMLParsingFailure: Error, Equatable, LocalizedError, ProviderFailure, Sendable {
    case invalidSelector(String)
    case noMatchingElement(String)
    case ambiguousElement(selector: String, count: Int)
    case missingAttribute(selector: String, name: String)
    case emptyValue(String)
    case malformedDocument

    var errorDescription: String? {
        switch self {
        case .invalidSelector(let selector):
            return "The HTML selector '\(selector)' is invalid."
        case .noMatchingElement(let selector):
            return "The HTML selector '\(selector)' did not match an element."
        case .ambiguousElement(let selector, let count):
            return "The HTML selector '\(selector)' matched \(count) elements; exactly one was required."
        case .missingAttribute(let selector, let name):
            return "An element matched by '\(selector)' has no '\(name)' attribute."
        case .emptyValue(let selector):
            return "The HTML selector '\(selector)' produced an empty value."
        case .malformedDocument:
            return "The response could not be parsed as HTML."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .invalidSelector:
            return .invalidDefinition(message: errorDescription ?? "Invalid HTML selector.")
        case .noMatchingElement(let selector), .emptyValue(let selector):
            return .missingField(name: selector)
        case .ambiguousElement, .malformedDocument:
            return .invalidResponse(message: errorDescription ?? "Invalid HTML response.")
        case .missingAttribute(let selector, let name):
            return .missingField(name: "\(selector)[\(name)]")
        }
    }
}

enum HTMLStatusPageParser {
    static let maximumSelectorLength = 512

    static func parse(_ data: Data, baseURL: URL) throws -> Document {
        do {
            return try SwiftSoup.parseHTML(data, baseURL.absoluteString)
        } catch {
            throw HTMLParsingFailure.malformedDocument
        }
    }

    static func matchingElements(_ selector: String, in document: Document) throws -> [Element] {
        guard !selector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              selector.count <= maximumSelectorLength else {
            throw HTMLParsingFailure.invalidSelector(selector)
        }

        do {
            return Array(try document.select(selector))
        } catch {
            throw HTMLParsingFailure.invalidSelector(selector)
        }
    }

    static func exactlyOneElement(_ selector: String, in document: Document) throws -> Element {
        let elements = try matchingElements(selector, in: document)
        guard !elements.isEmpty else {
            throw HTMLParsingFailure.noMatchingElement(selector)
        }
        guard elements.count == 1, let element = elements.first else {
            throw HTMLParsingFailure.ambiguousElement(selector: selector, count: elements.count)
        }

        return element
    }

    static func text(of element: Element, selectedBy selector: String) throws -> String {
        do {
            let value = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                throw HTMLParsingFailure.emptyValue(selector)
            }
            return value
        } catch let failure as HTMLParsingFailure {
            throw failure
        } catch {
            throw HTMLParsingFailure.malformedDocument
        }
    }

    static func attribute(
        named name: String,
        of element: Element,
        selectedBy selector: String
    ) throws -> String {
        guard element.hasAttr(name) else {
            throw HTMLParsingFailure.missingAttribute(selector: selector, name: name)
        }

        do {
            let value = try element.attr(name).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                throw HTMLParsingFailure.emptyValue(selector)
            }
            return value
        } catch let failure as HTMLParsingFailure {
            throw failure
        } catch {
            throw HTMLParsingFailure.malformedDocument
        }
    }
}
