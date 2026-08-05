import Foundation
import CoreGraphics

struct Point: Codable, Hashable {
    var x: Double
    var y: Double
    init(x: Double, y: Double) { self.x = x; self.y = y }
    init(_ p: CGPoint) { x = Double(p.x); y = Double(p.y) }
    var cg: CGPoint { CGPoint(x: x, y: y) }
}

enum ToolKind: String, CaseIterable, Identifiable, Hashable {
    case select, hand, freedraw, rectangle, ellipse, diamond, line, arrow, text, eraser

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .hand: "hand.raised"
        case .freedraw: "scribble.variable"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .diamond: "diamond"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .eraser: "eraser"
        }
    }

    var elementKind: ElementKind? {
        switch self {
        case .freedraw: .freedraw
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .diamond: .diamond
        case .line: .line
        case .arrow: .arrow
        case .text: .text
        default: nil
        }
    }
}

enum ElementKind: String, Codable, Hashable {
    case rectangle, ellipse, diamond, line, arrow, freedraw, text
}

enum FillStyle: String, Codable, Hashable {
    case none, solid, hachure
}

struct RGBAColor: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    static let ink = RGBAColor(r: 0.10, g: 0.10, b: 0.12, a: 1)
    static let black = RGBAColor(r: 0, g: 0, b: 0, a: 1)
    static let beige = RGBAColor(r: 0.96, g: 0.93, b: 0.85, a: 1)
    static let clear = RGBAColor(r: 0, g: 0, b: 0, a: 0)

    var cgColor: CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

struct ElementStyle: Codable, Hashable {
    var stroke: RGBAColor = .black
    var fill: RGBAColor = .clear
    var fillStyle: FillStyle = .none
    var strokeWidth: Double = 2.5
    var opacity: Double = 1
    var roughness: Double = 1.2
    var fontSize: Double = 20
}

struct Element: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: ElementKind
    var points: [Point]
    var rotation: Double = 0
    var style: ElementStyle = ElementStyle()
    var text: String = ""
    var seed: UInt64 = UInt64.random(in: 1 ... .max)
    var zIndex: Int = 0
}
