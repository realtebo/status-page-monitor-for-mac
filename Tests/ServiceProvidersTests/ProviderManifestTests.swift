import Foundation
import Testing
@testable import StatusPageMonitor

@Test func decodesVersionOneJSONProviderManifest() throws {
    let manifest = try ProviderManifestDecoder.decode(Data(jsonManifest.utf8))

    #expect(manifest.service.id.rawValue == "community-status")
    #expect(manifest.service.displayName == "Community Status")
    #expect(manifest.service.statusPageURL.absoluteString == "https://status.example.com/")

    if case .json(let check) = manifest.check {
        #expect(check.requestURL.absoluteString == "https://status.example.com/api/v2/summary.json")
        #expect(check.condition.pointer.tokens == ["status", "indicator"])
        #expect(check.condition.values["none"] == .operational)
        #expect(check.condition.values["major"] == .majorOutage)
        #expect(check.incidents?.titlePointer.tokens == ["name"])
        #expect(check.incidents?.status?.values["investigating"] == .investigating)
        #expect(check.incidents?.impact?.values["critical"] == .critical)
    } else {
        Issue.record("The JSON manifest was decoded as another response format.")
    }
}

@Test func decodesVersionOneHTMLProviderManifest() throws {
    let manifest = try ProviderManifestDecoder.decode(Data(htmlManifest.utf8))

    if case .html(let check) = manifest.check {
        #expect(check.condition.selector == "main .overall-status[data-state]")
        #expect(check.condition.source == .attribute("data-state"))
        #expect(check.condition.values["Operational"] == .operational)
        #expect(check.incidents?.titleSelector == "section.incidents h3")
        #expect(check.incidents?.idAttribute == "data-incident-id")
    } else {
        Issue.record("The HTML manifest was decoded as another response format.")
    }
}

@Test func rejectsUnsupportedManifestVersionsAndMethods() {
    let wrongVersion = jsonManifest.replacingOccurrences(
        of: "\"schemaVersion\": 1",
        with: "\"schemaVersion\": 2"
    )
    let wrongMethod = jsonManifest.replacingOccurrences(
        of: "\"method\": \"GET\"",
        with: "\"method\": \"POST\""
    )

    #expect(manifestError(for: wrongVersion) == .unsupportedSchemaVersion(2))
    #expect(manifestError(for: wrongMethod) == .unsupportedMethod("POST"))
}

@Test func rejectsMissingFieldsAndUnsafeURLs() {
    let missingPointer = jsonManifest.replacingOccurrences(
        of: "\"pointer\": \"/status/indicator\",\n",
        with: ""
    )
    let insecureURL = jsonManifest.replacingOccurrences(
        of: "https://status.example.com/",
        with: "http://status.example.com/"
    )
    let localHost = jsonManifest.replacingOccurrences(
        of: "status.example.com",
        with: "127.0.0.1"
    )
    let shortenedIPHost = jsonManifest.replacingOccurrences(
        of: "status.example.com",
        with: "127.1"
    )

    #expect(
        manifestError(for: missingPointer)
            == .missingRequiredField(path: "check.json.condition.pointer")
    )
    #expect(manifestError(for: insecureURL) == .invalidURL(field: "service.statusPageURL"))
    #expect(manifestError(for: localHost) == .unsafeURLHost(field: "service.statusPageURL"))
    #expect(manifestError(for: shortenedIPHost) == .unsafeURLHost(field: "service.statusPageURL"))
}

@Test func rejectsNullOptionalFieldsInsteadOfTreatingThemAsAbsent() {
    let nullIncidentCollection = jsonManifest.replacingOccurrences(
        of: "\"idPointer\": \"/id\"",
        with: "\"idPointer\": null"
    )
    let nullHTMLAttribute = htmlManifest.replacingOccurrences(
        of: "\"name\": \"data-state\"",
        with: "\"name\": null"
    )

    #expect(
        manifestError(for: nullIncidentCollection)
            == .invalidField(path: "check.json.incidents.idPointer")
    )
    #expect(
        manifestError(for: nullHTMLAttribute)
            == .invalidField(path: "check.html.condition.source.name")
    )
}

