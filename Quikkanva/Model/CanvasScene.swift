import Foundation

struct Camera: Codable, Hashable {
    var panX: Double = 0
    var panY: Double = 0
    var zoom: Double = 1
}

struct CanvasScene: Codable, Hashable {
    var elements: [Element] = []
    var camera: Camera = Camera()
    /// Canvas background; new scenes default to a warm beige.
    var background: RGBAColor? = .beige
}
