import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @AppStorage(CanvasPreferences.defaultAspectRatioKey)
    private var defaultAspectRatio = CanvasAspectRatio.portrait.rawValue
    @AppStorage(CanvasPreferences.discardEmptyCanvasesKey)
    private var discardEmptyCanvases = true
    @AppStorage(CanvasPreferences.maxOpenCanvasPanelsKey)
    private var maxOpenCanvasPanels = 0
    @AppStorage(CanvasPreferences.autoTitleDateFormatKey)
    private var autoTitleDateFormat = CanvasTitleDateFormat.system.rawValue
    @AppStorage(CanvasPreferences.alwaysOnTopKey)
    private var alwaysOnTop = false
    @State private var defaultBackground = CanvasPreferences.defaultBackground.swiftUIColor
    @State private var defaultStyle = CanvasPreferences.defaultStyle
    @State private var toolShortcuts = CanvasPreferences.toolShortcuts
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                discardEmptyCanvases: $discardEmptyCanvases,
                maxOpenCanvasPanels: $maxOpenCanvasPanels,
                autoTitleDateFormat: $autoTitleDateFormat,
                alwaysOnTop: $alwaysOnTop
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag(SettingsTab.general)
            .accessibilityLabel("General settings")

            CanvasSettingsView(
                defaultAspectRatio: $defaultAspectRatio,
                defaultBackground: $defaultBackground,
                defaultStyle: $defaultStyle,
                toolShortcuts: $toolShortcuts
            )
            .tabItem {
                Label("Canvas", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
            .tag(SettingsTab.canvas)
            .accessibilityLabel("Canvas settings")
        }
        .frame(width: 620, height: 500)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                bringSettingsToFront()
            }
        }
    }

    private func bringSettingsToFront() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "Quikanva Settings" }?.makeKeyAndOrderFront(nil)
    }
}

private enum SettingsTab: Hashable {
    case general
    case canvas
}

private struct GeneralSettingsView: View {
    @Binding var discardEmptyCanvases: Bool
    @Binding var maxOpenCanvasPanels: Int
    @Binding var autoTitleDateFormat: String
    @Binding var alwaysOnTop: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Discard empty canvases on close", isOn: $discardEmptyCanvases)
                    .accessibilityHint("Automatically discards canvases with no content when they close.")

                Toggle("Keep canvas windows on top", isOn: $alwaysOnTop)
                    .accessibilityHint("Keeps canvas windows visible above other apps for presentations and laser mode.")

                Picker("Maximum open canvases", selection: $maxOpenCanvasPanels) {
                    Text("Unlimited").tag(0)
                    ForEach(1 ... 4, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            } header: {
                Text("Behavior")
            } footer: {
                Text("Unlimited allows any number of canvas windows to remain open.")
            }

            Section {
                Picker("Auto-title date format", selection: $autoTitleDateFormat) {
                    ForEach(CanvasTitleDateFormat.allCases) { format in
                        Text(format.label).tag(format.rawValue)
                    }
                }
                .accessibilityHint("Choose how creation dates appear in new sketch names.")
            } header: {
                Text("Naming")
            } footer: {
                Text("Example: \(selectedDateFormat.string(from: .now))")
            }

            Section {
                KeyboardShortcuts.Recorder("Quick new canvas:", name: .newCanvas)
                    .accessibilityLabel("Quick new canvas keyboard shortcut")

                KeyboardShortcuts.Recorder("Toggle canvases on top:", name: .toggleAlwaysOnTop)
                    .accessibilityLabel("Toggle canvas windows on top keyboard shortcut")
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("Use these shortcuts from anywhere while Quikanva is running.")
            }
        }
        .formStyle(.grouped)
        .settingsContentInsets()
        .onChange(of: alwaysOnTop, initial: true) { _, enabled in
            CanvasWindowManager.shared.updateAlwaysOnTop(enabled)
        }
    }

    private var selectedDateFormat: CanvasTitleDateFormat {
        CanvasTitleDateFormat(rawValue: autoTitleDateFormat) ?? .system
    }
}

private struct CanvasSettingsView: View {
    @Binding var defaultAspectRatio: String
    @Binding var defaultBackground: Color
    @Binding var defaultStyle: ElementStyle
    @Binding var toolShortcuts: ToolShortcutConfiguration