@Test func rejectsUnknownFieldsUnknownStatesAndInvalidJSONPointers() {
    let unknownScriptField = jsonManifest.replacingOccurrences(
        of: "\"schemaVersion\": 1,",
        with: "\"schemaVersion\": 1,\n  \"script\": \"run something\","
    )
    let unknownState = jsonManifest.replacingOccurrences(
        of: "\"major\": \"majorOutage\"",
        with: "\"major\": \"unknown\""
    )
    let invalidPointer = jsonManifest.replacingOccurrences(
        of: "/status/indicator",
        with: "/status/~2indicator"
    )

    #expect(manifestError(for: unknownScriptField) == .unknownField(path: "script"))
    #expect(
        manifestError(for: unknownState)
            == .unknownMappingValue(field: "check.json.condition.values", value: "unknown")
    )
    #expect(
        manifestError(for: invalidPointer)
            == .invalidJSONPointer(field: "check.json.condition.pointer", value: "/status/~2indicator")
    )
}

@Test func rejectsMalformedCSSSelectorsAndResponseDefinitionMismatch() {
    let invalidSelector = htmlManifest.replacingOccurrences(
        of: "main .overall-status[data-state]",
        with: "main >"
    )
    let wrongFormatDefinition = jsonManifest.replacingOccurrences(
        of: "\"format\": \"json\"",
        with: "\"format\": \"html\""
    )

    #expect(
        manifestError(for: invalidSelector)
            == .invalidCSSSelector(field: "check.html.condition.selector")
    )
    #expect(
        manifestError(for: wrongFormatDefinition)
            == .missingFormatDefinition(format: "html")
    )
}

@Test func rejectsOversizedManifestDocumentsBeforeDecoding() {
    let data = Data(repeating: 0x20, count: ProviderManifestDecoder.maximumDocumentBytes + 1)

    do {
        _ = try ProviderManifestDecoder.decode(data)
        Issue.record("An oversized manifest was accepted.")
    } catch let error as ProviderManifestError {
        #expect(error == .documentTooLarge(maximumBytes: ProviderManifestDecoder.maximumDocumentBytes))
    } catch {
        Issue.record("The oversized manifest returned an unexpected error: \(error)")
    }
}

private func manifestError(for json: String) -> ProviderManifestError? {
    do {
        _ = try ProviderManifestDecoder.decode(Data(json.utf8))
        return nil
    } catch let error as ProviderManifestError {
        return error
    } catch {
        return nil
    }
}

private let jsonManifest = #"""
{
  "schemaVersion": 1,
  "service": {
    "id": "community-status",
    "displayName": "Community Status",
    "statusPageURL": "https://status.example.com/",
    "attribution": { "publisherName": "Example Vendor" }
  },
  "check": {
    "method": "GET",
    "requestURL": "https://status.example.com/api/v2/summary.json",
    "format": "json",
    "json": {
      "condition": {
        "pointer": "/status/indicator",
        "values": {
          "none": "operational",
          "minor": "degradedPerformance",
          "major": "majorOutage"
        }
      },
      "incidents": {
        "pointer": "/incidents",
        "idPointer": "/id",
        "titlePointer": "/name",
        "status": {
          "pointer": "/status",
          "values": { "investigating": "investigating" }
        },
        "impact": {
          "pointer": "/impact",
          "values": { "critical": "critical" }
        },
        "summaryPointer": "/body",
        "urlPointer": "/shortlink",
        "startedAtPointer": "/created_at",
        "updatedAtPointer": "/updated_at"
      }
    }
  }
}
"""#

private let htmlManifest = #"""
{
  "schemaVersion": 1,
  "service": {
    "id": "html-example",
    "displayName": "HTML Example",
    "statusPageURL": "https://status.example.com/",
    "attribution": { "publisherName": "Example Vendor" }
  },
  "check": {
    "method": "GET",
    "requestURL": "https://status.example.com/",
    "format": "html",
    "html": {
      "condition": {
        "selector": "main .overall-status[data-state]",
        "source": { "type": "attribute", "name": "data-state" },
        "values": {
          "Operational": "operational",
          "Partial outage": "partialOutage"
        }
      },
      "incidents": {
        "titleSelector": "section.incidents h3",
        "idAttribute": "data-incident-id"
      }
    }
  }
}
"""#
