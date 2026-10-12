import Foundation

public struct Credentials: Equatable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public enum BasicAuth {
    public static let challenge = "Basic realm=\"Flower\", charset=\"UTF-8\""

    /// Decodes an `Authorization: Basic <base64>` header value.
    public static func decode(_ header: String?) -> Credentials? {
        guard let header else { return nil }
        let parts = header.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0].lowercased() == "basic",
              let data = Data(base64Encoded: String(parts[1])),
              let decoded = String(data: data, encoding: .utf8),
              let colon = decoded.firstIndex(of: ":")
        else { return nil }
        return Credentials(username: String(decoded[..<colon]), password: String(decoded[decoded.index(after: colon)...]))
    }

    public static func verify(_ header: String?, against expected: Credentials) -> Bool {
        guard let given = decode(header) else { return false }
        // Evaluate both comparisons so timing doesn't reveal which one failed.
        let userOK = constantTimeEquals(given.username, expected.username)
        let passOK = constantTimeEquals(given.password, expected.password)
        return userOK && passOK
    }

    static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        var diff = UInt8(truncatingIfNeeded: x.count ^ y.count)
        for i in 0..<max(x.count, y.count) {
            diff |= (i < x.count ? x[i] : 0) ^ (i < y.count ? y[i] : 0)
        }
        return diff == 0
    }
}
