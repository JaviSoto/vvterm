import Foundation
import Testing
@testable import VVTerm

struct TerminalSoftwareModifierEncoderTests {
    @Test
    func encodesCtrlLetterAsControlByte() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: true,
            alt: false,
            command: false,
            shift: false
        )

        #expect(encoded == Data([0x14]))
    }

    @Test
    func prefixesEscapeForAltCtrlLetter() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: true,
            alt: true,
            command: false,
            shift: false
        )

        #expect(encoded == Data([0x1B, 0x14]))
    }

    @Test
    func doesNotEncodeWithoutCtrlModifier() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: false,
            alt: true,
            command: false,
            shift: false
        )

        #expect(encoded == nil)
    }

    @Test
    func doesNotEncodeNonAlphabeticCharacters() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "1",
            ctrl: true,
            alt: false,
            command: false,
            shift: false
        )

        #expect(encoded == nil)
    }

    @Test
    func preservesCommandCombinationForGhostty() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: true,
            alt: false,
            command: true,
            shift: false
        )

        #expect(encoded == nil)
    }

    @Test
    func preservesShiftCombinationForGhostty() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: true,
            alt: false,
            command: false,
            shift: true
        )

        #expect(encoded == nil)
    }
}
