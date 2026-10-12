import Foundation

public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public static func html(status: Int, _ html: String, headers: [String: String] = [:]) -> HTTPResponse {
        var merged = headers
        merged["Content-Type"] = "text/html; charset=utf-8"
        return HTTPResponse(status: status, headers: merged, body: Data(html.utf8))
    }

    /// Serializes the response. Every response closes the connection, which keeps the server simple
    /// and matches how the web UI polls (one request per frame).
    public func serialized(includeBody: Bool = true) -> Data {
        var head = "HTTP/1.1 \(status) \(Self.reasonPhrase(for: status))\r\n"
        var all = headers
        all["Content-Length"] = String(body.count)
        all["Connection"] = "close"
        for key in all.keys.sorted() {
            head += "\(key): \(all[key]!)\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        if includeBody { data.append(body) }
        return data
    }

    public static func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 431: "Request Header Fields Too Large"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "Unknown"
        }
    }
}
