import SwiftUI

enum CanvasCommand: Equatable {
    case zoomIn
    case zoomOut
    case zoomToFit
    case zoomToSelection
    case resetZoom
    case updateSelectionStyle(ElementStyle)
    case updateSelectedImageShadow(Bool)
    case updateSelectedCurve(Double)
    case togglePointEditing
    case bringSelectionToFront
    case sendSelectionToBack
}

struct CanvasRepresentable: NSViewRepresentable {
    var scene: CanvasScene
    var tool: ToolKind
    var style: ElementStyle
    var command: CanvasCommand?
    var onChange: (CanvasScene) -> Void
    var onToolChange: (ToolKind) -> Void
    var onSelectionChange: (ElementStyle?) -> Void
    var onImageShadowChange: (Bool?) -> Void
    var onCurveChange: (Double?) -> Void
    var onCommandHandled: () -> Void

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.scene = scene
        view.onToolChange = onToolChange
        view.tool = tool
        view.style = style
        view.onCommit = onChange
        view.onSelectionChange = onSelectionChange
        view.onImageShadowChange = onImageShadowChange
        view.onCurveChange = onCurveChange
        view.command = command
        view.onCommandHandled = onCommandHandled
        return view
    }

    func updateNSView(_ view: CanvasNSView, context: Context) {
        view.tool = tool
        view.style = style
        view.onCommit = onChange
        view.onToolChange = onToolChange
        view.onSelectionChange = onSelectionChange
        view.onImageShadowChange = onImageShadowChange
        view.onCurveChange = onCurveChange
        view.onCommandHandled = onCommandHandled
        let commandChanged = view.command != command
        let commandApplied = commandChanged && command != nil
        if commandChanged {
            view.command = command
        }

        guard !view.isInteracting else { return }
        if let next = Self.sceneToApply(
            viewScene: view.scene,
            incomingScene: scene,
            commandApplied: commandApplied
        ) {
            view.scene = next
        }
    }

    static func sceneToApply(
        viewScene: CanvasScene,
        incomingScene: CanvasScene,
        commandApplied: Bool
    ) -> CanvasScene? {
        guard !commandApplied else { return nil }
        guard viewScene.elements != incomingScene.elements ||
                viewScene.background != incomingScene.background else { return nil }
        var next = incomingScene
        next.camera = viewScene.camera
        return next
    }
}
