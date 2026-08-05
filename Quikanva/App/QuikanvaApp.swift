import SwiftUI
import SwiftData
import AppKit

@main
struct QuikanvaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

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
            MenuBarLabel()
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
}

enum WindowID {
    static let gallery = "gallery"
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
}

private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "scribble.variable")
            .onAppear {
                CanvasWindowManager.shared.openGallery = {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: WindowID.gallery)
                }
            }
        }
}
