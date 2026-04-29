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
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 12) {
            // Bypass macOS's app-icon styling pipeline (which adds Liquid
            // Glass bevel on Tahoe) by loading the raw .icns directly.
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let raw = NSImage(contentsOf: url) {
                Image(nsImage: raw)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
            }

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

            updateStatus
                .padding(.top, 8)
        }
        .frame(width: 380, height: 240)
        .onAppear { updateChecker.checkNow() }
    }

    @ViewBuilder
    private var updateStatus: some View {
        if updateChecker.updateAvailable, let tag = updateChecker.latestVersion {
            Button {
                NSWorkspace.shared.open(updateChecker.downloadURL)
            } label: {
                Label("Update available — \(tag)", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else if updateChecker.latestVersion != nil {
            Label("You're on the latest version", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
