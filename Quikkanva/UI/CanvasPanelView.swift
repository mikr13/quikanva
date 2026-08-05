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
    @State private var selectedImageShadow: Bool?
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
        _autosave = StateObject(wrappedValue: CanvasAutosaveCoordinator { scene in
            Self.persist(scene, doc: doc, context: context)
        })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CanvasRepresentable(scene: scene, tool: tool, style: style, command: canvasCommand) { updated in
                scene = updated
                autosave.schedule(updated)
            } onSelectionChange: { updated in
                selectedStyle = updated
            } onImageShadowChange: { updated in
                selectedImageShadow = updated
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
                        selectedImageShadow: $selectedImageShadow,
                        background: backgroundBinding,
                        includeExportBackground: $includeExportBackground,
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
                        onApplySelectedStyle: { updated in
                            canvasCommand = .updateSelectionStyle(updated)
                        },
                        onApplySelectedImageShadow: { enabled in
                            canvasCommand = .updateSelectedImageShadow(enabled)
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
            set: { newColor in
                scene.background = RGBAColor(newColor)
                autosave.schedule(scene)
            }
        )
    }

    private var closeButton: some View {
        Button {
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

    private static func persist(_ scene: CanvasScene,
                                title: String? = nil,
                                doc: CanvasDocument,
                                context: ModelContext,
                                onTitleChange: () -> Void = {}) {
        let encoded = SceneCodec.encode(scene)
        let sceneChanged = encoded != doc.sceneData
        let titleChanged = title.map { $0 != doc.title } ?? false
        guard sceneChanged || titleChanged else { return }

        if sceneChanged {
            doc.sceneData = encoded
            doc.thumbnail = Thumbnailer.png(for: scene)
        }
        if let title, titleChanged {
            doc.title = title
            onTitleChange()
        }
        doc.updatedAt = .now
        try? context.save()
    }
}
