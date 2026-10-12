import Foundation

/// A parsed HTTP/1.x request head. Flower only serves GET/HEAD, so bodies are ignored.
public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    /// Percent-decoded path without query string or fragment, always starting with "/".
    public var path: String
    /// Header names are lowercased.
    public var headers: [String: String]

    public init(method: String, path: String, headers: [String: String] = [:]) {
        self.method = method
        self.path = path
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    public enum ParseResult: Equatable, Sendable {
        case complete(HTTPRequest)
        case incomplete
        case invalid
    }

    public static let maxHeadBytes = 16 * 1024
    private static let headTerminator = Data("\r\n\r\n".utf8)

    public static func parse(_ data: Data) -> ParseResult {
        guard let end = data.range(of: headTerminator) else {
            return data.count > maxHeadBytes ? .invalid : .incomplete
        }
        guard end.lowerBound - data.startIndex <= maxHeadBytes else { return .invalid }

        let headData = data[data.startIndex..<end.lowerBound]
        guard let head = String(data: headData, encoding: .utf8) ?? String(data: headData, encoding: .isoLatin1) else {
            return .invalid
        }

        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true)
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1.") else { return .invalid }

        var target = Substring(requestLine[1])
        if let cut = target.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            target = target[..<cut]
        }
        guard target.hasPrefix("/"), let path = String(target).removingPercentEncoding else { return .invalid }

        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { return .invalid }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return .invalid }
            headers[name] = value
        }

        return .complete(HTTPRequest(method: String(requestLine[0]), path: path, headers: headers))
    }
}
