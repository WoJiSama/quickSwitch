import SwiftUI
import AppKit
import QuickSwitchCore

/// One dock icon: click to open (Button-based, so jittery clicks still register;
/// pressed state scales down; red flash on failure; dims while launching), hover to
/// magnify and show its name via the floating tooltip, right-click to rename/remove.
/// Grays out when the target is unavailable; flashes a ring on duplicate add.
struct DockIconView: View {
    let item: AppItem
    let size: CGFloat
    let axis: DockAxis
    let hideIfFrontmost: Bool
    let switcher: AppSwitcher
    @ObservedObject var feedback: FeedbackCenter
    let onHoverName: (String?) -> Void
    let onRename: (String) -> Void
    let onRemove: () -> Void

    @State private var isHovering = false
    @State private var isOpening = false
    @State private var failFlash = false
    @State private var dupFlash = false

    private static let hoverScale: CGFloat = 1.18
    private static let hoverLift: CGFloat = 3

    // Lift "out of" the bar: horizontal pops up, vertical stays put (lifting up would
    // overlap the icon above it).
    private var hoverOffsetY: CGFloat {
        guard isHovering, axis == .horizontal else { return 0 }
        return -Self.hoverLift
    }

    var body: some View {
        let available = IconLoader.isAvailable(for: item)
        Button(action: activate) {
            iconImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .grayscale(available ? 0 : 1)
                .opacity(available ? (isOpening ? 0.7 : 1) : 0.5)
                .scaleEffect(isHovering ? Self.hoverScale : 1.0)
                .offset(y: hoverOffsetY)
                .shadow(color: .black.opacity(isHovering ? 0.30 : 0), radius: 5, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.red.opacity(failFlash ? 0.35 : 0))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(dupFlash ? 0.9 : 0), lineWidth: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableIconStyle())
        .onHover { hovering in
            withMotion(.spring(response: 0.28, dampingFraction: 0.62)) {
                isHovering = hovering
            }
            onHoverName(hovering ? item.displayName : nil)
        }
        .onChange(of: feedback.tick) { _ in
            if feedback.event == .duplicate(item.id) { triggerDuplicate() }
        }
        .contextMenu {
            Button("重命名…") { promptRename() }
            Button("移除 \(item.displayName)", role: .destructive) { onRemove() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.displayName + (available ? "" : ",不可用"))
        .accessibilityAddTraits(.isButton)
        .zIndex(isHovering ? 1 : 0)
    }

    private func activate() {
        guard !isOpening else { return }
        isOpening = true
        switcher.open(item, hideIfFrontmost: hideIfFrontmost) { result in
            DispatchQueue.main.async {
                isOpening = false
                if result == .failed { triggerFail() }
            }
        }
    }

    private func triggerFail() {
        withMotion(.easeIn(duration: 0.08)) { failFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withMotion(.easeOut(duration: 0.3)) { failFlash = false }
        }
    }

    private func triggerDuplicate() {
        withMotion(.easeIn(duration: 0.08)) { dupFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withMotion(.easeOut(duration: 0.3)) { dupFlash = false }
        }
    }

    private func promptRename() {
        let alert = NSAlert()
        alert.messageText = "重命名"
        alert.informativeText = "给这个项目起一个显示名称。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = item.displayName
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        onRename(field.stringValue)
    }

    private var iconImage: Image {
        if let nsImage = IconLoader.icon(for: item) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.app.dashed")
    }
}

/// Press feedback: scale down while pressed (honors Reduce Motion).
private struct PressableIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(prefersReducedMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}
