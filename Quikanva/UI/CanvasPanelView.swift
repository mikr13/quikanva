import SwiftUI
import SwiftData
import AppKit

@MainActor
final class CanvasAutosaveCoordinator: ObservableObject {
    private let save: (CanvasScene) throws -> String
    private var pendingScene: CanvasScene?
    private var task: Task<Void, Never>?
    private(set) var savedRevision: String?
    @Published var errorMessage: String?
    var hasPendingChanges: Bool { pendingScene != nil }
    func shouldReload(revision: String) -> Bool {
        !hasPendingChanges && revision != savedRevision
    }

    init(save: @escaping (CanvasScene) throws -> String) {
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
        do {
            savedRevision = try save(pendingScene)
            self.pendingScene = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
    let onAutosaveReady: (@escaping () -> Bool) -> Void

    @State private var scene: CanvasScene
    @State private var reloadToken = UUID()
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
        onTitleChange: @escaping () -> Void = {},
        onAutosaveReady: @escaping (@escaping () -> Bool) -> Void = { _ in }
    ) throws {
        self.doc = doc
        self.context = context
        self.onClose = onClose
        self.onTitleChange = onTitleChange
        self.onAutosaveReady = onAutosaveReady
        _scene = State(initialValue: try CanvasStorage.load(doc, in: context))
        _style = State(initialValue: CanvasPreferences.defaultStyle)
        _autosave = StateObject(wrappedValue: CanvasAutosaveCoordinator { scene in
            try Self.persist(scene, doc: doc, context: context)
            return doc.revision
        })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CanvasRepresentable(
                scene: scene,
                reloadToken: reloadToken,
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
        .onAppear { onAutosaveReady { autosave.flush(); return !autosave.hasPendingChanges } }
        .onChange(of: doc.sceneData) { _, _ in
            guard !doc.isTombstone, autosave.shouldReload(revision: doc.revision),
                  let remote = try? CanvasStorage.load(doc, in: context) else { return }
            scene = remote
            reloadToken = UUID()
        }
        .onChange(of: doc.title) { _, _ in onTitleChange() }
        .onChange(of: doc.isTombstone) { _, deleted in
            if deleted { onClose() }
        }
        .alert("Could Not Save Sketch", isPresented: Binding(
            get: { autosave.errorMessage != nil },
            set: { if !$0 { autosave.errorMessage = nil } }
        )) {
            Button("Retry") { autosave.flush() }
            Button("OK", role: .cancel) { autosave.errorMessage = nil }
        } message: {
            Text(autosave.errorMessage ?? "")
        }
        .alert("Save Sketch", isPresented: $showNamePrompt) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                autosave.flush()
                do { try Self.persist(scene, title: name.isEmpty ? nil : name, doc: doc, context: context, onTitleChange: onTitleChange) }
                catch { autosave.errorMessage = error.localizedDescription }
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
            guard !autosave.hasPendingChanges else { return }
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

    static func persist(_ scene: CanvasScene,
                        title: String? = nil,
                        doc: CanvasDocument,
                        context: ModelContext,
                        onTitleChange: () -> Void = {}) throws {
        guard !doc.isTombstone else { return }
        let encoded = try CanvasStorage.encode(scene, in: context)
        let sceneChanged = encoded != doc.sceneData
        let titleChanged = title.map { $0 != doc.title } ?? false
        guard sceneChanged || titleChanged else {
            if context.hasChanges { try context.save() }
            return
        }

        let stored = try JSONDecoder().decode(CanvasScene.self, from: doc.sceneData)
        let updated = try JSONDecoder().decode(CanvasScene.self, from: encoded)
        let contentChanged = stored.elements != updated.elements || stored.background != updated.background
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
        doc.markChanged()
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
