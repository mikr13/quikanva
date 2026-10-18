import Foundation
import SwiftData

/// The working store is always local. Only this separate replica is managed by CloudKit.
@MainActor
enum CanvasMirror {
    static func reconcile(local: ModelContext, cloud: ModelContext) throws {
        let localAssets = try CanvasStorage.assetIndex(in: local)
        let cloudAssets = try CanvasStorage.assetIndex(in: cloud)
        var availableAssets = Set(localAssets.keys)
        for (hash, asset) in cloudAssets where localAssets[hash] == nil {
            let bytes = asset.data
            guard CanvasStorage.hash(bytes) == hash else { continue }
            local.insert(CanvasImageAsset(contentHash: hash, data: bytes))
            availableAssets.insert(hash)
        }
        for (hash, asset) in localAssets where cloudAssets[hash] == nil {
            cloud.insert(CanvasImageAsset(contentHash: hash, data: asset.data))
        }
        let localDocs = canonical(try local.fetch(FetchDescriptor<CanvasDocument>()))
        let cloudDocs = canonical(try cloud.fetch(FetchDescriptor<CanvasDocument>()))

        for id in Set(localDocs.keys).union(cloudDocs.keys) {
            let localDoc = localDocs[id]
            let cloudDoc = cloudDocs[id]
            if let remote = cloudDoc, localDoc == nil || isNewer(remote, than: localDoc!) {
                // Records and assets may arrive in different imports. Wait for all images.
                if !remote.isTombstone {
                    guard let scene = try? JSONDecoder().decode(CanvasScene.self, from: remote.sceneData),
                          scene.elements.allSatisfy({ element in
                              element.imageData != nil || element.imageAssetHash.map(availableAssets.contains) ?? true
                          }) else { continue }
                }
                let target = localDoc ?? insertCopy(of: remote, in: local)
                copy(remote, to: target)
            } else if let working = localDoc, cloudDoc == nil || isNewer(working, than: cloudDoc!) {
                let target = cloudDoc ?? insertCopy(of: working, in: cloud)
                copy(working, to: target)
            }
        }
        // Save locally first: a failed export remains queued in the durable working store.
        if local.hasChanges { try local.save() }
        if cloud.hasChanges { try cloud.save() }
    }

    static func isNewer(_ lhs: CanvasDocument, than rhs: CanvasDocument) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.revision > rhs.revision
    }

    private static func canonical(_ docs: [CanvasDocument]) -> [UUID: CanvasDocument] {
        Dictionary(docs.map { ($0.id, $0) }, uniquingKeysWith: { isNewer($0, than: $1) ? $0 : $1 })
    }

    private static func insertCopy(of source: CanvasDocument, in context: ModelContext) -> CanvasDocument {
        let doc = CanvasDocument(id: source.id, title: source.title, sceneData: source.sceneData)
        context.insert(doc)
        return doc
    }

    private static func copy(_ source: CanvasDocument, to target: CanvasDocument) {
        target.title = source.title
        target.createdAt = source.createdAt
        target.updatedAt = source.updatedAt
        target.sceneData = source.sceneData
        target.aspectRatioRawValue = source.aspectRatioRawValue
        target.thumbnail = source.thumbnail
        target.revision = source.revision
        target.isTombstone = source.isTombstone
    }
}
