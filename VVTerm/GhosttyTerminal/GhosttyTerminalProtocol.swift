//
//  GhosttyTerminalProtocol.swift
//  VVTerm
//
//  Shared enums and utilities for Ghostty terminal views
//

import Foundation

/// Special keys that can be sent to the terminal
enum TerminalSpecialKey {
    case escape
    case tab
    case enter
    case backspace
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case home
    case end
    case pageUp
    case pageDown
    case delete
}

/// Utility to get the escape sequence for a special key
enum TerminalSpecialKeySequence {
    static func escapeSequence(for key: TerminalSpecialKey) -> String {
        switch key {
        case .escape:
            return "\u{1B}"
        case .tab:
            return "\t"
        case .enter:
            return "\r"
        case .backspace:
            return "\u{7F}"
        case .delete:
            return "\u{1B}[3~"
        case .arrowUp:
            return "\u{1B}[A"
        case .arrowDown:
            return "\u{1B}[B"
        case .arrowLeft:
            return "\u{1B}[D"
        case .arrowRight:
            return "\u{1B}[C"
        case .home:
            return "\u{1B}[H"
        case .end:
            return "\u{1B}[F"
        case .pageUp:
            return "\u{1B}[5~"
        case .pageDown:
            return "\u{1B}[6~"
        }
    }
}

/// Utility to compute the control character for a given letter (Ctrl+A = 0x01, Ctrl+Z = 0x1A)
enum TerminalControlKey {
    /// Returns the control character for the given letter, or nil if not A-Z
    static func controlCharacter(for char: Character) -> Character? {
        let asciiValue = char.uppercased().first?.asciiValue ?? 0
        if asciiValue >= 65 && asciiValue <= 90 {
            return Character(UnicodeScalar(asciiValue - 64))
        }
        return nil
    }
}

/// Utility for encoding software-keyboard modifier combinations in a TUI-compatible form.
enum TerminalSoftwareModifierEncoder {
    /// Encodes Ctrl/Alt + printable key as ANSI bytes when that combination has
    /// a canonical control-byte representation (e.g. Ctrl+T => 0x14).
    static func encodeControlSequence(char: Character, ctrl: Bool, alt: Bool) -> Data? {
        guard ctrl else { return nil }
        guard let controlChar = TerminalControlKey.controlCharacter(for: char) else { return nil }
        var data = Data()
        if alt {
            data.append(0x1B)
        }
        data.append(contentsOf: String(controlChar).utf8)
        return data
    }
}

/// Mapping helper for software-keyboard characters sent through `insertText`.
/// Preserves the original typed character while still providing an unshifted key identity.
enum TerminalSoftwareCharacterMapper {
    struct MappedCharacter: Equatable {
        let key: Ghostty.Input.Key
        let mods: Ghostty.Input.Mods
        let consumedMods: Ghostty.Input.Mods
        let text: String
        let unshiftedCodepoint: UInt32
    }

    static func mapSingleCharacter(_ text: String) -> MappedCharacter? {
        guard text.count == 1, let scalar = text.unicodeScalars.first else { return nil }

        let typedCharacter = Character(scalar)
        guard let mapping = mapping(for: typedCharacter) else { return nil }
        let typedText = String(typedCharacter)
        let unshiftedCodepoint = mapping.unshifted.unicodeScalars.first?.value ?? scalar.value
        return MappedCharacter(
            key: mapping.key,
            mods: mapping.mods,
            consumedMods: mapping.mods,
            text: typedText,
            unshiftedCodepoint: unshiftedCodepoint
        )
    }

