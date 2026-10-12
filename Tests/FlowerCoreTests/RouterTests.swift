import Foundation
import Testing
@testable import FlowerCore

@Suite struct RouterTests {
    let root: URL
    let frames = FrameStore()
    let router: Router

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("FlowerTests-\(UUID().uuidString)/web")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try Data("<html>index</html>".utf8).write(to: root.appendingPathComponent("index.html"))
        try Data("body{}".utf8).write(to: root.appendingPathComponent("style.css"))
        try Data("secret".utf8).write(to: root.appendingPathComponent(".hidden"))
        try Data("outside".utf8).write(to: root.deletingLastPathComponent().appendingPathComponent("outside.txt"))
        router = Router(webRoot: root, frames: frames)
    }

    func get(_ path: String, method: String = "GET", headers: [String: String] = [:], credentials: Credentials? = nil) -> HTTPResponse {
        router.handle(HTTPRequest(method: method, path: path, headers: headers), credentials: credentials)
    }

    @Test func rootServesIndex() {
        let res = get("/")
        #expect(res.status == 200)
        #expect(res.headers["Content-Type"] == "text/html; charset=utf-8")
        #expect(res.body == Data("<html>index</html>".utf8))
    }

    @Test func servesCSSWithContentType() {
        #expect(get("/style.css").headers["Content-Type"] == "text/css; charset=utf-8")
    }

    @Test(arguments: ["/missing.html", "/sub", "/../outside.txt", "/sub/../../outside.txt", "/.hidden"])
    func notFound(path: String) {
        #expect(get(path).status == 404)
    }

    @Test func frameUnavailableUntilCaptured() {
        #expect(get("/frame.jpg").status == 503)
        frames.update(Data([0xFF, 0xD8, 0xFF]))
        let res = get("/frame.jpg")
        #expect(res.status == 200)
        #expect(res.headers["Content-Type"] == "image/jpeg")
        #expect(res.headers["Cache-Control"] == "no-store")
        #expect(res.body == Data([0xFF, 0xD8, 0xFF]))
    }

    @Test func rejectsOtherMethods() {
        let res = get("/", method: "POST")
        #expect(res.status == 405)
        #expect(res.headers["Allow"] == "GET, HEAD")
    }

    @Test func privateSessionRequiresAuth() {
        let creds = Credentials(username: "screen", password: "task")
        let challenged = get("/", credentials: creds)
        #expect(challenged.status == 401)
        #expect(challenged.headers["WWW-Authenticate"]?.hasPrefix("Basic") == true)

        // Auth is checked before existence, so unauthenticated clients can't probe for files.
        #expect(get("/missing.html", credentials: creds).status == 401)

        let auth = "Basic " + Data("screen:task".utf8).base64EncodedString()
        #expect(get("/", headers: ["Authorization": auth], credentials: creds).status == 200)
    }
}
