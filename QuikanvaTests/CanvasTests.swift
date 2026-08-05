import XCTest
import AppKit
import CoreGraphics
@testable import Quikanva

@MainActor
final class CanvasTests: XCTestCase {
    func testSceneCodableRoundTrip() throws {
        var image = Element(kind: .image,
                            points: [Point(x: 10, y: 20), Point(x: 210, y: 160)])
        image.imageData = Data([0, 1, 2, 3])
        let scene = CanvasScene(elements: [image], camera: Camera(panX: 12, panY: -8, zoom: 1.5), background: .beige)

        let decoded = try JSONDecoder().decode(CanvasScene.self, from: JSONEncoder().encode(scene))

        XCTAssertEqual(decoded, scene)
    }

    func testElementStyleRoundTripKeepsPresentationSettings() throws {
        var style = ElementStyle()
        style.strokeStyle = .dotted
        style.arrowheadStyle = .filled
        style.fontFamily = "Menlo"
        style.fontWeight = .semibold
        style.textAlignment = .center
        style.textDecoration = .underline

        let decoded = try JSONDecoder().decode(ElementStyle.self,
                                                from: JSONEncoder().encode(style))

        XCTAssertEqual(decoded, style)
    }

    func testHitTestingUsesElementGeometry() {
        let rectangle = Element(kind: .rectangle,
                                points: [Point(x: 20, y: 20), Point(x: 120, y: 100)])
        let line = Element(kind: .line,
                           points: [Point(x: 20, y: 20), Point(x: 120, y: 100)])

        XCTAssertTrue(CanvasNSView.hits(rectangle, CGPoint(x: 60, y: 60)))
        XCTAssertFalse(CanvasNSView.hits(rectangle, CGPoint(x: 180, y: 180)))
        XCTAssertTrue(CanvasNSView.hits(line, CGPoint(x: 70, y: 70)))

        let curvedLine = Element(kind: .line,
                                 points: [Point(x: 20, y: 20), Point(x: 70, y: 110), Point(x: 120, y: 20)])
        XCTAssertTrue(CanvasNSView.hits(curvedLine, CGPoint(x: 70, y: 65)))
    }

    func testSketchGenerationIsDeterministic() {
        var firstRNG = SketchRNG(seed: 42)
        let firstPath = CGMutablePath()
        Sketch.roughLine(CGPoint(x: 10, y: 20), CGPoint(x: 120, y: 80), roughness: 1.2, rng: &firstRNG, into: firstPath)

        var secondRNG = SketchRNG(seed: 42)
        let secondPath = CGMutablePath()
        Sketch.roughLine(CGPoint(x: 10, y: 20), CGPoint(x: 120, y: 80), roughness: 1.2, rng: &secondRNG, into: secondPath)

        XCTAssertEqual(pathSignature(firstPath), pathSignature(secondPath))
    }

    func testExporterProducesReadableImages() {
        var filledStyle = ElementStyle()
        filledStyle.fillStyle = .solid
        filledStyle.fill = RGBAColor(r: 0.2, g: 0.6, b: 0.9, a: 1)

        var hatchedStyle = ElementStyle()
        hatchedStyle.fillStyle = .hachure
        hatchedStyle.fill = RGBAColor(r: 0.9, g: 0.3, b: 0.2, a: 1)

        var image = Element(kind: .image,
                            points: [Point(x: 240, y: 190), Point(x: 360, y: 280)])
        image.imageData = testImageData()
        let scene = CanvasScene(elements: [
            Element(kind: .rectangle,
                    points: [Point(x: 20, y: 20), Point(x: 180, y: 120)],
                    style: filledStyle),
            Element(kind: .ellipse,
                    points: [Point(x: 200, y: 20), Point(x: 360, y: 120)],
                    style: hatchedStyle),
            Element(kind: .diamond,
                    points: [Point(x: 380, y: 20), Point(x: 520, y: 120)]),
            Element(kind: .line,
                    points: [Point(x: 20, y: 150), Point(x: 160, y: 220)]),
            Element(kind: .arrow,
                    points: [Point(x: 180, y: 150), Point(x: 320, y: 220)]),
            Element(kind: .freedraw,
                    points: [Point(x: 340, y: 150), Point(x: 380, y: 180), Point(x: 440, y: 150)]),
            Element(kind: .text,
                    points: [Point(x: 20, y: 250)],
                    text: "Quikanva"),
            image,
        ])

        let png = Exporter.data(for: scene, format: .png)
        let jpeg = Exporter.data(for: scene, format: .jpeg)

        XCTAssertNotNil(png)
        XCTAssertNotNil(jpeg)
        XCTAssertNotNil(png.flatMap(NSImage.init(data:)))
        XCTAssertNotNil(jpeg.flatMap(NSImage.init(data:)))
        XCTAssertEqual(png, Exporter.data(for: scene, format: .png))
    }

