import Testing
@testable import VVTerm

#if os(iOS)
import CoreFoundation

struct GhosttyIOSHardwareInsertTextSuppressionTests {
    @Test
    func queuedHardwareTextIsSuppressedOnce() {
        var state = HardwareInsertTextSuppressionState(ttlSeconds: 1.0, maxPendingEntries: 4)
        state.queue("n", now: 10.0)

        #expect(state.shouldSuppress("n", now: 10.1))
        #expect(state.shouldSuppress("n", now: 10.2) == false)
    }

    @Test
    func staleQueuedTextExpires() {
        var state = HardwareInsertTextSuppressionState(ttlSeconds: 0.5, maxPendingEntries: 4)
        state.queue("n", now: 10.0)

        #expect(state.shouldSuppress("n", now: 10.6) == false)
    }

    @Test
    func nonMatchingTextIsNotSuppressed() {
        var state = HardwareInsertTextSuppressionState(ttlSeconds: 1.0, maxPendingEntries: 4)
        state.queue("n", now: 10.0)

        #expect(state.shouldSuppress("x", now: 10.1) == false)
        #expect(state.shouldSuppress("n", now: 10.2))
    }
}
#endif
