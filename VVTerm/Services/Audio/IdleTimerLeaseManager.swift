import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
final class IdleTimerLeaseManager {
    typealias IdleTimerSetter = @MainActor (Bool) -> Void

    static let shared = IdleTimerLeaseManager()

    private var activeTokenIDs: Set<UUID> = []
    private var appliedIdleTimerDisabled = false
    private let setIdleTimerDisabled: IdleTimerSetter

    init(setIdleTimerDisabled: @escaping IdleTimerSetter = { disabled in
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }) {
        self.setIdleTimerDisabled = setIdleTimerDisabled
    }

    func acquire() -> IdleTimerLease {
        let tokenID = UUID()
        activeTokenIDs.insert(tokenID)
        applyCurrentState()

        return IdleTimerLease(tokenID: tokenID) { [weak self] releasedID in
            Task { @MainActor [weak self] in
                self?.release(tokenID: releasedID)
            }
        }
    }

    var activeTokenCount: Int {
        activeTokenIDs.count
    }

    func forceReleaseAllForTesting() {
        activeTokenIDs.removeAll()
        applyCurrentState()
    }

    private func release(tokenID: UUID) {
        guard activeTokenIDs.remove(tokenID) != nil else { return }
        applyCurrentState()
    }

    private func applyCurrentState() {
        let shouldDisableIdleTimer = !activeTokenIDs.isEmpty
        guard shouldDisableIdleTimer != appliedIdleTimerDisabled else { return }
        appliedIdleTimerDisabled = shouldDisableIdleTimer
        setIdleTimerDisabled(shouldDisableIdleTimer)
    }
}

final class IdleTimerLease {
    private let tokenID: UUID
    private let lock = NSLock()
    private var releaseHandler: ((UUID) -> Void)?

    init(tokenID: UUID, releaseHandler: @escaping (UUID) -> Void) {
        self.tokenID = tokenID
        self.releaseHandler = releaseHandler
    }

    func invalidate() {
        lock.lock()
        let handler = releaseHandler
        releaseHandler = nil
        lock.unlock()

        handler?(tokenID)
    }

    deinit {
        invalidate()
    }
}
