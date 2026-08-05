import AppKit
import SwiftUI
import SwiftData

final class FloatingCanvasWindow: NSWindow {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func close() {
        onClose?()
        onClose = nil
        super.close()
    }
}

@MainActor
final class CanvasWindowManager {
    static let shared = CanvasWindowManager()

    var container: ModelContainer?
    var openGallery: (() -> Void)?

    private var windows: [UUID: FloatingCanvasWindow] = [:]

    private init() {}

    private var context: ModelContext? { container?.mainContext }

    func newCanvas() {
        guard let context else { return }
        let doc = CanvasDocument(title: CanvasTitle.dated(),
                                 sceneData: SceneCodec.encode(CanvasScene()))
        context.insert(doc)
        try? context.save()
        present(doc)
    }

    func open(_ id: UUID) {
        if let existing = windows[id] {
            activate(existing)
            return
        }
        guard let context else { return }
        let descriptor = FetchDescriptor<CanvasDocument>(predicate: #Predicate { $0.id == id })
        if let doc = try? context.fetch(descriptor).first {
            present(doc)
        }
    }

    func close(_ id: UUID) {
        windows[id]?.close()
    }

    func route(_ url: URL) {
        guard url.scheme == "quikkanva" else { return }
        switch url.host {
        case "new":
            newCanvas()
        case "gallery":
            openGallery?()
        case "open":
            if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
               let id = UUID(uuidString: value) {
                open(id)
            }
        default:
            break
        }
    }

    private func present(_ doc: CanvasDocument) {
        guard let context else { return }
        if let existing = windows[doc.id] {
            activate(existing)
            return
        }

        let window = FloatingCanvasWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.title = doc.title
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.tabbingMode = .disallowed
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.minSize = NSSize(width: 480, height: 360)
        window.collectionBehavior.insert(.fullScreenPrimary)

        window.contentView = NSHostingView(rootView: CanvasPanelView(doc: doc, context: context) { [weak window] in
            window?.close()
        })
        window.center()

        let id = doc.id
        window.onClose = { [weak self] in
            self?.didClose(doc, id: id)
        }
        windows[id] = window
        activate(window)
    }

    private func didClose(_ doc: CanvasDocument, id: UUID) {
        windows.removeValue(forKey: id)
        guard let context,
              doc.title.hasPrefix("Sketch — "),
              SceneCodec.decode(doc.sceneData).elements.isEmpty else { return }
        context.delete(doc)
        try? context.save()
    }

    private func activate(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
