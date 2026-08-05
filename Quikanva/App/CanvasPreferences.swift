import CoreGraphics
import Foundation

enum CanvasAspectRatio: String, CaseIterable, Identifiable {
    case portrait = "9:16"
    case square = "1:1"
    case standard = "4:3"
    case widescreen = "16:9"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait: "Portrait (9:16)"
        case .square: "Square (1:1)"
        case .standard: "Standard (4:3)"
        case .widescreen: "Widescreen (16:9)"
        }
    }

    var widthToHeight: CGFloat {
        switch self {
        case .portrait: 9.0 / 16.0
        case .square: 1
        case .standard: 4.0 / 3.0
        case .widescreen: 16.0 / 9.0
        }
    }
}

enum CanvasPreferences {
    static let defaultAspectRatioKey = "defaultCanvasAspectRatio"
    static let discardEmptyCanvasesKey = "discardEmptyCanvases"

    static var defaultAspectRatio: CanvasAspectRatio {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: defaultAspectRatioKey) else {
                return .portrait
            }
            return CanvasAspectRatio(rawValue: rawValue) ?? .portrait
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultAspectRatioKey)
        }
    }

    static var discardEmptyCanvases: Bool {
        get {
            UserDefaults.standard.object(forKey: discardEmptyCanvasesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: discardEmptyCanvasesKey)
        }
    }
}