    var body: some View {
        Form {
            Section {
                Picker("Default aspect ratio", selection: $defaultAspectRatio) {
                    ForEach(CanvasAspectRatio.allCases) { ratio in
                        Text(ratio.label).tag(ratio.rawValue)
                    }
                }
                .accessibilityLabel("Default canvas aspect ratio")

                ColorPicker("Default canvas background", selection: $defaultBackground, supportsOpacity: false)
            } header: {
                Text("Canvas")
            } footer: {
                Text("Background color changes do not count as canvas content.")
            }

            Section {
                ForEach(ToolKind.allCases) { tool in
                    Picker(tool.rawValue.capitalized, selection: shortcutBinding(for: tool)) {
                        ForEach(ToolShortcutConfiguration.availableKeys, id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .accessibilityLabel("\(tool.rawValue.capitalized) tool shortcut")
                }

                Button("Restore Default Tool Shortcuts") {
                    toolShortcuts = .defaultValue
                }
                .disabled(toolShortcuts == .defaultValue)
            } header: {
                Text("Tool Shortcuts")
            } footer: {
                Text("These single-letter shortcuts work while a canvas is focused. Choosing an assigned key swaps the two tools.")
            }

            Section {
                ColorPicker("Default stroke", selection: strokeBinding, supportsOpacity: true)
                ColorPicker("Default fill", selection: fillBinding, supportsOpacity: true)

                Picker("Default fill style", selection: fillStyleBinding) {
                    Text("No fill").tag(FillStyle.none)
                    Text("Solid").tag(FillStyle.solid)
                    Text("Hachure").tag(FillStyle.hachure)
                }

                Picker("Default drawing style", selection: $defaultStyle.drawingStyle) {
                    ForEach(DrawingStyle.allCases) { drawingStyle in
                        Text(drawingStyle.label).tag(drawingStyle)
                    }
                }

                if defaultStyle.drawingStyle == .handDrawn {
                    Slider(value: $defaultStyle.roughness, in: 0 ... 2.5, step: 0.1) {
                        Text("Default roughness")
                    } minimumValueLabel: {
                        Text("Clean")
                    } maximumValueLabel: {
                        Text("Loose")
                    }
                }

                Picker("Default stroke style", selection: $defaultStyle.strokeStyle) {
                    ForEach(StrokeStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }

                Picker("Default arrowhead", selection: $defaultStyle.arrowheadStyle) {
                    ForEach(ArrowheadStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }

                Picker("Default arrow ends", selection: $defaultStyle.arrowheadPlacement) {
                    ForEach(ArrowheadPlacement.allCases) { placement in
                        Text(placement.label).tag(placement)
                    }
                }
            } header: {
                Text("Drawing")
            }

            Section {
                Picker("Default font", selection: $defaultStyle.fontFamily) {
                    ForEach(["Helvetica Neue", "Avenir Next", "Comic Sans MS", "Georgia", "Menlo"], id: \.self) { family in
                        Text(family).tag(family)
                    }
                }

                Picker("Default font weight", selection: $defaultStyle.fontWeight) {
                    ForEach(FontWeight.allCases) { weight in
                        Text(weight.label).tag(weight)
                    }
                }

                Picker("Default text size", selection: $defaultStyle.fontSize) {
                    ForEach([14.0, 18.0, 20.0, 24.0, 32.0], id: \.self) { size in
                        Text("\(Int(size)) pt").tag(size)
                    }
                }
            } header: {
                Text("Text")
            }
        }
        .formStyle(.grouped)
        .settingsContentInsets()
        .onChange(of: defaultBackground) { _, value in
            CanvasPreferences.defaultBackground = RGBAColor(value)
        }
        .onChange(of: defaultStyle) { _, value in
            CanvasPreferences.defaultStyle = value
        }
        .onChange(of: toolShortcuts) { _, value in
            CanvasPreferences.toolShortcuts = value
        }
    }

    private var strokeBinding: Binding<Color> {
        Binding(
            get: { defaultStyle.stroke.swiftUIColor },
            set: { defaultStyle.stroke = RGBAColor($0) }
        )
    }

    private var fillBinding: Binding<Color> {
        Binding(
            get: { defaultStyle.fill.swiftUIColor },
            set: { defaultStyle.fill = RGBAColor($0) }
        )
    }

    private var fillStyleBinding: Binding<FillStyle> {
        Binding(
            get: { defaultStyle.fillStyle },
            set: { defaultStyle.setFillStyle($0) }
        )
    }

    private func shortcutBinding(for tool: ToolKind) -> Binding<String> {
        Binding(
            get: { toolShortcuts.shortcut(for: tool) },
            set: { toolShortcuts.assign($0, to: tool) }
        )
    }
}

private extension View {
    func settingsContentInsets() -> some View {
        padding(20)
            .padding(.top, 8)
    }
}
