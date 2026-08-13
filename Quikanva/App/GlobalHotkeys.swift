import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let newCanvas = Self("newCanvas", initial: .init(.k, modifiers: [.command, .shift]))
    static let toggleAlwaysOnTop = Self("toggleAlwaysOnTop", initial: .init(.t, modifiers: [.control, .option]))
}
