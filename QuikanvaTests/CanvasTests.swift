import XCTest
import AppKit
import CoreGraphics
import SwiftUI
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
        style.drawingStyle = .handDrawn
        style.strokeStyle = .dotted
        style.arrowheadStyle = .bar
        style.arrowheadPlacement = .both
        style.fontFamily = "Menlo"
        style.fontWeight = .semibold
        style.textAlignment = .center
        style.textDecoration = .underline

        let decoded = try JSONDecoder().decode(ElementStyle.self,
                                                from: JSONEncoder().encode(style))

        XCTAssertEqual(decoded, style)
    }

    func testLegacyElementStyleDefaultsToAnEndOnlyArrowhead() throws {
        let legacyStyle = """
        {
          "stroke": { "r": 0, "g": 0, "b": 0, "a": 1 },
          "fill": { "r": 0, "g": 0, "b": 0, "a": 0 },
          "arrowheadStyle": "open"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ElementStyle.self, from: legacyStyle)

        XCTAssertEqual(decoded.arrowheadPlacement, .end)
    }

    func testBarArrowheadPlacementDrawsTheRequestedEnds() {
        var style = ElementStyle()
        style.arrowheadStyle = .bar
        style.arrowheadPlacement = .end
        let endOnly = Element(kind: .arrow,
                              points: [Point(x: 30, y: 40), Point(x: 130, y: 40)],
                              style: style)

        let endOnlyPixels = renderedPixels(for: endOnly, width: 160, height: 80)
        XCTAssertFalse(containsInk(endOnlyPixels, width: 160, x: 30, y: 31))
        XCTAssertTrue(containsInk(endOnlyPixels, width: 160, x: 130, y: 31))

        style.arrowheadPlacement = .both
        let bothEnds = Element(kind: .arrow,
                               points: [Point(x: 30, y: 40), Point(x: 130, y: 40)],
                               style: style)
        let bothEndsPixels = renderedPixels(for: bothEnds, width: 160, height: 80)

        XCTAssertTrue(containsInk(bothEndsPixels, width: 160, x: 30, y: 31))
        XCTAssertTrue(containsInk(bothEndsPixels, width: 160, x: 130, y: 31))
    }

    func testDefaultElementStyleUsesPreciseGeometry() {
        XCTAssertEqual(ElementStyle().drawingStyle, .precise)
    }

    func testVisibleFillStylesMaterializeAVisibleFillColor() {
        for fillStyle in [FillStyle.solid, .hachure] {
            var style = ElementStyle()

            style.setFillStyle(fillStyle)

            XCTAssertEqual(style.fillStyle, fillStyle)
            XCTAssertGreaterThan(style.fill.a, 0)
        }
    }

    func testVisibleFillStylesRenderEvenFromAnInconsistentInMemoryStyle() {
        for fillStyle in [FillStyle.solid, .hachure] {
            var style = ElementStyle()
            style.fillStyle = fillStyle
            let rectangle = Element(kind: .rectangle,
                                    points: [Point(x: 20, y: 20), Point(x: 140, y: 70)],
                                    style: style)

            let pixels = renderedPixels(for: rectangle, width: 160, height: 90)
            let interiorAlpha = (30 ..< 60).flatMap { y in
                (30 ..< 130).map { x in pixels[(y * 160 + x) * 4 + 3] }
            }

            XCTAssertTrue(interiorAlpha.contains { $0 > 0 }, "\(fillStyle) should paint inside the shape")
        }
    }

    func testDecodingRepairsAVisibleFillStyleWithTransparentColor() throws {
        let brokenStyle = """
        {
          "stroke": { "r": 0.8, "g": 0.1, "b": 0.2, "a": 1 },
          "fill": { "r": 0, "g": 0, "b": 0, "a": 0 },
          "fillStyle": "solid"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ElementStyle.self, from: brokenStyle)

        XCTAssertEqual(decoded.fillStyle, .solid)
        XCTAssertEqual(decoded.fill, decoded.stroke)
    }

    func testSelectionStyleChangesRemainActiveForTheNextElement() {
        var active = ElementStyle()
        var selected: ElementStyle? = ElementStyle()

        CanvasStyleState.update(active: &active, selected: &selected) {
            $0.strokeStyle = .dashed
        }
        CanvasStyleState.update(active: &active, selected: &selected) {
            $0.arrowheadStyle = .filled
        }

        XCTAssertEqual(selected?.strokeStyle, .dashed)
        XCTAssertEqual(selected?.arrowheadStyle, .filled)
        XCTAssertEqual(active.strokeStyle, .dashed)
        XCTAssertEqual(active.arrowheadStyle, .filled)
        XCTAssertEqual(Element(kind: .arrow,
                               points: [Point(x: 0, y: 0), Point(x: 100, y: 100)],
                               style: active).style,
                       selected)
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

    func testFloatingWindowRoutesUndoAndRedoToTheCanvasResponder() {
        let element = Element(kind: .rectangle,
                              points: [Point(x: 40, y: 40), Point(x: 140, y: 120)])
        let initial = CanvasScene(elements: [element])
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = FloatingCanvasWindow(contentRect: view.frame,
                                          styleMask: [.titled],
                                          backing: .buffered,
                                          defer: false)
        window.contentView = view
        window.makeFirstResponder(view)
        view.scene = initial
        view.tool = .select

        dragSelection(in: view,
                      window: window,
                      from: CGPoint(x: 90, y: 80),
                      to: CGPoint(x: 120, y: 100))

        XCTAssertNotEqual(view.scene, initial)
        window.activeUndoManager?.undo()
        XCTAssertEqual(view.scene, initial)
        window.activeUndoManager?.redo()
        XCTAssertNotEqual(view.scene, initial)
        window.orderOut(nil)
    }

    func testAlwaysOnTopPreferenceMapsToFloatingWindowLevel() {
        XCTAssertEqual(CanvasWindowLevel.value(alwaysOnTop: false), .normal)
        XCTAssertEqual(CanvasWindowLevel.value(alwaysOnTop: true), .floating)
    }

    func testAlwaysOnTopPreferenceDefaultsOffAndPersists() {
        let defaults = UserDefaults.standard
        let oldValue = defaults.object(forKey: CanvasPreferences.alwaysOnTopKey)
        defer {
            if let oldValue {
                defaults.set(oldValue, forKey: CanvasPreferences.alwaysOnTopKey)
            } else {
                defaults.removeObject(forKey: CanvasPreferences.alwaysOnTopKey)
            }
        }

        defaults.removeObject(forKey: CanvasPreferences.alwaysOnTopKey)
        XCTAssertFalse(CanvasPreferences.alwaysOnTop)

        CanvasPreferences.alwaysOnTop = true
        XCTAssertTrue(CanvasPreferences.alwaysOnTop)
    }

    func testCommandReturnEntersPointEditingAndDraggingMidpointBendsArrow() {
        let arrow = Element(kind: .arrow,
                             points: [Point(x: 40, y: 80), Point(x: 160, y: 80)])
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = testWindow(for: view)
        view.scene = CanvasScene(elements: [arrow])
        view.tool = .select

        selectElement(at: CGPoint(x: 100, y: 80), in: view, window: window)
        view.keyDown(with: keyEvent(for: window, modifiers: [.command], characters: "\r", keyCode: 36))

        XCTAssertTrue(view.pointEditingEnabled)

        dragSelection(in: view,
                      window: window,
                      from: CGPoint(x: 100, y: 80),
                      to: CGPoint(x: 100, y: 140))

        XCTAssertEqual(view.scene.elements[0].points.count, 3)
        XCTAssertEqual(view.scene.elements[0].points[1].x, 100, accuracy: 0.001)
        XCTAssertEqual(view.scene.elements[0].points[1].y, 140, accuracy: 0.001)
        window.orderOut(nil)
    }

    func testNewLineEntersPointEditingByDefault() {
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = testWindow(for: view)
        view.tool = .line

        dragSelection(in: view,
                      window: window,
                      from: CGPoint(x: 40, y: 80),
                      to: CGPoint(x: 160, y: 80))

        XCTAssertEqual(view.tool, .select)
        XCTAssertTrue(view.pointEditingEnabled)
        XCTAssertEqual(view.scene.elements.first?.kind, .line)
        window.orderOut(nil)
    }

    func testClickingAwayFromTextReturnsToSelectTool() {
        let view = CanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = testWindow(for: view)
        view.tool = .text

        clickElement(at: CGPoint(x: 40, y: 80), in: view, window: window)
        let editor = view.subviews.compactMap { $0 as? NSTextField }.first
        editor?.stringValue = "Hello"

        clickElement(at: CGPoint(x: 240, y: 180), in: view, window: window)

        XCTAssertEqual(view.tool, .select)
        XCTAssertEqual(view.scene.elements.last?.text, "Hello")
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

    func testCanvasTitleUsesRandomWordPairPrefix() {
        let title = CanvasTitle.dated(
            Date(timeIntervalSince1970: 0),
            adjective: "Cosmic",
            noun: "Ladle"
        )

        let separator = "Cosmic Ladle - "
        XCTAssertTrue(title.hasPrefix(separator))
        XCTAssertFalse(title.dropFirst(separator.count).isEmpty)
    }

    func testCanvasTitleUsesSortableDateFormat() throws {
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let title = CanvasTitle.dated(
            Date(timeIntervalSince1970: 0),
            adjective: "Cosmic",
            noun: "Ladle",
            dateFormat: .sortable,
            timeZone: utc
        )

        XCTAssertEqual(title, "Cosmic Ladle - 1970-01-01 00:00")
    }

    func testAutoTitleDateFormatPreferenceDefaultsToSystem() {
        let defaults = UserDefaults.standard
        let oldValue = defaults.object(forKey: CanvasPreferences.autoTitleDateFormatKey)
        defer {
            if let oldValue {
                defaults.set(oldValue, forKey: CanvasPreferences.autoTitleDateFormatKey)
            } else {
                defaults.removeObject(forKey: CanvasPreferences.autoTitleDateFormatKey)
            }
        }

        defaults.removeObject(forKey: CanvasPreferences.autoTitleDateFormatKey)
        XCTAssertEqual(CanvasPreferences.autoTitleDateFormat, .system)

        CanvasPreferences.autoTitleDateFormat = .sortable
        XCTAssertEqual(CanvasPreferences.autoTitleDateFormat, .sortable)
    }

    func testGalleryPreviewSizesAreCappedPerAspectRatio() {
        XCTAssertEqual(CanvasAspectRatio.portrait.galleryPreviewSize, CGSize(width: 150, height: 800.0 / 3.0))
        XCTAssertEqual(CanvasAspectRatio.square.galleryPreviewSize, CGSize(width: 190, height: 190))
        XCTAssertEqual(CanvasAspectRatio.standard.galleryPreviewSize, CGSize(width: 220, height: 165))
        XCTAssertEqual(CanvasAspectRatio.widescreen.galleryPreviewSize, CGSize(width: 240, height: 135))
    }

    func testGallerySelectAllButtonTogglesBackToNoSelection() {
        let ids = [UUID(), UUID(), UUID()]
        let selected = GallerySelection.togglingAll([], within: ids)

        XCTAssertEqual(selected, Set(ids))
        XCTAssertTrue(GallerySelection.togglingAll(selected, within: ids).isEmpty)
    }

    func testGalleryGridCreatesOnlyVisibleCards() {
        let counter = AppearanceCounter()
        let host = NSHostingController(rootView:
            ScrollView {
                GalleryGrid {
                    ForEach(0 ..< 1_000, id: \.self) { _ in
                        CountingGalleryCard(counter: counter)
                    }
                }
            }
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        host.view.frame = window.contentView?.bounds ?? .zero
        host.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        defer { window.orderOut(nil) }

        XCTAssertGreaterThan(counter.count, 0)
        XCTAssertLessThan(counter.count, 1_000, "The gallery must not instantiate every card at once")
    }

    func testGalleryThumbnailDoesNotDecodeAgainWhenItsBodyUpdates() {
        var decodeCount = 0
        let thumbnail = GalleryThumbnail(data: Data([1])) { _ in
            decodeCount += 1
            return NSImage(size: NSSize(width: 1, height: 1))
        }

        _ = thumbnail.body
        _ = thumbnail.body

        XCTAssertEqual(decodeCount, 1, "Hover updates must reuse the already-decoded gallery thumbnail")
    }

    func testDocumentStoresItsCanvasAspectRatio() {
        let doc = CanvasDocument(title: "Wide",
                                 sceneData: SceneCodec.encode(CanvasScene()),
                                 aspectRatio: .widescreen)

        XCTAssertEqual(doc.aspectRatio, .widescreen)
    }

    func testThumbnailMatchesTheCanvasAspectRatio() {
        let portrait = Thumbnailer.png(for: CanvasScene(), aspectRatio: .portrait)
            .flatMap(NSImage.init(data:))
        let widescreen = Thumbnailer.png(for: CanvasScene(), aspectRatio: .widescreen)
            .flatMap(NSImage.init(data:))

        XCTAssertEqual(portrait?.size.width ?? 0, 270, accuracy: 0.5)
        XCTAssertEqual(portrait?.size.height ?? 0, 480, accuracy: 0.5)
        XCTAssertEqual(widescreen?.size.width ?? 0, 480, accuracy: 0.5)
        XCTAssertEqual(widescreen?.size.height ?? 0, 270, accuracy: 0.5)
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

    private func keyEvent(for window: NSWindow,
                          modifiers: NSEvent.ModifierFlags,
                          characters: String,
                          keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown,
                         location: .zero,
                         modifierFlags: modifiers,
                         timestamp: 0,
                         windowNumber: window.windowNumber,
                         context: nil,
                         characters: characters,
                         charactersIgnoringModifiers: characters,
                         isARepeat: false,
                         keyCode: keyCode)!
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

    private func renderedPixels(for element: Element, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { storage in
            let context = CGContext(data: storage.baseAddress,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            Renderer.draw(element, in: context)
        }
        return pixels
    }

    private func containsInk(_ pixels: [UInt8], width: Int, x: Int, y: Int) -> Bool {
        let radius = 3
        for sampleY in (y - radius) ... (y + radius) {
            for sampleX in (x - radius) ... (x + radius) {
                let alphaIndex = (sampleY * width + sampleX) * 4 + 3
                if pixels[alphaIndex] > 0 { return true }
            }
        }
        return false
    }
}

@MainActor
private final class AppearanceCounter {
    var count = 0

    func record() {
        count += 1
    }
}

private struct CountingGalleryCard: View {
    let counter: AppearanceCounter

    var body: some View {
        let _ = counter.record()
        Color.clear.frame(width: 240, height: 300)
    }
}
