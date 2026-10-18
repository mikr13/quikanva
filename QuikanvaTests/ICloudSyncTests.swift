import AppKit
import CoreData
import SwiftData
import SwiftUI
import XCTest
@testable import Quikanva

@MainActor
final class ICloudSyncTests: XCTestCase {
    func testReleaseStoreMigratesWithoutLosingSketchMetadata() throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LegacyStore", withExtension: nil))
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try CanvasStorage.backUpBeforeMigration(at: directory.appending(path: "Quikanva.store"))
        try CanvasStorage.backUpBeforeMigration(at: directory.appending(path: "Quikanva.store"))
        let backup = directory.appending(path: "Before-iCloud-Migration/Quikanva.store")
        XCTAssertEqual(try Data(contentsOf: backup), try Data(contentsOf: directory.appending(path: "Quikanva.store")))
        let store = try CanvasStorage.container(at: directory.appending(path: "Quikanva.store"))
        let doc = try XCTUnwrap(store.mainContext.fetch(FetchDescriptor<CanvasDocument>()).first)
        XCTAssertEqual(doc.id.uuidString, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(doc.title, "Release 0.3.4 sketch")
        XCTAssertEqual(doc.createdAt, Date(timeIntervalSince1970: 1234))
        XCTAssertEqual(doc.updatedAt, Date(timeIntervalSince1970: 5678))
        XCTAssertEqual(doc.thumbnail, Data([9, 8, 7]))
        XCTAssertFalse(doc.isTombstone)
        XCTAssertEqual(try CanvasStorage.load(doc, in: store.mainContext).camera.zoom, 1.5)
        let originalImage = try XCTUnwrap(CanvasStorage.load(doc, in: store.mainContext).elements.first?.imageData)
        XCTAssertNotNil(NSImage(data: originalImage))
        try CanvasStorage.migrateEmbeddedImages(in: store.mainContext)
        XCTAssertEqual(try CanvasStorage.load(doc, in: store.mainContext).elements.first?.imageData, originalImage)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<CanvasImageAsset>()), 1)
        XCTAssertEqual(doc.updatedAt, Date(timeIntervalSince1970: 5678))
    }

    func testImageMigrationIsLosslessSmallAndIdempotent() throws {
        let store = try CanvasStorage.container()
        let scene = imageScene()
        let doc = CanvasDocument(title: "Legacy image", sceneData: SceneCodec.encode(scene))
        store.mainContext.insert(doc)
        try store.mainContext.save()
        let originalDate = doc.updatedAt
        try CanvasStorage.migrateEmbeddedImages(in: store.mainContext)
        try CanvasStorage.migrateEmbeddedImages(in: store.mainContext)
        XCTAssertLessThan(doc.sceneData.count, 3_000)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<CanvasImageAsset>()), 1)
        let loaded = try CanvasStorage.load(doc, in: store.mainContext)
        XCTAssertEqual(loaded.elements.map(\.imageData), scene.elements.map(\.imageData))
        XCTAssertEqual(doc.updatedAt, originalDate)
        let asset = try XCTUnwrap(store.mainContext.fetch(FetchDescriptor<CanvasImageAsset>()).first)
        try CanvasPanelView.persist(loaded, doc: doc, context: store.mainContext)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<CanvasImageAsset>()), 1)
        XCTAssertEqual(asset.data, scene.elements[0].imageData)
    }

    func testTwoStoresExchangeCreateEditRenameImageAndDelete() throws {
        let macA = try CanvasStorage.container()
        let macB = try CanvasStorage.container()
        let cloud = try CanvasStorage.container()
        let scene = imageScene()
        let doc = CanvasDocument(title: "Sketch", sceneData: try CanvasStorage.encode(scene, in: macA.mainContext))
        macA.mainContext.insert(doc)
        try macA.mainContext.save()
        try CanvasMirror.reconcile(local: macA.mainContext, cloud: cloud.mainContext)
        try CanvasMirror.reconcile(local: macB.mainContext, cloud: cloud.mainContext)
        let received = try XCTUnwrap(macB.mainContext.fetch(FetchDescriptor<CanvasDocument>()).first)
        XCTAssertEqual(received.id, doc.id)
        XCTAssertEqual(try CanvasStorage.load(received, in: macB.mainContext).elements[0].imageData, scene.elements[0].imageData)
        received.title = "Renamed on B"
        received.markChanged()
        try macB.mainContext.save()
        try CanvasMirror.reconcile(local: macB.mainContext, cloud: cloud.mainContext)
        try CanvasMirror.reconcile(local: macA.mainContext, cloud: cloud.mainContext)
        XCTAssertEqual(doc.title, "Renamed on B")
        received.markDeleted()
        try macB.mainContext.save()
        try CanvasMirror.reconcile(local: macB.mainContext, cloud: cloud.mainContext)
        try CanvasMirror.reconcile(local: macA.mainContext, cloud: cloud.mainContext)
        XCTAssertTrue(doc.isTombstone)
        let before = doc.revision
        try CanvasPanelView.persist(scene, doc: doc, context: macA.mainContext)
        XCTAssertTrue(doc.isTombstone)
        XCTAssertEqual(doc.revision, before, "An open editor must not resurrect a remote deletion")
    }

    func testOfflineWholeCanvasConflictConvergesToLatestSave() throws {
        let a = try CanvasStorage.container()
        let b = try CanvasStorage.container()
        let cloud = try CanvasStorage.container()
        let id = UUID()
        let earlier = CanvasDocument(id: id, title: "A", updatedAt: Date(timeIntervalSince1970: 100), sceneData: SceneCodec.encode(CanvasScene()))
        let later = CanvasDocument(id: id, title: "B", updatedAt: Date(timeIntervalSince1970: 200), sceneData: SceneCodec.encode(CanvasScene(background: .black)))
        a.mainContext.insert(earlier)
        b.mainContext.insert(later)
        try CanvasMirror.reconcile(local: a.mainContext, cloud: cloud.mainContext)
        try CanvasMirror.reconcile(local: b.mainContext, cloud: cloud.mainContext)
        try CanvasMirror.reconcile(local: a.mainContext, cloud: cloud.mainContext)
        XCTAssertEqual(earlier.title, "B")
        XCTAssertEqual(earlier.sceneData, later.sceneData)
        try CanvasMirror.reconcile(local: a.mainContext, cloud: cloud.mainContext)
        XCTAssertFalse(a.mainContext.hasChanges)
        XCTAssertFalse(cloud.mainContext.hasChanges)
    }

    func testRemoteCanvasWaitsForImagesArrivingInLaterImport() throws {
        let local = try CanvasStorage.container()
        let cloud = try CanvasStorage.container()
        let scene = imageScene()
        let encoded = try CanvasStorage.encode(scene, in: cloud.mainContext)
        let asset = try XCTUnwrap(cloud.mainContext.fetch(FetchDescriptor<CanvasImageAsset>()).first)
        let hash = asset.contentHash
        let bytes = asset.data
        cloud.mainContext.delete(asset)
        let remote = CanvasDocument(title: "Arriving", sceneData: encoded)
        cloud.mainContext.insert(remote)
        try cloud.mainContext.save()
        XCTAssertThrowsError(try CanvasPanelView(doc: remote, context: cloud.mainContext))
        try CanvasMirror.reconcile(local: local.mainContext, cloud: cloud.mainContext)
        XCTAssertEqual(try local.mainContext.fetchCount(FetchDescriptor<CanvasDocument>()), 0)
        cloud.mainContext.insert(CanvasImageAsset(contentHash: hash, data: bytes))
        try cloud.mainContext.save()
        try CanvasMirror.reconcile(local: local.mainContext, cloud: cloud.mainContext)
        XCTAssertEqual(try local.mainContext.fetchCount(FetchDescriptor<CanvasDocument>()), 1)
    }

    func testCloudReplicaRemovalCannotDeleteWorkingSketches() throws {
        let local = try CanvasStorage.container()
        var cloud = try CanvasStorage.container()
        let doc = CanvasDocument(title: "Keep local", sceneData: SceneCodec.encode(CanvasScene()))
        local.mainContext.insert(doc)
        try CanvasMirror.reconcile(local: local.mainContext, cloud: cloud.mainContext)
        cloud = try CanvasStorage.container() // Simulate CloudKit clearing its account store.
        XCTAssertEqual(try local.mainContext.fetchCount(FetchDescriptor<CanvasDocument>()), 1)
        try CanvasMirror.reconcile(local: local.mainContext, cloud: cloud.mainContext)
        XCTAssertEqual(try cloud.mainContext.fetchCount(FetchDescriptor<CanvasDocument>()), 1)
        XCTAssertEqual(doc.title, "Keep local")
    }

    func testDuplicateCloudIDsWithTimestampTieChooseOneStableWinner() throws {
        let local = try CanvasStorage.container()
        let cloud = try CanvasStorage.container()
        let id = UUID()
        let date = Date(timeIntervalSince1970: 100)
        let first = CanvasDocument(id: id, title: "First", updatedAt: date, sceneData: SceneCodec.encode(CanvasScene()))
        let winner = CanvasDocument(id: id, title: "Winner", updatedAt: date, sceneData: SceneCodec.encode(CanvasScene()))
        first.revision = "A"
        winner.revision = "Z"
        cloud.mainContext.insert(winner)
        cloud.mainContext.insert(first)
        try cloud.mainContext.save()
        try CanvasMirror.reconcile(local: local.mainContext, cloud: cloud.mainContext)
        let docs = try local.mainContext.fetch(FetchDescriptor<CanvasDocument>())
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs.first?.title, "Winner")
        try CanvasMirror.reconcile(local: local.mainContext, cloud: cloud.mainContext)
        XCTAssertFalse(local.mainContext.hasChanges)
    }

    func testRemoteReloadClearsUndoAndPreservesActiveTextEditing() {
        let view = CanvasNSView()
        let remote = CanvasScene(background: .black)
        view.undoManager?.registerUndo(withTarget: view) { $0.scene = CanvasScene() }
        XCTAssertTrue(view.reloadScene(remote))
        XCTAssertEqual(view.scene, remote)
        XCTAssertFalse(view.undoManager?.canUndo ?? true)
        view.tool = .text
        view.mouseDown(with: mouseEvent(type: .leftMouseDown, view: view))
        view.mouseUp(with: mouseEvent(type: .leftMouseUp, view: view))
        XCTAssertNotNil(view.textEditorView)
        XCTAssertFalse(view.reloadScene(CanvasScene()))
        XCTAssertEqual(view.scene, remote)
    }

    func testAutosaveKeepsPendingEditsAfterFailureAndFlushesOnRetry() {
        var fail = true
        var saves = 0
        let autosave = CanvasAutosaveCoordinator { _ in
            if fail { throw CanvasStorage.StorageError.missingImage }
            saves += 1
            return "saved"
        }
        autosave.schedule(CanvasScene())
        XCTAssertFalse(autosave.shouldReload(revision: "remote"))
        autosave.flush()
        XCTAssertTrue(autosave.hasPendingChanges)
        XCTAssertNotNil(autosave.errorMessage)
        fail = false
        autosave.flush()
        XCTAssertFalse(autosave.hasPendingChanges)
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(autosave.savedRevision, "saved")
        XCTAssertFalse(autosave.shouldReload(revision: "saved"))
        XCTAssertTrue(autosave.shouldReload(revision: "remote"))
    }

    func testHostedOpenCanvasLoadsRemoteChangesWithoutAnAutosaveEcho() throws {
        let store = try CanvasStorage.container()
        let doc = CanvasDocument(title: "Open", sceneData: SceneCodec.encode(CanvasScene()))
        store.mainContext.insert(doc)
        try store.mainContext.save()
        let host = NSHostingView(rootView: try CanvasPanelView(doc: doc, context: store.mainContext))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let canvas = try XCTUnwrap(canvasView(in: host))
        let remote = CanvasScene(background: .black)
        doc.sceneData = SceneCodec.encode(remote)
        doc.markChanged()
        try store.mainContext.save()
        let remoteRevision = doc.revision
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(canvas.scene, remote)
        XCTAssertEqual(doc.revision, remoteRevision, "Reloading must not schedule another save")
    }

    func testFreshContextReadsCloudImportsFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = try CanvasStorage.container(at: directory.appending(path: "Local.store"))
        let cloud = try CanvasStorage.container(at: directory.appending(path: "Cloud.store"))
        let importer = ModelContext(cloud)
        let remote = CanvasDocument(title: "Imported on disk", sceneData: try CanvasStorage.encode(imageScene(), in: importer))
        importer.insert(remote)
        try importer.save()
        try CanvasMirror.reconcile(local: local.mainContext, cloud: ModelContext(cloud))
        let received = try XCTUnwrap(local.mainContext.fetch(FetchDescriptor<CanvasDocument>()).first)
        XCTAssertEqual(received.title, remote.title)
        XCTAssertEqual(try CanvasStorage.load(received, in: local.mainContext).elements[0].imageData?.count, 256_000)
        let reopened = try CanvasStorage.container(at: directory.appending(path: "Local.store"))
        XCTAssertEqual(try reopened.mainContext.fetchCount(FetchDescriptor<CanvasDocument>()), 1)
    }

    private func canvasView(in view: NSView) -> CanvasNSView? {
        if let canvas = view as? CanvasNSView { return canvas }
        return view.subviews.lazy.compactMap { self.canvasView(in: $0) }.first
    }

    func testCloudKitModelHasDefaultsAndNoUniqueConstraints() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.makeManagedObjectModel(for: [CanvasDocument.self, CanvasImageAsset.self]))
        for entity in model.entities {
            XCTAssertTrue(entity.uniquenessConstraints.isEmpty)
            for attribute in entity.attributesByName.values {
                XCTAssertTrue(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name ?? "").\(attribute.name) needs a default")
            }
        }
    }

    private func imageScene() -> CanvasScene {
        var image = Element(kind: .image, points: [Point(x: 10, y: 20), Point(x: 210, y: 160)])
        image.imageData = Data(repeating: 42, count: 256_000)
        var duplicate = image
        duplicate.id = UUID()
        return CanvasScene(elements: [image, duplicate])
    }

    private func mouseEvent(type: NSEvent.EventType, view: NSView) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: CGPoint(x: 30, y: 30), modifierFlags: [], timestamp: 0,
                          windowNumber: view.window?.windowNumber ?? 0, context: nil,
                          eventNumber: 0, clickCount: 1, pressure: 1)!
    }
}
