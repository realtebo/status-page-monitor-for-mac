import Foundation
import Testing
@testable import StatusPageMonitor

@Test func parsesJSONValuesAndResolvesPointersWithoutGuessing() throws {
    let data = Data(#"{"status":{"indicator":"minor"},"incidents":[{"id":"inc-1","title":"API outage"}],"escaped":{"a/b~c":"value"}}"#.utf8)
    let document = try JSONResponseParser.parse(data)
    let conditionPointer = try JSONPointer(validating: "/status/indicator", field: "test")
    let incidentTitlePointer = try JSONPointer(validating: "/incidents/0/title", field: "test")
    let escapedPointer = try JSONPointer(validating: "/escaped/a~1b~0c", field: "test")
    let rootPointer = try JSONPointer(validating: "", field: "test")
    let invalidArrayPointer = try JSONPointer(validating: "/incidents/01/title", field: "test")
    let conditionMapping = JSONValueMapping(
        pointer: conditionPointer,
        values: ["minor": ServiceCondition.partialOutage]
    )

    #expect(conditionMapping.mappedValue(in: document) == .partialOutage)
    #expect(incidentTitlePointer.value(in: document)?.stringValue == "API outage")
    #expect(escapedPointer.value(in: document)?.stringValue == "value")
    #expect(rootPointer.value(in: document) == document)
    #expect(invalidArrayPointer.value(in: document) == nil)
}

@Test func rejectsMalformedAndOversizedJSONResponses() {
    do {
        _ = try JSONResponseParser.parse(Data("{".utf8))
        Issue.record("Malformed JSON was accepted.")
    } catch let error as JSONResponseParserError {
        #expect(error == .malformedJSON)
    } catch {
        Issue.record("Malformed JSON returned an unexpected error: \(error)")
    }

    let oversizedData = Data(repeating: 0x20, count: HTTPResponseLimits.maximumBodyBytes + 1)
    do {
        _ = try JSONResponseParser.parse(oversizedData)
        Issue.record("An oversized JSON response was accepted.")
    } catch let error as JSONResponseParserError {
        #expect(error == .responseTooLarge(maximumBytes: HTTPResponseLimits.maximumBodyBytes))
    } catch {
        Issue.record("The oversized JSON response returned an unexpected error: \(error)")
    }
}

@Test func parsesHTMLFixtureAndExtractsExplicitTextAndAttributes() throws {
    let html = Data(#"<main><p class="status"> Operational </p><a class="incident" href="/incidents/1">Details</a></main>"#.utf8)
    let baseURL = URL(string: "https://status.example.com/")!
    let document = try HTMLStatusPageParser.parse(html, baseURL: baseURL)
    let status = try HTMLStatusPageParser.exactlyOneElement("main .status", in: document)
    let incidentLink = try HTMLStatusPageParser.exactlyOneElement("a.incident", in: document)

    #expect(try HTMLStatusPageParser.text(of: status, selectedBy: "main .status") == "Operational")
    #expect(
        try HTMLStatusPageParser.attribute(named: "href", of: incidentLink, selectedBy: "a.incident")
            == "/incidents/1"
    )
}

@Test func HTMLSelectorsRequireValidAndUnambiguousElements() throws {
    let html = Data(#"<main><p class="status">Operational</p><p class="status">Degraded</p></main>"#.utf8)
    let document = try HTMLStatusPageParser.parse(html, baseURL: URL(string: "https://status.example.com/")!)

    #expect(
        htmlFailure { _ = try HTMLStatusPageParser.exactlyOneElement("main >", in: document) }
            == .invalidSelector("main >")
    )
    #expect(
        htmlFailure { _ = try HTMLStatusPageParser.exactlyOneElement("main .missing", in: document) }
            == .noMatchingElement("main .missing")
    )
    #expect(
        htmlFailure { _ = try HTMLStatusPageParser.exactlyOneElement(".status", in: document) }
            == .ambiguousElement(selector: ".status", count: 2)
    )
}

@Test func HTMLExtractionFailsWhenRequiredValuesAreMissingOrEmpty() throws {
    let html = Data(#"<main><p class="status"> </p><a class="incident">Details</a></main>"#.utf8)
    let document = try HTMLStatusPageParser.parse(html, baseURL: URL(string: "https://status.example.com/")!)
    let status = try HTMLStatusPageParser.exactlyOneElement(".status", in: document)
    let incidentLink = try HTMLStatusPageParser.exactlyOneElement(".incident", in: document)

    #expect(htmlFailure { _ = try HTMLStatusPageParser.text(of: status, selectedBy: ".status") } == .emptyValue(".status"))
    #expect(
        htmlFailure {
            _ = try HTMLStatusPageParser.attribute(named: "href", of: incidentLink, selectedBy: ".incident")
        } == .missingAttribute(selector: ".incident", name: "href")
    )
}

