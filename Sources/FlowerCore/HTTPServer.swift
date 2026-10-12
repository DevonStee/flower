import Foundation
import Network
import os

public enum ServerEvent: Sendable, Equatable {
    case ready
    case portInUse
    case failed(String)
    case rejected(remote: String)
    case badLogin(remote: String, username: String?)
}

public struct ServerOptions: Sendable, Equatable {
    /// Required credentials, or nil for a public session.
    public var credentials: Credentials?
    public var allowPublicAccess: Bool

    public init(credentials: Credentials? = nil, allowPublicAccess: Bool = false) {
        self.credentials = credentials
        self.allowPublicAccess = allowPublicAccess
    }
}

/// Minimal HTTP/1.1 server on Network.framework, bound to a single interface address.
public final class HTTPServer: @unchecked Sendable {
    private let router: Router
    private let queue = DispatchQueue(label: "Flower.HTTPServer")
    private let options = OSAllocatedUnfairLock(initialState: ServerOptions())
    /// Only touched on `queue`.
    private var listener: NWListener?

    public init(router: Router) {
        self.router = router
    }

    /// Options can change while running (e.g. toggling the private session).
    public func update(options newValue: ServerOptions) {
        options.withLock { $0 = newValue }
    }

    public func start(interface: NetworkInterfaceInfo, port: UInt16, events: @escaping @Sendable (ServerEvent) -> Void) {
        queue.async { [self] in
            listener?.cancel()
            listener = nil

            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                events(.failed("Invalid port \(port)"))
                return
            }
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(interface.address), port: nwPort)

            let newListener: NWListener
            do {
                newListener = try NWListener(using: params)
            } catch {
                events(Self.event(for: error))
                return
            }

            newListener.stateUpdateHandler = { [weak self, weak newListener] state in
                switch state {
                case .ready:
                    events(.ready)
                case .failed(let error), .waiting(let error):
                    events(Self.event(for: error))
                    newListener?.cancel()
                    if let self, self.listener === newListener { self.listener = nil }
                default:
                    break
                }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection, interface: interface, events: events)
            }
            listener = newListener
            newListener.start(queue: queue)
        }
    }

    public func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
        }
    }

    private static func event(for error: Error) -> ServerEvent {
        if case NWError.posix(let code) = error, code == .EADDRINUSE {
            return .portInUse
        }
        return .failed(error.localizedDescription)
    }

    private func accept(_ connection: NWConnection, interface: NetworkInterfaceInfo, events: @escaping @Sendable (ServerEvent) -> Void) {
        let current = options.withLock { $0 }
        let remote = Self.remoteAddress(of: connection)
        let remoteDescription = remote.description

        guard let ip = remote.ipv4,
              AccessPolicy.isAllowed(remote: ip, interface: interface, allowPublicAccess: current.allowPublicAccess)
        else {
            events(.rejected(remote: remoteDescription))
            connection.cancel()
            return
        }

        let handler = ConnectionHandler(connection: connection, queue: queue) { [router, options] request in
            let credentials = options.withLock { $0.credentials }
            let response = router.handle(request, credentials: credentials)
            if response.status == 401, request.header("Authorization") != nil {
                events(.badLogin(remote: remoteDescription, username: BasicAuth.decode(request.header("Authorization"))?.username))
            }
            return response
        }
        handler.start()
    }

    private struct RemoteAddress: CustomStringConvertible {
        var ipv4: UInt32?
        var description: String
    }

    private static func remoteAddress(of connection: NWConnection) -> RemoteAddress {
        guard case .hostPort(let host, _) = connection.endpoint else {
            return RemoteAddress(ipv4: nil, description: "\(connection.endpoint)")
        }
        switch host {
        case .ipv4(let addr):
            return RemoteAddress(ipv4: IPv4.fromBytes(addr.rawValue), description: "\(addr)")
        case .ipv6(let addr):
            return RemoteAddress(ipv4: addr.asIPv4.flatMap { IPv4.fromBytes($0.rawValue) }, description: "\(addr)")
        default:
            return RemoteAddress(ipv4: nil, description: "\(host)")
        }
    }
}

/// Reads one request head, writes one response, closes. All callbacks run on the server queue.
private final class ConnectionHandler: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let respond: @Sendable (HTTPRequest) -> HTTPResponse
    private var buffer = Data()

    init(connection: NWConnection, queue: DispatchQueue, respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) {
        self.connection = connection
        self.queue = queue
        self.respond = respond
    }

    func start() {
        connection.start(queue: queue)
        // Drop clients that never finish sending a request head.
        queue.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.connection.cancel()
        }
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [self] data, _, isComplete, error in
            if let data { buffer.append(data) }
            switch HTTPRequest.parse(buffer) {
            case .complete(let request):
                send(respond(request), includeBody: request.method != "HEAD")
            case .invalid:
                let status = buffer.count > HTTPRequest.maxHeadBytes ? 431 : 400
                send(.html(status: status, "<h1>\(status) \(HTTPResponse.reasonPhrase(for: status))</h1>"), includeBody: true)
            case .incomplete:
                if isComplete || error != nil {
                    connection.cancel()
                } else {
                    receive()
                }
            }
        }
    }

    private func send(_ response: HTTPResponse, includeBody: Bool) {
        connection.send(content: response.serialized(includeBody: includeBody), completion: .contentProcessed { [self] _ in
            connection.cancel()
        })
    }
}
