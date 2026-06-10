import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Formats a (virtual key code, Carbon modifier mask) combo for display, and
/// converts NSEvent modifier flags to a Carbon mask.
enum KeyCombo {
    static func display(keyCode: Int, modifiers: Int) -> String {
        modifierSymbols(modifiers) + keyName(keyCode)
    }

    static func modifierSymbols(_ mask: Int) -> String {
        var s = ""
        if mask & controlKey != 0 { s += "⌃" }
        if mask & optionKey != 0 { s += "⌥" }
        if mask & shiftKey != 0 { s += "⇧" }
        if mask & cmdKey != 0 { s += "⌘" }
        return s
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var mask = 0
        if flags.contains(.control) { mask |= controlKey }
        if flags.contains(.option) { mask |= optionKey }
        if flags.contains(.shift) { mask |= shiftKey }
        if flags.contains(.command) { mask |= cmdKey }
        return mask
    }

    static func keyName(_ keyCode: Int) -> String {
        if let name = keyNames[keyCode] { return name }
        return "键\(keyCode)"
    }

    private static let keyNames: [Int: String] = [
        49: "Space", 36: "↩", 48: "⇥", 53: "⎋", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        50: "`", 27: "-", 24: "=", 33: "[", 30: "]", 42: "\\",
        41: ";", 39: "'", 43: ",", 47: ".", 44: "/",
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O",
        35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V",
        13: "W", 7: "X", 16: "Y", 6: "Z",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
        26: "7", 28: "8", 25: "9", 29: "0",
    ]
}

/// A click-to-record hotkey field: click it, press any combo (must include at least
/// one modifier), and it saves the key code + Carbon modifiers. Esc cancels.
struct HotKeyRecorder: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "按下组合键…(⎋ 取消)" : KeyCombo.display(keyCode: keyCode, modifiers: modifiers))
                .font(.system(size: 12, weight: .medium))
                .frame(minWidth: 110)
        }
        .background(
            KeyCaptureRepresentable(isRecording: $isRecording) { code, mods in
                keyCode = code
                modifiers = mods
                isRecording = false
            }
        )
    }
}

/// Invisible AppKit view that grabs first-responder while recording and captures
/// the next key press (including ⌘ combos, which arrive as key equivalents).
private struct KeyCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (Int, Int) -> Void

    func makeNSView(context: Context) -> CaptureView { CaptureView() }

    func updateNSView(_ view: CaptureView, context: Context) {
        view.onCapture = onCapture
        view.onCancel = { isRecording = false }
        DispatchQueue.main.async {
            if isRecording {
                view.window?.makeFirstResponder(view)
            } else if view.window?.firstResponder === view {
                view.window?.makeFirstResponder(nil)
            }
        }
    }

    final class CaptureView: NSView {
        var onCapture: ((Int, Int) -> Void)?
        var onCancel: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            handle(event)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self, event.type == .keyDown else { return false }
            handle(event)
            return true
        }

        private func handle(_ event: NSEvent) {
            if event.keyCode == UInt16(kVK_Escape) {
                onCancel?()
                return
            }
            let mods = KeyCombo.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else {
                NSSound.beep() // require at least one modifier for a global hotkey
                return
            }
            onCapture?(Int(event.keyCode), mods)
        }
    }
}
