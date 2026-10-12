import SwiftUI

@main
struct FlowerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: .menuBarDot(active: model.isRunning))
        }

        Window("Flower", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(AppModel.showsWindowAtLaunch ? .presented : .suppressed)
    }
}

struct MenuContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

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
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate()
        }
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