    func testCanvasMoveSupportsUndoAndRedo() {
        let element = Element(kind: .rectangle,
                               points: [Point(x: 40, y: 40), Point(x: 140, y: 120)])
        let initial = CanvasScene(elements: [element])
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = NSWindow(contentRect: view.frame,
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = view
        view.scene = initial
        view.tool = .select

        let down = mouseEvent(.leftMouseDown, at: CGPoint(x: 90, y: 220), window: window)
        let drag = mouseEvent(.leftMouseDragged, at: CGPoint(x: 120, y: 200), window: window)
        view.mouseDown(with: down)
        view.mouseDragged(with: drag)
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: CGPoint(x: 120, y: 200), window: window))

        XCTAssertNotEqual(view.scene, initial)
        view.undoManager?.undo()
        XCTAssertEqual(view.scene, initial)
        view.undoManager?.redo()
        XCTAssertNotEqual(view.scene, initial)
        window.orderOut(nil)
    }

    func testSelectedStyleCommandUpdatesShape() {
        let element = Element(kind: .rectangle,
                               points: [Point(x: 40, y: 40), Point(x: 140, y: 120)])
        let initial = CanvasScene(elements: [element])
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = NSWindow(contentRect: view.frame,
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = view
        view.scene = initial
        view.tool = .select

        view.mouseDown(with: mouseEvent(.leftMouseDown, at: CGPoint(x: 90, y: 220), window: window))
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: CGPoint(x: 90, y: 220), window: window))

        var updatedStyle = element.style
        updatedStyle.fillStyle = .solid
        updatedStyle.strokeWidth = 4
        updatedStyle.roughness = 0.6
        view.command = .updateSelectionStyle(updatedStyle)

        XCTAssertEqual(view.scene.elements.first?.style, updatedStyle)
        window.orderOut(nil)
    }

    func testSelectionResizeRotateDeleteSupportsUndoAndRedo() {
        let element = Element(kind: .rectangle,
                               points: [Point(x: 40, y: 40), Point(x: 140, y: 120)])
        let initial = CanvasScene(elements: [element])
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = testWindow(for: view)
        view.scene = initial
        view.tool = .select

        selectElement(at: CGPoint(x: 90, y: 80), in: view, window: window)

        resize(view,
               window: window,
               from: CGPoint(x: 40, y: 40),
               to: CGPoint(x: 20, y: 20))
        XCTAssertEqual(view.scene.elements[0].points[0].x, 20, accuracy: 0.001)
        XCTAssertEqual(view.scene.elements[0].points[0].y, 20, accuracy: 0.001)
        view.undoManager?.undo()
        XCTAssertEqual(view.scene, initial)
        view.undoManager?.redo()
        XCTAssertEqual(view.scene.elements[0].points[0].x, 20, accuracy: 0.001)

        view.undoManager?.undo()
        rotate(view,
               window: window,
               from: CGPoint(x: 90, y: 4),
               to: CGPoint(x: 140, y: 80))
        XCTAssertEqual(view.scene.elements[0].rotation, .pi / 2, accuracy: 0.02)
        view.undoManager?.undo()
        XCTAssertEqual(view.scene, initial)
        view.undoManager?.redo()
        XCTAssertEqual(view.scene.elements[0].rotation, .pi / 2, accuracy: 0.02)

        deleteSelection(in: view, window: window)
        XCTAssertTrue(view.scene.elements.isEmpty)
        view.undoManager?.undo()
        XCTAssertEqual(view.scene.elements.count, 1)
        view.undoManager?.redo()
        XCTAssertTrue(view.scene.elements.isEmpty)
        window.orderOut(nil)
    }

    func testMultiSelectionMovesAsOneUndoableOperation() {
        let first = Element(kind: .rectangle,
                            points: [Point(x: 40, y: 40), Point(x: 140, y: 120)])
        let second = Element(kind: .ellipse,
                             points: [Point(x: 200, y: 40), Point(x: 300, y: 120)])
        let initial = CanvasScene(elements: [first, second])
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = testWindow(for: view)
        view.scene = initial
        view.tool = .select

        selectElement(at: CGPoint(x: 90, y: 80), in: view, window: window)
        clickElement(at: CGPoint(x: 250, y: 80), in: view, window: window, modifiers: [.shift])
        dragSelection(in: view,
                      window: window,
                      from: CGPoint(x: 90, y: 80),
                      to: CGPoint(x: 110, y: 95))

        XCTAssertEqual(view.scene.elements[0].points[0], Point(x: 60, y: 55))
        XCTAssertEqual(view.scene.elements[1].points[0], Point(x: 220, y: 55))
        view.undoManager?.undo()
        XCTAssertEqual(view.scene, initial)
        view.undoManager?.redo()
        XCTAssertEqual(view.scene.elements[1].points[1], Point(x: 320, y: 135))
        window.orderOut(nil)
    }

    func testCanvasTitleUsesSketchPrefix() {
        XCTAssertTrue(CanvasTitle.dated(Date(timeIntervalSince1970: 0)).hasPrefix("Sketch — "))
    }

    func testCanvasPreferencesUsePortraitAndDiscardEmptyDefaults() {
        let defaults = UserDefaults.standard
        let oldAspectRatio = defaults.object(forKey: CanvasPreferences.defaultAspectRatioKey)
        let oldDiscardEmpty = defaults.object(forKey: CanvasPreferences.discardEmptyCanvasesKey)
        defer {
            if let oldAspectRatio {
                defaults.set(oldAspectRatio, forKey: CanvasPreferences.defaultAspectRatioKey)
            } else {
                defaults.removeObject(forKey: CanvasPreferences.defaultAspectRatioKey)
            }
            if let oldDiscardEmpty {
                defaults.set(oldDiscardEmpty, forKey: CanvasPreferences.discardEmptyCanvasesKey)
            } else {
                defaults.removeObject(forKey: CanvasPreferences.discardEmptyCanvasesKey)
            }
        }

        defaults.removeObject(forKey: CanvasPreferences.defaultAspectRatioKey)
        defaults.removeObject(forKey: CanvasPreferences.discardEmptyCanvasesKey)

        XCTAssertEqual(CanvasPreferences.defaultAspectRatio, .portrait)
        XCTAssertTrue(CanvasPreferences.discardEmptyCanvases)

        CanvasPreferences.defaultAspectRatio = .widescreen
        CanvasPreferences.discardEmptyCanvases = false

        XCTAssertEqual(CanvasPreferences.defaultAspectRatio, .widescreen)
        XCTAssertFalse(CanvasPreferences.discardEmptyCanvases)
    }

    private func pathSignature(_ path: CGPath) -> [String] {
        var signature: [String] = []
        path.applyWithBlock { element in
            let points = (0 ..< Self.pointCount(for: element.pointee.type)).map { index in
                let point = element.pointee.points[index]
                return "\(point.x),\(point.y)"
            }
            signature.append("\(element.pointee.type.rawValue):\(points.joined(separator: ";"))")
        }
        return signature
    }

    private static func pointCount(for type: CGPathElementType) -> Int {
        switch type {
        case .moveToPoint, .addLineToPoint: 1
        case .addQuadCurveToPoint: 2
        case .addCurveToPoint: 3
        case .closeSubpath: 0
        @unknown default: 0
        }
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: CGPoint, window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: type,
                           location: point,
                           modifierFlags: [],
                           timestamp: 0,
                           windowNumber: window.windowNumber,
                           context: nil,
                           eventNumber: 0,
                           clickCount: 1,
                           pressure: 1)!
    }

    private func testWindow(for view: CanvasNSView) -> NSWindow {
        let window = NSWindow(contentRect: view.frame,
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = view
        return window
    }

    private func selectElement(at point: CGPoint, in view: CanvasNSView, window: NSWindow) {
        clickElement(at: point, in: view, window: window)
    }

    private func clickElement(at point: CGPoint,
                              in view: CanvasNSView,
                              window: NSWindow,
                              modifiers: NSEvent.ModifierFlags = []) {
        view.mouseDown(with: mouseEvent(.leftMouseDown,
                                         at: windowPoint(for: point, in: view),
                                         window: window,
                                         modifiers: modifiers))
        view.mouseUp(with: mouseEvent(.leftMouseUp,
                                       at: windowPoint(for: point, in: view),
                                       window: window,
                                       modifiers: modifiers))
    }

    private func dragSelection(in view: CanvasNSView,
                               window: NSWindow,
                               from start: CGPoint,
                               to end: CGPoint) {
        view.mouseDown(with: mouseEvent(.leftMouseDown,
                                         at: windowPoint(for: start, in: view),
                                         window: window))
        view.mouseDragged(with: mouseEvent(.leftMouseDragged,
                                            at: windowPoint(for: end, in: view),
                                            window: window))
        view.mouseUp(with: mouseEvent(.leftMouseUp,
                                      at: windowPoint(for: end, in: view),
                                      window: window))
    }

    private func resize(_ view: CanvasNSView,
                        window: NSWindow,
                        from start: CGPoint,
                        to end: CGPoint) {
        dragSelection(in: view, window: window, from: start, to: end)
    }

    private func rotate(_ view: CanvasNSView,
                        window: NSWindow,
                        from start: CGPoint,
                        to end: CGPoint) {
        dragSelection(in: view, window: window, from: start, to: end)
    }

    private func deleteSelection(in view: CanvasNSView, window: NSWindow) {
        view.keyDown(with: NSEvent.keyEvent(with: .keyDown,
                                            location: .zero,
                                            modifierFlags: [],
                                            timestamp: 0,
                                            windowNumber: window.windowNumber,
                                            context: nil,
                                            characters: "",
                                            charactersIgnoringModifiers: "",
                                            isARepeat: false,
                                            keyCode: 51)!)
    }

    private func windowPoint(for scenePoint: CGPoint, in view: CanvasNSView) -> CGPoint {
        CGPoint(x: scenePoint.x, y: view.bounds.height - scenePoint.y)
    }

    private func mouseEvent(_ type: NSEvent.EventType,
                            at point: CGPoint,
                            window: NSWindow,
                            modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type,
                           location: point,
                           modifierFlags: modifiers,
                           timestamp: 0,
                           windowNumber: window.windowNumber,
                           context: nil,
                           eventNumber: 0,
                           clickCount: 1,
                           pressure: 1)!
    }

    private func testImageData() -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: 40,
                                   pixelsHigh: 40,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 4,
                                   hasAlpha: true,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0,
                                   bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        context.cgContext.setFillColor(RGBAColor(r: 0.2, g: 0.8, b: 0.4, a: 1).cgColor)
        context.cgContext.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        return rep.representation(using: .png, properties: [:])!
    }
}
