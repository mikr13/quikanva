import SwiftUI

struct CanvasToolbar: View {
    @Binding var tool: ToolKind
    @Binding var style: ElementStyle
    @Binding var selectedStyle: ElementStyle?
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

    @State private var showingInspector = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private let tools: [ToolKind] = [
        .select, .hand, .freedraw, .rectangle, .ellipse, .diamond, .line, .arrow, .text, .eraser,
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tools) { item in
                Button { tool = item } label: {
                    Label(item.rawValue.capitalized, systemImage: item.symbol)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 30, height: 28)
                        .background(tool == item ? Color.accentColor.opacity(0.18) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(tool == item ? Color.accentColor : Color.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .help("\(item.rawValue.capitalized) (\(item.shortcut))")
                .accessibilityLabel(item.rawValue.capitalized)
                .accessibilityHint("Select drawing tool")
                .accessibilityAddTraits(tool == item ? .isSelected : [])
            }

            Divider().frame(height: 22).padding(.horizontal, 2)

            colorSwatch(icon: "pencil.tip", help: "Stroke color", color: Binding(
                get: { style.stroke.swiftUIColor },
                set: { style.stroke = RGBAColor($0) }
            ))

            colorSwatch(icon: "paintbrush.fill", help: "Fill color", color: fillColorBinding)

            colorSwatch(icon: "square.fill", help: "Canvas background", color: $background)

            Divider().frame(height: 22).padding(.horizontal, 2)

            Menu {
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
                Section("Style for new shapes") {
                    Picker("Fill style", selection: $style.fillStyle) {
                        Text("No fill").tag(FillStyle.none)
                        Text("Solid").tag(FillStyle.solid)
                        Text("Hachure").tag(FillStyle.hachure)
                    }
                    Divider()
                    Button("Fine stroke") { style.strokeWidth = 1.5 }
                    Button("Medium stroke") { style.strokeWidth = 2.5 }
                    Button("Bold stroke") { style.strokeWidth = 4 }
                    Divider()
                    Button("Subtle roughness") { style.roughness = 0.6 }
                    Button("Sketchy roughness") { style.roughness = 1.2 }
                    Button("Loose roughness") { style.roughness = 2 }
                }
                Divider()
                Section("Selected elements") {
                    Button("Edit selected style…") { showingInspector = true }
                        .disabled(selectedStyle == nil)
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
            .accessibilityLabel("More canvas tools")

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
                CanvasStyleInspector(style: selectedStyleBinding)
            }
        }
    }

    private func colorSwatch(icon: String, help: String, color: Binding<Color>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 13)
                .accessibilityHidden(true)
            ZStack {
                ColorPicker("", selection: color, supportsOpacity: true)
                    .labelsHidden()
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.wrappedValue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                    )
                    .allowsHitTesting(false)
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .help(help)
    }

    private var fillColorBinding: Binding<Color> {
        Binding(
            get: { style.fill.swiftUIColor },
            set: { style.fill = RGBAColor($0) }
        )
    }

    private var selectedStyleBinding: Binding<ElementStyle> {
        Binding(
            get: { selectedStyle ?? style },
            set: { onApplySelectedStyle($0) }
        )
    }
}

private struct CanvasStyleInspector: View {
    @Binding var style: ElementStyle

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
