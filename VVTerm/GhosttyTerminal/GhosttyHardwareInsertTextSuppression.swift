#if os(iOS)
import Foundation

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
#endif
