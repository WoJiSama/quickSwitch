import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickSwitchCore

struct DockBarView: View {
    @ObservedObject var store: AppListStore
    @ObservedObject var prefs: PreferencesStore
    @ObservedObject var feedback: FeedbackCenter
    @ObservedObject var dockState: DockState
    let switcher: AppSwitcher
    let resolver: AppResolver
    let onResize: (CGSize) -> Void
    let windowOrigin: () -> CGPoint
    let moveWindow: (CGPoint) -> Void
    let onOpenSettings: () -> Void
    let onOpenHelp: () -> Void
    let showHoverName: (String?) -> Void
    let onMoveEnded: () -> Void
    let onReset: () -> Void

    @State private var dragging: AppItem?
    @State private var shake: CGFloat = 0
    @State private var rejectFlash = false
    @State private var summonDip = false
    @State private var summonFlash = false

    /// Drop types we accept for ADDING an entry (apps/files/folders + web links).
    private static let addTypes: [UTType] = [.fileURL, .url]

    var body: some View {
        bar
            .fixedSize()
            .contentShape(Rectangle())
            .onDrop(of: Self.addTypes, isTargeted: nil) { providers in
                addDroppedItems(providers)
            }
            .background(sizeReporter)
            .onPreferenceChange(BarSizeKey.self) { onResize($0) }
            .onChange(of: feedback.tick) { _ in
                guard feedback.event == .rejected else { return }
                if prefersReducedMotion {
                    // Non-motion rejection feedback: brief red border instead of a shake.
                    rejectFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { rejectFlash = false }
                } else {
                    withAnimation(.linear(duration: 0.4)) { shake += 1 }
                }
            }
            .onChange(of: dockState.summonPulse) { _ in
                // "Hotkey received" acknowledgment: accent border flash + a quick
                // press-down/bounce-back dip (dip skipped under Reduce Motion).
                summonFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { summonFlash = false }
                guard !prefersReducedMotion else { return }
                withAnimation(.easeOut(duration: 0.08)) { summonDip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { summonDip = false }
                }
            }
    }

