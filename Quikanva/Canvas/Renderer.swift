import Foundation
import AppKit
import CoreGraphics
import CoreText

struct SketchRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0) }
    mutating func signed() -> CGFloat { CGFloat(unit() * 2 - 1) }
}

extension CGRect {
    init(corner a: CGPoint, _ b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
    var topLeft: CGPoint { CGPoint(x: minX, y: minY) }
    var topRight: CGPoint { CGPoint(x: maxX, y: minY) }
    var bottomRight: CGPoint { CGPoint(x: maxX, y: maxY) }
    var bottomLeft: CGPoint { CGPoint(x: minX, y: maxY) }
}

enum Sketch {
    static func roughLine(_ a: CGPoint, _ b: CGPoint, roughness: Double, rng: inout SketchRNG, into path: CGMutablePath) {
        let len = hypot(b.x - a.x, b.y - a.y)
        let m = CGFloat(max(1.0, min(6.0, Double(len) * 0.02)) * roughness)
        for pass in 0 ..< 2 {
            let k: CGFloat = pass == 0 ? 1.0 : 0.55
            let s = CGPoint(x: a.x + rng.signed() * m * k, y: a.y + rng.signed() * m * k)
            let e = CGPoint(x: b.x + rng.signed() * m * k, y: b.y + rng.signed() * m * k)
            let c = CGPoint(x: (a.x + b.x) / 2 + rng.signed() * m * 2 * k,
                            y: (a.y + b.y) / 2 + rng.signed() * m * 2 * k)
            path.move(to: s)
            path.addQuadCurve(to: e, control: c)
        }
    }

    static func roughCurve(_ a: CGPoint,
                           _ control: CGPoint,
                           _ b: CGPoint,
                           roughness: Double,
                           rng: inout SketchRNG,
                           into path: CGMutablePath) {
        let len = hypot(b.x - a.x, b.y - a.y)
        let m = CGFloat(max(1.0, min(6.0, Double(len) * 0.02)) * roughness)
        for pass in 0 ..< 2 {
            let k: CGFloat = pass == 0 ? 1.0 : 0.55
            let start = CGPoint(x: a.x + rng.signed() * m * k, y: a.y + rng.signed() * m * k)
            let bend = CGPoint(x: control.x + rng.signed() * m * 2 * k,
                               y: control.y + rng.signed() * m * 2 * k)
            let end = CGPoint(x: b.x + rng.signed() * m * k, y: b.y + rng.signed() * m * k)
            path.move(to: start)
            path.addQuadCurve(to: end, control: bend)
        }
    }

    static func roughPolygon(_ pts: [CGPoint], roughness: Double, rng: inout SketchRNG, into path: CGMutablePath) {
        guard pts.count > 1 else { return }
        for i in 0 ..< pts.count {
            roughLine(pts[i], pts[(i + 1) % pts.count], roughness: roughness, rng: &rng, into: path)
        }
    }

    static func ellipsePoints(in rect: CGRect, count: Int = 22) -> [CGPoint] {
        (0 ..< count).map { i in
            let t = Double(i) / Double(count) * 2 * .pi
            return CGPoint(x: rect.midX + CGFloat(cos(t)) * rect.width / 2,
                           y: rect.midY + CGFloat(sin(t)) * rect.height / 2)
        }
    }
}

private final class CachedPath: NSObject, @unchecked Sendable {
    let path: CGPath

    init(_ path: CGPath) {
        self.path = path
    }
}

private final class CachedImage: NSObject, @unchecked Sendable {
    let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }
}

private final class RoughPathCache: @unchecked Sendable {
    private let storage = NSCache<NSString, CachedPath>()

    func path(forKey key: NSString) -> CGPath? {
        storage.object(forKey: key)?.path
    }

    func insert(_ path: CGPath, forKey key: NSString) {
        storage.setObject(CachedPath(path), forKey: key)
    }
}

private final class ImageCache: @unchecked Sendable {
    private let storage = NSCache<NSString, CachedImage>()

    func image(forKey key: NSString) -> CGImage? {
        storage.object(forKey: key)?.image
    }

    func insert(_ image: CGImage, forKey key: NSString) {
        storage.setObject(CachedImage(image), forKey: key)
    }
}

enum Renderer {
    private static let roughPathCache = RoughPathCache()
    private static let imageCache = ImageCache()

    static func draw(_ scene: CanvasScene, in ctx: CGContext, live: Element?) {
        var all = scene.elements
        if let live { all.append(live) }
        for el in all.sorted(by: { $0.zIndex < $1.zIndex }) {
            draw(el, in: ctx)
        }
    }

