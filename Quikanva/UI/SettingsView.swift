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
    @State private var defaultBackground = CanvasPreferences.defaultBackground.swiftUIColor
    @State private var defaultStyle = CanvasPreferences.defaultStyle
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                defaultAspectRatio: $defaultAspectRatio,
                discardEmptyCanvases: $discardEmptyCanvases,
                maxOpenCanvasPanels: $maxOpenCanvasPanels,
                defaultBackground: $defaultBackground,
                defaultStyle: $defaultStyle
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag(SettingsTab.general)
            .accessibilityLabel("General settings")

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(SettingsTab.shortcuts)
                .accessibilityLabel("Keyboard shortcuts settings")
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
    case shortcuts
}

private struct GeneralSettingsView: View {
    @Binding var defaultAspectRatio: String
    @Binding var discardEmptyCanvases: Bool
    @Binding var maxOpenCanvasPanels: Int
    @Binding var defaultBackground: Color
    @Binding var defaultStyle: ElementStyle

    var body: some View {
        Form {
            Section {
                Picker("Default aspect ratio", selection: $defaultAspectRatio) {
                    ForEach(CanvasAspectRatio.allCases) { ratio in
                        Text(ratio.label).tag(ratio.rawValue)
                    }
                }
                .accessibilityLabel("Default canvas aspect ratio")

                Toggle("Discard empty canvases on close", isOn: $discardEmptyCanvases)
                    .accessibilityHint("Automatically discards canvases with no content when they close.")

                Picker("Maximum open canvases", selection: $maxOpenCanvasPanels) {
                    Text("Unlimited").tag(0)
                    ForEach(1 ... 4, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }

                ColorPicker("Default canvas background", selection: $defaultBackground, supportsOpacity: false)
                ColorPicker("Default stroke", selection: strokeBinding, supportsOpacity: true)
                ColorPicker("Default fill", selection: fillBinding, supportsOpacity: true)

                Picker("Default fill style", selection: $defaultStyle.fillStyle) {
                    Text("No fill").tag(FillStyle.none)
                    Text("Solid").tag(FillStyle.solid)
                    Text("Hachure").tag(FillStyle.hachure)
                }

                Slider(value: $defaultStyle.roughness, in: 0 ... 2.5, step: 0.1) {
                    Text("Default roughness")
                } minimumValueLabel: {
                    Text("Clean")
                } maximumValueLabel: {
                    Text("Loose")
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
                Text("Canvas")
            } footer: {
                Text("Background color changes do not count as canvas content. Unlimited allows any number of canvas panels.")
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
}

private struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Quick new canvas:", name: .newCanvas)
                    .accessibilityLabel("Quick new canvas keyboard shortcut")
            } header: {
                Text("Canvas")
            } footer: {
                Text("Choose the shortcut used to create a new canvas from anywhere in Quikanva.")
            }
        }
        .formStyle(.grouped)
        .settingsContentInsets()
    }
}

private extension View {
    func settingsContentInsets() -> some View {
        padding(20)
            .padding(.top, 8)
    }
}
