import AppKit

final class CanvasNSView: NSView {
    var scene = CanvasScene() { didSet { needsDisplay = true } }
    var tool: ToolKind = .freedraw {
        didSet {
            guard tool != oldValue else { return }
            endTextEditing()
            window?.invalidateCursorRects(for: self)
        }
    }
    var style = ElementStyle()
    var onCommit: ((CanvasScene) -> Void)?

    private var live: Element?
    private var selectedID: UUID?
    private var erasedSomething = false

    private var textEditor: NSTextField?
    private var textAnchor: CGPoint = .zero

    private enum Drag {
        case none
        case drawing
        case erasing
        case moving(origin: CGPoint, start: [Point])
        case panning(startPan: CGPoint, startMouse: CGPoint)
    }
    private var drag: Drag = .none

    var isInteracting: Bool {
        if case .none = drag { return false }
        return true
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(scene.background?.cgColor ?? RGBAColor.beige.cgColor)
        ctx.fill(bounds)

        ctx.saveGState()
        ctx.translateBy(x: CGFloat(scene.camera.panX), y: CGFloat(scene.camera.panY))
        ctx.scaleBy(x: CGFloat(scene.camera.zoom), y: CGFloat(scene.camera.zoom))
        Renderer.draw(scene, in: ctx, live: live)
        if let id = selectedID, let el = scene.elements.first(where: { $0.id == id }) {
            drawSelection(el, in: ctx)
        }
        ctx.restoreGState()
    }