@Test func responseValidationSeparatesHTTPStatusAndBodySizeFailures() throws {
    let endpoint = URL(string: "https://status.example.com/")!
    let nonHTTPResponse = URLResponse(url: endpoint, mimeType: "text/plain", expectedContentLength: 1, textEncodingName: nil)
    let unavailableResponse = HTTPURLResponse(url: endpoint, statusCode: 503, httpVersion: "HTTP/1.1", headerFields: nil)!
    let oversizedResponse = HTTPURLResponse(
        url: endpoint,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Length": "3"]
    )!

    #expect(responseFailure(nonHTTPResponse, maximumBodyBytes: 10) == .nonHTTPResponse)
    #expect(responseFailure(unavailableResponse, maximumBodyBytes: 10) == .httpStatus(code: 503))
    #expect(responseFailure(oversizedResponse, maximumBodyBytes: 2) == .responseTooLarge(maximumBytes: 2))
}

@Test func boundedResponseBodyRejectsTheFirstBytePastItsLimit() throws {
    var responseBody = BoundedResponseBody(maximumBytes: 2)
    try responseBody.append(0x41)
    try responseBody.append(0x42)
    #expect(responseBody.data == Data([0x41, 0x42]))

    do {
        try responseBody.append(0x43)
        Issue.record("A response body larger than its configured limit was accepted.")
    } catch let error as HTTPTransportFailure {
        #expect(error == .responseTooLarge(maximumBytes: 2))
    } catch {
        Issue.record("An oversized body returned an unexpected error: \(error)")
    }
}

@Test func redirectsMustRemainSafeHTTPSGETRequestsAndStayWithinTheLimit() {
    let safeRequest = URLRequest(url: URL(string: "https://status.example.com/summary")!)
    let insecureRequest = URLRequest(url: URL(string: "http://status.example.com/summary")!)
    let localRequest = URLRequest(url: URL(string: "https://127.1/summary")!)

    #expect(HTTPRedirectPolicy.rejection(for: safeRequest, redirectCount: 1) == nil)
    #expect(HTTPRedirectPolicy.rejection(for: insecureRequest, redirectCount: 1) == .unsafeRedirect)
    #expect(HTTPRedirectPolicy.rejection(for: localRequest, redirectCount: 1) == .unsafeRedirect)
    #expect(
        HTTPRedirectPolicy.rejection(for: safeRequest, redirectCount: HTTPRedirectPolicy.maximumRedirects + 1)
            == .tooManyRedirects
    )
}

@Test func transportRejectsInvalidEndpointsBeforeMakingARequest() async {
    let transport = URLSessionHTTPTransport()
    let endpoint = URL(string: "http://status.example.com/")!

    do {
        _ = try await transport.get(endpoint)
        Issue.record("An insecure endpoint was accepted.")
    } catch let error as HTTPTransportFailure {
        #expect(error == .invalidEndpoint)
    } catch {
        Issue.record("The invalid endpoint returned an unexpected error: \(error)")
    }
}

@Test func transportAndParserFailuresBecomeTypedProviderCheckFailures() throws {
    let attemptedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let httpFailure = HTTPTransportFailure.httpStatus(code: 503).checkFailure(at: attemptedAt)
    let timeout = HTTPTransportFailure.network(domain: NSURLErrorDomain, code: URLError.timedOut.rawValue)
        .checkFailure(at: attemptedAt)
    let invalidJSON = JSONResponseParserError.malformedJSON.checkFailure(at: attemptedAt)
    let missingHTMLState = HTMLParsingFailure.noMatchingElement(".overall-status")
        .checkFailure(at: attemptedAt)

    #expect(httpFailure == CheckFailure(reason: .httpStatus(code: 503), attemptedAt: attemptedAt))
    #expect(
        timeout == CheckFailure(
            reason: .network(message: "The network request failed (\(NSURLErrorDomain), \(URLError.timedOut.rawValue))."),
            attemptedAt: attemptedAt
        )
    )
    #expect(
        invalidJSON == CheckFailure(
            reason: .invalidResponse(message: "The endpoint did not return valid JSON."),
            attemptedAt: attemptedAt
        )
    )
    #expect(missingHTMLState == CheckFailure(reason: .missingField(name: ".overall-status"), attemptedAt: attemptedAt))
}

private func htmlFailure(_ operation: () throws -> Void) -> HTMLParsingFailure? {
    do {
        try operation()
        return nil
    } catch let failure as HTMLParsingFailure {
        return failure
    } catch {
        return nil
    }
}

private func responseFailure(_ response: URLResponse, maximumBodyBytes: Int) -> HTTPTransportFailure? {
    do {
        _ = try HTTPResponseValidator.validate(response, maximumBodyBytes: maximumBodyBytes)
        return nil
    } catch let failure as HTTPTransportFailure {
        return failure
    } catch {
        return nil
    }
}
