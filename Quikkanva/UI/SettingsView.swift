import SwiftUI
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

                Toggle("Discard empty canvases on close", isOn: $discardEmptyCanvases)
                Text("Background color changes do not count as canvas content.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Quick new canvas:", name: .newCanvas)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
