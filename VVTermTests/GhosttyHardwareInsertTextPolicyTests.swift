import Foundation
import Testing
@testable import VVTerm

#if os(iOS)
import UIKit

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

struct HardwareModifierStateTests {
    @Test
    func keepsControlActiveAcrossSeparateModifierAndCharacterPresses() {
        var state = HardwareModifierState()
        state.handlePressBegan(keyCode: UInt16(UIKeyboardHIDUsage.keyboardLeftControl.rawValue))

        let effective = state.effectiveModifiers(reported: [])
        #expect(effective.contains(.control))

        state.handlePressEnded(keyCode: UInt16(UIKeyboardHIDUsage.keyboardLeftControl.rawValue))
        let afterRelease = state.effectiveModifiers(reported: [])
        #expect(!afterRelease.contains(.control))
    }

    @Test
    func preservesReportedModifiersWhenNoTrackedStateExists() {
        let state = HardwareModifierState()
        let effective = state.effectiveModifiers(reported: [.command])
        #expect(effective.contains(.command))
    }
}
#endif
