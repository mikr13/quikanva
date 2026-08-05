import AppKit
import CoreGraphics
import UniformTypeIdentifiers

enum ExportFormat {
    case png
    case jpeg

    var contentType: UTType { self == .png ? .png : .jpeg }
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

enum Exporter {
    private static let padding: CGFloat = 24

    static func bitmap(for scene: CanvasScene, scale: CGFloat, background: Bool) -> NSBitmapImageRep? {
        guard let box = Thumbnailer.contentBounds(scene) else { return nil }
        let width = Int((box.width + padding * 2) * scale)
        let height = Int((box.height + padding * 2) * scale)
        guard width >= 1, height >= 1,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: width,
                                         pixelsHigh: height,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0),
              let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let ctx = nsCtx.cgContext

        if background {
            ctx.setFillColor(scene.background?.cgColor ?? RGBAColor.beige.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: padding - box.minX, y: padding - box.minY)
        Renderer.draw(scene, in: ctx, live: nil)

        return rep
    }

    static func data(for scene: CanvasScene, format: ExportFormat, scale: CGFloat = 2, background: Bool = true) -> Data? {
        guard let rep = bitmap(for: scene, scale: scale, background: background) else { return nil }
        switch format {
        case .png:
            return rep.representation(using: .png, properties: [:])
        case .jpeg:
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        }
    }

    @MainActor
    static func copyToClipboard(_ scene: CanvasScene, scale: CGFloat = 2, background: Bool = true) {
        guard let rep = bitmap(for: scene, scale: scale, background: background) else { return }
        let image = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
        image.addRepresentation(rep)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    @MainActor
    static func exportWithPanel(_ scene: CanvasScene,
                                format: ExportFormat,
                                suggestedName: String,
                                background: Bool = true) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(sanitized(suggestedName)).\(format.fileExtension)"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let data = data(for: scene, format: format, background: background) else { return }
            try? data.write(to: url)
        }
    }

    private static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "Sketch" : cleaned
    }
}
