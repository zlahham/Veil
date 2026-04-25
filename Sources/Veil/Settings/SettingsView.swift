import SwiftUI

struct SettingsView: View {
    let itemStore: MenuBarItemStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 440, minHeight: 360)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Veil")
                .font(.title)
                .fontWeight(.semibold)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .foregroundStyle(.secondary)
            }

            Text("A lightweight menu bar manager for macOS")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .frame(width: 380, height: 200)
    }
}
