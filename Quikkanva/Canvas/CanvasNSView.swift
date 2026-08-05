import AppKit

final class CanvasNSView: NSView {
    var scene = CanvasScene() { didSet { redraw() } }
    var tool: ToolKind = .freedraw {
        didSet {
            guard tool != oldValue else { return }
            endTextEditing()
            window?.invalidateCursorRects(for: self)
        }
    }
    var style = ElementStyle()
    var onCommit: ((CanvasScene) -> Void)?
    var onSelectionChange: ((ElementStyle?) -> Void)?
    var onCommandHandled: (() -> Void)?
    var command: CanvasCommand? {
        didSet {
            guard let command, command != oldValue else { return }
            apply(command)
        }
    }

    private var live: Element?
    private var selectedIDs = Set<UUID>()
    private var textEditor: NSTextField?
    private var textAnchor = CGPoint.zero
    private let canvasUndoManager = UndoManager()
    private var cameraTimer: Timer?
    private var cameraAnimation: CameraAnimation?
    private let committedSceneView = CanvasCommittedSceneView()
    private let liveOverlayView = CanvasLiveOverlayView()

    private struct CameraAnimation {
        let from: Camera
        let to: Camera
        let start: TimeInterval
        let duration: TimeInterval
    }

    private enum SelectionHandle {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, rotate
    }

    private enum Drag {
        case none
        case drawing
        case erasing(original: CanvasScene)
        case moving(original: CanvasScene, origin: CGPoint, starts: [UUID: [Point]])
        case resizing(original: CanvasScene, handle: SelectionHandle, bounds: CGRect, points: [Point])
        case rotating(original: CanvasScene, center: CGPoint, startAngle: CGFloat, points: [Point])
        case selecting(start: CGPoint, current: CGPoint, additive: Bool, initial: Set<UUID>)
        case panning(original: CanvasScene, startPan: CGPoint, startMouse: CGPoint)
    }
    private var drag: Drag = .none

    private static let pasteboardType = NSPasteboard.PasteboardType("com.mihirpandey.quikkanva.elements")

    var isInteracting: Bool {
        if case .none = drag { return false }
        return true
    }

