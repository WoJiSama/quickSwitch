import AppKit
import Carbon.HIToolbox
import QuickSwitchCore

/// Registers global hotkeys via Carbon `RegisterEventHotKey` — system-wide capture
/// WITHOUT requiring the Accessibility permission, preserving the app's
/// no-sensitive-permissions guarantee.
final class HotKeyCenter {
    /// Virtual key codes for the digit row 1...9 (ANSI layout; not sequential).
    static let digitKeyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x5153_5743) /* 'QSWC' */, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return }
        refs[id] = ref
        handlers[id] = handler
    }

    func unregisterAll() {
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
    }

    fileprivate func handle(id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(event,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil,
                                  MemoryLayout<EventHotKeyID>.size,
                                  nil,
                                  &hotKeyID)
                Unmanaged<HotKeyCenter>.fromOpaque(userData)
                    .takeUnretainedValue()
                    .handle(id: hotKeyID.id)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}

extension SummonHotKey {
    var keyCode: UInt32 { UInt32(kVK_Space) }

    var carbonModifiers: UInt32 {
        switch self {
        case .optionSpace: return UInt32(optionKey)
        case .commandOptionSpace: return UInt32(cmdKey | optionKey)
        case .controlOptionSpace: return UInt32(controlKey | optionKey)
        case .commandShiftSpace: return UInt32(cmdKey | shiftKey)
        }
    }
}
