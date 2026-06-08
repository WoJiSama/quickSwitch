import Testing
@testable import QuickSwitchCore

struct AppSwitcherTests {
    final class MockWorkspace: WorkspaceProviding {
        var running: Set<String> = []
        var activateReturn = true
        var launchReturn = true
        private(set) var activatedIDs: [String] = []
        private(set) var launchedIDs: [String] = []

        func isRunning(bundleID: String) -> Bool { running.contains(bundleID) }
        func activate(bundleID: String) -> Bool {
            activatedIDs.append(bundleID); return activateReturn
        }
        func launch(bundleID: String, completion: @escaping (Bool) -> Void) {
            launchedIDs.append(bundleID); completion(launchReturn)
        }
    }

    @Test func runningAppActivatesAndDoesNotLaunch() {
        let mock = MockWorkspace()
        mock.running = ["com.foo.Bar"]
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

        #expect(result == .activated)
        #expect(mock.activatedIDs == ["com.foo.Bar"])
        #expect(mock.launchedIDs.isEmpty)
    }

    @Test func notRunningAppLaunches() {
        let mock = MockWorkspace()
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

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
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

        #expect(result == .failed)
    }

    @Test func launchFailsReturnsFailed() {
        let mock = MockWorkspace()
        mock.launchReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

        #expect(result == .failed)
    }
}
