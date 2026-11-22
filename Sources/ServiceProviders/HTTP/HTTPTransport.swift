import Foundation

struct HTTPResponse: Equatable, Sendable {
    let statusCode: Int
    let finalURL: URL
    let mimeType: String?
    let body: Data
}

protocol HTTPTransport: Sendable {
    func get(_ url: URL) async throws -> HTTPResponse
}

enum HTTPTransportFailure: Error, Equatable, LocalizedError, ProviderFailure, Sendable {
    case invalidEndpoint
    case nonHTTPResponse
    case httpStatus(code: Int)
    case responseTooLarge(maximumBytes: Int)
    case tooManyRedirects
    case unsafeRedirect
    case network(domain: String, code: Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The request URL is not an allowed public HTTPS endpoint."
        case .nonHTTPResponse:
            return "The server returned a response that was not HTTP."
        case .httpStatus(let code):
            return "The status endpoint returned HTTP status \(code)."
        case .responseTooLarge(let maximumBytes):
            return "The status response exceeded the \(maximumBytes)-byte limit."
        case .tooManyRedirects:
            return "The status endpoint exceeded the redirect limit."
        case .unsafeRedirect:
            return "The status endpoint redirected to a disallowed URL."
        case .network(let domain, let code):
            return "The network request failed (\(domain), \(code))."
        }
    }

    var checkFailureReason: CheckFailureReason {
        switch self {
        case .invalidEndpoint:
            return .invalidDefinition(message: errorDescription ?? "Invalid endpoint.")
        case .nonHTTPResponse, .responseTooLarge, .tooManyRedirects, .unsafeRedirect:
            return .invalidResponse(message: errorDescription ?? "Invalid HTTP response.")
        case .httpStatus(let code):
            return .httpStatus(code: code)
        case .network:
            return .network(message: errorDescription ?? "Network request failed.")
        }
    }
}

enum HTTPResponseValidator {
    static func validate(
        _ response: URLResponse,
        maximumBodyBytes: Int
    ) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPTransportFailure.nonHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPTransportFailure.httpStatus(code: httpResponse.statusCode)
        }
        if httpResponse.expectedContentLength >= 0,
           httpResponse.expectedContentLength > Int64(maximumBodyBytes) {
            throw HTTPTransportFailure.responseTooLarge(maximumBytes: maximumBodyBytes)
        }

        return httpResponse
    }
}

enum HTTPRedirectPolicy {
    static let maximumRedirects = 5

    static func rejection(
        for request: URLRequest,
        redirectCount: Int
    ) -> HTTPTransportFailure? {
        guard redirectCount <= maximumRedirects else {
            return .tooManyRedirects
        }

        guard request.httpMethod?.uppercased() == "GET",
              let url = request.url,
              ProviderURLPolicy.isAllowedHTTPSURL(url) else {
            return .unsafeRedirect
        }

        return nil
    }
}

struct BoundedResponseBody: Equatable, Sendable {
    let maximumBytes: Int
    private(set) var data = Data()

    init(maximumBytes: Int) {
        self.maximumBytes = maximumBytes
    }

    mutating func append(_ byte: UInt8) throws {
        guard data.count < maximumBytes else {
            throw HTTPTransportFailure.responseTooLarge(maximumBytes: maximumBytes)
        }

        data.append(byte)
    }
}

actor URLSessionHTTPTransport: HTTPTransport {
    static let maximumResponseBytes = HTTPResponseLimits.maximumBodyBytes

    private let session: URLSession
    private let redirectDelegate: RedirectValidatingDelegate

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 4

        let redirectDelegate = RedirectValidatingDelegate()
        self.redirectDelegate = redirectDelegate
        session = URLSession(
            configuration: configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }

    func get(_ url: URL) async throws -> HTTPResponse {
        guard ProviderURLPolicy.isAllowedHTTPSURL(url) else {
            throw HTTPTransportFailure.invalidEndpoint
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false

        do {
            let (bytes, response) = try await session.bytes(for: request)
            let taskIdentifier = bytes.task.taskIdentifier

            if let rejection = redirectDelegate.takeRejection(for: taskIdentifier) {
                bytes.task.cancel()
                throw rejection
            }

            let httpResponse: HTTPURLResponse
            do {
                httpResponse = try HTTPResponseValidator.validate(
                    response,
                    maximumBodyBytes: Self.maximumResponseBytes
                )
            } catch {
                bytes.task.cancel()
                throw error
            }

            var responseBody = BoundedResponseBody(maximumBytes: Self.maximumResponseBytes)
            do {
                for try await byte in bytes {
                    try responseBody.append(byte)
                }
            } catch {
                bytes.task.cancel()
                throw error
            }

            let finalURL = httpResponse.url ?? url
            guard ProviderURLPolicy.isAllowedHTTPSURL(finalURL) else {
                throw HTTPTransportFailure.unsafeRedirect
            }

            return HTTPResponse(
                statusCode: httpResponse.statusCode,
                finalURL: finalURL,
                mimeType: httpResponse.mimeType,
                body: responseBody.data
            )
        } catch let failure as HTTPTransportFailure {
            throw failure
        } catch {
            let networkError = error as NSError
            throw HTTPTransportFailure.network(domain: networkError.domain, code: networkError.code)
        }
    }
}

private final class RedirectValidatingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private struct RedirectState {
        var count = 0
        var rejection: HTTPTransportFailure?
    }

    private let lock = NSLock()
    private var statesByTask: [Int: RedirectState] = [:]

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let rejection = recordRedirect(request, taskIdentifier: task.taskIdentifier)
        if rejection == nil {
            completionHandler(request)
        } else {
            completionHandler(nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        if statesByTask[task.taskIdentifier]?.rejection == nil {
            statesByTask.removeValue(forKey: task.taskIdentifier)
        }
        lock.unlock()
    }

    func takeRejection(for taskIdentifier: Int) -> HTTPTransportFailure? {
        lock.lock()
        defer { lock.unlock() }
        return statesByTask.removeValue(forKey: taskIdentifier)?.rejection
    }

    private func recordRedirect(_ request: URLRequest, taskIdentifier: Int) -> HTTPTransportFailure? {
        lock.lock()
        defer { lock.unlock() }

        var state = statesByTask[taskIdentifier] ?? RedirectState()
        state.count += 1
        state.rejection = HTTPRedirectPolicy.rejection(for: request, redirectCount: state.count)
        statesByTask[taskIdentifier] = state
        return state.rejection
    }
}
