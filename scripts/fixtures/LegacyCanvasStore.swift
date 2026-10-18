import Foundation
import SwiftData

@Model
final class CanvasDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var sceneData: Data
    var aspectRatioRawValue: String
    @Attribute(.externalStorage) var thumbnail: Data?

    init(id: UUID = UUID(),
         title: String,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         sceneData: Data,
         aspectRatio: CanvasAspectRatio = .portrait,
         thumbnail: Data? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sceneData = sceneData
        aspectRatioRawValue = aspectRatio.rawValue
        self.thumbnail = thumbnail
    }

    var aspectRatio: CanvasAspectRatio {
        get { CanvasAspectRatio(rawValue: aspectRatioRawValue) ?? .portrait }
        set { aspectRatioRawValue = newValue.rawValue }
    }
}


enum CanvasAspectRatio: String { case portrait }

/// Frozen release schema; compile this separately with module name Quikanva.
@main
struct Fixture {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let config = ModelConfiguration(url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CanvasDocument.self, configurations: config)
        let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        let scene = try JSONSerialization.data(withJSONObject: [
            "elements": [["id": "22222222-3333-4444-5555-666666666666", "kind": "image",
                          "points": [["x": 10, "y": 20], ["x": 210, "y": 160]],
                          "rotation": 0, "style": [:], "text": "", "imageData": png,
                          "seed": 1, "zIndex": 0]],
            "camera": ["panX": 12, "panY": -8, "zoom": 1.5],
            "background": ["r": 0.96, "g": 0.93, "b": 0.85, "a": 1]
        ])
        let doc = CanvasDocument(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                                 title: "Release 0.3.4 sketch",
                                 createdAt: Date(timeIntervalSince1970: 1234),
                                 updatedAt: Date(timeIntervalSince1970: 5678),
                                 sceneData: scene, thumbnail: Data([9, 8, 7]))
        container.mainContext.insert(doc)
        try container.mainContext.save()
    }
}
