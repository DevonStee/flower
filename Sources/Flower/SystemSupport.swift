import AppKit
import Foundation
import Security

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String

    @MainActor
    static func current() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let id = CGDirectDisplayID(number.uint32Value)
            let size = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
            return DisplayInfo(id: id, name: "\(screen.localizedName) (\(size))")
        }
    }
}

enum Keychain {
    private static let service = "com.jiaqi.flower"

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func write(_ value: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }
}

enum WebRoot {
    /// Inside the .app the web UI is copied to Contents/Resources/WebServer by scripts/build-app.sh.
    /// When run via `swift run`, fall back to Resources/WebServer in the package.
    static func locate() -> URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("WebServer"),
           FileManager.default.fileExists(atPath: bundled.appendingPathComponent("index.html").path) {
            return bundled
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Sources/Flower
            .deletingLastPathComponent()  // Sources
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Resources/WebServer")
    }
}
