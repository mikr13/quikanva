import Foundation
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

enum Renderer {
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

        var rng = SketchRNG(seed: el.seed)
        let rough = el.style.roughness

        switch el.kind {
        case .freedraw:
            let path = CGMutablePath()
            path.addLines(between: pts)
            ctx.addPath(path)
            ctx.strokePath()

        case .line:
            let path = CGMutablePath()
            Sketch.roughLine(pts[0], pts[pts.count - 1], roughness: rough, rng: &rng, into: path)
            ctx.addPath(path)
            ctx.strokePath()

        case .arrow:
            let a = pts[0], b = pts[pts.count - 1]
            let shaft = CGMutablePath()
            Sketch.roughLine(a, b, roughness: rough, rng: &rng, into: shaft)
            ctx.addPath(shaft)
            ctx.strokePath()

            let dist = hypot(b.x - a.x, b.y - a.y)
            guard dist > 1 else { break }
            let ang = atan2(b.y - a.y, b.x - a.x)
            let hl = max(14, min(dist * 0.28, 30))
            let spread = CGFloat.pi / 7
            let left = CGPoint(x: b.x - hl * cos(ang - spread), y: b.y - hl * sin(ang - spread))
            let right = CGPoint(x: b.x - hl * cos(ang + spread), y: b.y - hl * sin(ang + spread))
            let head = CGMutablePath()
            head.move(to: left)
            head.addLine(to: b)
            head.addLine(to: right)
            ctx.addPath(head)
            ctx.strokePath()

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
            if el.style.fillStyle == .solid {
                let fill = CGMutablePath()
                fill.addLines(between: corners)
                fill.closeSubpath()
                ctx.addPath(fill)
                ctx.setFillColor(el.style.fill.cgColor)
                ctx.fillPath()
            }
            let path = CGMutablePath()
            Sketch.roughPolygon(corners, roughness: rough, rng: &rng, into: path)
            ctx.addPath(path)
            ctx.setStrokeColor(el.style.stroke.cgColor)
            ctx.strokePath()

        case .text:
            drawText(el, at: pts[0], in: ctx)
        }

        ctx.restoreGState()
    }

    private static func drawText(_ el: Element, at p: CGPoint, in ctx: CGContext) {
        guard !el.text.isEmpty else { return }
        let font = CTFontCreateWithName("HelveticaNeue" as CFString, CGFloat(el.style.fontSize), nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: el.style.stroke.cgColor,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: el.text, attributes: attrs))
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: p.x, y: p.y + CGFloat(el.style.fontSize))
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
