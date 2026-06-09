import Testing
@testable import QuickSwitchCore

struct AppSwitcherTests {
    final class MockWorkspace: WorkspaceProviding {
        var running: Set<String> = []
        var activateReturn = true
        var launchReturn = true
        var openReturn = true
        var webReturn = true
        private(set) var activatedIDs: [String] = []
        private(set) var launchedIDs: [String] = []
        private(set) var openedPaths: [String] = []
        private(set) var openedWebURLs: [String] = []

        func isRunning(bundleID: String) -> Bool { running.contains(bundleID) }
        func activate(bundleID: String) -> Bool {
            activatedIDs.append(bundleID); return activateReturn
        }
        func launch(bundleID: String, completion: @escaping (Bool) -> Void) {
            launchedIDs.append(bundleID); completion(launchReturn)
        }
        func open(path: String) -> Bool {
            openedPaths.append(path); return openReturn
        }
        func openWeb(_ urlString: String) -> Bool {
            openedWebURLs.append(urlString); return webReturn
        }
    }

    private func app(_ bundleID: String) -> AppItem {
        AppItem(bundleID: bundleID, displayName: bundleID)
    }

    @Test func runningAppActivatesAndDoesNotLaunch() {
        let mock = MockWorkspace()
        mock.running = ["com.foo.Bar"]
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(app("com.foo.Bar")) { result = $0 }

        #expect(result == .activated)
        #expect(mock.activatedIDs == ["com.foo.Bar"])
        #expect(mock.launchedIDs.isEmpty)
    }

    @Test func notRunningAppLaunches() {
        let mock = MockWorkspace()
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(app("com.foo.Bar")) { result = $0 }

        #expect(result == .launched)
        #expect(mock.launchedIDs == ["com.foo.Bar"])
        #expect(mock.activatedIDs.isEmpty)
    }

    @Test func activateFailsReturnsFailed() {
        let mock = MockWorkspace()
        mock.running = ["com.foo.Bar"]
        mock.activateReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(app("com.foo.Bar")) { result = $0 }

        #expect(result == .failed)
    }

    @Test func launchFailsReturnsFailed() {
        let mock = MockWorkspace()
        mock.launchReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(app("com.foo.Bar")) { result = $0 }

        #expect(result == .failed)
    }

    @Test func pathItemOpens() {
        let mock = MockWorkspace()
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(path: "/tmp/notes.txt", displayName: "notes.txt")) { result = $0 }

        #expect(result == .opened)
        #expect(mock.openedPaths == ["/tmp/notes.txt"])
        #expect(mock.activatedIDs.isEmpty)
        #expect(mock.launchedIDs.isEmpty)
    }

    @Test func pathOpenFailsReturnsFailed() {
        let mock = MockWorkspace()
        mock.openReturn = false
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
        #expect(mock.openedPaths.isEmpty)
    }

    @Test func urlOpenFailsReturnsFailed() {
        let mock = MockWorkspace()
        mock.webReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.open(AppItem(url: "https://x.test", displayName: "x")) { result = $0 }

        #expect(result == .failed)
    }
}
