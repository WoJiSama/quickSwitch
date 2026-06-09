import Testing
import Foundation
@testable import QuickSwitchCore

struct AppItemTests {
    @Test func appIdEqualsBundleID() {
        let item = AppItem(bundleID: "com.google.Chrome", displayName: "Google Chrome")
        #expect(item.id == "com.google.Chrome")
    }

    @Test func pathIdEqualsPath() {
        let item = AppItem(path: "/Users/me/Documents", displayName: "Documents")
        #expect(item.id == "/Users/me/Documents")
    }

    @Test func appCodableRoundTripPreservesValues() throws {
        let item = AppItem(bundleID: "com.apple.Safari", displayName: "Safari")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(AppItem.self, from: data)
        #expect(decoded == item)
    }

    @Test func pathCodableRoundTripPreservesValues() throws {
        let item = AppItem(path: "/tmp/report.pdf", displayName: "report.pdf")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(AppItem.self, from: data)
        #expect(decoded == item)
    }

    @Test func equalityIsByValue() {
        let a = AppItem(bundleID: "x", displayName: "X")
        let b = AppItem(bundleID: "x", displayName: "X")
        #expect(a == b)
    }
}