    private func drawSelection(_ el: Element, in ctx: CGContext) {
        guard let box = Self.bounds(of: el)?.insetBy(dx: -6, dy: -6) else { return }
        let zoom = CGFloat(scene.camera.zoom)
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.5 / zoom)
        ctx.setLineDash(phase: 0, lengths: [5 / zoom, 4 / zoom])
        ctx.stroke(box)
        ctx.restoreGState()
    }

    // MARK: Coordinate conversion

    private func scenePoint(_ event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        return CGPoint(x: (local.x - CGFloat(scene.camera.panX)) / CGFloat(scene.camera.zoom),
                       y: (local.y - CGFloat(scene.camera.panY)) / CGFloat(scene.camera.zoom))
    }

    private func viewPoint(_ scenePt: CGPoint) -> CGPoint {
        CGPoint(x: scenePt.x * CGFloat(scene.camera.zoom) + CGFloat(scene.camera.panX),
                y: scenePt.y * CGFloat(scene.camera.zoom) + CGFloat(scene.camera.panY))
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        endTextEditing()
        window?.makeFirstResponder(self)
        let p = scenePoint(event)
        let pt = Point(p)
        switch tool {
        case .hand:
            NSCursor.closedHand.set()
            drag = .panning(startPan: CGPoint(x: scene.camera.panX, y: scene.camera.panY),
                            startMouse: convert(event.locationInWindow, from: nil))
        case .select:
            if let hit = pickElement(p) {
                selectedID = hit.id
                drag = .moving(origin: p, start: hit.points)
            } else {
                selectedID = nil
                drag = .none
            }
            needsDisplay = true
        case .eraser:
            erasedSomething = false
            drag = .erasing
            eraseAt(p)
        case .text:
            beginTextEditing(at: p)
            drag = .none
        case .freedraw:
            live = Element(kind: .freedraw, points: [pt], style: style)
            drag = .drawing
        case .rectangle, .ellipse, .diamond, .line, .arrow:
            if let kind = tool.elementKind {
                live = Element(kind: kind, points: [pt, pt], style: style)
                drag = .drawing
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        switch drag {
        case .drawing:
            guard var el = live else { return }
            let p = Point(scenePoint(event))
            if el.kind == .freedraw {
                el.points.append(p)
            } else if el.points.count >= 2 {
                el.points[1] = p
            }
            live = el
            needsDisplay = true
        case .erasing:
            eraseAt(scenePoint(event))
        case .moving(let origin, let start):
            guard let id = selectedID,
                  let idx = scene.elements.firstIndex(where: { $0.id == id }) else { return }
            let p = scenePoint(event)
            let dx = Double(p.x - origin.x), dy = Double(p.y - origin.y)
            scene.elements[idx].points = start.map { Point(x: $0.x + dx, y: $0.y + dy) }
        case .panning(let startPan, let startMouse):
            let now = convert(event.locationInWindow, from: nil)
            scene.camera.panX = Double(startPan.x + (now.x - startMouse.x))
            scene.camera.panY = Double(startPan.y + (now.y - startMouse.y))
        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch drag {
        case .drawing:
            commitLive()
        case .erasing:
            if erasedSomething { onCommit?(scene) }
        case .moving:
            onCommit?(scene)
        case .panning:
            if tool == .hand { NSCursor.openHand.set() }
        case .none:
            break
        }
        drag = .none
    }

    private func commitLive() {
        defer { live = nil }
        guard let el = live else { return }

        if el.kind != .freedraw, el.points.count >= 2 {
            let d = hypot(el.points[0].x - el.points[1].x, el.points[0].y - el.points[1].y)
            if d < 3 { needsDisplay = true; return }
        }

        var updated = scene
        var committed = el
        committed.zIndex = (updated.elements.map(\.zIndex).max() ?? 0) + 1
        updated.elements.append(committed)
        scene = updated
        onCommit?(updated)
    }

    private func eraseAt(_ p: CGPoint) {
        guard let hit = pickElement(p) else { return }
        scene.elements.removeAll { $0.id == hit.id }
        if selectedID == hit.id { selectedID = nil }
        erasedSomething = true
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117, let id = selectedID {
            scene.elements.removeAll { $0.id == id }
            selectedID = nil
            onCommit?(scene)
            return
        }
        super.keyDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        scene.camera.panX += Double(event.scrollingDeltaX)
        scene.camera.panY += Double(event.scrollingDeltaY)
        needsDisplay = true
    }

    override func magnify(with event: NSEvent) {
        let anchor = convert(event.locationInWindow, from: nil)
        let sceneAnchor = scenePoint(event)
        let zoom = max(0.2, min(6, scene.camera.zoom * (1 + Double(event.magnification))))
        scene.camera.zoom = zoom
        let adjustedAnchor = viewPoint(sceneAnchor)
        scene.camera.panX += Double(anchor.x - adjustedAnchor.x)
        scene.camera.panY += Double(anchor.y - adjustedAnchor.y)
        needsDisplay = true
    }

    // MARK: Text editing

    private func beginTextEditing(at p: CGPoint) {
        endTextEditing()
        let zoom = CGFloat(scene.camera.zoom)
        let origin = viewPoint(p)
        let size = max(8, CGFloat(style.fontSize) * zoom)
        let field = NSTextField(frame: NSRect(x: origin.x, y: origin.y, width: 260, height: size + 10))
        field.font = NSFont(name: "HelveticaNeue", size: size) ?? NSFont.systemFont(ofSize: size)
        field.textColor = NSColor(cgColor: style.stroke.cgColor) ?? .labelColor
        field.drawsBackground = false
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = "Text"
        field.delegate = self
        textAnchor = p
        textEditor = field
        addSubview(field)
        window?.makeFirstResponder(field)
    }

    private func endTextEditing() {
        guard let field = textEditor else { return }
        textEditor = nil
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        field.removeFromSuperview()
        guard !value.isEmpty else { return }
        var el = Element(kind: .text, points: [Point(textAnchor)], style: style, text: value)
        el.zIndex = (scene.elements.map(\.zIndex).max() ?? 0) + 1
        scene.elements.append(el)
        onCommit?(scene)
    }

    // MARK: Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.activeInKeyWindow, .inVisibleRect, .cursorUpdate],
                                       owner: self,
                                       userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        if tool == .hand {
            NSCursor.openHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    // MARK: Hit testing

    private func pickElement(_ p: CGPoint) -> Element? {
        for el in scene.elements.sorted(by: { $0.zIndex > $1.zIndex }) where Self.hits(el, p) {
            return el
        }
        return nil
    }

    static func hits(_ el: Element, _ p: CGPoint) -> Bool {
        let pts = el.points.map(\.cg)
        guard !pts.isEmpty else { return false }
        let tol = max(8, CGFloat(el.style.strokeWidth) + 6)
        switch el.kind {
        case .rectangle, .ellipse, .diamond, .text:
            return (bounds(of: el) ?? .null).insetBy(dx: -tol, dy: -tol).contains(p)
        case .line, .arrow:
            guard pts.count >= 2 else { return false }
            return distance(p, segment: pts[0], pts[pts.count - 1]) <= tol
        case .freedraw:
            for i in 0 ..< max(0, pts.count - 1) where distance(p, segment: pts[i], pts[i + 1]) <= tol {
                return true
            }
            return false
        }
    }

    static func bounds(of el: Element) -> CGRect? {
        let pts = el.points.map(\.cg)
        guard let first = pts.first else { return nil }
        if el.kind == .text {
            let w = max(24, CGFloat(el.text.count) * CGFloat(el.style.fontSize) * 0.58)
            let h = CGFloat(el.style.fontSize) * 1.3
            return CGRect(x: first.x, y: first.y, width: w, height: h)
        }
        var box = CGRect(origin: first, size: .zero)
        for pt in pts.dropFirst() { box = box.union(CGRect(origin: pt, size: .zero)) }
        return box
    }

    private static func distance(_ p: CGPoint, segment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

extension CanvasNSView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        endTextEditing()
    }
}
