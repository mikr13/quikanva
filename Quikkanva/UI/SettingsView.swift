import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @AppStorage(CanvasPreferences.defaultAspectRatioKey)
    private var defaultAspectRatio = CanvasAspectRatio.portrait.rawValue
    @AppStorage(CanvasPreferences.discardEmptyCanvasesKey)
    private var discardEmptyCanvases = true

    var body: some View {
        Form {
            Section("Canvas") {
                Picker("Default aspect ratio", selection: $defaultAspectRatio) {
                    ForEach(CanvasAspectRatio.allCases) { ratio in
                        Text(ratio.label).tag(ratio.rawValue)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Discard empty canvases on close", isOn: $discardEmptyCanvases)
                    Text("Background color changes do not count as canvas content.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Quick new canvas:", name: .newCanvas)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                bringSettingsToFront()
            }
        }
    }

    private func bringSettingsToFront() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "Quikkanva Settings" }?.makeKeyAndOrderFront(nil)
    }
}
