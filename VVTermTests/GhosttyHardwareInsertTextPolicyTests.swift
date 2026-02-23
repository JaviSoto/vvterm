import Foundation
import Testing
@testable import VVTerm

#if os(iOS)
struct GhosttyHardwareInsertTextPolicyTests {
    @Test
    func suppressesSinglePrintableInsertTextAfterRecentHardwarePress() {
        let suppressed = GhosttyHardwareInsertTextPolicy.shouldSuppressFallbackInsertText(
            text: "n",
            hasActiveIMEComposition: false,
            systemTextInputPressesCount: 0,
            now: 10.2,
            lastGhosttyHardwarePressAt: 10.0
        )

        #expect(suppressed)
    }

    @Test
    func doesNotSuppressWhenHardwarePressIsStale() {
        let suppressed = GhosttyHardwareInsertTextPolicy.shouldSuppressFallbackInsertText(
            text: "n",
            hasActiveIMEComposition: false,
            systemTextInputPressesCount: 0,
            now: 11.0,
            lastGhosttyHardwarePressAt: 10.0
        )

        #expect(!suppressed)
    }

    @Test
    func doesNotSuppressWhenSystemTextInputOwnsThePress() {
        let suppressed = GhosttyHardwareInsertTextPolicy.shouldSuppressFallbackInsertText(
            text: "n",
            hasActiveIMEComposition: false,
            systemTextInputPressesCount: 1,
            now: 10.2,
            lastGhosttyHardwarePressAt: 10.0
        )

        #expect(!suppressed)
    }

    @Test
    func doesNotSuppressNonPrintableOrMultiCharacterText() {
        let controlSuppressed = GhosttyHardwareInsertTextPolicy.shouldSuppressFallbackInsertText(
            text: "\u{1}",
            hasActiveIMEComposition: false,
            systemTextInputPressesCount: 0,
            now: 10.2,
            lastGhosttyHardwarePressAt: 10.0
        )
        let multiSuppressed = GhosttyHardwareInsertTextPolicy.shouldSuppressFallbackInsertText(
            text: "ab",
            hasActiveIMEComposition: false,
            systemTextInputPressesCount: 0,
            now: 10.2,
            lastGhosttyHardwarePressAt: 10.0
        )

        #expect(!controlSuppressed)
        #expect(!multiSuppressed)
    }

    @Test
    func suppressesWithoutExplicitHardwareKeyboardFlag() {
        let suppressed = GhosttyHardwareInsertTextPolicy.shouldSuppressFallbackInsertText(
            text: "n",
            hasActiveIMEComposition: false,
            systemTextInputPressesCount: 0,
            now: 10.2,
            lastGhosttyHardwarePressAt: 10.0
        )

        #expect(suppressed)
    }
}
#endif
