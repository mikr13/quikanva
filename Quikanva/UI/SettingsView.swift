import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @AppStorage(CanvasPreferences.defaultAspectRatioKey)
    private var defaultAspectRatio = CanvasAspectRatio.portrait.rawValue
    @AppStorage(CanvasPreferences.discardEmptyCanvasesKey)
    private var discardEmptyCanvases = true
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                defaultAspectRatio: $defaultAspectRatio,
                discardEmptyCanvases: $discardEmptyCanvases
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
        .frame(width: 520, height: 260)
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
            } header: {
                Text("Canvas")
            } footer: {
                Text("Background color changes do not count as canvas content.")
            }
        }
        .formStyle(.grouped)
        .settingsContentInsets()
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
