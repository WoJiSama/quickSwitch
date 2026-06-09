import SwiftUI
import AppKit
import QuickSwitchCore

/// One dock icon: tap to open (with red flash on failure), hover to magnify and show
/// its name (via a floating tooltip window), right-click to rename/remove. Grays out
/// when the target is unavailable, and flashes an accent ring on a duplicate add.
struct DockIconView: View {
    let item: AppItem
    let size: CGFloat
    let axis: DockAxis
    let switcher: AppSwitcher
    @ObservedObject var feedback: FeedbackCenter
    let onHoverName: (String?) -> Void
    let onRename: (String) -> Void
    let onRemove: () -> Void

    @State private var isHovering = false
    @State private var failFlash = false
    @State private var dupFlash = false

    private static let hoverScale: CGFloat = 1.18
    private static let hoverLift: CGFloat = 3

    private var isAvailable: Bool { IconLoader.isAvailable(for: item) }

    // Lift "out of" the bar: horizontal pops up, vertical stays put (lifting up would
    // overlap the icon above it).
    private var hoverOffsetY: CGFloat {
        guard isHovering, axis == .horizontal else { return 0 }
        return -Self.hoverLift
    }

    var body: some View {
        iconImage
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .grayscale(isAvailable ? 0 : 1)
            .opacity(isAvailable ? 1 : 0.5)
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
            .onHover { hovering in
                withMotion(.spring(response: 0.28, dampingFraction: 0.62)) {
                    isHovering = hovering
                }
                onHoverName(hovering ? item.displayName : nil)
            }
            .onTapGesture {
                switcher.open(item) { result in
                    if result == .failed { triggerFail() }
                }
            }
            .onChange(of: feedback.tick) { _ in
                if feedback.event == .duplicate(item.id) { triggerDuplicate() }
            }
            .contextMenu {
                Button("重命名…") { promptRename() }
                Button("移除 \(item.displayName)", role: .destructive) { onRemove() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.displayName + (isAvailable ? "" : ",不可用"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { switcher.open(item) { _ in } }
            .zIndex(isHovering ? 1 : 0)
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
