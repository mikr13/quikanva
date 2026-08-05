import SwiftUI

enum CanvasCommand: Equatable {
    case zoomIn
    case zoomOut
    case zoomToFit
    case zoomToSelection
    case resetZoom
    case updateSelectionStyle(ElementStyle)
}

struct CanvasRepresentable: NSViewRepresentable {
    var scene: CanvasScene
    var tool: ToolKind
    var style: ElementStyle
    var command: CanvasCommand?
    var onChange: (CanvasScene) -> Void
    var onSelectionChange: (ElementStyle?) -> Void
    var onCommandHandled: () -> Void

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.scene = scene
        view.tool = tool
        view.style = style
        view.onCommit = onChange
        view.onSelectionChange = onSelectionChange
        view.command = command
        view.onCommandHandled = onCommandHandled
        return view
    }

    func updateNSView(_ view: CanvasNSView, context: Context) {
        view.tool = tool
        view.style = style
        view.onCommit = onChange
        view.onSelectionChange = onSelectionChange
        view.onCommandHandled = onCommandHandled
        if view.command != command {
            view.command = command
        }

        guard !view.isInteracting else { return }
        if view.scene.elements != scene.elements || view.scene.background != scene.background {
            var next = scene
            next.camera = view.scene.camera
            view.scene = next
        }
    }
}
