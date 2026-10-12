import Foundation
import Testing
@testable import FlowerCore

@Suite struct NetworkTests {
    @Test func parsesIPv4() {
        #expect(IPv4.parse("192.168.1.10") == 0xC0A8_010A)
        #expect(IPv4.parse("not an ip") == nil)
        #expect(IPv4.fromBytes([192, 168, 1, 10]) == 0xC0A8_010A)
        #expect(IPv4.fromBytes([1, 2, 3]) == nil)
    }

    @Test(arguments: [("10.0.0.1", true), ("172.16.5.4", true), ("172.31.255.1", true), ("172.32.0.1", false),
                      ("192.168.0.2", true), ("8.8.8.8", false)])
    func privateRanges(address: String, expected: Bool) {
        #expect(NetworkInterfaces.isPrivate(address) == expected)
    }

    @Test func recommendsPrivateNonLoopback() {
        let list = [
            NetworkInterfaceInfo(name: "utun0", address: "100.64.0.2", netmask: "255.255.255.255"),
            NetworkInterfaceInfo(name: "en0", address: "192.168.1.5", netmask: "255.255.255.0"),
            NetworkInterfaceInfo(name: "lo0", address: "127.0.0.1", netmask: "255.0.0.0", isLoopback: true),
        ]
        #expect(NetworkInterfaces.recommended(from: list)?.name == "en0")
        #expect(NetworkInterfaces.recommended(from: [list[2]])?.name == "lo0")
        #expect(NetworkInterfaces.recommended(from: []) == nil)
    }

    @Test func enumeratesLoopbackLast() {
        let list = NetworkInterfaces.ipv4()
        #expect(list.contains(where: { $0.address == "127.0.0.1" && $0.isLoopback }))
        if let firstLoopback = list.firstIndex(where: \.isLoopback) {
            let tailIsLoopback = list[firstLoopback...].allSatisfy { $0.isLoopback }
            #expect(tailIsLoopback)
        }
    }

    @Test func accessPolicyLimitsToSubnet() {
        let en0 = NetworkInterfaceInfo(name: "en0", address: "192.168.1.5", netmask: "255.255.255.0")
        #expect(AccessPolicy.isAllowed(remote: IPv4.parse("192.168.1.77")!, interface: en0, allowPublicAccess: false))
        #expect(AccessPolicy.isAllowed(remote: IPv4.parse("127.0.0.1")!, interface: en0, allowPublicAccess: false))
        #expect(!AccessPolicy.isAllowed(remote: IPv4.parse("192.168.2.77")!, interface: en0, allowPublicAccess: false))
        #expect(AccessPolicy.isAllowed(remote: IPv4.parse("8.8.8.8")!, interface: en0, allowPublicAccess: true))
    }
}

@Suite struct AppSettingsTests {
    @Test func decodesMissingKeysWithDefaults() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"port": 8080, "isPrivate": true}"#.utf8))
        #expect(s.port == 8080)
        #expect(s.isPrivate)
        #expect(s.intervalMs == 500)
        #expect(s.username == "screen")
        #expect(s.showMenuBarIcon)
    }

    @Test func roundTrips() throws {
        var s = AppSettings()
        s.ip = "10.0.0.2"
        s.displayID = 42
        let decoded = try JSONDecoder().decode(AppSettings.self, from: try JSONEncoder().encode(s))
        #expect(decoded == s)
    }

    @Test func normalizesRanges() {
        var s = AppSettings()
        s.port = 0
        s.intervalMs = 1
        s.imageQuality = 500
        let n = s.normalized()
        #expect(n.port == 1)
        #expect(n.intervalMs == 50)
        #expect(n.imageQuality == 100)
    }
}
