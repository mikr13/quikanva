import AppKit
import CoreGraphics

enum Thumbnailer {
    static func png(for scene: CanvasScene, aspectRatio: CanvasAspectRatio) -> Data? {
        let maximumDimension: CGFloat = 480
        let widthToHeight = aspectRatio.widthToHeight
        let size = widthToHeight >= 1
            ? CGSize(width: maximumDimension, height: maximumDimension / widthToHeight)
            : CGSize(width: maximumDimension * widthToHeight, height: maximumDimension)
        return png(for: scene, size: size)
    }

    static func png(for scene: CanvasScene, size: CGSize = CGSize(width: 480, height: 320)) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width),
                                         pixelsHigh: Int(size.height),
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0),
              let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let ctx = nsCtx.cgContext

        ctx.setFillColor(scene.background?.cgColor ?? RGBAColor.beige.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        if let box = contentBounds(scene) {
            let pad: CGFloat = 28
            let scale = min((size.width - pad * 2) / max(box.width, 1),
                            (size.height - pad * 2) / max(box.height, 1),
                            3)
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -box.midX, y: -box.midY)
            Renderer.draw(scene, in: ctx)
        }

        return rep.representation(using: .png, properties: [:])
    }

    static func contentBounds(_ scene: CanvasScene) -> CGRect? {
        var box: CGRect?
        for element in scene.elements {
            for point in element.points {
                let r = CGRect(x: point.x, y: point.y, width: 0, height: 0)
                box = box?.union(r) ?? r
            }
        }
        return box?.insetBy(dx: -12, dy: -12)
    }
}
