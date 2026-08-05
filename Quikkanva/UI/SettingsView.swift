import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Quick new canvas:", name: .newCanvas)
        }
        .padding(20)
        .frame(width: 380)
    }
}
