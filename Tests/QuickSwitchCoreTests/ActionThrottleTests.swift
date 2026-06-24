import Testing
@testable import QuickSwitchCore

struct ActionThrottleTests {
    @Test func firstCallFires() {
        var throttle = ActionThrottle(minInterval: 0.2)
        #expect(throttle.shouldFire(now: 100) == true)
    }

    @Test func rapidSecondCallIsSuppressed() {
        var throttle = ActionThrottle(minInterval: 0.2)
        _ = throttle.shouldFire(now: 100)
        #expect(throttle.shouldFire(now: 100.1) == false)
    }

    @Test func callAfterIntervalFires() {
        var throttle = ActionThrottle(minInterval: 0.2)
        _ = throttle.shouldFire(now: 100)
        #expect(throttle.shouldFire(now: 100.25) == true)
    }

    @Test func suppressedCallDoesNotAdvanceTheWindow() {
        var throttle = ActionThrottle(minInterval: 0.2)
        _ = throttle.shouldFire(now: 100)   // fires; window anchored at 100
        _ = throttle.shouldFire(now: 100.1) // suppressed; must NOT re-anchor to 100.1
        // 0.21s after the last *allowed* fire (100), so this must fire.
        #expect(throttle.shouldFire(now: 100.21) == true)
    }

    @Test func aBurstAllowsOnlyOneFire() {
        var throttle = ActionThrottle(minInterval: 0.2)
        let times: [Double] = [0, 0.01, 0.02, 0.03, 0.04, 0.05]
        let fired = times.filter { throttle.shouldFire(now: $0) }
        #expect(fired == [0])
    }
}