    private var bar: some View {
        let layout = prefs.axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: CGFloat(prefs.spacing)))
            : AnyLayout(VStackLayout(spacing: CGFloat(prefs.spacing)))
        return layout {
            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                DockIconView(
                    item: item,
                    size: CGFloat(prefs.iconSize),
                    axis: prefs.axis,
                    hideIfFrontmost: prefs.clickFrontmostHides,
                    badge: (dockState.showDigitBadges && prefs.digitHotKeysEnabled && index < 9)
                        ? index + 1 : nil,
                    switcher: switcher,
                    feedback: feedback,
                    onHoverName: showHoverName,
                    onRename: { store.rename(id: item.id, to: $0) },
                    onRemove: {
                        withMotion(.spring(response: 0.3, dampingFraction: 0.72)) {
                            store.remove(id: item.id)
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .onDrag {
                    dragging = item
                    return NSItemProvider(object: item.id as NSString)
                }
                .onDrop(
                    of: [UTType.fileURL, UTType.url, UTType.text],
                    delegate: IconDropDelegate(
                        target: item, store: store, resolver: resolver,
                        feedback: feedback, dragging: $dragging
                    )
                )
            }
            if store.items.isEmpty { emptyHint }
            // Always reachable while the bar is empty, regardless of the toggle —
            // otherwise an empty bar with the + hidden becomes a dead end.
            if prefs.showAddButton || store.items.isEmpty { addMenu }
        }
        .padding(CGFloat(prefs.padding))
        // The drag/menu layer is the ENTIRE bar background (incl. the padding margin),
        // behind the icons: dragging any empty spot moves the window, right-click opens
        // settings. Icons in front consume their own taps/drags.
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: CGFloat(prefs.cornerRadius), style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(prefs.backgroundOpacity)
                WindowDragHandle(windowOrigin: windowOrigin, moveWindow: moveWindow, onMoveEnded: onMoveEnded)
                    .contextMenu { settingsMenu }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(prefs.cornerRadius), style: .continuous)
                .strokeBorder(Color.red.opacity(rejectFlash ? 0.8 : 0), lineWidth: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(prefs.cornerRadius), style: .continuous)
                .strokeBorder(Color.accentColor.opacity(summonFlash ? 0.9 : 0), lineWidth: 2)
        }
        // Steady "选择中" highlight while the digit modifier is held — drawn as an
        // INSET border + fill so it never spills past the window edge (no outer glow
        // or scale-up, which clipped against the content-sized window).
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(prefs.cornerRadius), style: .continuous)
                .strokeBorder(Color.accentColor.opacity(dockState.digitSelecting ? 0.95 : 0), lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(prefs.cornerRadius), style: .continuous)
                        .fill(Color.accentColor.opacity(dockState.digitSelecting ? 0.12 : 0))
                )
        }
        .scaleEffect(summonDip ? 0.94 : 1)
        .animation(prefersReducedMotion ? nil : .easeOut(duration: 0.15),
                   value: dockState.digitSelecting)
        .animation(prefersReducedMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                   value: dockState.showDigitBadges)
        // High-contrast indicator on the peeking edge when docked & hidden, so the
        // sliver stays visible on light backgrounds — sized to the bar's length.
        .overlay {
            if dockState.mode != .floating && !dockState.revealed {
                GeometryReader { geo in
                    edgeIndicator(size: geo.size)
                }
                .allowsHitTesting(false)
            }
        }
        .modifier(Shake(animatableData: shake))
    }

    private func edgeIndicator(size: CGSize) -> some View {
        let alignment: Alignment = dockState.mode == .left ? .trailing : .leading
        let handleHeight = min(max(28, size.height * 0.4), max(28, size.height - 12))
        return ZStack {
            // Faint full-length strip so the whole hoverable sliver reads on any background.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor.opacity(0.4))
                .frame(width: 3, height: max(20, size.height - 16))
            // Bright capsule marking the center grab point.
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 5, height: handleHeight)
                .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.35), radius: 2)
        }
        .frame(width: size.width, height: size.height, alignment: alignment)
        .padding(.horizontal, 1)
    }

    private var emptyHint: some View {
        Text("拖入应用 / 文件,或右键打开菜单")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize()
            .padding(.horizontal, 4)
    }

    private var sizeReporter: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: BarSizeKey.self, value: proxy.size)
        }
    }

    @discardableResult
    private func addDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        dragging = nil // an external drop ends any stale internal-drag state
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
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    addItem(from: url, resolver: resolver, store: store, feedback: feedback)
                }
            }
        }
        return accepted
    }

    // MARK: - Menus

    @ViewBuilder private var addMenuItems: some View {
        Menu("添加正在运行的应用") {
            ForEach(runningApps(), id: \.bundleID) { app in
                Button(app.name) {
                    let item = AppItem(bundleID: app.bundleID, displayName: app.name)
                    withMotion(.spring(response: 0.3, dampingFraction: 0.72)) {
                        if store.add(item) == .duplicate { feedback.duplicate(item.id) }
                    }
                }
            }
        }
        Button("添加文件 / 应用…") { openPicker() }
        Button("添加网址…") { promptAddURL() }
    }

    @ViewBuilder private var settingsMenu: some View {
        addMenuItems
        Divider()
        Button("设置…") { onOpenSettings() }
        Button("使用教程") { onOpenHelp() }
        Divider()
        Button("重置并重启 quickSwitch") { onReset() }
        Button("退出 quickSwitch") { NSApp.terminate(nil) }
    }

    /// The + control: a menu covering every add path (running apps / files / URLs),
    /// so the most discoverable button exposes the full capability.
    private var addMenu: some View {
        Menu {
            addMenuItems
        } label: {
            Image(systemName: "plus")
                .font(.system(size: CGFloat(prefs.iconSize) * 0.5, weight: .semibold))
                .frame(width: CGFloat(prefs.iconSize), height: CGFloat(prefs.iconSize))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("添加应用 / 文件 / 网址")
        .accessibilityLabel("添加应用、文件或网址")
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

    private func openPicker() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                addItem(from: url, resolver: resolver, store: store, feedback: feedback)
            }
        }
    }

    /// Reliable way to add a web page without fighting tab/Dock drag: paste a link.
    private func promptAddURL() {
        let alert = NSAlert()
        alert.messageText = "添加网址"
        alert.informativeText = "粘贴一个网页链接(http/https),点它会用默认浏览器打开。"
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://example.com"
        if let clip = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           clip.contains("://") || clip.contains(".") {
            field.stringValue = clip
        }
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        var text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.contains("://") { text = "https://" + text }
        if let url = URL(string: text) {
            addItem(from: url, resolver: resolver, store: store, feedback: feedback)
        } else {
            feedback.rejected()
        }
    }
}

private struct BarSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Handles drops on a specific icon: an external app/file/folder/link adds it (with
/// feedback); an internal icon drag reorders the list live as it passes over this icon.
private struct IconDropDelegate: DropDelegate {
    let target: AppItem
    let store: AppListStore
    let resolver: AppResolver
    let feedback: FeedbackCenter
    @Binding var dragging: AppItem?

    func validateDrop(info: DropInfo) -> Bool {
        dragging != nil || info.hasItemsConforming(to: [UTType.fileURL, UTType.url])
    }

    func dropEntered(info: DropInfo) {
        // Only reorder for INTERNAL drags. An external file/url drag must never
        // reorder — even if a stale `dragging` value survived a cancelled drag.
        guard !info.hasItemsConforming(to: [UTType.fileURL, UTType.url]),
              let dragging, dragging != target,
              let from = store.items.firstIndex(of: dragging),
              let to = store.items.firstIndex(of: target)
        else { return }
        withMotion(.spring(response: 0.28, dampingFraction: 0.72)) {
            store.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: dragging != nil ? .move : .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.fileURL, UTType.url])
        if !providers.isEmpty {
            dragging = nil
            for provider in providers {
                let typeID = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                    ? UTType.fileURL.identifier : UTType.url.identifier
                provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        addItem(from: url, resolver: resolver, store: store, feedback: feedback)
                    }
                }
            }
            return true
        }
        dragging = nil // internal reorder already applied in dropEntered
        return true
    }
}
