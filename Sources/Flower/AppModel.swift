import AppKit
import Observation
import FlowerCore
import ServiceManagement

@MainActor
@Observable
final class AppModel {
    private static let settingsKey = "settings"
    private static let passwordAccount = "web-password"

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
            applyLiveChanges(from: oldValue)
        }
    }

    var password: String {
        didSet {
            guard password != oldValue else { return }
            Keychain.write(password, account: Self.passwordAccount)
            server.update(options: serverOptions)
        }
    }

    private(set) var isRunning = false
    private(set) var isStarting = false
    private(set) var serverURL: String?
    private(set) var logLines: [String] = []
    private(set) var interfaces: [NetworkInterfaceInfo] = []
    private(set) var displays: [DisplayInfo] = []
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    var isServerActive: Bool { isRunning || isStarting }

    private let frames = FrameStore()
    private let server: HTTPServer
    private let capturer: ScreenCapturer
    /// Interface the running server is bound to.
    private var boundInterface: NetworkInterfaceInfo?

    static var showsWindowAtLaunch: Bool { !loadSettings().autoStartServer }

    init() {
        settings = Self.loadSettings()
        password = Keychain.read(account: Self.passwordAccount) ?? "task"
        server = HTTPServer(router: Router(webRoot: WebRoot.locate(), frames: frames))
        capturer = ScreenCapturer(frames: frames)
        capturer.setQuality(settings.normalized().imageQuality)
        capturer.onStop = { [weak self] message in
            self?.log("Capture stopped: \(message)")
            self?.stop()
        }
        refreshEnvironment()
        server.update(options: serverOptions)

        if settings.autoStartServer {
            Task { await start() }
        }
    }

    // MARK: - Environment

    func refreshEnvironment() {
        interfaces = NetworkInterfaces.ipv4()
        displays = DisplayInfo.current()
        launchAtLogin = SMAppService.mainApp.status == .enabled

        if !interfaces.contains(where: { $0.address == settings.ip }),
           let recommended = NetworkInterfaces.recommended(from: interfaces) {
            settings.ip = recommended.address
        }
        if !displays.contains(where: { $0.id == settings.displayID }), let main = displays.first {
            settings.displayID = main.id
        }
    }

    // MARK: - Server lifecycle

    func toggle() {
        if isServerActive {
            stop()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        guard !isServerActive else { return }

        guard CGPreflightScreenCaptureAccess() else {
            log("Screen Recording permission is required.")
            if !CGRequestScreenCaptureAccess() {
                presentPermissionAlert()
            }
            return
        }

        refreshEnvironment()
        let s = settings.normalized()
        guard let interface = interfaces.first(where: { $0.address == s.ip }) else {
            log("No network interface available.")
            return
        }

        isStarting = true
        log("Starting server, please wait…")
        do {
            try await capturer.start(displayID: s.displayID, intervalMs: s.intervalMs, showCursor: s.showCursor)
        } catch {
            isStarting = false
            log("Failed to start capture: \(error.localizedDescription)")
            return
        }

        boundInterface = interface
        server.update(options: serverOptions)
        server.start(interface: interface, port: UInt16(s.port)) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
    }

    func stop() {
        guard isServerActive else { return }
        let wasRunning = isRunning
        server.stop()
        isRunning = false
        isStarting = false
        serverURL = nil
        boundInterface = nil
        frames.update(nil)
        Task { await capturer.stop() }
        if wasRunning { log("Server stopped.") }
    }

    private func handle(_ event: ServerEvent) {
        switch event {
        case .ready:
            guard isStarting, let interface = boundInterface else { return }
            isStarting = false
            isRunning = true
            serverURL = "http://\(interface.address):\(settings.normalized().port)"
            log("Server started: \(serverURL!)")
        case .portInUse:
            let port = settings.normalized().port
            stop()
            log("Port \(port) is already in use.")
            if confirm("Port \(port) is already in use", "Do you want to use another random port?") {
                settings.port = Int.random(in: 49152...65000)
                log("New port is \(settings.port)")
                Task { await start() }
            }
        case .failed(let message):
            stop()
            log("Server error: \(message)")
        case .rejected(let remote):
            log("Rejected connection from \(remote) (outside local subnet)")
        case .badLogin(let remote, let username):
            log("Bad login from \(remote) as \"\(username ?? "?")\"")
        }
    }

    // MARK: - Settings

    private var serverOptions: ServerOptions {
        ServerOptions(
            credentials: settings.isPrivate ? Credentials(username: settings.username, password: password) : nil,
            allowPublicAccess: settings.allowPublicAccess
        )
    }

    private func applyLiveChanges(from old: AppSettings) {
        let new = settings.normalized()
        let previous = old.normalized()
        server.update(options: serverOptions)
        capturer.setQuality(new.imageQuality)

        guard isRunning,
              new.displayID != previous.displayID || new.intervalMs != previous.intervalMs || new.showCursor != previous.showCursor
        else { return }
        Task {
            do {
                try await capturer.start(displayID: new.displayID, intervalMs: new.intervalMs, showCursor: new.showCursor)
            } catch {
                log("Failed to restart capture: \(error.localizedDescription)")
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log("Launch at login failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    // MARK: - UI helpers

    func log(_ text: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        logLines.append("\(time)  \(text)")
        if logLines.count > 500 { logLines.removeFirst(logLines.count - 500) }
    }

    func copyURL() {
        guard let serverURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(serverURL, forType: .string)
    }

    func openInBrowser() {
        guard let serverURL, let url = URL(string: serverURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func presentPermissionAlert() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission required"
        alert.informativeText = "Enable Flower in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch Flower."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func confirm(_ title: String, _ message: String) -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