    private func redraw() {
        needsDisplay = true
        committedSceneView.needsDisplay = true
        liveOverlayView.needsDisplay = true
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var undoManager: UndoManager? { canvasUndoManager }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        committedSceneView.owner = self
        liveOverlayView.owner = self
        for subview in [committedSceneView, liveOverlayView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
            NSLayoutConstraint.activate([
                subview.leadingAnchor.constraint(equalTo: leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: trailingAnchor),
                subview.topAnchor.constraint(equalTo: topAnchor),
                subview.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { stopCameraAnimation() }
        super.viewWillMove(toWindow: newWindow)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(scene.background?.cgColor ?? RGBAColor.beige.cgColor)
        ctx.fill(bounds)
    }

    fileprivate func drawCommittedScene(in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(scene.camera.panX), y: CGFloat(scene.camera.panY))
        ctx.scaleBy(x: CGFloat(scene.camera.zoom), y: CGFloat(scene.camera.zoom))
        Renderer.draw(scene, in: ctx, live: nil)
        ctx.restoreGState()
    }

    fileprivate func drawLiveOverlay(in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(scene.camera.panX), y: CGFloat(scene.camera.panY))
        ctx.scaleBy(x: CGFloat(scene.camera.zoom), y: CGFloat(scene.camera.zoom))
        if let live {
            Renderer.draw(CanvasScene(elements: [live], camera: scene.camera, background: nil), in: ctx, live: nil)
        }
        drawSelection(in: ctx)
        if case .selecting(let start, let current, _, _) = drag {
            let box = CGRect(corner: start, current)
            ctx.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor)
            ctx.fill(box)
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1 / CGFloat(scene.camera.zoom))
            ctx.setLineDash(phase: 0, lengths: [5 / CGFloat(scene.camera.zoom), 4 / CGFloat(scene.camera.zoom)])
            ctx.stroke(box)
        }
        ctx.restoreGState()
    }

    private func drawSelection(in ctx: CGContext) {
        guard let box = selectionBounds else { return }
        let zoom = CGFloat(scene.camera.zoom)
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.5 / zoom)
        ctx.setLineDash(phase: 0, lengths: [5 / zoom, 4 / zoom])
        ctx.stroke(box)
        ctx.setLineDash(phase: 0, lengths: [])
        let handles = [SelectionHandle.topLeft, .top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left]
        for handle in handles {
            let point = handlePoint(handle, in: box)
            let size = 8 / zoom
            let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
            ctx.setFillColor(NSColor.windowBackgroundColor.cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.strokeEllipse(in: rect)
        }
        let rotatePoint = handlePoint(.rotate, in: box)
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1 / zoom)
        ctx.move(to: CGPoint(x: box.midX, y: box.minY))
        ctx.addLine(to: rotatePoint)
        ctx.strokePath()
        ctx.setFillColor(NSColor.windowBackgroundColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: rotatePoint.x - 4 / zoom,
                                   y: rotatePoint.y - 4 / zoom,
                                   width: 8 / zoom,
                                   height: 8 / zoom))
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.strokeEllipse(in: CGRect(x: rotatePoint.x - 4 / zoom,
                                     y: rotatePoint.y - 4 / zoom,
                                     width: 8 / zoom,
                                     height: 8 / zoom))
        ctx.restoreGState()
    }

    private var selectionBounds: CGRect? {
        selectedIDs.compactMap { id in
            scene.elements.first(where: { $0.id == id }).flatMap(Self.bounds(of:))
        }.reduce(into: nil) { result, box in
            result = result?.union(box) ?? box
        }?.insetBy(dx: -6, dy: -6)
    }

    private var selectedStyle: ElementStyle? {
        let selected = scene.elements.filter { selectedIDs.contains($0.id) }
        guard let first = selected.first?.style,
              selected.dropFirst().allSatisfy({ $0.style == first }) else { return nil }
        return first
    }

    func notifySelectionChange() {
        onSelectionChange?(selectedStyle)
    }

    private func handlePoint(_ handle: SelectionHandle, in box: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: box.minX, y: box.minY)
        case .top: CGPoint(x: box.midX, y: box.minY)
        case .topRight: CGPoint(x: box.maxX, y: box.minY)
        case .right: CGPoint(x: box.maxX, y: box.midY)
        case .bottomRight: CGPoint(x: box.maxX, y: box.maxY)
        case .bottom: CGPoint(x: box.midX, y: box.maxY)
        case .bottomLeft: CGPoint(x: box.minX, y: box.maxY)
        case .left: CGPoint(x: box.minX, y: box.midY)
        case .rotate: CGPoint(x: box.midX, y: box.minY - 30 / CGFloat(scene.camera.zoom))
        }
    }

    private func scenePoint(_ event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        return scenePoint(local)
    }

    private func scenePoint(_ local: CGPoint) -> CGPoint {
        return CGPoint(x: (local.x - CGFloat(scene.camera.panX)) / CGFloat(scene.camera.zoom),
                       y: (local.y - CGFloat(scene.camera.panY)) / CGFloat(scene.camera.zoom))
    }

    private func viewPoint(_ scenePoint: CGPoint) -> CGPoint {
        CGPoint(x: scenePoint.x * CGFloat(scene.camera.zoom) + CGFloat(scene.camera.panX),
                y: scenePoint.y * CGFloat(scene.camera.zoom) + CGFloat(scene.camera.panY))
    }

    override func mouseDown(with event: NSEvent) {
        endTextEditing()
        stopCameraAnimation()
        window?.makeFirstResponder(self)
        let p = scenePoint(event)
        switch tool {
        case .hand:
            NSCursor.closedHand.set()
            drag = .panning(original: scene,
                            startPan: CGPoint(x: scene.camera.panX, y: scene.camera.panY),
                            startMouse: convert(event.locationInWindow, from: nil))
        case .select:
            beginSelection(at: p, event: event)
        case .eraser:
            drag = .erasing(original: scene)
            eraseAt(p)
        case .text:
            beginTextEditing(at: p)
        case .freedraw:
            live = Element(kind: .freedraw, points: [Point(p)], style: style)
            drag = .drawing
        case .rectangle, .ellipse, .diamond, .line, .arrow:
            if let kind = tool.elementKind {
                live = Element(kind: kind, points: [Point(p), Point(p)], style: style)
                drag = .drawing
            }
        }
        redraw()
    }

    private func beginSelection(at p: CGPoint, event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        if let handle = selectionHandle(at: p), selectedIDs.count == 1 {
            guard let id = selectedIDs.first,
                  let element = scene.elements.first(where: { $0.id == id }),
                  let box = Self.bounds(of: element) else { return }
            if handle == .rotate {
                let center = CGPoint(x: box.midX, y: box.midY)
                drag = .rotating(original: scene,
                                 center: center,
                                 startAngle: atan2(p.y - center.y, p.x - center.x),
                                 points: element.points)
            } else {
                drag = .resizing(original: scene, handle: handle, bounds: box, points: element.points)
            }
            return
        }

        if let hit = pickElement(p) {
            if shift {
                if selectedIDs.contains(hit.id) {
                    selectedIDs.remove(hit.id)
                } else {
                    selectedIDs.insert(hit.id)
                }
                notifySelectionChange()
                return
            }
            if !selectedIDs.contains(hit.id) { selectedIDs = [hit.id] }
            notifySelectionChange()
            let starts = Dictionary(uniqueKeysWithValues: selectedIDs.compactMap { id in
                scene.elements.first(where: { $0.id == id }).map { (id, $0.points) }
            })
            drag = .moving(original: scene, origin: p, starts: starts)
            return
        }

        if !shift { selectedIDs.removeAll() }
        notifySelectionChange()
        drag = .selecting(start: p, current: p, additive: shift, initial: selectedIDs)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = scenePoint(event)
        switch drag {
        case .drawing:
            guard var element = live else { return }
            if element.kind == .freedraw {
                element.points.append(Point(p))
            } else if element.points.count >= 2 {
                element.points[1] = Point(p)
            }
            live = element
        case .erasing:
            eraseAt(p)
        case .moving(_, let origin, let starts):
            let dx = p.x - origin.x
            let dy = p.y - origin.y
            for (id, points) in starts {
                guard let index = scene.elements.firstIndex(where: { $0.id == id }) else { continue }
                scene.elements[index].points = points.map { Point(x: $0.x + dx, y: $0.y + dy) }
            }
        case .resizing(_, let handle, let originalBounds, let points):
            guard let id = selectedIDs.first,
                  let index = scene.elements.firstIndex(where: { $0.id == id }) else { return }
            let target = resizeBounds(originalBounds, handle: handle, pointer: p, preserveAspect: event.modifierFlags.contains(.shift))
            scene.elements[index].points = transformed(points, from: originalBounds, to: target)
        case .rotating(_, let center, let startAngle, let points):
            guard let id = selectedIDs.first,
                  let index = scene.elements.firstIndex(where: { $0.id == id }) else { return }
            let angle = atan2(p.y - center.y, p.x - center.x) - startAngle
            scene.elements[index].points = points.map { Point(rotate($0.cg, around: center, by: angle)) }
            scene.elements[index].rotation = angle
        case .selecting(let start, _, let additive, let initial):
            drag = .selecting(start: start, current: p, additive: additive, initial: initial)
        case .panning(let original, let startPan, let startMouse):
            let now = convert(event.locationInWindow, from: nil)
            scene.camera.panX = Double(startPan.x + now.x - startMouse.x)
            scene.camera.panY = Double(startPan.y + now.y - startMouse.y)
            if original.camera != scene.camera { redraw() }
        case .none:
            break
        }
        redraw()
    }

    override func mouseUp(with event: NSEvent) {
        switch drag {
        case .drawing:
            commitLive()
        case .erasing(let original), .moving(let original, _, _), .resizing(let original, _, _, _), .rotating(let original, _, _, _):
            finishMutation(from: original)
        case .selecting(let start, let current, let additive, let initial):
            let box = CGRect(corner: start, current)
            let matches = scene.elements.filter { element in
                guard let bounds = Self.bounds(of: element) else { return false }
                return box.intersects(bounds) || box.contains(bounds)
            }.map(\.id)
            selectedIDs = additive ? initial.union(matches) : Set(matches)
            notifySelectionChange()
        case .panning(let original, _, _):
            if tool == .hand { NSCursor.openHand.set() }
            if original.camera != scene.camera { onCommit?(scene) }
        case .none:
            break
        }
        drag = .none
        redraw()
    }

    private func commitLive() {
        defer { live = nil }
        guard var element = live else { return }
        if element.kind == .freedraw {
            element.points = smoothed(element.points)
        } else if element.points.count >= 2 {
            let d = hypot(element.points[0].x - element.points[1].x, element.points[0].y - element.points[1].y)
            if d < 3 { return }
        }
        var updated = scene
        element.zIndex = (updated.elements.map(\.zIndex).max() ?? 0) + 1
        updated.elements.append(element)
        commit(updated)
    }

    private func smoothed(_ points: [Point]) -> [Point] {
        guard points.count > 2 else { return points }
        var result = [points[0]]
        for index in 1 ..< points.count - 1 {
            let previous = points[index - 1]
            let current = points[index]
            let next = points[index + 1]
            result.append(Point(x: previous.x * 0.2 + current.x * 0.6 + next.x * 0.2,
                                y: previous.y * 0.2 + current.y * 0.6 + next.y * 0.2))
        }
        result.append(points[points.count - 1])
        return result
    }

    private func eraseAt(_ p: CGPoint) {
        guard let hit = pickElement(p) else { return }
        scene.elements.removeAll { $0.id == hit.id }
        selectedIDs.remove(hit.id)
        redraw()
    }

    private func commit(_ updated: CanvasScene) {
        guard updated != scene else { return }
        registerUndo(for: scene)
        scene = updated
        onCommit?(updated)
    }

    private func finishMutation(from original: CanvasScene) {
        guard original != scene else { return }
        registerUndo(for: original)
        onCommit?(scene)
    }

    private func registerUndo(for previous: CanvasScene) {
        canvasUndoManager.registerUndo(withTarget: self) { view in
            view.restore(previous)
        }
        canvasUndoManager.setActionName("Edit Canvas")
    }

    private func restore(_ restored: CanvasScene) {
        let current = scene
        canvasUndoManager.registerUndo(withTarget: self) { view in
            view.restore(current)
        }
        scene = restored
        selectedIDs = selectedIDs.intersection(restored.elements.map(\.id))
        notifySelectionChange()
        onCommit?(scene)
        redraw()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        if command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "z": shift ? redo() : undo()
            case "y": redo()
            case "d": duplicateSelection()
            case "c" where shift: super.keyDown(with: event)
            case "c": copySelection()
            case "v": pasteSelection()
            case "]": changeZOrder(forward: true)
            case "[": changeZOrder(forward: false)
            case "=", "+": apply(.zoomIn)
            case "-": apply(.zoomOut)
            case "1": apply(.zoomToFit)
            case "2": apply(.zoomToSelection)
            case "0": apply(.resetZoom)
            default: super.keyDown(with: event)
            }
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            deleteSelection()
            return
        }
        if selectedIDs.isEmpty == false, let key = movementKey(for: event) {
            moveSelection(for: key, distance: shift ? 10 : 1)
            return
        }
        guard flags.intersection([.shift, .option, .control]).isEmpty,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }
        let shortcuts: [String: ToolKind] = [
            "v": .select, "h": .hand, "p": .freedraw, "r": .rectangle, "o": .ellipse,
            "d": .diamond, "l": .line, "a": .arrow, "t": .text, "e": .eraser,
        ]
        if let nextTool = shortcuts[key] {
            tool = nextTool
        } else {
            super.keyDown(with: event)
        }
    }

    private func movementKey(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return nil
        }
    }

    private func deleteSelection() {
        guard !selectedIDs.isEmpty else { return }
        var updated = scene
        updated.elements.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        notifySelectionChange()
        commit(updated)
    }

    private func moveSelection(for key: String, distance: Double) {
        var updated = scene
        for index in updated.elements.indices where selectedIDs.contains(updated.elements[index].id) {
            for pointIndex in updated.elements[index].points.indices {
                switch key {
                case "left": updated.elements[index].points[pointIndex].x -= distance
                case "right": updated.elements[index].points[pointIndex].x += distance
                case "up": updated.elements[index].points[pointIndex].y -= distance
                case "down": updated.elements[index].points[pointIndex].y += distance
                default: break
                }
            }
        }
        commit(updated)
    }

    private func duplicateSelection() {
        let selected = scene.elements.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        var updated = scene
        let nextZ = (updated.elements.map(\.zIndex).max() ?? 0) + 1
        var duplicatedIDs = Set<UUID>()
        for (offset, original) in selected.enumerated() {
            var copy = original
            copy.id = UUID()
            copy.points = original.points.map { Point(x: $0.x + 16, y: $0.y + 16) }
            copy.seed = UInt64.random(in: 1 ... .max)
            copy.zIndex = nextZ + offset
            updated.elements.append(copy)
            duplicatedIDs.insert(copy.id)
        }
        selectedIDs = duplicatedIDs
        notifySelectionChange()
        commit(updated)
    }

    private func copySelection() {
        let selected = scene.elements.filter { selectedIDs.contains($0.id) }
        guard let data = try? JSONEncoder().encode(selected) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: Self.pasteboardType)
    }

    private func pasteSelection() {
        guard let data = NSPasteboard.general.data(forType: Self.pasteboardType),
              var elements = try? JSONDecoder().decode([Element].self, from: data),
              !elements.isEmpty else { return }
        var updated = scene
        let nextZ = (updated.elements.map(\.zIndex).max() ?? 0) + 1
        var pastedIDs = Set<UUID>()
        for index in elements.indices {
            elements[index].id = UUID()
            elements[index].points = elements[index].points.map { Point(x: $0.x + 16, y: $0.y + 16) }
            elements[index].zIndex = nextZ + index
            updated.elements.append(elements[index])
            pastedIDs.insert(elements[index].id)
        }
        selectedIDs = pastedIDs
        notifySelectionChange()
        commit(updated)
    }

    private func changeZOrder(forward: Bool) {
        guard !selectedIDs.isEmpty else { return }
        var updated = scene
        let maximum = updated.elements.map(\.zIndex).max() ?? 0
        let minimum = updated.elements.map(\.zIndex).min() ?? 0
        for index in updated.elements.indices where selectedIDs.contains(updated.elements[index].id) {
            updated.elements[index].zIndex = forward ? maximum + index + 1 : minimum - index - 1
        }
        commit(updated)
    }

    private func undo() {
        guard canvasUndoManager.canUndo else { return }
        canvasUndoManager.undo()
    }

    private func redo() {
        guard canvasUndoManager.canRedo else { return }
        canvasUndoManager.redo()
    }

    override func scrollWheel(with event: NSEvent) {
        stopCameraAnimation()
        scene.camera.panX += Double(event.scrollingDeltaX)
        scene.camera.panY += Double(event.scrollingDeltaY)
        redraw()
        onCommit?(scene)
    }

    override func magnify(with event: NSEvent) {
        stopCameraAnimation()
        let anchor = convert(event.locationInWindow, from: nil)
        let sceneAnchor = scenePoint(event)
        let zoom = max(0.2, min(6, scene.camera.zoom * (1 + Double(event.magnification))))
        scene.camera.zoom = zoom
        let adjustedAnchor = viewPoint(sceneAnchor)
        scene.camera.panX += Double(anchor.x - adjustedAnchor.x)
        scene.camera.panY += Double(anchor.y - adjustedAnchor.y)
        redraw()
        onCommit?(scene)
    }

    private func apply(_ command: CanvasCommand) {
        switch command {
        case .zoomIn: zoom(by: 1.2)
        case .zoomOut: zoom(by: 1 / 1.2)
        case .resetZoom: animateCamera(to: Camera())
        case .zoomToFit: zoomToFit(selectionBounds ?? contentBounds)
        case .zoomToSelection: zoomToFit(selectionBounds)
        case .updateSelectionStyle(let style):
            guard !selectedIDs.isEmpty else { break }
            var updated = scene
            for index in updated.elements.indices where selectedIDs.contains(updated.elements[index].id) {
                updated.elements[index].style = style
            }
            commit(updated)
            notifySelectionChange()
        }
        if case .updateSelectionStyle = command {} else { onCommit?(scene) }
        onCommandHandled?()
    }

    private var contentBounds: CGRect? {
        scene.elements.compactMap(Self.bounds(of:)).reduce(into: nil) { result, box in
            result = result?.union(box) ?? box
        }
    }

    private func zoom(by factor: CGFloat) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let before = scenePoint(center)
        var target = scene.camera
        target.zoom = max(0.2, min(6, target.zoom * Double(factor)))
        let after = CGPoint(x: before.x * CGFloat(target.zoom) + CGFloat(target.panX),
                            y: before.y * CGFloat(target.zoom) + CGFloat(target.panY))
        target.panX += Double(center.x - after.x)
        target.panY += Double(center.y - after.y)
        animateCamera(to: target)
    }

    private func zoomToFit(_ box: CGRect?) {
        guard let box, box.width > 0, box.height > 0 else { return }
        let padding: CGFloat = 80
        let scale = min((bounds.width - padding * 2) / box.width,
                        (bounds.height - padding * 2) / box.height)
        let zoom = max(0.2, min(6, Double(scale)))
        animateCamera(to: Camera(panX: Double(bounds.midX - box.midX * CGFloat(zoom)),
                                 panY: Double(bounds.midY - box.midY * CGFloat(zoom)),
                                 zoom: zoom))
    }

    private func animateCamera(to target: Camera) {
        stopCameraAnimation()
        guard scene.camera != target else { return }
        cameraAnimation = CameraAnimation(from: scene.camera,
                                          to: target,
                                          start: ProcessInfo.processInfo.systemUptime,
                                          duration: 0.28)
        cameraTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stepCameraAnimation()
            }
        }
        stepCameraAnimation()
    }

    private func stepCameraAnimation() {
        guard let animation = cameraAnimation else {
            stopCameraAnimation()
            return
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - animation.start
        let time = min(1, max(0, elapsed / animation.duration))
        let progress = 1 - exp(-12 * time) * (1 + 12 * time)
        scene.camera = Camera(
            panX: animation.from.panX + (animation.to.panX - animation.from.panX) * progress,
            panY: animation.from.panY + (animation.to.panY - animation.from.panY) * progress,
            zoom: animation.from.zoom + (animation.to.zoom - animation.from.zoom) * progress
        )
        redraw()
        onCommit?(scene)
        if time >= 1 {
            scene.camera = animation.to
            stopCameraAnimation()
            redraw()
            onCommit?(scene)
        }
    }

    private func stopCameraAnimation() {
        cameraTimer?.invalidate()
        cameraTimer = nil
        cameraAnimation = nil
    }

    private func selectionHandle(at p: CGPoint) -> SelectionHandle? {
        guard let box = selectionBounds, selectedIDs.count == 1 else { return nil }
        let tolerance = 10 / CGFloat(scene.camera.zoom)
        let handles = [SelectionHandle.rotate, .topLeft, .top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left]
        return handles.first { distance(p, to: handlePoint($0, in: box)) <= tolerance }
    }

    private func resizeBounds(_ original: CGRect, handle: SelectionHandle, pointer: CGPoint, preserveAspect: Bool) -> CGRect {
        let opposite: CGPoint
        switch handle {
        case .topLeft: opposite = CGPoint(x: original.maxX, y: original.maxY)
        case .top: opposite = CGPoint(x: original.midX, y: original.maxY)
        case .topRight: opposite = CGPoint(x: original.minX, y: original.maxY)
        case .right: opposite = CGPoint(x: original.minX, y: original.midY)
        case .bottomRight: opposite = CGPoint(x: original.minX, y: original.minY)
        case .bottom: opposite = CGPoint(x: original.midX, y: original.minY)
        case .bottomLeft: opposite = CGPoint(x: original.maxX, y: original.minY)
        case .left: opposite = CGPoint(x: original.maxX, y: original.midY)
        case .rotate: return original
        }

        var point = pointer
        if preserveAspect, [.topLeft, .topRight, .bottomRight, .bottomLeft].contains(handle) {
            let ratio = max(original.width, 1) / max(original.height, 1)
            var width = abs(point.x - opposite.x)
            var height = abs(point.y - opposite.y)
            if width / max(height, 1) > ratio { height = width / ratio } else { width = height * ratio }
            point.x = opposite.x + (point.x >= opposite.x ? width : -width)
            point.y = opposite.y + (point.y >= opposite.y ? height : -height)
        }
        switch handle {
        case .top, .bottom:
            return CGRect(x: original.minX, y: min(point.y, opposite.y), width: original.width, height: max(abs(point.y - opposite.y), 1))
        case .left, .right:
            return CGRect(x: min(point.x, opposite.x), y: original.minY, width: max(abs(point.x - opposite.x), 1), height: original.height)
        default:
            return CGRect(corner: point, opposite)
        }
    }

    private func transformed(_ points: [Point], from source: CGRect, to target: CGRect) -> [Point] {
        let sx = target.width / max(source.width, 1)
        let sy = target.height / max(source.height, 1)
        return points.map { point in
            Point(x: target.minX + (point.x - source.minX) * sx,
                  y: target.minY + (point.y - source.minY) * sy)
        }
    }

    private func rotate(_ point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
        let x = point.x - center.x
        let y = point.y - center.y
        return CGPoint(x: center.x + x * cos(angle) - y * sin(angle),
                       y: center.y + x * sin(angle) + y * cos(angle))
    }

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
        var element = Element(kind: .text, points: [Point(textAnchor)], style: style, text: value)
        element.zIndex = (scene.elements.map(\.zIndex).max() ?? 0) + 1
        var updated = scene
        updated.elements.append(element)
        commit(updated)
    }

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

    private func pickElement(_ p: CGPoint) -> Element? {
        scene.elements.sorted(by: { $0.zIndex > $1.zIndex }).first(where: { Self.hits($0, p) })
    }

    static func hits(_ element: Element, _ p: CGPoint) -> Bool {
        let points = element.points.map(\.cg)
        guard !points.isEmpty else { return false }
        let tolerance = max(8, CGFloat(element.style.strokeWidth) + 6)
        switch element.kind {
        case .rectangle, .ellipse, .diamond, .text:
            return (bounds(of: element) ?? .null).insetBy(dx: -tolerance, dy: -tolerance).contains(p)
        case .line, .arrow:
            guard points.count >= 2 else { return false }
            return segmentDistance(p, segment: points[0], points[points.count - 1]) <= tolerance
        case .freedraw:
            return (0 ..< max(0, points.count - 1)).contains { index in
                segmentDistance(p, segment: points[index], points[index + 1]) <= tolerance
            }
        }
    }

    static func bounds(of element: Element) -> CGRect? {
        let points = element.points.map(\.cg)
        guard let first = points.first else { return nil }
        if element.kind == .text {
            let width = max(24, CGFloat(element.text.count) * CGFloat(element.style.fontSize) * 0.58)
            return CGRect(x: first.x, y: first.y, width: width, height: CGFloat(element.style.fontSize) * 1.3)
        }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    private func distance(_ p: CGPoint, to other: CGPoint) -> CGFloat {
        hypot(p.x - other.x, p.y - other.y)
    }

    private static func segmentDistance(_ p: CGPoint, segment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

extension CanvasNSView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        endTextEditing()
    }
}

private final class CanvasCommittedSceneView: NSView {
    weak var owner: CanvasNSView?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        owner?.drawCommittedScene(in: ctx)
    }
}

private final class CanvasLiveOverlayView: NSView {
    weak var owner: CanvasNSView?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        owner?.drawLiveOverlay(in: ctx)
    }
}