    /// Reconstruct a hardware-like key identity for printable ASCII software input.
    /// This keeps TUIs like zellij in the same keybinding path they use for hardware keyboards.
    private static func mapping(for character: Character) -> (key: Ghostty.Input.Key, mods: Ghostty.Input.Mods, unshifted: Character)? {
        func shifted(_ key: Ghostty.Input.Key, _ unshifted: Character) -> (Ghostty.Input.Key, Ghostty.Input.Mods, Character) {
            (key, [.shift], unshifted)
        }

        switch character {
        case "a": return (.a, [], "a")
        case "A": return shifted(.a, "a")
        case "b": return (.b, [], "b")
        case "B": return shifted(.b, "b")
        case "c": return (.c, [], "c")
        case "C": return shifted(.c, "c")
        case "d": return (.d, [], "d")
        case "D": return shifted(.d, "d")
        case "e": return (.e, [], "e")
        case "E": return shifted(.e, "e")
        case "f": return (.f, [], "f")
        case "F": return shifted(.f, "f")
        case "g": return (.g, [], "g")
        case "G": return shifted(.g, "g")
        case "h": return (.h, [], "h")
        case "H": return shifted(.h, "h")
        case "i": return (.i, [], "i")
        case "I": return shifted(.i, "i")
        case "j": return (.j, [], "j")
        case "J": return shifted(.j, "j")
        case "k": return (.k, [], "k")
        case "K": return shifted(.k, "k")
        case "l": return (.l, [], "l")
        case "L": return shifted(.l, "l")
        case "m": return (.m, [], "m")
        case "M": return shifted(.m, "m")
        case "n": return (.n, [], "n")
        case "N": return shifted(.n, "n")
        case "o": return (.o, [], "o")
        case "O": return shifted(.o, "o")
        case "p": return (.p, [], "p")
        case "P": return shifted(.p, "p")
        case "q": return (.q, [], "q")
        case "Q": return shifted(.q, "q")
        case "r": return (.r, [], "r")
        case "R": return shifted(.r, "r")
        case "s": return (.s, [], "s")
        case "S": return shifted(.s, "s")
        case "t": return (.t, [], "t")
        case "T": return shifted(.t, "t")
        case "u": return (.u, [], "u")
        case "U": return shifted(.u, "u")
        case "v": return (.v, [], "v")
        case "V": return shifted(.v, "v")
        case "w": return (.w, [], "w")
        case "W": return shifted(.w, "w")
        case "x": return (.x, [], "x")
        case "X": return shifted(.x, "x")
        case "y": return (.y, [], "y")
        case "Y": return shifted(.y, "y")
        case "z": return (.z, [], "z")
        case "Z": return shifted(.z, "z")
        case "0": return (.digit0, [], "0")
        case ")": return shifted(.digit0, "0")
        case "1": return (.digit1, [], "1")
        case "!": return shifted(.digit1, "1")
        case "2": return (.digit2, [], "2")
        case "@": return shifted(.digit2, "2")
        case "3": return (.digit3, [], "3")
        case "#": return shifted(.digit3, "3")
        case "4": return (.digit4, [], "4")
        case "$": return shifted(.digit4, "4")
        case "5": return (.digit5, [], "5")
        case "%": return shifted(.digit5, "5")
        case "6": return (.digit6, [], "6")
        case "^": return shifted(.digit6, "6")
        case "7": return (.digit7, [], "7")
        case "&": return shifted(.digit7, "7")
        case "8": return (.digit8, [], "8")
        case "*": return shifted(.digit8, "8")
        case "9": return (.digit9, [], "9")
        case "(": return shifted(.digit9, "9")
        case "-": return (.minus, [], "-")
        case "_": return shifted(.minus, "-")
        case "=": return (.equal, [], "=")
        case "+": return shifted(.equal, "=")
        case "[": return (.bracketLeft, [], "[")
        case "{": return shifted(.bracketLeft, "[")
        case "]": return (.bracketRight, [], "]")
        case "}": return shifted(.bracketRight, "]")
        case "\\": return (.backslash, [], "\\")
        case "|": return shifted(.backslash, "\\")
        case ";": return (.semicolon, [], ";")
        case ":": return shifted(.semicolon, ";")
        case "'": return (.quote, [], "'")
        case "\"": return shifted(.quote, "'")
        case ",": return (.comma, [], ",")
        case "<": return shifted(.comma, ",")
        case ".": return (.period, [], ".")
        case ">": return shifted(.period, ".")
        case "/": return (.slash, [], "/")
        case "?": return shifted(.slash, "/")
        case "`": return (.backquote, [], "`")
        case "~": return shifted(.backquote, "`")
        case " ": return (.space, [], " ")
        default: return nil
        }
    }
}

/// Mapping helper for iOS software keyboard special tokens (for example
/// `UIKeyInputDelete`) that may be delivered through `insertText`.
enum TerminalSoftwareInputTokenMapper {
    static func mapToken(_ token: String) -> TerminalSpecialKey? {
        switch token {
        case "UIKeyInputDelete":
            return .backspace
        case "UIKeyInputDeleteForward":
            return .delete
        case "UIKeyInputEscape":
            return .escape
        case "UIKeyInputUpArrow":
            return .arrowUp
        case "UIKeyInputDownArrow":
            return .arrowDown
        case "UIKeyInputLeftArrow":
            return .arrowLeft
        case "UIKeyInputRightArrow":
            return .arrowRight
        case "UIKeyInputHome":
            return .home
        case "UIKeyInputEnd":
            return .end
        case "UIKeyInputPageUp":
            return .pageUp
        case "UIKeyInputPageDown":
            return .pageDown
        case "UIKeyInputTab":
            return .tab
        default:
            return nil
        }
    }

    static func cursorDelta(for key: TerminalSpecialKey) -> Int {
        switch key {
        case .backspace:
            return -1
        case .enter, .tab:
            return 1
        default:
            return 0
        }
    }
}
