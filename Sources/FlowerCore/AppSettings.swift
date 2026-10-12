import Foundation

/// User settings. The password is stored separately in the Keychain.
public struct AppSettings: Codable, Equatable, Sendable {
    public var ip: String = ""
    public var port: Int = 7070
    public var intervalMs: Int = 500
    public var imageQuality: Int = 75
    /// CGDirectDisplayID of the shared display; 0 means the main display.
    public var displayID: UInt32 = 0
    public var showCursor: Bool = true
    public var isPrivate: Bool = false
    public var username: String = "screen"
    public var allowPublicAccess: Bool = false
    public var autoStartServer: Bool = false
    public var showMenuBarIcon: Bool = true

    public static let portRange = 1...65535
    public static let intervalRange = 50...10_000
    public static let qualityRange = 10...100

    public init() {}

    /// Decodes leniently so settings saved by older versions (missing keys) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        ip = try c.decodeIfPresent(String.self, forKey: .ip) ?? d.ip
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? d.port
        intervalMs = try c.decodeIfPresent(Int.self, forKey: .intervalMs) ?? d.intervalMs
        imageQuality = try c.decodeIfPresent(Int.self, forKey: .imageQuality) ?? d.imageQuality
        displayID = try c.decodeIfPresent(UInt32.self, forKey: .displayID) ?? d.displayID
        showCursor = try c.decodeIfPresent(Bool.self, forKey: .showCursor) ?? d.showCursor
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? d.isPrivate
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? d.username
        allowPublicAccess = try c.decodeIfPresent(Bool.self, forKey: .allowPublicAccess) ?? d.allowPublicAccess
        autoStartServer = try c.decodeIfPresent(Bool.self, forKey: .autoStartServer) ?? d.autoStartServer
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? d.showMenuBarIcon
    }

    /// Clamps numeric fields into their valid ranges.
    public func normalized() -> AppSettings {
        var s = self
        s.port = s.port.clamped(to: Self.portRange)
        s.intervalMs = s.intervalMs.clamped(to: Self.intervalRange)
        s.imageQuality = s.imageQuality.clamped(to: Self.qualityRange)
        return s
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
