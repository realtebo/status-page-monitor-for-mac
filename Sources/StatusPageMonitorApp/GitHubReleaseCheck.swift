import Foundation

/// Identifies a numeric version from an official release tag such as `v0.02.1`.
struct GitHubReleaseVersion: Comparable, Equatable, Hashable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: GitHubReleaseVersion, rhs: GitHubReleaseVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

/// Describes the latest compatible macOS release found on GitHub.
struct GitHubMacRelease: Equatable, Sendable {
    let tagName: String
    let numericVersion: GitHubReleaseVersion
    let releaseURL: URL
    let downloadURL: URL
    let appcastURL: URL?

    /// The version string used by the app bundle, without the tag's `v` prefix.
    var version: String {
        String(tagName.dropFirst())
    }


}

/// Errors returned while checking the official GitHub release history.
enum GitHubReleaseCheckFailure: Error, Equatable, LocalizedError, Sendable {
    case transport(HTTPTransportFailure)
    case transportMessage(String)
    case malformedJSON
    case responseTooLarge(maximumBytes: Int)
    case invalidResponse(path: String)
    case noCompatibleRelease

    var errorDescription: String? {
        switch self {
        case .transport(let failure):
            return failure.errorDescription ?? "The GitHub release request failed."
        case .transportMessage(let message):
            return "The GitHub release request failed: \(message)"
        case .malformedJSON:
            return "GitHub returned malformed release data."
        case .responseTooLarge(let maximumBytes):
            return "GitHub returned more than \(maximumBytes) bytes of release data."
        case .invalidResponse(let path):
            return "GitHub returned an invalid releases response at '\(path)'."
        case .noCompatibleRelease:
            return "No compatible macOS release was found on GitHub."
        }
    }
}

/// Finds the latest compatible macOS release from the official repository.
struct GitHubReleaseCheck: Sendable {
    static let archiveAssetName = "StatusPageMonitor-macOS-arm64.zip"
    static let appcastAssetName = "appcast.xml"

    // Keep each page comfortably below the bounded HTTP response limit. GitHub
    // release entries include asset metadata, so 100 entries can exceed 2 MiB.
    private static let pageSize = 30
    private static let releasesEndpoint = URL(string: "https://api.github.com/repos/realtebo/status-page-monitor-for-mac/releases")!
    private static let releasePageBase = "https://github.com/realtebo/status-page-monitor-for-mac/releases/tag"
    private static let downloadBase = "https://github.com/realtebo/status-page-monitor-for-mac/releases/download"

    private let transport: any HTTPTransport

    init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    /// Returns the numerically greatest compatible release, including prereleases.
    ///
    /// GitHub's `/releases/latest` endpoint excludes prereleases, so this method
    /// walks the paginated `/releases` endpoint instead.
    func latestMacRelease() async throws -> GitHubMacRelease {
        var page = 1
        var latest: GitHubMacRelease?

        while true {
            try Task.checkCancellation()
            let response: HTTPResponse
            do {
                response = try await transport.get(Self.releasesURL(page: page))
            } catch let failure as HTTPTransportFailure {
                throw GitHubReleaseCheckFailure.transport(failure)
            } catch {
                throw GitHubReleaseCheckFailure.transportMessage(error.localizedDescription)
            }

            let values: [JSONValue]
            do {
                let document = try JSONResponseParser.parse(response.body)
                guard case .array(let array) = document else {
                    throw GitHubReleaseCheckFailure.invalidResponse(path: "/")
                }
                values = array
            } catch let failure as GitHubReleaseCheckFailure {
                throw failure
            } catch let failure as JSONResponseParserError {
                switch failure {
                case .malformedJSON:
                    throw GitHubReleaseCheckFailure.malformedJSON
                case .responseTooLarge(let maximumBytes):
                    throw GitHubReleaseCheckFailure.responseTooLarge(maximumBytes: maximumBytes)
                }
            } catch {
                throw GitHubReleaseCheckFailure.malformedJSON
            }

            for value in values {
                guard let candidate = Self.candidate(from: value) else { continue }
                if let latest, latest.numericVersion >= candidate.numericVersion { continue }
                latest = candidate
            }

            guard values.count == Self.pageSize else { break }
            page += 1
        }

        guard let latest else {
            throw GitHubReleaseCheckFailure.noCompatibleRelease
        }
        return latest
    }

    private static func releasesURL(page: Int) -> URL {
        var components = URLComponents(url: releasesEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page))
        ]
        return components.url!
    }

    private static func candidate(from value: JSONValue) -> GitHubMacRelease? {
        guard case .object(let fields) = value,
              let tagName = fields["tag_name"]?.stringValue,
              let version = GitHubReleaseVersion(tagName: tagName),
              fields["draft"]?.booleanValue == false,
              case .array(let assets) = fields["assets"] else {
            return nil
        }

        var archiveURL: URL?
        var appcastURL: URL?
        for asset in assets {
            guard case .object(let fields) = asset,
                  let name = fields["name"]?.stringValue,
                  let rawURL = fields["browser_download_url"]?.stringValue else {
                continue
            }

            if name == archiveAssetName {
                archiveURL = archiveURL ?? validatedAssetURL(rawURL, tagName: tagName, assetName: name)
            } else if name == appcastAssetName {
                appcastURL = appcastURL ?? validatedAssetURL(rawURL, tagName: tagName, assetName: name)
            }
        }

        guard let archiveURL else { return nil }
        guard let releaseURL = URL(string: "\(releasePageBase)/\(tagName)") else { return nil }
        return GitHubMacRelease(
            tagName: tagName,
            numericVersion: version,
            releaseURL: releaseURL,
            downloadURL: archiveURL,
            appcastURL: appcastURL
        )
    }

    private static func validatedAssetURL(
        _ rawURL: String,
        tagName: String,
        assetName: String
    ) -> URL? {
        let expected = "\(downloadBase)/\(tagName)/\(assetName)"
        guard rawURL == expected, let url = URL(string: expected) else { return nil }
        return url
    }
}

extension GitHubReleaseVersion {
    init?(tagName: String) {
        guard tagName.first == "v" else { return nil }
        self.init(versionString: String(tagName.dropFirst()))
    }

    /// Parses the numeric version stored in `CFBundleShortVersionString`.
    init?(cfBundleShortVersionString: String) {
        self.init(versionString: cfBundleShortVersionString)
    }

    private init?(versionString: String) {
        let components = versionString.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(components.count) else { return nil }

        var numbers: [Int] = []
        numbers.reserveCapacity(3)
        for component in components {
            let bytes = Array(component.utf8)
            guard !bytes.isEmpty,
                  bytes.allSatisfy({ (48...57).contains($0) }),
                  let number = Int(String(component)) else {
                return nil
            }
            numbers.append(number)
        }

        self.init(major: numbers[0], minor: numbers[1], patch: numbers.count == 3 ? numbers[2] : 0)
    }
}

private extension JSONValue {
    var booleanValue: Bool? {
        guard case .boolean(let value) = self else { return nil }
        return value
    }
}
