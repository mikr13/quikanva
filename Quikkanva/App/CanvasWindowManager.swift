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
    private var prewarmedWindow: FloatingCanvasWindow?

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

    func prewarm() {
        guard prewarmedWindow == nil else { return }
        let window = makeWindow()
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.orderOut(nil)
        prewarmedWindow = window
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

    func undo() {
        activeWindow?.undoManager?.undo()
    }

    func redo() {
        activeWindow?.undoManager?.redo()
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

        let window = prewarmedWindow ?? makeWindow()
        prewarmedWindow = nil
        window.title = doc.title

        window.contentView = NSHostingView(rootView: CanvasPanelView(
            doc: doc,
            context: context,
            onClose: { [weak window] in
                window?.close()
            },
            onTitleChange: { [weak window] in
                window?.title = doc.title
            }
        ))
        window.center()

        let id = doc.id
        window.onClose = { [weak self] in
            self?.didClose(doc, id: id)
        }
        windows[id] = window
        activate(window)
        prewarm()
    }

    private func makeWindow() -> FloatingCanvasWindow {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        let idealContentSize = NSSize(width: 675, height: 1200)
        let idealFrameSize = NSWindow.frameRect(forContentRect: NSRect(origin: .zero, size: idealContentSize),
                                                styleMask: styleMask).size
        let availableFrameSize = NSScreen.main?.visibleFrame.insetBy(dx: 24, dy: 24).size ?? idealFrameSize
        let scale = min(1,
                        availableFrameSize.width / idealFrameSize.width,
                        availableFrameSize.height / idealFrameSize.height)
        let contentSize = NSSize(width: idealContentSize.width * scale,
                                 height: idealContentSize.height * scale)
        let window = FloatingCanvasWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.tabbingMode = .disallowed
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.minSize = NSSize(width: 360, height: 640)
        window.collectionBehavior.insert(.fullScreenPrimary)
        return window
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

    private var activeWindow: FloatingCanvasWindow? {
        windows.values.first(where: \.isKeyWindow)
    }
}