    static func draw(_ el: Element, in ctx: CGContext) {
        let pts = el.points.map(\.cg)
        guard !pts.isEmpty else { return }

        ctx.saveGState()
        ctx.setAlpha(CGFloat(el.style.opacity))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(CGFloat(el.style.strokeWidth))
        ctx.setStrokeColor(el.style.stroke.cgColor)
        applyStrokeStyle(el.style.strokeStyle, in: ctx)

        var rng = SketchRNG(seed: el.seed)
        let rough = el.style.roughness

        switch el.kind {
        case .freedraw:
            let path = CGMutablePath()
            path.addLines(between: pts)
            ctx.addPath(path)
            ctx.strokePath()

        case .line:
            let path = linePath(for: el, points: pts, roughness: rough, rng: &rng)
            ctx.addPath(path)
            ctx.strokePath()

        case .arrow:
            let a = pts[0], b = pts[pts.count - 1]
            let shaft = linePath(for: el, points: pts, roughness: rough, rng: &rng)
            ctx.addPath(shaft)
            ctx.strokePath()

            let dist = hypot(b.x - a.x, b.y - a.y)
            guard dist > 1 else { break }
            if el.style.arrowheadPlacement == .both {
                let startTangent = pts.count >= 3 ? pts[1] : b
                drawArrowMarker(el.style.arrowheadStyle,
                                tip: a,
                                tangent: startTangent,
                                shaftLength: dist,
                                color: el.style.stroke.cgColor,
                                in: ctx)
            }
            let endTangent = pts.count >= 3 ? pts[pts.count - 2] : a
            drawArrowMarker(el.style.arrowheadStyle,
                            tip: b,
                            tangent: endTangent,
                            shaftLength: dist,
                            color: el.style.stroke.cgColor,
                            in: ctx)

        case .rectangle, .ellipse, .diamond:
            let rect = CGRect(corner: pts[0], pts[pts.count - 1])
            let corners: [CGPoint]
            switch el.kind {
            case .rectangle:
                corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]
            case .diamond:
                corners = [CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY),
                           CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY)]
            default:
                corners = Sketch.ellipsePoints(in: rect)
            }
            let shape = shapePath(for: el.kind, in: rect)
            switch el.style.fillStyle {
            case .none:
                break
            case .solid:
                ctx.addPath(shape)
                ctx.setFillColor(el.style.visibleFillColor.cgColor)
                ctx.fillPath()
            case .hachure:
                drawHachure(shape, in: rect, color: el.style.visibleFillColor.cgColor, ctx: ctx)
            }
            let path = el.style.drawingStyle == .precise
                ? shape
                : roughPolygonPath(for: el, corners: corners, roughness: rough, rng: &rng)
            ctx.addPath(path)
            ctx.setStrokeColor(el.style.stroke.cgColor)
            ctx.strokePath()

        case .text:
            drawText(el, at: pts[0], in: ctx)

        case .image:
            drawImage(el, in: ctx)
        }

        ctx.restoreGState()
    }

    private static func drawArrowMarker(_ style: ArrowheadStyle,
                                        tip: CGPoint,
                                        tangent: CGPoint,
                                        shaftLength: CGFloat,
                                        color: CGColor,
                                        in ctx: CGContext) {
        let angle = atan2(tip.y - tangent.y, tip.x - tangent.x)
        let markerLength = max(14, min(shaftLength * 0.28, 30))

        ctx.saveGState()
        ctx.setLineDash(phase: 0, lengths: [])

        if style == .bar {
            let halfHeight = max(7, min(markerLength * 0.5, 12))
            let perpendicular = angle + .pi / 2
            let dx = halfHeight * cos(perpendicular)
            let dy = halfHeight * sin(perpendicular)
            ctx.move(to: CGPoint(x: tip.x - dx, y: tip.y - dy))
            ctx.addLine(to: CGPoint(x: tip.x + dx, y: tip.y + dy))
            ctx.strokePath()
            ctx.restoreGState()
            return
        }

        let spread = CGFloat.pi / 7
        let left = CGPoint(x: tip.x - markerLength * cos(angle - spread),
                           y: tip.y - markerLength * sin(angle - spread))
        let right = CGPoint(x: tip.x - markerLength * cos(angle + spread),
                            y: tip.y - markerLength * sin(angle + spread))
        let path = CGMutablePath()
        path.move(to: left)
        path.addLine(to: tip)
        path.addLine(to: right)

        switch style {
        case .open:
            ctx.addPath(path)
            ctx.strokePath()
        case .closed:
            path.closeSubpath()
            ctx.addPath(path)
            ctx.strokePath()
        case .filled:
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setFillColor(color)
            ctx.fillPath()
        case .bar:
            break
        }
        ctx.restoreGState()
    }

    private static func drawHachure(_ path: CGPath, in rect: CGRect, color: CGColor, ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setStrokeColor(color)
        ctx.setLineWidth(1.2)
        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [])
        let step: CGFloat = 10
        var offset = -rect.height
        while offset < rect.width + rect.height {
            ctx.move(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            ctx.addLine(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.minY))
            offset += step
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func roughLinePath(for element: Element,
                                      points: [CGPoint],
                                      roughness: Double,
                                      rng: inout SketchRNG) -> CGPath {
        let key = "line-\(element.hashValue)" as NSString
        if let cached = roughPathCache.path(forKey: key) { return cached }
        let path = CGMutablePath()
        if points.count >= 3 {
            Sketch.roughCurve(points[0], points[1], points[2], roughness: roughness, rng: &rng, into: path)
        } else if points.count >= 2 {
            Sketch.roughLine(points[0], points[1], roughness: roughness, rng: &rng, into: path)
        }
        roughPathCache.insert(path, forKey: key)
        return path
    }

    private static func linePath(for element: Element,
                                 points: [CGPoint],
                                 roughness: Double,
                                 rng: inout SketchRNG) -> CGPath {
        guard element.style.drawingStyle == .precise else {
            return roughLinePath(for: element, points: points, roughness: roughness, rng: &rng)
        }
        let path = CGMutablePath()
        guard let start = points.first else { return path }
        path.move(to: start)
        if points.count >= 3 {
            path.addQuadCurve(to: points[2], control: points[1])
        } else if points.count >= 2 {
            path.addLine(to: points[1])
        }
        return path
    }

    private static func shapePath(for kind: ElementKind, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        switch kind {
        case .rectangle:
            path.addRect(rect)
        case .ellipse:
            path.addEllipse(in: rect)
        case .diamond:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        default:
            break
        }
        return path
    }

    private static func roughPolygonPath(for element: Element,
                                         corners: [CGPoint],
                                         roughness: Double,
                                         rng: inout SketchRNG) -> CGPath {
        let key = "polygon-\(element.hashValue)" as NSString
        if let cached = roughPathCache.path(forKey: key) { return cached }
        let path = CGMutablePath()
        Sketch.roughPolygon(corners, roughness: roughness, rng: &rng, into: path)
        roughPathCache.insert(path, forKey: key)
        return path
    }

    private static func drawText(_ el: Element, at p: CGPoint, in ctx: CGContext) {
        guard !el.text.isEmpty else { return }
        var font = CTFontCreateWithName(el.style.fontFamily as CFString, CGFloat(el.style.fontSize), nil)
        var traits: CTFontSymbolicTraits = []
        if el.style.fontWeight == .bold || el.style.fontWeight == .semibold {
            traits.insert(.traitBold)
        }
        if el.style.textDecoration == .italic {
            traits.insert(.traitItalic)
        }
        if !traits.isEmpty {
            font = CTFontCreateCopyWithSymbolicTraits(font, 0, nil, traits, traits) ?? font
        }
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: el.style.stroke.cgColor,
        ]
        switch el.style.textDecoration {
        case .underline:
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        case .strikethrough:
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        case .none, .italic:
            break
        }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: el.text, attributes: attrs))
        let flush: CGFloat
        switch el.style.textAlignment {
        case .leading: flush = 0
        case .center: flush = 0.5
        case .trailing: flush = 1
        }
        let offset = CTLineGetPenOffsetForFlush(line, flush, CGFloat(el.style.textWidth))
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: p.x + offset, y: p.y + CGFloat(el.style.fontSize))
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private static func applyStrokeStyle(_ style: StrokeStyle, in ctx: CGContext) {
        switch style {
        case .solid:
            ctx.setLineDash(phase: 0, lengths: [])
        case .dashed:
            ctx.setLineDash(phase: 0, lengths: [8, 6])
        case .dotted:
            ctx.setLineDash(phase: 0, lengths: [1, 6])
        }
    }

    private static func drawImage(_ el: Element, in ctx: CGContext) {
        guard el.points.count >= 2,
              let data = el.imageData,
              let image = image(for: el, data: data) else { return }
        let rect = CGRect(corner: el.points[0].cg, el.points[1].cg)
        ctx.saveGState()
        if el.imageShadow ?? true {
            ctx.setShadow(offset: CGSize(width: 0, height: 3),
                          blur: 10,
                          color: NSColor.black.withAlphaComponent(0.2).cgColor)
        }
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    private static func image(for element: Element, data: Data) -> CGImage? {
        let key = element.id.uuidString as NSString
        if let cached = imageCache.image(forKey: key) { return cached }
        guard let nsImage = NSImage(data: data) else { return nil }
        var proposedRect = NSRect(origin: .zero, size: nsImage.size)
        guard let image = nsImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else { return nil }
        imageCache.insert(image, forKey: key)
        return image
    }
}
