import SwiftUI

struct CanvasToolbar: View {
    @Binding var tool: ToolKind
    @Binding var style: ElementStyle
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

            colorSwatch(icon: "square.fill", help: "Canvas background", color: $background)

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

            Divider().frame(height: 22).padding(.horizontal, 2)

            Menu {
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
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(PressableStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Zoom")
            .accessibilityLabel("Zoom canvas")
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
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
