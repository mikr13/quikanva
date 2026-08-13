import SwiftUI
import SwiftData
import AppKit
import KeyboardShortcuts

@main
struct QuikanvaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @AppStorage(CanvasPreferences.alwaysOnTopKey) private var alwaysOnTop = false

    init() {
        do {
            let base = URL.applicationSupportDirectory.appending(path: "Quikanva", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            let config = ModelConfiguration(url: base.appending(path: "Quikanva.store"))
            container = try ModelContainer(for: CanvasDocument.self, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        CanvasWindowManager.shared.container = container
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image(nsImage: .quikanvaMenuBar)
                .accessibilityLabel("Quikanva")
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    CanvasWindowManager.shared.undo()
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    CanvasWindowManager.shared.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandMenu("Canvas") {
                Button("New Canvas") {
                    CanvasWindowManager.shared.newCanvas()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open Gallery") {
                    NSApp.activate(ignoringOtherApps: true)
                    CanvasWindowManager.shared.openGallery?()
                }
                .keyboardShortcut("g", modifiers: .command)

                Divider()

                Toggle("Keep Canvas Windows on Top", isOn: alwaysOnTopBinding)
                    .globalKeyboardShortcut(.toggleAlwaysOnTop)
            }
        }

        Window("Gallery", id: WindowID.gallery) {
            GalleryView()
        }
        .defaultSize(width: 900, height: 640)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
    }

    private var alwaysOnTopBinding: Binding<Bool> {
        Binding(
            get: { alwaysOnTop },
            set: { enabled in
                alwaysOnTop = enabled
                CanvasWindowManager.shared.updateAlwaysOnTop(enabled)
            }
        )
    }
}

enum WindowID {
    static let gallery = "gallery"
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("New Canvas") {
                CanvasWindowManager.shared.newCanvas()
            }
            .keyboardShortcut("n")

            Button("Open Gallery…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: WindowID.gallery)
            }
            .keyboardShortcut("g")

            Divider()

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            Button("Quit Quikanva") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            CanvasWindowManager.shared.openGallery = {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: WindowID.gallery)
            }
        }
    }
}

private extension NSImage {
    static var quikanvaMenuBar: NSImage {
        guard let base = NSImage(named: "QuikanvaMenuBar") else { return NSImage() }
        let image = (base.copy() as? NSImage) ?? base
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
