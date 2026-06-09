import SwiftUI
import AppKit
import QuickSwitchCore

/// One dock icon: tap to open (with red flash on failure), hover to magnify + show
/// its name, right-click to remove. Grays out when the target is unavailable, and
/// flashes an accent ring when a duplicate add targets it.
struct DockIconView: View {
    let item: AppItem
    let size: CGFloat
    let switcher: AppSwitcher
    @ObservedObject var feedback: FeedbackCenter
    let onRemove: () -> Void

    @State private var isHovering = false
    @State private var failFlash = false
    @State private var dupFlash = false

    private static let hoverScale: CGFloat = 1.18
    private static let hoverLift: CGFloat = 3

    private var isAvailable: Bool { IconLoader.isAvailable(for: item) }

    var body: some View {
        iconImage
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .grayscale(isAvailable ? 0 : 1)
            .opacity(isAvailable ? 1 : 0.5)
            .scaleEffect(isHovering ? Self.hoverScale : 1.0)
            .offset(y: isHovering ? -Self.hoverLift : 0)
            .shadow(color: .black.opacity(isHovering ? 0.30 : 0), radius: 5, y: 2)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.red.opacity(failFlash ? 0.35 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(dupFlash ? 0.9 : 0), lineWidth: 3)
            }
            .overlay(alignment: .center) {
                if isHovering {
                    nameLabel
                        .offset(y: -(size / 2) - 16)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                    isHovering = hovering
                }
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
                Button("移除 \(item.displayName)", role: .destructive) { onRemove() }
            }
            .zIndex(isHovering ? 1 : 0)
    }

    private func triggerFail() {
        withAnimation(.easeIn(duration: 0.08)) { failFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.3)) { failFlash = false }
        }
    }

    private func triggerDuplicate() {
        withAnimation(.easeIn(duration: 0.08)) { dupFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) { dupFlash = false }
        }
    }

    private var nameLabel: some View {
        Text(item.displayName)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.20), radius: 3, y: 1)
    }

    private var iconImage: Image {
        if let nsImage = IconLoader.icon(for: item) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.app.dashed")
    }
}
