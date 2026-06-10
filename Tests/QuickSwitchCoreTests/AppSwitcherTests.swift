import Testing
@testable import QuickSwitchCore

struct AppSwitcherTests {
    final class MockWorkspace: WorkspaceProviding {
        var appReturn = true
        var pathReturn = true
        var webReturn = true
        var frontmost: String?
        var hideReturn = true
        private(set) var openedApps: [String] = []
        private(set) var openedPaths: [String] = []
        private(set) var openedWebURLs: [String] = []
        private(set) var hiddenApps: [String] = []

        func openApp(bundleID: String, completion: @escaping (Bool) -> Void) {
            openedApps.append(bundleID); completion(appReturn)
        }
        func open(path: String) -> Bool {
            openedPaths.append(path); return pathReturn
        }
        func openWeb(_ urlString: String) -> Bool {
            openedWebURLs.append(urlString); return webReturn
        }
        func isFrontmost(bundleID: String) -> Bool { frontmost == bundleID }
        func hideApp(bundleID: String) -> Bool {
            hiddenApps.append(bundleID); return hideReturn
        }
    }

    @Test func appItemOpens() {
        let mock = MockWorkspace()
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(bundleID: "com.foo.Bar", displayName: "Bar")) { result = $0 }

        #expect(result == .opened)
        #expect(mock.openedApps == ["com.foo.Bar"])
        #expect(mock.openedPaths.isEmpty)
        #expect(mock.openedWebURLs.isEmpty)
    }

    @Test func appOpenFailureReturnsFailed() {
        let mock = MockWorkspace()
        mock.appReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(bundleID: "com.foo.Bar", displayName: "Bar")) { result = $0 }

        #expect(result == .failed)
    }

    @Test func pathItemOpens() {
        let mock = MockWorkspace()
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(path: "/tmp/notes.txt", displayName: "notes.txt")) { result = $0 }

        #expect(result == .opened)
        #expect(mock.openedPaths == ["/tmp/notes.txt"])
        #expect(mock.openedApps.isEmpty)
    }

    @Test func pathOpenFailureReturnsFailed() {
        let mock = MockWorkspace()
        mock.pathReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(path: "/tmp/gone", displayName: "gone")) { result = $0 }

        #expect(result == .failed)
    }

    @Test func urlItemOpensInBrowser() {
        let mock = MockWorkspace()
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(url: "https://github.com", displayName: "github.com")) { result = $0 }

        #expect(result == .opened)
        #expect(mock.openedWebURLs == ["https://github.com"])
        #expect(mock.openedApps.isEmpty)
    }

    @Test func urlOpenFailureReturnsFailed() {
        let mock = MockWorkspace()
        mock.webReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(url: "https://x.test", displayName: "x")) { result = $0 }

        #expect(result == .failed)
    }

    @Test func frontmostAppHidesWhenEnabled() {
        let mock = MockWorkspace()
        mock.frontmost = "com.foo.Bar"
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(bundleID: "com.foo.Bar", displayName: "Bar"),
                      hideIfFrontmost: true) { result = $0 }

        #expect(result == .opened)
        #expect(mock.hiddenApps == ["com.foo.Bar"])
        #expect(mock.openedApps.isEmpty)
    }

    @Test func frontmostAppStillOpensWhenHideDisabled() {
        let mock = MockWorkspace()
        mock.frontmost = "com.foo.Bar"
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(bundleID: "com.foo.Bar", displayName: "Bar"),
                      hideIfFrontmost: false) { result = $0 }

        #expect(result == .opened)
        #expect(mock.openedApps == ["com.foo.Bar"])
        #expect(mock.hiddenApps.isEmpty)
    }

    @Test func nonFrontmostAppOpensEvenWithHideEnabled() {
        let mock = MockWorkspace()
        mock.frontmost = "com.other.App"
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(bundleID: "com.foo.Bar", displayName: "Bar"),
                      hideIfFrontmost: true) { result = $0 }

        #expect(result == .opened)
        #expect(mock.openedApps == ["com.foo.Bar"])
        #expect(mock.hiddenApps.isEmpty)
    }
}
