import Foundation

/// Maps requests to responses: static files from the web root plus the live frame.
public struct Router: Sendable {
    public static let frameName = "frame.jpg"

    public let webRoot: URL
    public let frames: FrameStore

    public init(webRoot: URL, frames: FrameStore) {
        self.webRoot = webRoot.standardizedFileURL.resolvingSymlinksInPath()
        self.frames = frames
    }

    /// - Parameter credentials: required credentials, or nil for a public session.
    public func handle(_ request: HTTPRequest, credentials: Credentials?) -> HTTPResponse {
        guard request.method == "GET" || request.method == "HEAD" else {
            return .html(status: 405, "<h1>405 Method Not Allowed</h1>", headers: ["Allow": "GET, HEAD"])
        }

        if let credentials, !BasicAuth.verify(request.header("Authorization"), against: credentials) {
            return .html(
                status: 401,
                "<h1 style=\"color:red\">Not Authorized</h1><hr><a href=\"./\">Back to Home</a>",
                headers: ["WWW-Authenticate": BasicAuth.challenge]
            )
        }

        let path = request.path == "/" ? "/index.html" : request.path

        if path == "/" + Self.frameName {
            guard let frame = frames.latest else {
                // No frame captured yet; the web UI retries on error.
                return .html(status: 503, "<h1>No frame yet</h1>", headers: ["Retry-After": "1", "Cache-Control": "no-store"])
            }
            return HTTPResponse(status: 200, headers: ["Content-Type": "image/jpeg", "Cache-Control": "no-store"], body: frame)
        }

        guard let file = resolve(path), let data = try? Data(contentsOf: file) else {
            return .html(status: 404, "<h1 style=\"color:red\">Error 404, File Not Found</h1><hr><a href=\"./\">Back to Home</a>")
        }
        return HTTPResponse(status: 200, headers: ["Content-Type": Self.contentType(forExtension: file.pathExtension)], body: data)
    }

    /// Resolves a request path to a regular file inside the web root, rejecting traversal and dotfiles.
    func resolve(_ path: String) -> URL? {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty, !components.contains(where: { $0.hasPrefix(".") }) else { return nil }

        let candidate = components
            .reduce(webRoot) { $0.appendingPathComponent(String($1)) }
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard candidate.path.hasPrefix(webRoot.path + "/") else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return nil
        }
        return candidate
    }

    public static func contentType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": "text/html; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "js": "text/javascript; charset=utf-8"
        case "json": "application/json"
        case "svg": "image/svg+xml"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "ico": "image/x-icon"
        default: "application/octet-stream"
        }
    }
}
