import Foundation
import Testing
@testable import FlowerCore

@Suite struct HTTPRequestTests {
    @Test func parsesRequestLineAndHeaders() {
        let raw = Data("GET /a%20b.html?x=1 HTTP/1.1\r\nHost: 1.2.3.4\r\nAuthorization:  Basic abc \r\n\r\n".utf8)
        guard case .complete(let req) = HTTPRequest.parse(raw) else {
            Issue.record("expected complete")
            return
        }
        #expect(req.method == "GET")
        #expect(req.path == "/a b.html")
        #expect(req.header("authorization") == "Basic abc")
        #expect(req.header("HOST") == "1.2.3.4")
    }

    @Test func incompleteUntilBlankLine() {
        #expect(HTTPRequest.parse(Data("GET / HTTP/1.1\r\nHost: x\r\n".utf8)) == .incomplete)
    }

    @Test(arguments: [
        "GET /\r\n\r\n",
        "GET relative HTTP/1.1\r\n\r\n",
        "GET / FTP/1.0\r\n\r\n",
        "GET / HTTP/1.1\r\nbadheader\r\n\r\n",
        "GET /%zz HTTP/1.1\r\n\r\n",
    ])
    func rejectsMalformed(raw: String) {
        #expect(HTTPRequest.parse(Data(raw.utf8)) == .invalid)
    }

    @Test func rejectsOversizedHead() {
        let raw = Data(("GET / HTTP/1.1\r\nX: " + String(repeating: "a", count: HTTPRequest.maxHeadBytes + 1)).utf8)
        #expect(HTTPRequest.parse(raw) == .invalid)
    }
}

@Suite struct HTTPResponseTests {
    @Test func serializesWithLengthAndClose() {
        let text = String(decoding: HTTPResponse(status: 200, headers: ["Content-Type": "text/plain"], body: Data("hi".utf8)).serialized(), as: UTF8.self)
        #expect(text.hasPrefix("HTTP/1.1 200 OK\r\n"))
        #expect(text.contains("Content-Length: 2\r\n"))
        #expect(text.contains("Connection: close\r\n"))
        #expect(text.hasSuffix("\r\n\r\nhi"))
    }

    @Test func headOmitsBodyButKeepsLength() {
        let text = String(decoding: HTTPResponse(status: 200, body: Data("hello".utf8)).serialized(includeBody: false), as: UTF8.self)
        #expect(text.contains("Content-Length: 5\r\n"))
        #expect(text.hasSuffix("\r\n\r\n"))
    }
}

@Suite struct BasicAuthTests {
    let expected = Credentials(username: "screen", password: "ta:sk")

    func header(_ s: String) -> String { "Basic " + Data(s.utf8).base64EncodedString() }

    @Test func acceptsMatchingCredentials() {
        #expect(BasicAuth.verify(header("screen:ta:sk"), against: expected))
        #expect(BasicAuth.verify("basic " + Data("screen:ta:sk".utf8).base64EncodedString(), against: expected))
    }

    @Test func rejectsWrongOrMalformed() {
        #expect(!BasicAuth.verify(header("screen:task"), against: expected))
        #expect(!BasicAuth.verify(header("other:ta:sk"), against: expected))
        #expect(!BasicAuth.verify(header("nocolon"), against: expected))
        #expect(!BasicAuth.verify("Basic !!!", against: expected))
        #expect(!BasicAuth.verify("Bearer abc", against: expected))
        #expect(!BasicAuth.verify(nil, against: expected))
    }
}
