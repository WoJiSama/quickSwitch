import AppKit
import SwiftUI
import QuickSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: DockPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let stub = HStack {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 28))
                .padding(12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        panel = DockPanel(rootView: stub, alwaysOnTop: true)
        panel?.showCentered()
    }
}
