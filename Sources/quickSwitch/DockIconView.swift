import SwiftUI
import AppKit
import QuickSwitchCore

/// One dock icon: tap to activate, right-click to remove, shows a fallback when uninstalled.
struct DockIconView: View {
    let item: AppItem
    let size: CGFloat
    let onActivate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        iconImage
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture { onActivate() }
            .help(item.displayName)
            .contextMenu {
                Button("移除 \(item.displayName)", role: .destructive) { onRemove() }
            }
    }

    private var iconImage: Image {
        if let nsImage = IconLoader.icon(forBundleID: item.bundleID) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.app.dashed")
    }
}
