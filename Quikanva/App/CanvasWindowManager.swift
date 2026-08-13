import AppKit
import SwiftUI
import SwiftData

final class FloatingCanvasWindow: NSWindow {
    var onClose: (() -> Void)?

    var activeUndoManager: UndoManager? {
        firstResponder?.undoManager ?? contentView?.canvasUndoManager
    }

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

enum CanvasWindowLevel {
    static func value(alwaysOnTop: Bool) -> NSWindow.Level {
        alwaysOnTop ? .floating : .normal
    }
}

@MainActor
final class CanvasWindowManager {
    static let shared = CanvasWindowManager()

    var container: ModelContainer?
    var openGallery: (() -> Void)?

    private var windows: [UUID: FloatingCanvasWindow] = [:]
    private var prewarmedWindow: FloatingCanvasWindow?
    private var prewarmedAspectRatio: CanvasAspectRatio?

    private init() {}

    private var context: ModelContext? { container?.mainContext }

    func newCanvas() {
        if let maximum = openCanvasLimit, windows.count >= maximum {
            windows.values.first.map(activate)
            return
        }
        guard let context else { return }
        let aspectRatio = CanvasPreferences.defaultAspectRatio
        let doc = CanvasDocument(title: CanvasTitle.dated(),
                                 sceneData: SceneCodec.encode(CanvasScene(background: CanvasPreferences.defaultBackground)),
                                 aspectRatio: aspectRatio)
        context.insert(doc)
        try? context.save()
        present(doc)
    }

    func prewarm() {
        guard prewarmedWindow == nil else { return }
        let aspectRatio = CanvasPreferences.defaultAspectRatio
        let window = makeWindow(aspectRatio: aspectRatio)
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.orderOut(nil)
        prewarmedWindow = window
        prewarmedAspectRatio = aspectRatio
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
        guard let undoManager = activeWindow?.activeUndoManager, undoManager.canUndo else { return }
        undoManager.undo()
    }

    func redo() {
        guard let undoManager = activeWindow?.activeUndoManager, undoManager.canRedo else { return }
        undoManager.redo()
    }

    func updateAlwaysOnTop(_ enabled: Bool) {
        let level = CanvasWindowLevel.value(alwaysOnTop: enabled)
        windows.values.forEach { $0.level = level }
        prewarmedWindow?.level = level
    }

    func route(_ url: URL) {
        guard url.scheme == "quikanva" else { return }
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
        if let maximum = openCanvasLimit, windows.count >= maximum {
            windows.values.first.map(activate)
            return
        }

        let aspectRatio = doc.aspectRatio
        let window: FloatingCanvasWindow
        if let prewarmedWindow, prewarmedAspectRatio == aspectRatio {
            window = prewarmedWindow
        } else {
            window = makeWindow(aspectRatio: aspectRatio)
        }
        prewarmedWindow = nil
        prewarmedAspectRatio = nil
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
        window.setContentSize(initialContentSize(for: aspectRatio))
        window.center()

        let id = doc.id
        window.onClose = { [weak self] in
            self?.didClose(doc, id: id)
        }
        windows[id] = window
        activate(window)
        prewarm()
    }

    private func makeWindow(aspectRatio: CanvasAspectRatio = CanvasPreferences.defaultAspectRatio) -> FloatingCanvasWindow {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        let contentSize = initialContentSize(for: aspectRatio)
        let window = FloatingCanvasWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false)
        window.minSize = NSSize(width: 360, height: 640)
        window.contentAspectRatio = NSSize(width: aspectRatio.widthToHeight, height: 1)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.level = CanvasWindowLevel.value(alwaysOnTop: CanvasPreferences.alwaysOnTop)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.tabbingMode = .disallowed
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenPrimary)
        return window
    }

    private func initialContentSize(for aspectRatio: CanvasAspectRatio) -> NSSize {
        let idealHeight: CGFloat = 1200
        let idealContentSize = NSSize(width: idealHeight * aspectRatio.widthToHeight,
                                      height: idealHeight)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        let idealFrameSize = NSWindow.frameRect(forContentRect: NSRect(origin: .zero, size: idealContentSize),
                                                styleMask: styleMask).size
        let availableFrameSize = NSScreen.main?.visibleFrame.insetBy(dx: 24, dy: 24).size ?? idealFrameSize
        let scale = min(1,
                        availableFrameSize.width / idealFrameSize.width,
                        availableFrameSize.height / idealFrameSize.height)
        return NSSize(width: idealContentSize.width * scale,
                      height: idealContentSize.height * scale)
    }

    private func didClose(_ doc: CanvasDocument, id: UUID) {
        windows.removeValue(forKey: id)
        guard let context,
              CanvasPreferences.discardEmptyCanvases,
              SceneCodec.decode(doc.sceneData).elements.isEmpty else { return }
        context.delete(doc)
        try? context.save()
    }

    private func activate(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private var openCanvasLimit: Int? {
        let maximum = CanvasPreferences.maxOpenCanvasPanels
        return maximum > 0 ? maximum : nil
    }

    private var activeWindow: FloatingCanvasWindow? {
        windows.values.first(where: \.isKeyWindow)
    }
}

private extension NSView {
    var canvasUndoManager: UndoManager? {
        if let canvas = self as? CanvasNSView {
            return canvas.undoManager
        }
        return subviews.lazy.compactMap(\.canvasUndoManager).first
    }
}
