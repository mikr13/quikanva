import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        CanvasWindowManager.shared.prewarm()
        KeyboardShortcuts.onKeyUp(for: .newCanvas) {
            CanvasWindowManager.shared.newCanvas()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            CanvasWindowManager.shared.route(url)
        }
    }
}
