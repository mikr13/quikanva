import AppKit

final class CanvasTextLayer: NSView {
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

final class CanvasTextView: NSTextView {
    var onCommit: (() -> Void)?
    var onTextChange: (() -> Void)?
    var onResign: (() -> Void)?

    private let backingStorage: NSTextStorage
    private let editingUndoManager = UndoManager()

    init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()
        TextLayout.configure(container, width: TextLayout.legacyWidth)
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        backingStorage = storage
        super.init(frame: .zero, textContainer: container)
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        isHorizontallyResizable = false
        isVerticallyResizable = false
        textContainerInset = .zero
        focusRingType = .none
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        setAccessibilityLabel("Canvas text")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var undoManager: UndoManager? { editingUndoManager }

    override func didChangeText() {
        super.didChangeText()
        onTextChange?()
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onResign?() }
        return resigned
    }

    override func cancelOperation(_ sender: Any?) {
        onCommit?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76, event.modifierFlags.contains(.command) {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard window?.firstResponder === self,
              modifiers == .command,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        let shift = event.modifierFlags.contains(.shift)
        switch key {
        case "x" where !shift: cut(nil)
        case "c" where !shift: copy(nil)
        case "v" where !shift: paste(nil)
        case "a" where !shift: selectAll(nil)
        case "z":
            if shift {
                if editingUndoManager.canRedo { editingUndoManager.redo() }
            } else if editingUndoManager.canUndo {
                editingUndoManager.undo()
            }
        default:
            return super.performKeyEquivalent(with: event)
        }
        return true
    }
}
