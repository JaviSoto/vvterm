import Foundation
import Testing
@testable import VVTerm

struct TerminalSoftwareModifierEncoderTests {
    @Test
    func encodesCtrlLetterAsControlByte() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: true,
            alt: false
        )

        #expect(encoded == Data([0x14]))
    }

    @Test
    func prefixesEscapeForAltCtrlLetter() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: true,
            alt: true
        )

        #expect(encoded == Data([0x1B, 0x14]))
    }

    @Test
    func doesNotEncodeWithoutCtrlModifier() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "t",
            ctrl: false,
            alt: true
        )

        #expect(encoded == nil)
    }

    @Test
    func doesNotEncodeNonAlphabeticCharacters() {
        let encoded = TerminalSoftwareModifierEncoder.encodeControlSequence(
            char: "1",
            ctrl: true,
            alt: false
        )

        #expect(encoded == nil)
    }


    @Test
    func preservesUppercaseCharacterTextWhenMappingSingleKey() {
        let mapped = TerminalSoftwareCharacterMapper.mapSingleCharacter("A")

        #expect(mapped?.key == .a)
        #expect(mapped?.text == "A")
        #expect(mapped?.unshiftedCodepoint == 97)
    }

    @Test
    func ignoresMultiCharacterStringsForSingleKeyMapping() {
        let mapped = TerminalSoftwareCharacterMapper.mapSingleCharacter("ab")

        #expect(mapped == nil)
    }

}
