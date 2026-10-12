import Foundation
import os
import Testing
@testable import FlowerCore

/// Exercises the real Network.framework listener on loopback.
@Suite(.serialized) struct HTTPServerTests {
    let loopback = NetworkInterfaceInfo(name: "lo0", address: "127.0.0.1", netmask: "255.0.0.0", isLoopback: true)

    func makeServer(frames: FrameStore = FrameStore()) throws -> HTTPServer {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FlowerServer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("<html>hello</html>".utf8).write(to: root.appendingPathComponent("index.html"))
        return HTTPServer(router: Router(webRoot: root, frames: frames))
    }

    /// Starts the server and returns its first lifecycle event (.ready / .portInUse / .failed).
    func start(_ server: HTTPServer, port: UInt16) async -> ServerEvent {
        await withCheckedContinuation { continuation in
            let resumed = OSAllocatedUnfairLock(initialState: false)
            server.start(interface: loopback, port: port) { event in
                switch event {
                case .ready, .portInUse, .failed:
                    if resumed.withLock({ old in defer { old = true }; return !old }) {
                        continuation.resume(returning: event)
                    }
                default:
                    break
                }
            }
        }
    }

    func fetch(_ port: UInt16, _ path: String, auth: String? = nil) async throws -> (Int, Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let auth { request.setValue(auth, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        return (http.statusCode, data, http)
    }

    @Test func servesPagesFramesAndAuth() async throws {
        let frames = FrameStore()
        let server = try makeServer(frames: frames)
        let port = UInt16.random(in: 50000...60000)
        #expect(await start(server, port: port) == .ready)
        defer { server.stop() }

        let (status, body, _) = try await fetch(port, "/")
        #expect(status == 200)
        #expect(String(decoding: body, as: UTF8.self) == "<html>hello</html>")

        #expect(try await fetch(port, "/frame.jpg?rand=0.5").0 == 503)
        frames.update(Data([0xFF, 0xD8, 0xFF, 0xD9]))
        let (jpgStatus, jpg, jpgResponse) = try await fetch(port, "/frame.jpg?rand=0.6")
        #expect(jpgStatus == 200)
        #expect(jpg == Data([0xFF, 0xD8, 0xFF, 0xD9]))
        #expect(jpgResponse.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")

        server.update(options: ServerOptions(credentials: Credentials(username: "u", password: "p")))
        #expect(try await fetch(port, "/").0 == 401)
        let auth = "Basic " + Data("u:p".utf8).base64EncodedString()
        #expect(try await fetch(port, "/", auth: auth).0 == 200)
    }

    @Test func reportsPortInUse() async throws {
        let first = try makeServer()
        let second = try makeServer()
        let port = UInt16.random(in: 50000...60000)
        #expect(await start(first, port: port) == .ready)
        defer { first.stop() }
        #expect(await start(second, port: port) == .portInUse)
        second.stop()
    }
}
