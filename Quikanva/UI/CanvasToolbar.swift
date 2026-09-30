import SwiftUI

enum QuikanvaMotion {
    static let toolSelection = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let inspectorReveal = Animation.spring(response: 0.3, dampingFraction: 0.9)
    static let galleryHover = Animation.spring(response: 0.24, dampingFraction: 0.86)
}

enum CanvasStyleState {
    static func apply(_ edit: StyleEdit, active: inout ElementStyle, selected: inout ElementStyle?) {
        var updated = selected ?? active
        updated.apply(edit)
        active = updated
        if selected != nil { selected = updated }
    }
}

extension Array where Element == Double {
    func nearest(to value: Double) -> Double {
        self.min { abs($0 - value) < abs($1 - value) } ?? value
    }
}

struct CanvasToolbar: View {
    private enum ColorTarget: String, Identifiable {
        case stroke, fill, background

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stroke: "Stroke color"
            case .fill: "Fill color"
            case .background: "Canvas background"
            }
        }
    }

    @Binding var tool: ToolKind
    @Binding var style: ElementStyle
    @Binding var selectedStyle: ElementStyle?
    let hasSelection: Bool
    @Binding var selectedImageShadow: Bool?
    @Binding var selectedCurve: Double?
    @Binding var background: Color
    @Binding var includeExportBackground: Bool
    let toolShortcuts: ToolShortcutConfiguration
    var onSave: () -> Void = {}
    var onCopyImage: () -> Void = {}
    var onExportPNG: () -> Void = {}
    var onExportJPEG: () -> Void = {}
    var onZoomIn: () -> Void = {}
    var onZoomOut: () -> Void = {}
    var onZoomToFit: () -> Void = {}
    var onZoomToSelection: () -> Void = {}
    var onResetZoom: () -> Void = {}
    var onApplySelectedStyle: (StyleEdit) -> Void = { _ in }
    var onApplySelectedImageShadow: (Bool) -> Void = { _ in }
    var onApplySelectedCurve: (Double) -> Void = { _ in }
    var onTogglePointEditing: () -> Void = {}
    var onBringSelectionToFront: () -> Void = {}
    var onSendSelectionToBack: () -> Void = {}
    var availableWidth: CGFloat = 900

    @State private var showingInspector = false
    @State private var colorTarget: ColorTarget?
    @Namespace private var toolSelectionAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private let tools: [ToolKind] = [
        .select, .hand, .freedraw, .line, .arrow, .rectangle, .ellipse, .diamond, .text, .eraser,
    ]

    private var visibleTools: ArraySlice<ToolKind> {
        tools.prefix(visibleToolCount)
    }

    private var overflowTools: ArraySlice<ToolKind> {
        tools.dropFirst(visibleToolCount)
    }

    private var visibleToolCount: Int {
        let reservedWidth: CGFloat = 170
        let buttonWidth: CGFloat = 34
        return min(tools.count, max(2, Int((availableWidth - reservedWidth) / buttonWidth)))
    }

    var body: some View {
        HStack(spacing: 4) {
            toolButtons(visibleTools)

            Menu {
                if !overflowTools.isEmpty {
                    Section("Tools") {
                        toolMenuItems(overflowTools)
                    }
                    Divider()
                }

                Section("Zoom") {
                    Button("Zoom In") { onZoomIn() }
                        .keyboardShortcut("=", modifiers: .command)
                    Button("Zoom Out") { onZoomOut() }
                        .keyboardShortcut("-", modifiers: .command)
                    Button("Zoom to Fit") { onZoomToFit() }
                        .keyboardShortcut("1", modifiers: .command)
                    Button("Zoom to Selection") { onZoomToSelection() }
                        .keyboardShortcut("2", modifiers: .command)
                    Button("Reset Zoom") { onResetZoom() }
                        .keyboardShortcut("0", modifiers: .command)
                }

                Divider()
                Section("Colors") {
                    Button("Stroke color…") { colorTarget = .stroke }
                    Button("Fill color…") { colorTarget = .fill }
                    Button("Canvas background…") { colorTarget = .background }
                }

                Divider()
                Section(hasSelection ? "Style for selection and new shapes" : "Style for new shapes") {
                    Picker("Drawing style", selection: styleBinding(currentStyle.drawingStyle, StyleEdit.drawingStyle)) {
                        ForEach(DrawingStyle.allCases) { drawingStyle in
                            Text(drawingStyle.label).tag(drawingStyle)
                        }
                    }
                    Picker("Stroke style", selection: styleBinding(currentStyle.strokeStyle, StyleEdit.strokeStyle)) {
                        ForEach(StrokeStyle.allCases) { strokeStyle in
                            Text(strokeStyle.label).tag(strokeStyle)
                        }
                    }
                    Picker("Arrowhead style", selection: styleBinding(currentStyle.arrowheadStyle, StyleEdit.arrowheadStyle)) {
                        ForEach(ArrowheadStyle.allCases) { arrowheadStyle in
                            Text(arrowheadStyle.label).tag(arrowheadStyle)
                        }
                    }
                    Picker("Arrow ends",
                           selection: styleBinding(currentStyle.arrowheadPlacement, StyleEdit.arrowheadPlacement)) {
                        ForEach(ArrowheadPlacement.allCases) { placement in
                            Text(placement.label).tag(placement)
                        }
                    }
                    Picker("Fill style", selection: styleBinding(currentStyle.fillStyle, StyleEdit.fillStyle)) {
                        Text("No fill").tag(FillStyle.none)
                        Text("Solid").tag(FillStyle.solid)
                        Text("Hachure").tag(FillStyle.hachure)
                    }
                    Picker("Stroke width",
                           selection: styleBinding([1.5, 2.5, 4.0].nearest(to: currentStyle.strokeWidth),
                                                   StyleEdit.strokeWidth)) {
                        Text("Fine").tag(1.5)
                        Text("Medium").tag(2.5)
                        Text("Bold").tag(4.0)
                    }
                    if currentStyle.drawingStyle == .handDrawn {
                        Picker("Roughness",
                               selection: styleBinding([0.6, 1.2, 2.0].nearest(to: currentStyle.roughness),
                                                       StyleEdit.roughness)) {
                            Text("Subtle").tag(0.6)
                            Text("Sketchy").tag(1.2)
                            Text("Loose").tag(2.0)
                        }
                    }
                    Button("Edit all style settings…") { showingInspector = true }
                }

                Divider()
                Section("Arrange") {
                    if selectedCurve != nil {
                        Button("Edit line points") { onTogglePointEditing() }
                            .keyboardShortcut(.return, modifiers: .command)
                            .help("Cmd-Return or Cmd-double-click a line to edit its points")
                    }
                    Button("Send to Back") { onSendSelectionToBack() }
                        .keyboardShortcut("[", modifiers: .command)
                    Button("Bring to Front") { onBringSelectionToFront() }
                        .keyboardShortcut("]", modifiers: .command)
                }
            } label: {
                Image(systemName: showingInspector ? "slider.horizontal.3" : "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
                    .animation(reduceMotion ? nil : QuikanvaMotion.toolSelection,
                               value: showingInspector)
            }
            .menuStyle(.button)
            .buttonStyle(PressableStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More tools")
            .accessibilityLabel("More tools and appearance")

            Divider().frame(height: 22).padding(.horizontal, 2)

            Button(action: onSave) {
                Label("Save sketch", systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .keyboardShortcut("s", modifiers: .command)
            .help("Save (name this sketch)")
            .accessibilityLabel("Save sketch")

            Menu {
                CanvasExportMenuItems(
                    includeBackground: $includeExportBackground,
                    onCopyImage: onCopyImage,
                    onExportPNG: onExportPNG,
                    onExportJPEG: onExportJPEG
                )
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(PressableStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Share")
            .accessibilityLabel("Export or copy sketch")
        }
        .padding(6)
        .quikanvaGlassSurface(
            in: RoundedRectangle(cornerRadius: 12),
            interactive: true,
            borderOpacity: contrast == .increased ? 0.3 : 0.12
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .popover(isPresented: $showingInspector, arrowEdge: .bottom) {
            CanvasStyleInspector(title: hasSelection ? "Selected style" : "Style for new shapes",
                                 style: currentStyle,
                                 onEdit: apply,
                                 imageShadow: selectedImageShadowBinding,
                                 showsImageShadow: selectedImageShadow != nil,
                                 curve: selectedCurveBinding,
                                 showsCurve: selectedCurve != nil)
        }
        .popover(item: $colorTarget, arrowEdge: .bottom) { target in
            VStack(alignment: .leading, spacing: 10) {
                Text(target.title)
                    .font(.headline)
                ColorPicker("Color",
                            selection: colorBinding,
                            supportsOpacity: target != .background)
            }
            .padding(16)
            .frame(width: 240)
        }
    }

    @ViewBuilder
    private func toolButtons(_ items: ArraySlice<ToolKind>) -> some View {
        ForEach(items) { item in
            Button { selectTool(item) } label: {
                Label(item.rawValue.capitalized, systemImage: item.symbol)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .background {
                        if tool == item {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(nsColor: .selectedContentBackgroundColor))
                                .matchedGeometryEffect(id: "selected-tool", in: toolSelectionAnimation)
                        }
                    }
                    .foregroundStyle(tool == item ? Color(nsColor: .selectedTextColor) : Color.primary)
                    .overlay {
                        if tool == item {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color(nsColor: .selectedTextColor), lineWidth: 1)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .help("\(item.rawValue.capitalized) (\(toolShortcuts.shortcut(for: item)))")
            .accessibilityLabel(item.rawValue.capitalized)
            .accessibilityHint("Select drawing tool")
            .accessibilityAddTraits(tool == item ? .isSelected : [])
        }
        .animation(reduceMotion ? nil : QuikanvaMotion.toolSelection, value: tool)
    }

    @ViewBuilder
    private func toolMenuItems(_ items: ArraySlice<ToolKind>) -> some View {
        ForEach(items) { item in
            Button("\(item.rawValue.capitalized) (\(toolShortcuts.shortcut(for: item)))") { selectTool(item) }
        }
    }

    private func selectTool(_ item: ToolKind) {
        if reduceMotion {
            tool = item
        } else {
            withAnimation(QuikanvaMotion.toolSelection) {
                tool = item
            }
        }
    }

    private var currentStyle: ElementStyle {
        selectedStyle ?? style
    }

    private func styleBinding<Value>(_ value: Value, _ edit: @escaping (Value) -> StyleEdit) -> Binding<Value> {
        Binding(get: { value }, set: { apply(edit($0)) })
    }

    private func apply(_ edit: StyleEdit) {
        CanvasStyleState.apply(edit, active: &style, selected: &selectedStyle)
        onApplySelectedStyle(edit)
    }

    private var fillColorBinding: Binding<Color> {
        styleBinding(currentStyle.fill.swiftUIColor) { .fill(RGBAColor($0)) }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                switch colorTarget {
                case .stroke: strokeColorBinding.wrappedValue
                case .fill: fillColorBinding.wrappedValue
                case .background: background
                case nil: .clear
                }
            },
            set: { newColor in
                switch colorTarget {
                case .stroke: strokeColorBinding.wrappedValue = newColor
                case .fill: fillColorBinding.wrappedValue = newColor
                case .background: background = newColor
                case nil: break
                }
            }
        )
    }

    private var strokeColorBinding: Binding<Color> {
        styleBinding(currentStyle.stroke.swiftUIColor) { .stroke(RGBAColor($0)) }
    }

    private var selectedImageShadowBinding: Binding<Bool> {
        Binding(
            get: { selectedImageShadow ?? true },
            set: { onApplySelectedImageShadow($0) }
        )
    }

    private var selectedCurveBinding: Binding<Double> {
        Binding(
            get: { selectedCurve ?? 0 },
            set: { onApplySelectedCurve($0) }
        )
    }
}

struct CanvasExportMenuItems: View {
    @Binding var includeBackground: Bool
    let onCopyImage: () -> Void
    let onExportPNG: () -> Void
    let onExportJPEG: () -> Void

    var body: some View {
        Button("Copy as Image", action: onCopyImage)
            .keyboardShortcut("c", modifiers: [.command, .shift])
        Divider()
        Toggle("Include canvas background", isOn: $includeBackground)
        Divider()
        Button("Export PNG…", action: onExportPNG)
            .keyboardShortcut("e", modifiers: .command)
        Button("Export JPEG…", action: onExportJPEG)
    }
}

private struct CanvasStyleInspector: View {
    let title: String
    let style: ElementStyle
    let onEdit: (StyleEdit) -> Void
    @Binding var imageShadow: Bool
    let showsImageShadow: Bool
    @Binding var curve: Double
    let showsCurve: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ColorPicker("Stroke", selection: binding(style.stroke.swiftUIColor) { .stroke(RGBAColor($0)) }, supportsOpacity: true)
            ColorPicker("Fill", selection: binding(style.fill.swiftUIColor) { .fill(RGBAColor($0)) }, supportsOpacity: true)

            Picker("Drawing style", selection: binding(style.drawingStyle, StyleEdit.drawingStyle)) {
                ForEach(DrawingStyle.allCases) { drawingStyle in
                    Text(drawingStyle.label).tag(drawingStyle)
                }
            }

            Picker("Fill style", selection: binding(style.fillStyle, StyleEdit.fillStyle)) {
                Text("No fill").tag(FillStyle.none)
                Text("Solid").tag(FillStyle.solid)
                Text("Hachure").tag(FillStyle.hachure)
            }

            Picker("Arrowhead style", selection: binding(style.arrowheadStyle, StyleEdit.arrowheadStyle)) {
                ForEach(ArrowheadStyle.allCases) { arrowheadStyle in
                    Text(arrowheadStyle.label).tag(arrowheadStyle)
                }
            }

            Picker("Arrow ends", selection: binding(style.arrowheadPlacement, StyleEdit.arrowheadPlacement)) {
                ForEach(ArrowheadPlacement.allCases) { placement in
                    Text(placement.label).tag(placement)
                }
            }

            if showsImageShadow {
                Toggle("Image shadow", isOn: $imageShadow)
            }

            Slider(value: binding(style.strokeWidth, StyleEdit.strokeWidth), in: 0.5 ... 8, step: 0.5) {
                Text("Stroke width")
            } minimumValueLabel: {
                Text("0.5")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("8")
                    .font(.caption2)
            }

            Slider(value: binding(style.opacity, StyleEdit.opacity), in: 0.05 ... 1, step: 0.05) {
                Text("Opacity")
            } minimumValueLabel: {
                Text("0")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("1")
                    .font(.caption2)
            }

            if style.drawingStyle == .handDrawn {
                Slider(value: binding(style.roughness, StyleEdit.roughness), in: 0 ... 2.5, step: 0.1) {
                    Text("Roughness")
                } minimumValueLabel: {
                    Text("Clean")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("Loose")
                        .font(.caption2)
                }
            }

            Slider(value: binding(style.fontSize, StyleEdit.fontSize), in: 10 ... 72, step: 1) {
                Text("Text size")
            } minimumValueLabel: {
                Text("10")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("72")
                    .font(.caption2)
            }

            if showsCurve {
                Slider(value: $curve, in: -1 ... 1, step: 0.05) {
                    Text("Line curve")
                } minimumValueLabel: {
                    Text("Left")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("Right")
                        .font(.caption2)
                }
            }

            Menu("Font family") {
                ForEach(["Helvetica Neue", "Avenir Next", "Comic Sans MS", "Georgia", "Menlo"], id: \.self) { family in
                    Button(family) { onEdit(.fontFamily(family)) }
                }
            }

            Picker("Font weight", selection: binding(style.fontWeight, StyleEdit.fontWeight)) {
                ForEach(FontWeight.allCases) { weight in
                    Text(weight.label).tag(weight)
                }
            }

            Picker("Text alignment", selection: binding(style.textAlignment, StyleEdit.textAlignment)) {
                ForEach(TextAlignment.allCases) { alignment in
                    Text(alignment.label).tag(alignment)
                }
            }

            Picker("Text style", selection: binding(style.textDecoration, StyleEdit.textDecoration)) {
                ForEach(TextDecoration.allCases) { decoration in
                    Text(decoration.label).tag(decoration)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.98, anchor: .bottom)
        .offset(y: isVisible ? 0 : 6)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(QuikanvaMotion.inspectorReveal) {
                    isVisible = true
                }
            }
        }
    }

    private func binding<Value>(_ value: Value, _ edit: @escaping (Value) -> StyleEdit) -> Binding<Value> {
        Binding(get: { value }, set: { onEdit(edit($0)) })
    }
}

struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 1), value: configuration.isPressed)
    }
}

private struct QuikanvaGlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let borderOpacity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .controlBackgroundColor), in: shape)
                .overlay(shape.stroke(Color.primary.opacity(borderOpacity), lineWidth: 1))
        } else if #available(macOS 26.0, *) {
            content
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(borderOpacity), lineWidth: 1))
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(borderOpacity), lineWidth: 1))
        }
    }
}

extension View {
    func quikanvaGlassSurface<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false,
        borderOpacity: Double = 0.12
    ) -> some View {
        modifier(QuikanvaGlassSurfaceModifier(
            shape: shape,
            interactive: interactive,
            borderOpacity: borderOpacity
        ))
    }
}

struct QuikanvaWindowGlass: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    var body: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: .rect)
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }
}
