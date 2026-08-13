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
    private static let adjectives = [
        "Amber", "Brisk", "Cosmic", "Daring", "Electric", "Gentle", "Hidden", "Lunar",
        "Merry", "Nimble", "Quiet", "Radiant", "Silver", "Tiny", "Velvet", "Witty"
    ]
    private static let nouns = [
        "Badger", "Beacon", "Comet", "Fern", "Finch", "Harbor", "Kettle", "Ladle",
        "Lantern", "Meadow", "Otter", "Pebble", "Rocket", "Sparrow", "Teacup", "Willow"
    ]

    static func dated(_ date: Date = .now) -> String {
        dated(
            date,
            adjective: adjectives.randomElement() ?? "Cosmic",
            noun: nouns.randomElement() ?? "Ladle"
        )
    }

    static func dated(_ date: Date, adjective: String, noun: String) -> String {
        dated(
            date,
            adjective: adjective,
            noun: noun,
            dateFormat: CanvasPreferences.autoTitleDateFormat
        )
    }

    static func dated(
        _ date: Date,
        adjective: String,
        noun: String,
        dateFormat: CanvasTitleDateFormat,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        "\(adjective) \(noun) - \(dateFormat.string(from: date, timeZone: timeZone))"
    }
}
