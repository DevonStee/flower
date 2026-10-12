import Darwin
import Foundation

public struct NetworkInterfaceInfo: Hashable, Identifiable, Sendable {
    public var name: String
    public var address: String
    public var netmask: String
    public var isLoopback: Bool

    public var id: String { "\(name)-\(address)" }

    public init(name: String, address: String, netmask: String, isLoopback: Bool = false) {
        self.name = name
        self.address = address
        self.netmask = netmask
        self.isLoopback = isLoopback
    }
}

public enum NetworkInterfaces {
    /// All IPv4 addresses on interfaces that are up, loopback last.
    public static func ipv4() -> [NetworkInterfaceInfo] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var result: [NetworkInterfaceInfo] = []
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            let flags = Int32(ifa.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0,
                  let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  let address = string(from: addr), let mask = ifa.ifa_netmask.flatMap(string(from:))
            else { continue }
            result.append(NetworkInterfaceInfo(
                name: String(cString: ifa.ifa_name),
                address: address,
                netmask: mask,
                isLoopback: flags & IFF_LOOPBACK != 0
            ))
        }
        return result.filter { !$0.isLoopback } + result.filter(\.isLoopback)
    }

    /// Prefers a private LAN address (192.168/10/172.16-31), then any non-loopback, then loopback.
    public static func recommended(from interfaces: [NetworkInterfaceInfo]) -> NetworkInterfaceInfo? {
        let nonLoopback = interfaces.filter { !$0.isLoopback }
        return nonLoopback.first(where: { isPrivate($0.address) }) ?? nonLoopback.first ?? interfaces.first
    }

    public static func isPrivate(_ address: String) -> Bool {
        guard let ip = IPv4.parse(address) else { return false }
        return ip >> 24 == 10
            || ip >> 20 == (172 << 4 | 1)  // 172.16.0.0/12
            || ip >> 16 == (192 << 8 | 168)
    }

    private static func string(from addr: UnsafeMutablePointer<sockaddr>) -> String? {
        guard addr.pointee.sa_family == UInt8(AF_INET) else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let ok = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin -> Bool in
            var inAddr = sin.pointee.sin_addr
            return inet_ntop(AF_INET, &inAddr, &buffer, socklen_t(buffer.count)) != nil
        }
        return ok ? String(decoding: buffer.prefix(while: { $0 != 0 }).map(UInt8.init(bitPattern:)), as: UTF8.self) : nil
    }
}

public enum IPv4 {
    /// Parses dotted-quad notation into a host-order integer.
    public static func parse(_ string: String) -> UInt32? {
        var addr = in_addr()
        guard inet_pton(AF_INET, string, &addr) == 1 else { return nil }
        return UInt32(bigEndian: addr.s_addr)
    }

    /// Builds a host-order integer from 4 network-order bytes.
    public static func fromBytes<C: Collection>(_ bytes: C) -> UInt32? where C.Element == UInt8 {
        guard bytes.count == 4 else { return nil }
        return bytes.reduce(0) { $0 << 8 | UInt32($1) }
    }
}

/// Replaces the original Windows firewall rule (remoteip=localsubnet vs any).
public enum AccessPolicy {
    public static func isAllowed(remote: UInt32, interface: NetworkInterfaceInfo, allowPublicAccess: Bool) -> Bool {
        if allowPublicAccess { return true }
        if remote >> 24 == 127 { return true }
        guard let local = IPv4.parse(interface.address), let mask = IPv4.parse(interface.netmask) else { return false }
        return remote & mask == local & mask
    }
}
