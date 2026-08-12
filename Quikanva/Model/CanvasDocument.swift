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

enum SceneCodec {
    static func encode(_ scene: CanvasScene) -> Data {
        (try? JSONEncoder().encode(scene)) ?? Data()
    }

    static func decode(_ data: Data) -> CanvasScene {
        (try? JSONDecoder().decode(CanvasScene.self, from: data)) ?? CanvasScene()
    }
}

enum CanvasTitle {
    static func dated(_ date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Sketch - \(formatter.string(from: date))"
    }
}
