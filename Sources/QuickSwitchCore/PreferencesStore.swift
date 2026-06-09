import Foundation
import Combine

/// Whether the dock lays its icons out in a row or a column.
public enum DockAxis: String, CaseIterable, Codable, Sendable {
    case horizontal, vertical
}

/// Global UI preferences. Each property persists to UserDefaults on write.
public final class PreferencesStore: ObservableObject {
    // Style (continuous — driven by the Settings window sliders)
    @Published public var iconSize: Double { didSet { defaults.set(iconSize, forKey: Keys.iconSize) } }
    @Published public var cornerRadius: Double { didSet { defaults.set(cornerRadius, forKey: Keys.cornerRadius) } }
    @Published public var backgroundOpacity: Double { didSet { defaults.set(backgroundOpacity, forKey: Keys.backgroundOpacity) } }
    @Published public var spacing: Double { didSet { defaults.set(spacing, forKey: Keys.spacing) } }
    @Published public var padding: Double { didSet { defaults.set(padding, forKey: Keys.padding) } }

    // Layout / behavior
    @Published public var showAddButton: Bool { didSet { defaults.set(showAddButton, forKey: Keys.showAddButton) } }
    @Published public var alwaysOnTop: Bool { didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) } }
    @Published public var axis: DockAxis { didSet { defaults.set(axis.rawValue, forKey: Keys.axis) } }

    /// Default values + the ranges the Settings sliders use.
    public enum Default {
        public static let iconSize = 40.0
        public static let cornerRadius = 18.0
        public static let backgroundOpacity = 1.0
        public static let spacing = 8.0
        public static let padding = 10.0
        public static let iconSizeRange = 24.0...72.0
        public static let cornerRadiusRange = 0.0...32.0
        public static let backgroundOpacityRange = 0.2...1.0
        public static let spacingRange = 0.0...20.0
        public static let paddingRange = 4.0...24.0
    }

    private enum Keys {
        static let iconSize = "iconSize"
        static let cornerRadius = "cornerRadius"
        static let backgroundOpacity = "backgroundOpacity"
        static let spacing = "spacing"
        static let padding = "padding"
        static let showAddButton = "showAddButton"
        static let alwaysOnTop = "alwaysOnTop"
        static let axis = "axis"
    }
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `as? NSNumber` so a legacy string value under the same key is ignored, not coerced to 0.
        func number(_ key: String, _ fallback: Double) -> Double {
            (defaults.object(forKey: key) as? NSNumber)?.doubleValue ?? fallback
        }
        self.iconSize = number(Keys.iconSize, Default.iconSize)
        self.cornerRadius = number(Keys.cornerRadius, Default.cornerRadius)
        self.backgroundOpacity = number(Keys.backgroundOpacity, Default.backgroundOpacity)
        self.spacing = number(Keys.spacing, Default.spacing)
        self.padding = number(Keys.padding, Default.padding)
        self.showAddButton = (defaults.object(forKey: Keys.showAddButton) as? Bool) ?? true
        self.alwaysOnTop = (defaults.object(forKey: Keys.alwaysOnTop) as? Bool) ?? true
        self.axis = DockAxis(rawValue: defaults.string(forKey: Keys.axis) ?? "") ?? .horizontal
    }

    /// Reset the visual style to defaults (leaves behavior toggles like axis/on-top).
    public func resetStyle() {
        iconSize = Default.iconSize
        cornerRadius = Default.cornerRadius
        backgroundOpacity = Default.backgroundOpacity
        spacing = Default.spacing
        padding = Default.padding
        showAddButton = true
    }
}
