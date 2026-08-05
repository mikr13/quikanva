import XCTest
import AppKit
import CoreGraphics
@testable import Quikkanva

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

    func testHitTestingUsesElementGeometry() {
        let rectangle = Element(kind: .rectangle,
                                points: [Point(x: 20, y: 20), Point(x: 120, y: 100)])
        let line = Element(kind: .line,
                           points: [Point(x: 20, y: 20), Point(x: 120, y: 100)])

        XCTAssertTrue(CanvasNSView.hits(rectangle, CGPoint(x: 60, y: 60)))
        XCTAssertFalse(CanvasNSView.hits(rectangle, CGPoint(x: 180, y: 180)))
        XCTAssertTrue(CanvasNSView.hits(line, CGPoint(x: 70, y: 70)))
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
                    text: "Quikkanva"),
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

    func testCanvasTitleUsesSketchPrefix() {
        XCTAssertTrue(CanvasTitle.dated(Date(timeIntervalSince1970: 0)).hasPrefix("Sketch — "))
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
