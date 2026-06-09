import SwiftUI
import AppKit
import QuickSwitchCore

/// One dock icon: tap to activate, hover to magnify, right-click to remove,
/// shows a fallback glyph when the app is uninstalled.
struct DockIconView: View {
    let item: AppItem
    let size: CGFloat
    let onActivate: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    private static let hoverScale: CGFloat = 1.18
    private static let hoverLift: CGFloat = 3

    var body: some View {
        iconImage
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .scaleEffect(isHovering ? Self.hoverScale : 1.0)
            .offset(y: isHovering ? -Self.hoverLift : 0)
            .shadow(color: .black.opacity(isHovering ? 0.30 : 0), radius: 5, y: 2)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                    isHovering = hovering
                }
            }
            .onTapGesture { onActivate() }
            .help(item.displayName)
            .contextMenu {
                Button("移除 \(item.displayName)", role: .destructive) { onRemove() }
            }
            .zIndex(isHovering ? 1 : 0)
    }

    private var iconImage: Image {
        if let nsImage = IconLoader.icon(forBundleID: item.bundleID) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.app.dashed")
    }
}
