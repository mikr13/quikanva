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

    var galleryPreviewSize: CGSize {
        switch self {
        case .portrait: CGSize(width: 150, height: 150 / widthToHeight)
        case .square: CGSize(width: 190, height: 190)
        case .standard: CGSize(width: 220, height: 220 / widthToHeight)
        case .widescreen: CGSize(width: 240, height: 240 / widthToHeight)
        }
    }
}

enum CanvasTitleDateFormat: String, CaseIterable, Identifiable {
    case system
    case sortable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .sortable: "Sortable"
        }
    }

    func string(from date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone

        switch self {
        case .system:
            formatter.locale = .autoupdatingCurrent
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        case .sortable:
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        }

        return formatter.string(from: date)
    }
}

enum CanvasPreferences {
    static let defaultAspectRatioKey = "defaultCanvasAspectRatio"
    static let discardEmptyCanvasesKey = "discardEmptyCanvases"
    static let defaultBackgroundKey = "defaultCanvasBackground"
    static let defaultStyleKey = "defaultElementStyle"
    static let maxOpenCanvasPanelsKey = "maxOpenCanvasPanels"
    static let autoTitleDateFormatKey = "autoTitleDateFormat"

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

    static var defaultBackground: RGBAColor {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultBackgroundKey),
                  let background = try? JSONDecoder().decode(RGBAColor.self, from: data) else {
                return .beige
            }
            return background
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: defaultBackgroundKey)
        }
    }

    static var defaultStyle: ElementStyle {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultStyleKey),
                  let style = try? JSONDecoder().decode(ElementStyle.self, from: data) else {
                return ElementStyle()
            }
            return style
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: defaultStyleKey)
        }
    }

    static var maxOpenCanvasPanels: Int {
        get { UserDefaults.standard.integer(forKey: maxOpenCanvasPanelsKey) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: maxOpenCanvasPanelsKey) }
    }

    static var autoTitleDateFormat: CanvasTitleDateFormat {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: autoTitleDateFormatKey) else {
                return .system
            }
            return CanvasTitleDateFormat(rawValue: rawValue) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: autoTitleDateFormatKey)
        }
    }
}
