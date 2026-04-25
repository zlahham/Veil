import SwiftUI

struct HotkeySettingsView: View {
    @State private var toggleHideHotkey: KeyCombination?
    @State private var recording: Bool = false

    var body: some View {
        Form {
            Section("Global Hotkeys") {
                HStack {
                    Text("Toggle hide items")
                    Spacer()
                    if recording {
                        HotkeyRecorderView { combo in
                            setHotkey(combo)
                            recording = false
                        }
                        .frame(width: 120, height: 24)
                    } else {
                        Button {
                            recording = true
                        } label: {
                            Text(toggleHideHotkey?.displayString ?? "None")
                                .frame(width: 100)
                        }
                    }
                    if toggleHideHotkey != nil {
                        Button(role: .destructive) {
                            setHotkey(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .onAppear { loadHotkey() }
    }

    private static let key = "hotkey.toggleHide"

    private func loadHotkey() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let combo = try? JSONDecoder().decode(KeyCombination.self, from: data) {
            toggleHideHotkey = combo
        }
    }

    private func setHotkey(_ combo: KeyCombination?) {
        toggleHideHotkey = combo
        if let combo, let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
        NotificationCenter.default.post(name: .veilHotkeysChanged, object: nil)
    }
}
