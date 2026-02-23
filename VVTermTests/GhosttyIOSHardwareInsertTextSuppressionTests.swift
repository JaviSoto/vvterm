import Testing
@testable import VVTerm

#if os(iOS)
import CoreFoundation

struct GhosttyIOSHardwareInsertTextSuppressionTests {
    @Test
    func queuedHardwareTextIsSuppressedOnce() {
        var state = HardwareInsertTextSuppressionState(ttlSeconds: 1.0, maxPendingEntries: 4)
        state.queue("n", now: 10.0)

        let firstSuppressed = state.shouldSuppress("n", now: 10.1)
        let secondSuppressed = state.shouldSuppress("n", now: 10.2)
        #expect(firstSuppressed)
        #expect(secondSuppressed == false)
    }

    @Test
    func staleQueuedTextExpires() {
        var state = HardwareInsertTextSuppressionState(ttlSeconds: 0.5, maxPendingEntries: 4)
        state.queue("n", now: 10.0)

        let suppressed = state.shouldSuppress("n", now: 10.6)
        #expect(suppressed == false)
    }

    @Test
    func nonMatchingTextIsNotSuppressed() {
        var state = HardwareInsertTextSuppressionState(ttlSeconds: 1.0, maxPendingEntries: 4)
        state.queue("n", now: 10.0)

        let wrongTextSuppressed = state.shouldSuppress("x", now: 10.1)
        let queuedTextSuppressed = state.shouldSuppress("n", now: 10.2)
        #expect(wrongTextSuppressed == false)
        #expect(queuedTextSuppressed)
    }
}
#endif
