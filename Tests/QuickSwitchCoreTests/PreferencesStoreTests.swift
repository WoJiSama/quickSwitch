import Testing
import Foundation
@testable import QuickSwitchCore

final class PreferencesStoreTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() {
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func defaultsAreSensible() {
        let prefs = PreferencesStore(defaults: defaults)
        #expect(prefs.iconSize == PreferencesStore.Default.iconSize)
        #expect(prefs.cornerRadius == PreferencesStore.Default.cornerRadius)
        #expect(prefs.backgroundOpacity == PreferencesStore.Default.backgroundOpacity)
        #expect(prefs.spacing == PreferencesStore.Default.spacing)
        #expect(prefs.padding == PreferencesStore.Default.padding)
        #expect(prefs.showAddButton)
        #expect(prefs.alwaysOnTop)
        #expect(prefs.axis == .horizontal)
        #expect(prefs.showMenuBarIcon)
        #expect(prefs.clickFrontmostHides)
    }

    @Test func behaviorTogglesPersist() {
        let p1 = PreferencesStore(defaults: defaults)
        p1.showMenuBarIcon = false
        p1.clickFrontmostHides = false

        let p2 = PreferencesStore(defaults: defaults)
        #expect(p2.showMenuBarIcon == false)
        #expect(p2.clickFrontmostHides == false)
    }

    @Test func hotkeyDefaultsAreEnabledOptionSpace() {
        let prefs = PreferencesStore(defaults: defaults)
        #expect(prefs.summonHotKeyEnabled)
        #expect(prefs.summonKeyCode == PreferencesStore.Default.summonKeyCode)
        #expect(prefs.summonModifiers == PreferencesStore.Default.summonModifiers)
        #expect(prefs.digitHotKeysEnabled)
        #expect(prefs.digitModifiers == PreferencesStore.Default.digitModifiers)
    }

    @Test func digitModifiersPersist() {
        let p1 = PreferencesStore(defaults: defaults)
        p1.digitModifiers = 4096 // ⌃
        #expect(PreferencesStore(defaults: defaults).digitModifiers == 4096)
    }

    @Test func hotkeyPrefsPersist() {
        let p1 = PreferencesStore(defaults: defaults)
        p1.summonHotKeyEnabled = false
        p1.summonKeyCode = 11   // B
        p1.summonModifiers = 256 | 2048 // ⌘⌥
        p1.digitHotKeysEnabled = false

        let p2 = PreferencesStore(defaults: defaults)
        #expect(p2.summonHotKeyEnabled == false)
        #expect(p2.summonKeyCode == 11)
        #expect(p2.summonModifiers == 256 | 2048)
        #expect(p2.digitHotKeysEnabled == false)
    }

    @Test func stylePersistsAcrossInstances() {
        let p1 = PreferencesStore(defaults: defaults)
        p1.iconSize = 56
        p1.cornerRadius = 4
        p1.backgroundOpacity = 0.5
        p1.spacing = 14
        p1.padding = 6
        p1.showAddButton = false
        p1.axis = .vertical

        let p2 = PreferencesStore(defaults: defaults)
        #expect(p2.iconSize == 56)
        #expect(p2.cornerRadius == 4)
        #expect(p2.backgroundOpacity == 0.5)
        #expect(p2.spacing == 14)
        #expect(p2.padding == 6)
        #expect(p2.showAddButton == false)
        #expect(p2.axis == .vertical)
    }

    @Test func resetStyleRestoresDefaults() {
        let prefs = PreferencesStore(defaults: defaults)
        prefs.iconSize = 70
        prefs.cornerRadius = 2
        prefs.showAddButton = false
        prefs.resetStyle()
        #expect(prefs.iconSize == PreferencesStore.Default.iconSize)
        #expect(prefs.cornerRadius == PreferencesStore.Default.cornerRadius)
        #expect(prefs.showAddButton)
    }

    @Test func legacyStringValueDoesNotCorruptIconSize() {
        // Older builds stored iconSize as a string ("medium"); it must fall back to the default.
        defaults.set("medium", forKey: "iconSize")
        let prefs = PreferencesStore(defaults: defaults)
        #expect(prefs.iconSize == PreferencesStore.Default.iconSize)
    }
}
