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

    @Test func defaultsAreMediumAndAlwaysOnTop() {
        let prefs = PreferencesStore(defaults: defaults)
        #expect(prefs.iconSize == .medium)
        #expect(prefs.alwaysOnTop)
    }

    @Test func iconSizePersists() {
        let prefs1 = PreferencesStore(defaults: defaults)
        prefs1.iconSize = .large

        let prefs2 = PreferencesStore(defaults: defaults)
        #expect(prefs2.iconSize == .large)
    }

    @Test func alwaysOnTopPersists() {
        let prefs1 = PreferencesStore(defaults: defaults)
        prefs1.alwaysOnTop = false

        let prefs2 = PreferencesStore(defaults: defaults)
        #expect(prefs2.alwaysOnTop == false)
    }

    @Test func iconSizePointsIncreaseWithSize() {
        #expect(IconSize.small.points < IconSize.medium.points)
        #expect(IconSize.medium.points < IconSize.large.points)
    }

    @Test func axisDefaultsToHorizontal() {
        #expect(PreferencesStore(defaults: defaults).axis == .horizontal)
    }

    @Test func axisPersists() {
        let prefs1 = PreferencesStore(defaults: defaults)
        prefs1.axis = .vertical
        #expect(PreferencesStore(defaults: defaults).axis == .vertical)
    }
}
