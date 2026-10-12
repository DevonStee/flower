import SwiftUI

@main
struct FlowerApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        @Bindable var model = delegate.model
        MenuBarExtra(isInserted: $model.settings.showMenuBarIcon) {
            MenuContent(model: model, settingsWindow: delegate.settingsWindow)
        } label: {
            Image(nsImage: .menuBarDot(active: model.isRunning))
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    lazy var settingsWindow = SettingsWindowController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppModel.showsWindowAtLaunch {
            settingsWindow.show()
        }
    }

    /// Opening Flower again (Spotlight, Launchpad, Finder) brings up the settings window —
    /// the only way back in when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }
}

/// AppKit-owned settings window, so it can be shown without a menu bar entry point.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(model: AppModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = []
        window = NSWindow(contentViewController: hosting)
        window.title = "Flower"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 480, height: 640))
        window.contentMinSize = NSSize(width: 480, height: 320)
        window.contentMaxSize = NSSize(width: 480, height: 2000)
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

struct MenuContent: View {
    let model: AppModel
    let settingsWindow: SettingsWindowController

    var body: some View {
        if let url = model.serverURL {
            Text("Sharing at \(url)")
            Button("Copy URL") { model.copyURL() }
            Button("Open in Browser") { model.openInBrowser() }
        } else {
            Text(model.isStarting ? "Starting…" : "Server stopped")
        }
        Divider()
        Button(model.isServerActive ? "Stop Server" : "Start Server") { model.toggle() }
            .keyboardShortcut("s")
        Button("Settings…") { settingsWindow.show() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Flower") {
            model.stop()
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

extension NSImage {
    /// A single period-sized dot: solid while sharing, faint while stopped.
    static func menuBarDot(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            NSColor.black.withAlphaComponent(active ? 1 : 0.35).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.midX - 2, y: rect.midY - 2, width: 4, height: 4)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
