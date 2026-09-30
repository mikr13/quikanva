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
    case rectangle, ellipse, diamond, line, arrow, freedraw, text, image

    var isBoxShape: Bool {
        switch self {
        case .rectangle, .ellipse, .diamond, .image: true
        case .line, .arrow, .freedraw, .text: false
        }
    }
}

enum DrawingStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case precise
    case handDrawn

    var id: String { rawValue }

    var label: String {
        switch self {
        case .precise: "Precise"
        case .handDrawn: "Hand-drawn"
        }
    }
}

enum FillStyle: String, Codable, Hashable {
    case none, solid, hachure
}

enum StrokeStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case solid, dashed, dotted

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum ArrowheadStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case open, closed, filled, bar

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum ArrowheadPlacement: String, Codable, CaseIterable, Identifiable, Hashable {
    case end
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .end: "End only"
        case .both: "Both ends"
        }
    }
}

enum FontWeight: String, Codable, CaseIterable, Identifiable, Hashable {
    case regular, medium, semibold, bold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        }
    }
}

enum TextAlignment: String, Codable, CaseIterable, Identifiable, Hashable {
    case leading, center, trailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leading: "Leading"
        case .center: "Center"
        case .trailing: "Trailing"
        }
    }
}

enum TextDecoration: String, Codable, CaseIterable, Identifiable, Hashable {
    case none, italic, underline, strikethrough

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
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
    var drawingStyle: DrawingStyle = .precise
    var fillStyle: FillStyle = .none
    var strokeStyle: StrokeStyle = .solid
    var arrowheadStyle: ArrowheadStyle = .open
    var arrowheadPlacement: ArrowheadPlacement = .end
    var strokeWidth: Double = 2.5
    var opacity: Double = 1
    var roughness: Double = 1.2
    var fontSize: Double = 20
    var fontFamily: String = "Helvetica Neue"
    var fontWeight: FontWeight = .regular
    var textAlignment: TextAlignment = .leading
    var textDecoration: TextDecoration = .none

    var visibleFillColor: RGBAColor {
        guard fillStyle != .none, fill.a == 0 else { return fill }
        return stroke.a > 0 ? stroke : .black
    }

    private enum CodingKeys: String, CodingKey {
        case stroke, fill, drawingStyle, fillStyle, strokeStyle, arrowheadStyle, arrowheadPlacement, strokeWidth, opacity
        case roughness, fontSize, fontFamily, fontWeight, textAlignment, textDecoration
    }

    init(stroke: RGBAColor = .black,
         fill: RGBAColor = .clear,
         drawingStyle: DrawingStyle = .precise,
         fillStyle: FillStyle = .none,
         strokeStyle: StrokeStyle = .solid,
         arrowheadStyle: ArrowheadStyle = .open,
         arrowheadPlacement: ArrowheadPlacement = .end,
         strokeWidth: Double = 2.5,
         opacity: Double = 1,
         roughness: Double = 1.2,
         fontSize: Double = 20,
         fontFamily: String = "Helvetica Neue",
         fontWeight: FontWeight = .regular,
         textAlignment: TextAlignment = .leading,
         textDecoration: TextDecoration = .none) {
        self.stroke = stroke
        self.fill = fill
        self.drawingStyle = drawingStyle
        self.fillStyle = fillStyle
        self.strokeStyle = strokeStyle
        self.arrowheadStyle = arrowheadStyle
        self.arrowheadPlacement = arrowheadPlacement
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.roughness = roughness
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.fontWeight = fontWeight
        self.textAlignment = textAlignment
        self.textDecoration = textDecoration
        materializeVisibleFillIfNeeded()
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        stroke = try values.decodeIfPresent(RGBAColor.self, forKey: .stroke) ?? .black
        fill = try values.decodeIfPresent(RGBAColor.self, forKey: .fill) ?? .clear
        drawingStyle = try values.decodeIfPresent(DrawingStyle.self, forKey: .drawingStyle) ?? .handDrawn
        fillStyle = try values.decodeIfPresent(FillStyle.self, forKey: .fillStyle) ?? .none
        strokeStyle = try values.decodeIfPresent(StrokeStyle.self, forKey: .strokeStyle) ?? .solid
        arrowheadStyle = try values.decodeIfPresent(ArrowheadStyle.self, forKey: .arrowheadStyle) ?? .open
        arrowheadPlacement = try values.decodeIfPresent(ArrowheadPlacement.self, forKey: .arrowheadPlacement) ?? .end
        strokeWidth = try values.decodeIfPresent(Double.self, forKey: .strokeWidth) ?? 2.5
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        roughness = try values.decodeIfPresent(Double.self, forKey: .roughness) ?? 1.2
        fontSize = try values.decodeIfPresent(Double.self, forKey: .fontSize) ?? 20
        fontFamily = try values.decodeIfPresent(String.self, forKey: .fontFamily) ?? "Helvetica Neue"
        fontWeight = try values.decodeIfPresent(FontWeight.self, forKey: .fontWeight) ?? .regular
        textAlignment = try values.decodeIfPresent(TextAlignment.self, forKey: .textAlignment) ?? .leading
        textDecoration = try values.decodeIfPresent(TextDecoration.self, forKey: .textDecoration) ?? .none
        materializeVisibleFillIfNeeded()
    }

