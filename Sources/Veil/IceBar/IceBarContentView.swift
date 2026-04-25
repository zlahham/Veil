import SwiftUI

/// Ice Bar contents — a flat list of every menu bar extra Veil can see.
/// Click activates the owning app. Hiding is controlled by the section
/// dividers in the menu bar (cmd+drag to position them).
struct IceBarContentView: View {
    @ObservedObject var itemStore: MenuBarItemStore
    @State private var needsPermission: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cmd-drag items in the menu bar to arrange which ones sit left of the chevron (hideable) vs right (always visible).")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                if needsPermission {
                    Label("Grant Accessibility to list items.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.bottom, 4)
                }

                if itemStore.items.isEmpty {
                    Text("No menu bar items found")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(itemStore.items) { item in
                        itemRow(item)
                    }
                }
            }
            .padding(10)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { refresh() }
    }

    @ViewBuilder
    private func itemRow(_ item: MenuBarItem) -> some View {
        Button {
            NSRunningApplication(processIdentifier: item.pid)?.activate()
        } label: {
            HStack(spacing: 8) {
                if let app = NSRunningApplication(processIdentifier: item.pid), let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.dashed")
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                }
                Text(displayName(for: item))
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func displayName(for item: MenuBarItem) -> String {
        if !item.title.isEmpty { return item.title }
        let last = item.bundleID.split(separator: ".").last.map(String.init) ?? item.bundleID
        return last.capitalized
    }

    private func refresh() {
        needsPermission = !Permissions.isAccessibilityGranted
        itemStore.refresh()
    }
}
