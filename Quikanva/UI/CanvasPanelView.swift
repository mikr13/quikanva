import SwiftUI
import SwiftData
import AppKit

@MainActor
private final class CanvasAutosaveCoordinator: ObservableObject {
    private let save: (CanvasScene) -> Void
    private var pendingScene: CanvasScene?
    private var task: Task<Void, Never>?

    init(save: @escaping (CanvasScene) -> Void) {
        self.save = save
    }

    func schedule(_ scene: CanvasScene) {
        pendingScene = scene
        task?.cancel()
        task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        task?.cancel()
        task = nil
        guard let pendingScene else { return }
        self.pendingScene = nil
        save(pendingScene)
    }

    deinit {
        task?.cancel()
    }
}

struct CanvasPanelView: View {
    let doc: CanvasDocument
    let context: ModelContext
    let onClose: () -> Void
    let onTitleChange: () -> Void

    @State private var scene: CanvasScene
    @State private var tool: ToolKind = .freedraw
    @State private var style = ElementStyle()
    @State private var showNamePrompt = false
    @State private var draftName = ""
    @State private var canvasCommand: CanvasCommand?
    @State private var includeExportBackground = true
    @State private var selectedStyle: ElementStyle?
    @State private var hasSelection = false
    @State private var selectedImageShadow: Bool?
    @State private var selectedCurve: Double?
    @AppStorage(CanvasPreferences.toolShortcutsKey) private var toolShortcutsData = Data()
    @AppStorage(CanvasPreferences.defaultStyleKey) private var defaultStyleData = Data()
    @StateObject private var autosave: CanvasAutosaveCoordinator
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(
        doc: CanvasDocument,
        context: ModelContext,
        onClose: @escaping () -> Void = {},
        onTitleChange: @escaping () -> Void = {}
    ) {
        self.doc = doc
        self.context = context
        self.onClose = onClose
        self.onTitleChange = onTitleChange
        _scene = State(initialValue: SceneCodec.decode(doc.sceneData))
        _style = State(initialValue: CanvasPreferences.defaultStyle)
        _autosave = StateObject(wrappedValue: CanvasAutosaveCoordinator { scene in
            Self.persist(scene, doc: doc, context: context)
        })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CanvasRepresentable(
                scene: scene,
                tool: tool,
                style: style,
                toolShortcuts: toolShortcuts,
                command: canvasCommand
            ) { updated in
                scene = updated
                autosave.schedule(updated)
            } onToolChange: { updated in
                tool = updated
            } onSelectionChange: { updated, isSelected in
                selectedStyle = updated
                hasSelection = isSelected
            } onImageShadowChange: { updated in
                selectedImageShadow = updated
            } onCurveChange: { updated in
                selectedCurve = updated
            } onCommandHandled: {
                canvasCommand = nil
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                .padding(16)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            GeometryReader { proxy in
                HStack {
                    Spacer(minLength: 0)
                    CanvasToolbar(
                        tool: $tool,
                        style: $style,
                        selectedStyle: $selectedStyle,
                        hasSelection: hasSelection,
                        selectedImageShadow: $selectedImageShadow,
                        selectedCurve: $selectedCurve,
                        background: backgroundBinding,
                        includeExportBackground: $includeExportBackground,
                        toolShortcuts: toolShortcuts,
                        onSave: {
                            draftName = doc.title
                            showNamePrompt = true
                        },
                        onCopyImage: { Exporter.copyToClipboard(scene, background: includeExportBackground) },
                        onExportPNG: { Exporter.exportWithPanel(scene, format: .png, suggestedName: doc.title, background: includeExportBackground) },
                        onExportJPEG: { Exporter.exportWithPanel(scene, format: .jpeg, suggestedName: doc.title, background: includeExportBackground) },
                        onZoomIn: { canvasCommand = .zoomIn },
                        onZoomOut: { canvasCommand = .zoomOut },
                        onZoomToFit: { canvasCommand = .zoomToFit },
                        onZoomToSelection: { canvasCommand = .zoomToSelection },
                        onResetZoom: { canvasCommand = .resetZoom },
                        onApplySelectedStyle: { edit in
                            canvasCommand = .updateSelectionStyle(edit)
                        },
                        onApplySelectedImageShadow: { enabled in
                            canvasCommand = .updateSelectedImageShadow(enabled)
                        },
                        onApplySelectedCurve: { curve in
                            canvasCommand = .updateSelectedCurve(curve)
                        },
                        onTogglePointEditing: {
                            canvasCommand = .togglePointEditing
                        },
                        onBringSelectionToFront: {
                            canvasCommand = .bringSelectionToFront
                        },
                        onSendSelectionToBack: {
                            canvasCommand = .sendSelectionToBack
                        },
                        availableWidth: max(0, proxy.size.width - 32)
                    )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 360, minHeight: 640)
        .ignoresSafeArea()
        .onChange(of: style) { old, updated in
            CanvasPreferences.defaultStyle = CanvasPreferences.defaultStyle.merging(changesFrom: old, to: updated)
        }
        .onChange(of: defaultStyleData) { old, updated in
            style = style.merging(changesFrom: CanvasPreferences.decodedStyle(old),
                                  to: CanvasPreferences.decodedStyle(updated))
        }
        .onDisappear { autosave.flush() }
        .alert("Save Sketch", isPresented: $showNamePrompt) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                persist(scene, title: name.isEmpty ? nil : name)
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text("Give this sketch a name.")
        }
    }

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { scene.background?.swiftUIColor ?? RGBAColor.beige.swiftUIColor },
            set: { canvasCommand = .setBackground(RGBAColor($0)) }
        )
    }

    private var toolShortcuts: ToolShortcutConfiguration {
        CanvasPreferences.toolShortcuts(from: toolShortcutsData)
    }

    private var closeButton: some View {
        Button {
            // Commit inline text editing before the flush.
            NSApp.keyWindow?.makeFirstResponder(nil)
            autosave.flush()
            onClose()
        } label: {
            Label("Close canvas", systemImage: "xmark")
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
                : AnyShapeStyle(.regularMaterial),
            in: Circle()
        )
        .overlay(Circle().strokeBorder(Color.primary.opacity(contrast == .increased ? 0.3 : 0.14)))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        .keyboardShortcut(.cancelAction)
        .help("Close canvas")
        .accessibilityLabel("Close canvas")
    }

    private func persist(_ scene: CanvasScene, title: String? = nil) {
        Self.persist(scene, title: title, doc: doc, context: context, onTitleChange: onTitleChange)
    }

    static func persist(_ scene: CanvasScene,
                        title: String? = nil,
                        doc: CanvasDocument,
                        context: ModelContext,
                        onTitleChange: () -> Void = {}) {
        let encoded = SceneCodec.encode(scene)
        let sceneChanged = encoded != doc.sceneData
        let titleChanged = title.map { $0 != doc.title } ?? false
        guard sceneChanged || titleChanged else { return }

        let stored = SceneCodec.decode(doc.sceneData)
        let contentChanged = stored.elements != scene.elements || stored.background != scene.background
        if sceneChanged {
            doc.sceneData = encoded
        }
        if contentChanged {
            doc.thumbnail = Thumbnailer.png(for: scene, aspectRatio: doc.aspectRatio)
        }
        if let title, titleChanged {
            doc.title = title
            onTitleChange()
        }
        if contentChanged || titleChanged {
            doc.updatedAt = .now
        }
        try? context.save()
    }
}
