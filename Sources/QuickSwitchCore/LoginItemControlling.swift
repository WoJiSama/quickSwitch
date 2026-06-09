import Foundation
import ServiceManagement

/// Controls whether the app launches at login. Protocol lets the UI depend on an abstraction.
public protocol LoginItemControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Backed by SMAppService (macOS 13+). Only meaningful when running from a real .app bundle.
@available(macOS 13.0, *)
public struct LoginItemManager: LoginItemControlling {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
