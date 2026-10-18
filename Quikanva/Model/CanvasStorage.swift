import CryptoKit
import Foundation
import SwiftData

@Model
final class CanvasImageAsset {
    var contentHash: String = ""
    @Attribute(.externalStorage) var data: Data = Data()

    init(contentHash: String, data: Data) {
        self.contentHash = contentHash
        self.data = data
    }
}

@MainActor
enum CanvasStorage {
    /// Called before opening the first migrated store, while no other app instance owns it.
    static func backUpBeforeMigration(at storeURL: URL) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: storeURL.path) else { return }
        let base = storeURL.deletingLastPathComponent()
        let backup = base.appending(path: "Before-iCloud-Migration", directoryHint: .isDirectory)
        guard !files.fileExists(atPath: backup.path) else { return }
        let staging = base.appending(path: ".migration-backup-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: staging) }
        let names = [storeURL.lastPathComponent, storeURL.lastPathComponent + "-wal",
                     storeURL.lastPathComponent + "-shm", "." + storeURL.deletingPathExtension().lastPathComponent + "_SUPPORT"]
        for name in names {
            let source = base.appending(path: name)
            if files.fileExists(atPath: source.path) {
                try files.copyItem(at: source, to: staging.appending(path: name))
            }
        }
        try files.moveItem(at: staging, to: backup)
    }

    static func container(at url: URL? = nil) throws -> ModelContainer {
        let config: ModelConfiguration
        if let url {
            config = ModelConfiguration(url: url, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: CanvasDocument.self, CanvasImageAsset.self, configurations: config)
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func assetIndex(in context: ModelContext) throws -> [String: CanvasImageAsset] {
        Dictionary(try context.fetch(FetchDescriptor<CanvasImageAsset>()).map { ($0.contentHash, $0) },
                   uniquingKeysWith: { first, _ in first })
    }

    static func encode(_ scene: CanvasScene, in context: ModelContext) throws -> Data {
        var stored = scene
        var inserted = Set<String>()
        for index in stored.elements.indices {
            if let bytes = stored.elements[index].imageData {
                let key = hash(bytes)
                let descriptor = FetchDescriptor<CanvasImageAsset>(predicate: #Predicate { $0.contentHash == key })
                if !inserted.contains(key), try context.fetch(descriptor).isEmpty {
                    context.insert(CanvasImageAsset(contentHash: key, data: bytes))
                    inserted.insert(key)
                }
                stored.elements[index].imageAssetHash = key
                stored.elements[index].imageData = nil
            } else if let key = stored.elements[index].imageAssetHash {
                let descriptor = FetchDescriptor<CanvasImageAsset>(predicate: #Predicate { $0.contentHash == key })
                if !inserted.contains(key), try context.fetch(descriptor).isEmpty {
                    throw StorageError.missingImage
                }
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(stored)
    }

    static func decode(_ data: Data, assets: [String: Data]) throws -> CanvasScene {
        var scene = try JSONDecoder().decode(CanvasScene.self, from: data)
        for index in scene.elements.indices {
            if scene.elements[index].imageData == nil, let key = scene.elements[index].imageAssetHash {
                guard let bytes = assets[key] else { throw StorageError.missingImage }
                scene.elements[index].imageData = bytes
            }
        }
        return scene
    }

    static func load(_ doc: CanvasDocument, in context: ModelContext) throws -> CanvasScene {
        let scene = try JSONDecoder().decode(CanvasScene.self, from: doc.sceneData)
        let required = Set(scene.elements.compactMap(\.imageAssetHash))
        let index = try assetIndex(in: context)
        var bytes: [String: Data] = [:]
        for hash in required {
            if let asset = index[hash], self.hash(asset.data) == hash { bytes[hash] = asset.data }
        }
        return try decode(doc.sceneData, assets: bytes)
    }

    /// Runs in one transaction. A failed extraction leaves the legacy JSON intact.
    static func migrateEmbeddedImages(in context: ModelContext) throws {
        do {
            for doc in try context.fetch(FetchDescriptor<CanvasDocument>()) where !doc.isTombstone {
                let scene = try JSONDecoder().decode(CanvasScene.self, from: doc.sceneData)
                if scene.elements.contains(where: { $0.imageData != nil }) {
                    doc.sceneData = try encode(scene, in: context)
                }
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    enum StorageError: LocalizedError {
        case missingImage
        var errorDescription: String? { "A sketch image has not finished downloading. Try again shortly." }
    }
}
