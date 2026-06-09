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
    let onResize: (CGSize) -> Void

    @State private var dragging: AppItem?
    @State private var launchAtLogin: Bool = false

    /// Transparent space BELOW the bar so the hover name label has room to drop
    /// down without being clipped by the screen top (the bar lives up high).
    private static let labelRoom: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            bar
            Color.clear.frame(height: Self.labelRoom)
        }
        .fixedSize()
        .background(sizeReporter)
        .onPreferenceChange(BarSizeKey.self) { onResize($0) }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            ForEach(store.items) { item in
                DockIconView(
                    item: item,
                    size: prefs.iconSize.points,
                    onActivate: { switcher.open(item) { _ in } },
                    onRemove: { store.remove(id: item.id) }
                )
                .onDrag {
                    dragging = item
                    return NSItemProvider(object: item.id as NSString)
                }
                // Each icon accepts BOTH an external .app drop (add) and an
                // internal icon drag (reorder), so dropping an app anywhere on
                // the bar works — the icons no longer shadow the add target.
                .onDrop(
                    of: [UTType.fileURL, UTType.text],
                    delegate: IconDropDelegate(target: item, store: store, resolver: resolver, dragging: $dragging)
                )
            }
            addButton
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .contextMenu { settingsMenu }
        // Fallback target for drops landing on the bar's padding / gaps.
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            addApps(from: providers, resolver: resolver, store: store)
        }
        .onAppear { launchAtLogin = loginItem.isEnabled }
    }

    private var sizeReporter: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: BarSizeKey.self, value: proxy.size)
        }
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
        .help("添加应用 / 文件 / 文件夹")
    }

    private func openPicker() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true // allow folders
        panel.canChooseFiles = true       // allow apps and any file
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let item = resolver.resolve(url: url) { store.add(item) }
            }
        }
    }
}

private struct BarSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Loads dropped `.app` URLs, resolves each to an AppItem, and adds it on the main actor.
/// Shared by the per-icon drop delegate and the bar's fallback drop target.
@discardableResult
private func addApps(from providers: [NSItemProvider], resolver: AppResolver, store: AppListStore) -> Bool {
    var accepted = false
    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        accepted = true
        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
            guard let data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  let item = resolver.resolve(url: url)
            else { return }
            DispatchQueue.main.async { store.add(item) }
        }
    }
    return accepted
}

/// Handles drops on a specific icon: an external `.app` adds it; an internal
/// icon drag reorders the list live as it passes over this icon.
private struct IconDropDelegate: DropDelegate {
    let target: AppItem
    let store: AppListStore
    let resolver: AppResolver
    @Binding var dragging: AppItem?

    func validateDrop(info: DropInfo) -> Bool {
        dragging != nil || info.hasItemsConforming(to: [UTType.fileURL])
    }

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = store.items.firstIndex(of: dragging),
              let to = store.items.firstIndex(of: target)
        else { return }
        store.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: dragging != nil ? .move : .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        let fileProviders = info.itemProviders(for: [UTType.fileURL])
        if !fileProviders.isEmpty {
            dragging = nil
            return addApps(from: fileProviders, resolver: resolver, store: store)
        }
        dragging = nil // internal reorder already applied in dropEntered
        return true
    }
}
