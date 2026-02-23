#if os(iOS)
import Foundation
import UIKit

struct HardwareInsertTextSuppressionState {
    private struct PendingInsertText {
        let text: String
        let enqueuedAt: CFAbsoluteTime
    }

    private var pending: [PendingInsertText] = []
    private let ttlSeconds: CFAbsoluteTime
    private let maxPendingEntries: Int

    init(ttlSeconds: CFAbsoluteTime = 0.75, maxPendingEntries: Int = 8) {
        self.ttlSeconds = ttlSeconds
        self.maxPendingEntries = maxPendingEntries
    }

    mutating func queue(_ text: String, now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) {
        guard !text.isEmpty else { return }
        prune(now: now)
        pending.append(PendingInsertText(text: text, enqueuedAt: now))
        if pending.count > maxPendingEntries {
            pending.removeFirst(pending.count - maxPendingEntries)
        }
    }

    mutating func shouldSuppress(_ text: String, now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> Bool {
        guard !text.isEmpty else { return false }
        prune(now: now)
        guard let index = pending.firstIndex(where: { $0.text == text }) else {
            return false
        }
        pending.remove(at: index)
        return true
    }

    private mutating func prune(now: CFAbsoluteTime) {
        pending.removeAll { now - $0.enqueuedAt > ttlSeconds }
    }
}

struct HardwareModifierState {
    private(set) var activeModifiers: UIKeyModifierFlags = []

    mutating func handlePressBegan(keyCode: UInt16) {
        guard let flag = modifierFlag(for: keyCode) else { return }
        activeModifiers.insert(flag)
    }

    mutating func handlePressEnded(keyCode: UInt16) {
        guard let flag = modifierFlag(for: keyCode) else { return }
        activeModifiers.remove(flag)
    }

    mutating func reset() {
        activeModifiers = []
    }

    func effectiveModifiers(reported: UIKeyModifierFlags) -> UIKeyModifierFlags {
        activeModifiers.union(reported)
    }

    private func modifierFlag(for keyCode: UInt16) -> UIKeyModifierFlags? {
        guard let usage = UIKeyboardHIDUsage(rawValue: Int(keyCode)) else { return nil }
        switch usage {
        case .keyboardLeftControl, .keyboardRightControl:
            return .control
        case .keyboardLeftAlt, .keyboardRightAlt:
            return .alternate
        case .keyboardLeftShift, .keyboardRightShift:
            return .shift
        case .keyboardLeftGUI, .keyboardRightGUI:
            return .command
        default:
            return nil
        }
    }
}

struct GhosttyHardwareInsertTextPolicy {
    static let fallbackSuppressionWindow: CFAbsoluteTime = 0.45

    static func shouldSuppressFallbackInsertText(
        text: String,
        hasActiveIMEComposition: Bool,
        systemTextInputPressesCount: Int,
        now: CFAbsoluteTime,
        lastGhosttyHardwarePressAt: CFAbsoluteTime
    ) -> Bool {
        guard !hasActiveIMEComposition else { return false }
        guard systemTextInputPressesCount == 0 else { return false }
        guard text.count == 1 else { return false }
        guard let scalar = text.unicodeScalars.first, scalar.value >= 0x20 else { return false }
        guard !text.hasPrefix("UIKeyInput") else { return false }
        guard lastGhosttyHardwarePressAt > 0 else { return false }
        return now - lastGhosttyHardwarePressAt <= fallbackSuppressionWindow
    }
}
#endif
