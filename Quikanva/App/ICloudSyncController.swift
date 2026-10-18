import AppKit
import CloudKit
import Combine
import CoreData
import Security
import SwiftData

@MainActor
final class ICloudSyncController: ObservableObject {
    static let shared = ICloudSyncController()
    static let containerIdentifier = "iCloud.com.mihirpandey.quikanva"
    private static let enabledKey = "iCloudSyncEnabled"
    private static let accountKey = "iCloudSyncAccount"

    @Published private(set) var isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    @Published private(set) var canEnable = false
    @Published private(set) var isChecking = false
    @Published private(set) var statusMessage = "iCloud sync is off. Sketches stay on this Mac."

    private var localContainer: ModelContainer?
    private var cloudContainer: ModelContainer?
    private var baseURL: URL?
    private var observers = Set<AnyCancellable>()
    private var pollTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var generation = 0
    private var isReconciling = false

    private init() {}

    func configure(local: ModelContainer, baseURL: URL) {
        localContainer = local
        self.baseURL = baseURL
#if DEBUG
        if ProcessInfo.processInfo.environment["QUIKANVA_INITIALIZE_CLOUDKIT_SCHEMA"] == "1" {
            do { try initializeDevelopmentSchema() }
            catch { statusMessage = "CloudKit schema initialization failed: \(error.localizedDescription)" }
        }
#endif
        NotificationCenter.default.publisher(for: ModelContext.didSave)
            .sink { [weak self] _ in
                // SwiftData saves on the main actor in this app; defer to avoid reentrancy.
                Task { @MainActor in self?.requestSync() }
            }.store(in: &observers)
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in Task { @MainActor in self?.requestSync() } }
            .store(in: &observers)
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return }
                let message = event.error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.isEnabled else { return }
                    if let message {
                        self.statusMessage = "iCloud transfer failed. Local sketches are kept. \(message)"
                    } else if event.endDate != nil, event.type == .import {
                        self.requestSync()
                    }
                }
            }.store(in: &observers)
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in Task { @MainActor in await self?.accountChanged() } }
            .store(in: &observers)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.requestSync() } }
            .store(in: &observers)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.requestSync()
            }
        }
        if isEnabled { requestSync() }
    }

    func setEnabled(_ enabled: Bool) {
        generation += 1
        syncTask?.cancel()
        syncTask = nil
        cloudContainer = nil
        isChecking = false
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if enabled {
            // Explicit opt-in permits this account to receive the local library.
            UserDefaults.standard.removeObject(forKey: Self.accountKey)
            requestSync()
        } else {
            statusMessage = "iCloud sync is off. Local sketches and existing iCloud copies are kept."
        }
    }

    func refreshAvailability() async {
        guard hasCloudKitEntitlement else {
            canEnable = false
            statusMessage = "iCloud sync requires a Quikanva build signed with iCloud support."
            return
        }
        isChecking = true
        defer { isChecking = false }
        do {
            canEnable = try await CKContainer(identifier: Self.containerIdentifier).accountStatus() == .available
            if !canEnable { statusMessage = "Sign in to iCloud in System Settings to use sync." }
        } catch {
            canEnable = false
            statusMessage = "Could not check iCloud: \(error.localizedDescription)"
        }
    }

    func requestSync() {
        guard isEnabled, !isReconciling, syncTask == nil, localContainer != nil else { return }
        let currentGeneration = generation
        syncTask = Task { [weak self] in
            guard let self else { return }
            await synchronize(generation: currentGeneration)
            if generation == currentGeneration { syncTask = nil }
        }
    }

    private func synchronize(generation expectedGeneration: Int) async {
        guard hasCloudKitEntitlement else {
            setEnabled(false)
            canEnable = false
            statusMessage = "This build has no iCloud entitlement. Your sketches remain local."
            return
        }
        isChecking = true
        defer { if generation == expectedGeneration { isChecking = false } }
        do {
            let account = CKContainer(identifier: Self.containerIdentifier)
            let status = try await account.accountStatus()
            guard generation == expectedGeneration, !Task.isCancelled else { return }
            guard status == .available else {
                // Do not attach the working store to an absent or different account.
                if status == .noAccount { await accountChanged() }
                else { statusMessage = "iCloud is temporarily unavailable. Changes are saved locally." }
                return
            }
            let user = try await account.userRecordID()
            guard generation == expectedGeneration, !Task.isCancelled else { return }
            let accountHash = CanvasStorage.hash(Data(user.recordName.utf8))
            if let previous = UserDefaults.standard.string(forKey: Self.accountKey), previous != accountHash {
                await accountChanged()
                return
            }
            UserDefaults.standard.set(accountHash, forKey: Self.accountKey)
            canEnable = true
            guard let localContainer, let baseURL else { return }
            if cloudContainer == nil {
                let cloudURL = baseURL.appending(path: "iCloud-\(accountHash).store")
                let config = ModelConfiguration(url: cloudURL, cloudKitDatabase: .private(Self.containerIdentifier))
                cloudContainer = try ModelContainer(for: CanvasDocument.self, CanvasImageAsset.self, configurations: config)
                NSApp.registerForRemoteNotifications()
            }
            guard let cloudContainer else { return }
            isReconciling = true
            defer { isReconciling = false }
            // A fresh context sees imports made by CloudKit, without stale registered objects.
            let cloudContext = ModelContext(cloudContainer)
            cloudContext.autosaveEnabled = false
            try CanvasMirror.reconcile(local: localContainer.mainContext, cloud: cloudContext)
            statusMessage = "iCloud sync is on. Transfers continue in the background."
        } catch {
            if generation == expectedGeneration {
                statusMessage = "iCloud sync will retry. Your sketches are saved locally. \(error.localizedDescription)"
            }
        }
    }

    private func accountChanged() async {
        setEnabled(false)
        canEnable = false
        statusMessage = "iCloud account changed. Local sketches are kept. Enable sync again to use the current account."
    }

    private var signingEntitlements: [String: Any] {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return [:] }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return [:] }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any],
              let entitlements = values[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else { return [:] }
        return entitlements
    }

    private var hasCloudKitEntitlement: Bool {
        let entitlements = signingEntitlements
        guard
              let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String],
              let services = entitlements["com.apple.developer.icloud-services"] as? [String] else { return false }
        return containers.contains(Self.containerIdentifier) && services.contains("CloudKit")
    }

#if DEBUG
    private func initializeDevelopmentSchema() throws {
        guard hasCloudKitEntitlement,
              signingEntitlements["com.apple.developer.icloud-container-environment"] as? String == "Development" else {
            throw CocoaError(.featureUnsupported)
        }
        let directory = FileManager.default.temporaryDirectory.appending(path: "Quikanva-Schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try autoreleasepool {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [CanvasDocument.self, CanvasImageAsset.self]) else {
                throw CocoaError(.persistentStoreInvalidType)
            }
            let description = NSPersistentStoreDescription(url: directory.appending(path: "Schema.store"))
            description.shouldAddStoreAsynchronously = false
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.containerIdentifier)
            let container = NSPersistentCloudKitContainer(name: "QuikanvaSchema", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema()
            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }
#endif
}