    mutating func setFillStyle(_ fillStyle: FillStyle) {
        self.fillStyle = fillStyle
        materializeVisibleFillIfNeeded()
    }

    mutating func setFill(_ color: RGBAColor) {
        fill = color
        if color.a == 0 {
            fillStyle = .none
        } else if fillStyle == .none {
            fillStyle = .solid
        }
    }

    mutating func apply(_ edit: StyleEdit) {
        switch edit {
        case .stroke(let value): stroke = value
        case .fill(let value): setFill(value)
        case .drawingStyle(let value): drawingStyle = value
        case .fillStyle(let value): setFillStyle(value)
        case .strokeStyle(let value): strokeStyle = value
        case .arrowheadStyle(let value): arrowheadStyle = value
        case .arrowheadPlacement(let value): arrowheadPlacement = value
        case .strokeWidth(let value): strokeWidth = value
        case .opacity(let value): opacity = value
        case .roughness(let value): roughness = value
        case .fontSize(let value): fontSize = value
        case .fontFamily(let value): fontFamily = value
        case .fontWeight(let value): fontWeight = value
        case .textAlignment(let value): textAlignment = value
        case .textDecoration(let value): textDecoration = value
        }
    }

    func merging(changesFrom old: ElementStyle, to new: ElementStyle) -> ElementStyle {
        var merged = self
        func take<Value: Equatable>(_ keyPath: WritableKeyPath<ElementStyle, Value>) {
            if old[keyPath: keyPath] != new[keyPath: keyPath] {
                merged[keyPath: keyPath] = new[keyPath: keyPath]
            }
        }
        take(\.stroke)
        take(\.fill)
        take(\.drawingStyle)
        take(\.fillStyle)
        take(\.strokeStyle)
        take(\.arrowheadStyle)
        take(\.arrowheadPlacement)
        take(\.strokeWidth)
        take(\.opacity)
        take(\.roughness)
        take(\.fontSize)
        take(\.fontFamily)
        take(\.fontWeight)
        take(\.textAlignment)
        take(\.textDecoration)
        return merged
    }

    private mutating func materializeVisibleFillIfNeeded() {
        guard fillStyle != .none, fill.a == 0 else { return }
        fill = visibleFillColor
    }
}

enum StyleEdit: Equatable {
    case stroke(RGBAColor)
    case fill(RGBAColor)
    case drawingStyle(DrawingStyle)
    case fillStyle(FillStyle)
    case strokeStyle(StrokeStyle)
    case arrowheadStyle(ArrowheadStyle)
    case arrowheadPlacement(ArrowheadPlacement)
    case strokeWidth(Double)
    case opacity(Double)
    case roughness(Double)
    case fontSize(Double)
    case fontFamily(String)
    case fontWeight(FontWeight)
    case textAlignment(TextAlignment)
    case textDecoration(TextDecoration)
}

struct TextBox: Codable, Hashable {
    enum Sizing: String, Codable, Hashable {
        case auto
        case fixed
    }

    var sizing: Sizing
    var width: Double
}

struct Element: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: ElementKind
    var points: [Point]
    var rotation: Double = 0
    var style: ElementStyle = ElementStyle()
    var text: String = ""
    /// nil for text saved before wrapping existed; it keeps its single-line layout.
    var textBox: TextBox?
    var imageData: Data?
    var imageShadow: Bool?
    var seed: UInt64 = UInt64.random(in: 1 ... .max)
    var zIndex: Int = 0
}
