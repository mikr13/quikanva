import SwiftUI

enum CanvasCommand: Equatable {
    case zoomIn
    case zoomOut
    case zoomToFit
    case zoomToSelection
    case resetZoom
    case updateSelectionStyle(StyleEdit)
    case setBackground(RGBAColor)
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
    var toolShortcuts: ToolShortcutConfiguration
    var command: CanvasCommand?
    var onChange: (CanvasScene) -> Void
    var onToolChange: (ToolKind) -> Void
    var onSelectionChange: (ElementStyle?, Bool) -> Void
    var onImageShadowChange: (Bool?) -> Void
    var onCurveChange: (Double?) -> Void
    var onCommandHandled: () -> Void

    @MainActor
    final class Coordinator {
        var isUpdating = false

        func deliver(_ callback: @escaping () -> Void) {
            guard isUpdating else { return callback() }
            Task { @MainActor in callback() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.scene = scene
        sync(view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: CanvasNSView, context: Context) {
        sync(view, coordinator: context.coordinator)
    }

    private func sync(_ view: CanvasNSView, coordinator: Coordinator) {
        coordinator.isUpdating = true
        defer { coordinator.isUpdating = false }
        view.onCommit = { scene in coordinator.deliver { onChange(scene) } }
        view.onToolChange = { tool in coordinator.deliver { onToolChange(tool) } }
        view.onSelectionChange = { style, hasSelection in
            coordinator.deliver { onSelectionChange(style, hasSelection) }
        }
        view.onImageShadowChange = { shadow in coordinator.deliver { onImageShadowChange(shadow) } }
        view.onCurveChange = { curve in coordinator.deliver { onCurveChange(curve) } }
        view.onCommandHandled = { coordinator.deliver(onCommandHandled) }
        view.tool = tool
        view.style = style
        view.toolShortcuts = toolShortcuts
        if view.command != command {
            view.command = command
        }
    }
}
