import Testing
import Foundation
@testable import QuickSwitchCore

struct AppResolverTests {
    struct StubReader: BundleInfoReading {
        let result: (bundleID: String, displayName: String)?
        func readInfo(at url: URL) -> (bundleID: String, displayName: String)? { result }
    }

    @Test func validAppReturnsItem() {
        let reader = StubReader(result: ("com.google.Chrome", "Google Chrome"))
        let resolver = AppResolver(reader: reader)
        let url = URL(fileURLWithPath: "/Applications/Google Chrome.app")

        #expect(resolver.resolve(url: url) == AppItem(bundleID: "com.google.Chrome", displayName: "Google Chrome"))
    }

    @Test func nonAppExtensionReturnsNil() {
        let resolver = AppResolver(reader: StubReader(result: ("com.x", "X")))
        #expect(resolver.resolve(url: URL(fileURLWithPath: "/Users/me/file.txt")) == nil)
    }

    @Test func unreadableBundleReturnsNil() {
        let resolver = AppResolver(reader: StubReader(result: nil))
        #expect(resolver.resolve(url: URL(fileURLWithPath: "/Applications/Broken.app")) == nil)
    }

    @Test func emptyBundleIDReturnsNil() {
        let resolver = AppResolver(reader: StubReader(result: ("", "Nameless")))
        #expect(resolver.resolve(url: URL(fileURLWithPath: "/Applications/Nameless.app")) == nil)
    }

    @Test func systemReaderReadsHandBuiltApp() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fake-\(UUID().uuidString).app")
        let contents = tmp.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.example.Fake</string>
            <key>CFBundleName</key>
            <string>Fake App</string>
        </dict>
        </plist>
        """
        try plist.write(to: contents.appendingPathComponent("Info.plist"),
                        atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let info = SystemBundleInfoReader().readInfo(at: tmp)

        #expect(info?.bundleID == "com.example.Fake")
        #expect(info?.displayName == "Fake App")
    }
}
