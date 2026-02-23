import Testing
@testable import VVTerm

#if os(iOS)
import UIKit

struct GhosttyIOSHardwareKeyEventTests {
    @Test
    func releaseEventDoesNotCarryPrintableText() {
        let descriptor = Ghostty.Input.HardwareKeyDescriptor(
            keyCode: .keyboardN,
            modifierFlags: [],
            characters: "n",
            charactersIgnoringModifiers: "n"
        )

        let press = Ghostty.Input.KeyEvent(hardwareKey: descriptor, action: .press)
        let release = Ghostty.Input.KeyEvent(hardwareKey: descriptor, action: .release)

        #expect(press?.text == "n")
        #expect(release?.text == nil)
    }

    @Test
    func ctrlShortcutDoesNotInjectTextPayload() {
        let descriptor = Ghostty.Input.HardwareKeyDescriptor(
            keyCode: .keyboardT,
            modifierFlags: [.control],
            characters: "t",
            charactersIgnoringModifiers: "t"
        )

        let event = Ghostty.Input.KeyEvent(hardwareKey: descriptor, action: .press)
        #expect(event != nil)
        #expect(event?.text == nil)
        #expect(event?.mods.contains(.ctrl) == true)
    }

    @Test
    func tabModeFollowUpKeyKeepsReleaseTextNil() {
        let ctrlT = Ghostty.Input.HardwareKeyDescriptor(
            keyCode: .keyboardT,
            modifierFlags: [.control],
            characters: "t",
            charactersIgnoringModifiers: "t"
        )
        let n = Ghostty.Input.HardwareKeyDescriptor(
            keyCode: .keyboardN,
            modifierFlags: [],
            characters: "n",
            charactersIgnoringModifiers: "n"
        )

        let prefixPress = Ghostty.Input.KeyEvent(hardwareKey: ctrlT, action: .press)
        let prefixRelease = Ghostty.Input.KeyEvent(hardwareKey: ctrlT, action: .release)
        let followUpPress = Ghostty.Input.KeyEvent(hardwareKey: n, action: .press)
        let followUpRelease = Ghostty.Input.KeyEvent(hardwareKey: n, action: .release)

        #expect(prefixPress?.text == nil)
        #expect(prefixRelease?.text == nil)
        #expect(followUpPress?.text == "n")
        #expect(followUpRelease?.text == nil)
    }

    @Test
    func dispatchTreatsFalseReturnAsStillDispatched() {
        let descriptor = Ghostty.Input.HardwareKeyDescriptor(
            keyCode: .keyboardN,
            modifierFlags: [],
            characters: "n",
            charactersIgnoringModifiers: "n"
        )
        var sendCalls = 0
        let dispatched = Ghostty.Input.KeyEvent.dispatchHardwareKey(
            descriptor,
            action: .press
        ) { _ in
            sendCalls += 1
            // Ghostty may return false for non-binding keys even though dispatch succeeds.
            return false
        }

        #expect(dispatched)
        #expect(sendCalls == 1)
    }
}
#endif
