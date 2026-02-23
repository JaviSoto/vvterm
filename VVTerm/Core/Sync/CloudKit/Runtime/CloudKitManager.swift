import CloudKit
import Foundation
import os.log
import Security

// MARK: - CloudKit Manager

@MainActor
final class CloudKitManager {
    static let shared = CloudKitManager()

    typealias SyncStatus = CloudKitSyncState.Status

    let statusStore = CloudKitSyncStatusStore()

    var syncState: CloudKitSyncState { statusStore.syncState }
    var lastSyncDate: Date? { statusStore.lastSyncDate }
    var accountState: CloudKitAccountState { statusStore.accountState }
    var syncStatus: SyncStatus { statusStore.syncState.status }
    var isAvailable: Bool { statusStore.syncState.isAvailable }
    var cloudKitSyncGeneration = UUID()

    let container: CKContainer?
    let database: CKDatabase?
    let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "VVTerm",
        category: "CloudKit"
    )
    let recordZoneName = CloudKitSyncConstants.recordZoneName
    lazy var recordZone = CKRecordZone(zoneName: recordZoneName)
    var recordZoneID: CKRecordZone.ID { recordZone.zoneID }
    var changeTokenKey: String { CloudKitSyncConstants.changeTokenKey(for: recordZoneName) }
    var zoneReadyKey: String { CloudKitSyncConstants.zoneReadyKey(for: recordZoneName) }

    let syncEnabled: @MainActor @Sendable () -> Bool
    let fetchAccountStatus: @MainActor @Sendable () async throws -> CKAccountStatus
    var isSyncEnabled: Bool { syncEnabled() && database != nil }
    struct AccountStatusCheck {
        let id: UUID
        let generation: UUID
        let task: Task<CKAccountStatus, Error>
    }

    struct InFlightRecordChanges {
        let id: UUID
        let identity: CloudKitRecordChangeFetchIdentity
        let task: Task<CloudKitRawRecordChanges, Error>
        var waiters: [UUID: CloudKitTaskContinuation<CloudKitRawRecordChanges>]
        var teardownWaiters: [UUID: CloudKitTaskContinuation<Void>]
    }

    struct PendingRecordChanges {
        let identity: CloudKitRecordChangeFetchIdentity
        let changes: CloudKitRawRecordChanges
        let token: CKServerChangeToken?
    }

    struct FetchedRecordChanges {
        let changes: [CloudKitRawRecordChange]
        let isFullFetch: Bool
        let token: CKServerChangeToken?
    }

    var inFlightRecordChanges: InFlightRecordChanges?
    var pendingRecordChanges: PendingRecordChanges?
    var accountStatusCheck: AccountStatusCheck?
    var ensureZoneTask: Task<Void, Error>?
    var zoneReady: Bool

    private static func resolveCloudKitContainerID() -> String? {
        #if os(iOS) || os(tvOS) || os(watchOS)
        // Ad-hoc iOS builds frequently ship without CloudKit entitlements.
        return nil
        #else
        let entitlementKey = "com.apple.developer.icloud-container-identifiers" as CFString
        guard let task = SecTaskCreateFromSelf(nil),
              let entitlement = SecTaskCopyValueForEntitlement(task, entitlementKey, nil) else {
            return nil
        }

        if let containerIDs = entitlement as? [String] {
            return containerIDs.first
        }
        return entitlement as? String
        #endif
    }

    private convenience init() {
        guard let containerID = Self.resolveCloudKitContainerID() else {
            self.init(
                container: nil,
                syncEnabled: { SyncSettings.isEnabled },
                accountStatus: { throw CloudKitError.notAvailable }
            )
            logger.warning("CloudKit disabled: missing iCloud container entitlements")
            return
        }

        let container = CKContainer(identifier: containerID)
        self.init(
            container: container,
            syncEnabled: { SyncSettings.isEnabled },
            accountStatus: { try await container.accountStatus() }
        )
    }

    init(
        container: CKContainer?,
        syncEnabled: @escaping @MainActor @Sendable () -> Bool,
        accountStatus: @escaping @MainActor @Sendable () async throws -> CKAccountStatus,
        initialZoneReady: Bool = UserDefaults.standard.bool(
            forKey: CloudKitSyncConstants.zoneReadyKey()
        )
    ) {
        self.container = container
        database = container?.privateCloudDatabase
        self.syncEnabled = syncEnabled
        fetchAccountStatus = accountStatus
        zoneReady = initialZoneReady
        if isSyncEnabled {
            let generation = cloudKitSyncGeneration
            Task { [weak self] in
                await self?.checkAccountStatus(for: generation)
            }
        } else {
            applySyncDisabledState()
        }
    }

    func requireDatabase() throws -> CKDatabase {
        guard let database else {
            throw CloudKitError.notAvailable
        }
        return database
    }
}
