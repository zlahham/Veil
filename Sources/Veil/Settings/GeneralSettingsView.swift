import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("showOnHover") private var showOnHover = false
    @AppStorage("showOnClick") private var showOnClick = true
    @AppStorage("showOnScroll") private var showOnScroll = false
    @AppStorage("autoRehide") private var autoRehide = true
    @AppStorage("rehideInterval") private var rehideInterval = 3.0
    @AppStorage("useIceBar") private var useIceBar = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("iconStyle") private var iconStyleRaw = VeilIcon.bolt.rawValue

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Icon", selection: $iconStyleRaw) {
                    ForEach(VeilIcon.allCases) { icon in
                        HStack {
                            Image(systemName: icon.previewSymbol)
                            Text(icon.displayName)
                        }
                        .tag(icon.rawValue)
                    }
                }
                .onChange(of: iconStyleRaw) { _, _ in
                    NotificationCenter.default.post(name: .veilIconChanged, object: nil)
                }
            }

            Section("Reveal Hidden Items") {
                Toggle("Show on hover", isOn: $showOnHover)
                Toggle("Show on click", isOn: $showOnClick)
                Toggle("Show on scroll", isOn: $showOnScroll)
            }

            Section("Auto-Rehide") {
                Toggle("Automatically rehide", isOn: $autoRehide)
                if autoRehide {
                    HStack {
                        Text("Delay")
                        Slider(value: $rehideInterval, in: 1...15, step: 0.5)
                        Text("\(rehideInterval, specifier: "%.1f")s")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section("Ice Bar") {
                Toggle("Show hidden items in Ice Bar", isOn: $useIceBar)
                    .help("Display hidden menu bar items in a panel below the menu bar")
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                HStack {
                    Text("Accessibility")
                    Spacer()
                    if Permissions.isAccessibilityGranted {
                        Text("Granted")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant Access") {
                            Permissions.promptForAccessibility()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert on failure
            launchAtLogin = !enabled
        }
    }
}
