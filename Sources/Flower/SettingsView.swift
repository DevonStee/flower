import FlowerCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Server") {
                Picker("IP address", selection: $model.settings.ip) {
                    ForEach(model.interfaces) { interface in
                        Text("\(interface.address) — \(interface.name)").tag(interface.address)
                    }
                }
                .disabled(model.isServerActive)

                TextField("Port", value: $model.settings.port, format: .number.grouping(.never))
                    .disabled(model.isServerActive)

                Toggle("Allow access from outside the local subnet", isOn: $model.settings.allowPublicAccess)

                LabeledContent("URL") {
                    if let url = model.serverURL {
                        HStack {
                            Text(url).textSelection(.enabled)
                            Button("Copy") { model.copyURL() }
                            Button("Open") { model.openInBrowser() }
                        }
                    } else {
                        Text(model.isStarting ? "Starting…" : "Not running").foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("Refresh Interfaces & Displays") { model.refreshEnvironment() }
                        .disabled(model.isServerActive)
                    Spacer()
                    Button(model.isServerActive ? "Stop Server" : "Start Server") { model.toggle() }
                        .keyboardShortcut(.defaultAction)
                }
            }

            Section("Capture") {
                Picker("Display", selection: $model.settings.displayID) {
                    ForEach(model.displays) { display in
                        Text(display.name).tag(display.id)
                    }
                }

                TextField("Capture every (ms)", value: $model.settings.intervalMs, format: .number.grouping(.never))

                LabeledContent("Image quality") {
                    HStack {
                        Slider(value: qualityBinding, in: 10...100, step: 5)
                        Text("\(model.settings.imageQuality)%").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }

                Toggle("Show mouse pointer", isOn: $model.settings.showCursor)
            }

            Section("Private session") {
                Toggle("Require username and password", isOn: $model.settings.isPrivate)
                TextField("Username", text: $model.settings.username)
                    .disabled(!model.settings.isPrivate)
                SecureField("Password", text: $model.password)
                    .disabled(!model.settings.isPrivate)
            }

            Section("General") {
                Toggle("Start server automatically", isOn: $model.settings.autoStartServer)
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section("Log") {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(model.logLines.enumerated()), id: \.offset) { index, line in
                                Text(line).id(index)
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                    .onChange(of: model.logLines.count) { _, count in
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onAppear { if !model.isServerActive { model.refreshEnvironment() } }
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { Double(model.settings.imageQuality) },
            set: { model.settings.imageQuality = Int($0) }
        )
    }
}
