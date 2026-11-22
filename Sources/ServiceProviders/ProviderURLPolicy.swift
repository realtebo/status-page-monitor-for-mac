import Foundation

enum ProviderURLPolicy {
    static let maximumURLBytes = 2_048

    static func isAllowedHTTPSURL(_ url: URL) -> Bool {
        guard url.absoluteString.utf8.count <= maximumURLBytes,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let host = components.host else {
            return false
        }

        return isPublicDNSHost(host)
    }

    static func isPublicDNSHost(_ host: String) -> Bool {
        let normalizedHost = host.hasSuffix(".") ? String(host.dropLast()) : host
        let localSuffixes = [".localhost", ".local", ".internal", ".lan", ".home.arpa"]

        if normalizedHost == "localhost"
            || normalizedHost.contains(":")
            || normalizedHost.utf8.count > 253 {
            return false
        }
        if localSuffixes.contains(where: normalizedHost.hasSuffix) {
            return false
        }

        let labels = normalizedHost.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy(isValidDNSLabel),
              let topLevelLabel = labels.last,
              topLevelLabel.utf8.contains(where: isASCIILetter) else {
            return false
        }

        return true
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
}
