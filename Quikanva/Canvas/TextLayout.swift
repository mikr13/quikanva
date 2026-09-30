import AppKit
import CoreText

private final class FontCache: @unchecked Sendable {
    private let storage = NSCache<NSString, NSFont>()

    func font(forKey key: NSString) -> NSFont? {
        storage.object(forKey: key)
    }

    func insert(_ font: NSFont, forKey key: NSString) {
        storage.setObject(font, forKey: key)
    }
}

private final class TextSizeCache: @unchecked Sendable {
    private let storage: NSCache<NSString, NSValue> = {
        let cache = NSCache<NSString, NSValue>()
        cache.countLimit = 2_000
        return cache
    }()

    func size(forKey key: NSString) -> CGSize? {
        storage.object(forKey: key)?.sizeValue
    }

    func insert(_ size: CGSize, forKey key: NSString) {
        storage.setObject(NSValue(size: size), forKey: key)
    }
}

/// TextKit 1, shared with CanvasTextView, so editing and rendered text wrap identically.
enum TextLayout {
    static let legacyWidth: CGFloat = 260
    static let minimumWidth: CGFloat = 24

    private static let sizeCache = TextSizeCache()
    private static let fontCache = FontCache()

    static func font(for style: ElementStyle) -> NSFont {
        let italic = style.textDecoration == .italic
        let key = [style.fontFamily, "\(style.fontSize)", style.fontWeight.rawValue, "\(italic)"]
            .joined(separator: "|") as NSString
        if let cached = fontCache.font(forKey: key) { return cached }
        let size = CGFloat(style.fontSize)
        let weight = weightValue(style.fontWeight)
        var font = matchingFont(family: style.fontFamily, weight: weight, italic: italic, size: size)
        if abs(resolvedWeight(of: font) - weight) > 0.02, let fallback = fallbackWeight(for: style.fontWeight) {
            font = matchingFont(family: style.fontFamily, weight: fallback, italic: italic, size: size)
        }
        let resolved = font as NSFont
        fontCache.insert(resolved, forKey: key)
        return resolved
    }

    private static func weightValue(_ weight: FontWeight) -> CGFloat {
        switch weight {
        case .regular: NSFont.Weight.regular.rawValue
        case .medium: NSFont.Weight.medium.rawValue
        case .semibold: NSFont.Weight.semibold.rawValue
        case .bold: NSFont.Weight.bold.rawValue
        }
    }

    private static func fallbackWeight(for weight: FontWeight) -> CGFloat? {
        switch weight {
        case .medium: NSFont.Weight.regular.rawValue
        case .semibold: NSFont.Weight.bold.rawValue
        case .regular, .bold: nil
        }
    }

    private static func matchingFont(family: String, weight: CGFloat, italic: Bool, size: CGFloat) -> CTFont {
        var traits: [CFString: Any] = [kCTFontWeightTrait: weight]
        if italic {
            traits[kCTFontSymbolicTrait] = CTFontSymbolicTraits.traitItalic.rawValue
        }
        let attributes: [CFString: Any] = [kCTFontFamilyNameAttribute: family, kCTFontTraitsAttribute: traits]
        return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attributes as CFDictionary), size, nil)
    }

    private static func resolvedWeight(of font: CTFont) -> CGFloat {
        let traits = CTFontCopyTraits(font) as NSDictionary
        return (traits[kCTFontWeightTrait as String] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
    }

    static func attributes(for style: ElementStyle) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        switch style.textAlignment {
        case .leading: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .trailing: paragraph.alignment = .right
        }
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(for: style),
            .foregroundColor: NSColor(srgbRed: style.stroke.r,
                                      green: style.stroke.g,
                                      blue: style.stroke.b,
                                      alpha: style.stroke.a),
            .paragraphStyle: paragraph,
        ]
        switch style.textDecoration {
        case .underline:
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        case .strikethrough:
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        case .none, .italic:
            break
        }
        return attributes
    }

    static func lineHeight(for style: ElementStyle) -> CGFloat {
        let key = ["line", style.fontFamily, "\(style.fontSize)", style.fontWeight.rawValue, style.textDecoration.rawValue]
            .joined(separator: "|") as NSString
        if let cached = sizeCache.size(forKey: key) { return cached.height }
        let height = ceil(NSLayoutManager().defaultLineHeight(for: font(for: style)))
        sizeCache.insert(CGSize(width: 0, height: height), forKey: key)
        return height
    }

    static func containerWidth(for text: String, style: ElementStyle, box: TextBox?) -> CGFloat {
        guard let box else {
            let natural = size(of: text, style: style, width: .greatestFiniteMagnitude, alignment: .leading).width
            return max(legacyWidth, ceil(natural))
        }
        let limit = max(minimumWidth, CGFloat(box.width))
        switch box.sizing {
        case .fixed:
            return limit
        case .auto:
            let natural = size(of: text, style: style, width: limit, alignment: .leading).width
            return min(limit, max(1, ceil(natural)))
        }
    }

    static func frame(for element: Element) -> CGRect {
        let origin = element.points.first?.cg ?? .zero
        let width = containerWidth(for: element.text, style: element.style, box: element.textBox)
        let height = size(of: element.text, style: element.style, width: width, alignment: element.style.textAlignment).height
        return CGRect(x: origin.x, y: origin.y, width: width, height: max(height, lineHeight(for: element.style)))
    }

    static func draw(_ element: Element, in ctx: CGContext) {
        guard !element.text.isEmpty, let origin = element.points.first?.cg else { return }
        let width = containerWidth(for: element.text, style: element.style, box: element.textBox)
        let stack = Stack(text: element.text, style: element.style, width: width)
        let glyphs = stack.layoutManager.glyphRange(for: stack.container)
        ctx.saveGState()
        ctx.setLineDash(phase: 0, lengths: [])
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        stack.layoutManager.drawGlyphs(forGlyphRange: glyphs, at: origin)
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
    }

    static func configure(_ container: NSTextContainer, width: CGFloat) {
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.size = NSSize(width: width, height: .greatestFiniteMagnitude)
    }

    static func usedSize(of layoutManager: NSLayoutManager, in container: NSTextContainer) -> CGSize {
        layoutManager.ensureLayout(for: container)
        var used = layoutManager.usedRect(for: container)
        if layoutManager.extraLineFragmentTextContainer === container {
            used = used.union(layoutManager.extraLineFragmentUsedRect)
        }
        return CGSize(width: used.width, height: ceil(used.maxY))
    }

    private static func size(of text: String, style: ElementStyle, width: CGFloat, alignment: TextAlignment) -> CGSize {
        let key = [
            "\(width)",
            style.fontFamily,
            "\(style.fontSize)",
            style.fontWeight.rawValue,
            style.textDecoration.rawValue,
            alignment.rawValue,
            text,
        ].joined(separator: "|") as NSString
        if let cached = sizeCache.size(forKey: key) { return cached }
        var aligned = style
        aligned.textAlignment = alignment
        let stack = Stack(text: text, style: aligned, width: width)
        let size = usedSize(of: stack.layoutManager, in: stack.container)
        sizeCache.insert(size, forKey: key)
        return size
    }

    private struct Stack {
        let storage: NSTextStorage
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()

        init(text: String, style: ElementStyle, width: CGFloat) {
            storage = NSTextStorage(string: text, attributes: TextLayout.attributes(for: style))
            TextLayout.configure(container, width: width)
            layoutManager.addTextContainer(container)
            storage.addLayoutManager(layoutManager)
        }
    }
}
