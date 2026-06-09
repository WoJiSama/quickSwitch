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

    /// Drop types we accept for ADDING an entry (apps/files/folders + web links).
    private static let addTypes: [UTType] = [.fileURL, .url]

    var body: some View {
        VStack(spacing: 0) {
            bar
            Color.clear.frame(height: Self.labelRoom)
        }
        .fixedSize()
        .contentShape(Rectangle())
        // Whole-window drop target — covers the bar AND the transparent label
        // area below it, so an app/file/folder/link dropped anywhere lands
        // (e.g. dragged up from the Dock, entering via the lower region).
        .onDrop(of: Self.addTypes, isTargeted: nil) { providers in
            addItems(from: providers, resolver: resolver, store: store)
        }
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
                // Each icon accepts an external add (app/file/folder/link) and an
                // internal icon drag (reorder), so dropping anywhere on the bar works.
                .onDrop(
                    of: [UTType.fileURL, UTType.url, UTType.text],
                    delegate: IconDropDelegate(target: item, store: store, resolver: resolver, dragging: $dragging)
                )
            }
            addButton
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .contextMenu { settingsMenu }
        .onAppear { launchAtLogin = loginItem.isEnabled }
    }

    private var sizeReporter: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: BarSizeKey.self, value: proxy.size)
        }
    }

    @ViewBuilder private var settingsMenu: some View {
        Menu("添加正在运行的应用") {
            ForEach(runningApps(), id: \.bundleID) { app in
                Button(app.name) {
                    store.add(AppItem(bundleID: app.bundleID, displayName: app.name))
                }
            }
        }
        Divider()
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

    /// Currently-running, user-facing apps — a reliable way to add what's in the Dock
    /// without fighting the Dock's non-standard drag source.
    private func runningApps() -> [(bundleID: String, name: String)] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (bundleID: String, name: String)? in
                guard let bundleID = app.bundleIdentifier, seen.insert(bundleID).inserted else { return nil }
                return (bundleID, app.localizedName ?? bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

/// Loads dropped file/web URLs, resolves each to an AppItem, and adds it on the
/// main actor. Shared by the per-icon drop delegate and the window drop target.
@discardableResult
private func addItems(from providers: [NSItemProvider], resolver: AppResolver, store: AppListStore) -> Bool {
    var accepted = false
    for provider in providers {
        let typeID: String
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            typeID = UTType.fileURL.identifier
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            typeID = UTType.url.identifier
        } else {
            continue
        }
        accepted = true
        provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
            guard let data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  let item = resolver.resolve(url: url)
            else { return }
            DispatchQueue.main.async { store.add(item) }
        }
    }
    return accepted
}

/// Handles drops on a specific icon: an external app/file/folder/link adds it;
/// an internal icon drag reorders the list live as it passes over this icon.
private struct IconDropDelegate: DropDelegate {
    let target: AppItem
    let store: AppListStore
    let resolver: AppResolver
    @Binding var dragging: AppItem?

    func validateDrop(info: DropInfo) -> Bool {
        dragging != nil || info.hasItemsConforming(to: [UTType.fileURL, UTType.url])
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
        let providers = info.itemProviders(for: [UTType.fileURL, UTType.url])
        if !providers.isEmpty {
            dragging = nil
            return addItems(from: providers, resolver: resolver, store: store)
        }
        dragging = nil // internal reorder already applied in dropEntered
        return true
    }
}
