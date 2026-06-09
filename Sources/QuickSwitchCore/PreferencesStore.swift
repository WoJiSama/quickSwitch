import Foundation
import Combine
import CoreGraphics

public enum IconSize: String, CaseIterable, Codable, Sendable {
    case small, medium, large

    public var points: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 40
        case .large: return 52
        }
    }
}

/// Whether the dock lays its icons out in a row or a column.
public enum DockAxis: String, CaseIterable, Codable, Sendable {
    case horizontal, vertical
}

/// Global UI preferences. Each property persists to UserDefaults on write.
public final class PreferencesStore: ObservableObject {
    @Published public var iconSize: IconSize {
        didSet { defaults.set(iconSize.rawValue, forKey: Keys.iconSize) }
    }
    @Published public var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }
    @Published public var axis: DockAxis {
        didSet { defaults.set(axis.rawValue, forKey: Keys.axis) }
    }

    private enum Keys {
        static let iconSize = "iconSize"
        static let alwaysOnTop = "alwaysOnTop"
        static let axis = "axis"
    }
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.iconSize = IconSize(rawValue: defaults.string(forKey: Keys.iconSize) ?? "") ?? .medium
        self.alwaysOnTop = (defaults.object(forKey: Keys.alwaysOnTop) as? Bool) ?? true
        self.axis = DockAxis(rawValue: defaults.string(forKey: Keys.axis) ?? "") ?? .horizontal
    }
}
