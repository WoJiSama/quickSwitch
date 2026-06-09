import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickSwitchCore

struct DockBarView: View {
    @ObservedObject var store: AppListStore
    @ObservedObject var prefs: PreferencesStore
    let switcher: AppSwitcher
    let resolver: AppResolver
    let loginItem: LoginItemControlling
    let onAlwaysOnTopChange: (Bool) -> Void

    @State private var dragging: AppItem?
    @State private var launchAtLogin: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(store.items) { item in
                DockIconView(
                    item: item,
                    size: prefs.iconSize.points,
                    onActivate: { switcher.switchTo(bundleID: item.bundleID) { _ in } },
                    onRemove: { store.remove(bundleID: item.bundleID) }
                )
                .onDrag {
                    dragging = item
                    return NSItemProvider(object: item.bundleID as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ReorderDropDelegate(target: item, store: store, dragging: $dragging)
                )
            }
            addButton
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .contextMenu { settingsMenu }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleAppDrop(providers)
        }
        .onAppear { launchAtLogin = loginItem.isEnabled }
    }

    @ViewBuilder private var settingsMenu: some View {
        Menu("图标大小") {
            ForEach(IconSize.allCases, id: \.self) { size in
                Button {
                    prefs.iconSize = size
                } label: {
                    Label(label(for: size), systemImage: prefs.iconSize == size ? "checkmark" : "")
                }
            }
        }
        Button {
            prefs.alwaysOnTop.toggle()
            onAlwaysOnTopChange(prefs.alwaysOnTop)
        } label: {
            Label("窗口置顶", systemImage: prefs.alwaysOnTop ? "checkmark" : "")
        }
        Button {
            toggleLaunchAtLogin()
        } label: {
            Label("开机自启", systemImage: launchAtLogin ? "checkmark" : "")
        }
        Divider()
        Button("退出 quickSwitch") { NSApp.terminate(nil) }
    }

    private func label(for size: IconSize) -> String {
        switch size {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    private func toggleLaunchAtLogin() {
        let next = !launchAtLogin
        do {
            try loginItem.setEnabled(next)
            launchAtLogin = next
        } catch {
            NSSound.beep()
        }
    }

    private var addButton: some View {
        Button(action: openPicker) {
            Image(systemName: "plus")
                .font(.system(size: prefs.iconSize.points * 0.5, weight: .semibold))
                .frame(width: prefs.iconSize.points, height: prefs.iconSize.points)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("添加应用")
    }

    private func openPicker() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url, let item = resolver.resolve(url: url) {
            store.add(item)
        }
    }

    private func handleAppDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let item = resolver.resolve(url: url) else { return }
                DispatchQueue.main.async { store.add(item) }
            }
        }
        return accepted
    }
}

/// Reorders items as one is dragged over another.
private struct ReorderDropDelegate: DropDelegate {
    let target: AppItem
    let store: AppListStore
    @Binding var dragging: AppItem?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = store.items.firstIndex(of: dragging),
              let to = store.items.firstIndex(of: target)
        else { return }
        store.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
