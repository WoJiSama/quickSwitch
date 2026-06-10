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

/// A click-to-record hotkey field. Recording uses a LOCAL event monitor (no
/// first-responder games, which SwiftUI's focus system fights), and the caller is
/// told to pause global hotkeys while recording — otherwise pressing the currently
/// registered combo would be swallowed by our own hotkey instead of being captured.
struct HotKeyRecorder: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    /// Called with true when recording starts (pause global hotkeys) and false when
    /// it ends (re-register them).
    var onRecordingChanged: (Bool) -> Void = { _ in }

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "请按下组合键…(⎋ 取消)"
                             : KeyCombo.display(keyCode: keyCode, modifiers: modifiers))
                .font(.system(size: 12, weight: .medium))
                .frame(minWidth: 110)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        onRecordingChanged(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let mods = KeyCombo.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else {
                NSSound.beep() // a global hotkey needs at least one modifier
                return nil
            }
            keyCode = Int(event.keyCode)
            modifiers = mods
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording {
            isRecording = false
            onRecordingChanged(false)
        }
    }
}
