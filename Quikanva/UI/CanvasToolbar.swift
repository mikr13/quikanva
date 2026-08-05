import SwiftUI

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
    @Binding var selectedImageShadow: Bool?
    @Binding var selectedCurve: Double?
    @Binding var background: Color
    @Binding var includeExportBackground: Bool
    var onSave: () -> Void = {}
    var onCopyImage: () -> Void = {}
    var onExportPNG: () -> Void = {}
    var onExportJPEG: () -> Void = {}
    var onZoomIn: () -> Void = {}
    var onZoomOut: () -> Void = {}
    var onZoomToFit: () -> Void = {}
    var onZoomToSelection: () -> Void = {}
    var onResetZoom: () -> Void = {}
    var onApplySelectedStyle: (ElementStyle) -> Void = { _ in }
    var onApplySelectedImageShadow: (Bool) -> Void = { _ in }
    var onApplySelectedCurve: (Double) -> Void = { _ in }
    var onBringSelectionToFront: () -> Void = {}
    var onSendSelectionToBack: () -> Void = {}
    var availableWidth: CGFloat = 900

    @State private var showingInspector = false
    @State private var colorTarget: ColorTarget?
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
                Section(selectedStyle == nil ? "Style for new shapes" : "Style for selection") {
                    Menu("Stroke style") {
                        ForEach(StrokeStyle.allCases) { strokeStyle in
                            Button(strokeStyle.label) { updateStyle { $0.strokeStyle = strokeStyle } }
                        }
                    }
                    Menu("Arrowhead style") {
                        ForEach(ArrowheadStyle.allCases) { arrowheadStyle in
                            Button(arrowheadStyle.label) { updateStyle { $0.arrowheadStyle = arrowheadStyle } }
                        }
                    }
                    Menu("Fill style") {
                        Button("No fill") { updateStyle { $0.fillStyle = .none } }
                        Button("Solid") { updateStyle { $0.fillStyle = .solid } }
                        Button("Hachure") { updateStyle { $0.fillStyle = .hachure } }
                    }
                    Menu("Stroke width") {
                        Button("Fine") { updateStyle { $0.strokeWidth = 1.5 } }
                        Button("Medium") { updateStyle { $0.strokeWidth = 2.5 } }
                        Button("Bold") { updateStyle { $0.strokeWidth = 4 } }
                    }
                    Menu("Roughness") {
                        Button("Subtle") { updateStyle { $0.roughness = 0.6 } }
                        Button("Sketchy") { updateStyle { $0.roughness = 1.2 } }
                        Button("Loose") { updateStyle { $0.roughness = 2 } }
                    }
                    if selectedStyle != nil {
                        Button("Edit all style settings…") { showingInspector = true }
                    }
                }

                Divider()
                Section("Arrange") {
                    Button("Send to Back") { onSendSelectionToBack() }
                        .keyboardShortcut("[", modifiers: .command)
                    Button("Bring to Front") { onBringSelectionToFront() }
                        .keyboardShortcut("]", modifiers: .command)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
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
                Button("Copy as Image") { onCopyImage() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Divider()
                Toggle("Include canvas background", isOn: $includeExportBackground)
                Divider()
                Button("Export PNG…") { onExportPNG() }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Export JPEG…") { onExportJPEG() }
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
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
                : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.3 : 0.12))
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .popover(isPresented: $showingInspector, arrowEdge: .bottom) {
            if selectedStyle != nil {
                CanvasStyleInspector(style: selectedStyleBinding,
                                     imageShadow: selectedImageShadowBinding,
                                     showsImageShadow: selectedImageShadow != nil,
                                     curve: selectedCurveBinding,
                                     showsCurve: selectedCurve != nil)
            }
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
            Button { tool = item } label: {
                Label(item.rawValue.capitalized, systemImage: item.symbol)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .background(tool == item ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 7))
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
            .help("\(item.rawValue.capitalized) (\(item.shortcut))")
            .accessibilityLabel(item.rawValue.capitalized)
            .accessibilityHint("Select drawing tool")
            .accessibilityAddTraits(tool == item ? .isSelected : [])
        }
    }

    @ViewBuilder
    private func toolMenuItems(_ items: ArraySlice<ToolKind>) -> some View {
        ForEach(items) { item in
            Button(item.rawValue.capitalized) { tool = item }
        }
    }

    private var fillColorBinding: Binding<Color> {
        Binding(
            get: { selectedStyle?.fill.swiftUIColor ?? style.fill.swiftUIColor },
            set: { newColor in updateStyle { $0.fill = RGBAColor(newColor) } }
        )
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
        Binding(
            get: { selectedStyle?.stroke.swiftUIColor ?? style.stroke.swiftUIColor },
            set: { newColor in updateStyle { $0.stroke = RGBAColor(newColor) } }
        )
    }

    private func updateStyle(_ update: (inout ElementStyle) -> Void) {
        if var selectedStyle {
            update(&selectedStyle)
            onApplySelectedStyle(selectedStyle)
        } else {
            update(&style)
        }
    }

    private var selectedStyleBinding: Binding<ElementStyle> {
        Binding(
            get: { selectedStyle ?? style },
            set: { onApplySelectedStyle($0) }
        )
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

private struct CanvasStyleInspector: View {
    @Binding var style: ElementStyle
    @Binding var imageShadow: Bool
    let showsImageShadow: Bool
    @Binding var curve: Double
    let showsCurve: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected style")
                .font(.headline)

            ColorPicker("Stroke", selection: strokeBinding, supportsOpacity: true)
            ColorPicker("Fill", selection: fillBinding, supportsOpacity: true)

            Picker("Fill style", selection: $style.fillStyle) {
                Text("No fill").tag(FillStyle.none)
                Text("Solid").tag(FillStyle.solid)
                Text("Hachure").tag(FillStyle.hachure)
            }

            if showsImageShadow {
                Toggle("Image shadow", isOn: $imageShadow)
            }

            Slider(value: $style.strokeWidth, in: 0.5 ... 8, step: 0.5) {
                Text("Stroke width")
            } minimumValueLabel: {
                Text("0.5")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("8")
                    .font(.caption2)
            }

            Slider(value: $style.opacity, in: 0.05 ... 1, step: 0.05) {
                Text("Opacity")
            } minimumValueLabel: {
                Text("0")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("1")
                    .font(.caption2)
            }

            Slider(value: $style.roughness, in: 0 ... 2.5, step: 0.1) {
                Text("Roughness")
            } minimumValueLabel: {
                Text("Clean")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("Loose")
                    .font(.caption2)
            }

            Slider(value: $style.fontSize, in: 10 ... 72, step: 1) {
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
                    Button(family) { style.fontFamily = family }
                }
            }

            Picker("Font weight", selection: $style.fontWeight) {
                ForEach(FontWeight.allCases) { weight in
                    Text(weight.label).tag(weight)
                }
            }

            Picker("Text alignment", selection: $style.textAlignment) {
                ForEach(TextAlignment.allCases) { alignment in
                    Text(alignment.label).tag(alignment)
                }
            }

            Picker("Text style", selection: $style.textDecoration) {
                ForEach(TextDecoration.allCases) { decoration in
                    Text(decoration.label).tag(decoration)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var strokeBinding: Binding<Color> {
        Binding(
            get: { style.stroke.swiftUIColor },
            set: { style.stroke = RGBAColor($0) }
        )
    }

    private var fillBinding: Binding<Color> {
        Binding(
            get: { style.fill.swiftUIColor },
            set: { style.fill = RGBAColor($0) }
        )
    }
}

private extension ToolKind {
    var shortcut: String {
        switch self {
        case .select: "V"
        case .hand: "H"
        case .freedraw: "P"
        case .rectangle: "R"
        case .ellipse: "O"
        case .diamond: "D"
        case .line: "L"
        case .arrow: "A"
        case .text: "T"
        case .eraser: "E"
        }
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
