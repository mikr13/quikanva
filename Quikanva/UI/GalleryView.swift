import SwiftUI
import SwiftData
import AppKit

struct GalleryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CanvasDocument.updatedAt, order: .reverse) private var docs: [CanvasDocument]

    @State private var renaming: CanvasDocument?
    @State private var renameText = ""
    @State private var pendingDeletion = Set<UUID>()
    @State private var selectedIDs = Set<UUID>()
    @State private var isSelecting = false

    var body: some View {
        ScrollView {
            if docs.isEmpty {
                emptyState
            } else {
                GalleryGrid {
                    ForEach(docs) { doc in
                        GalleryCard(
                            doc: doc,
                            isSelecting: isSelecting,
                            isSelected: selectedIDs.contains(doc.id)
                        )
                            .onTapGesture {
                                guard isSelecting else { return }
                                toggleSelection(doc.id)
                            }
                            .onTapGesture(count: 2) {
                                guard !isSelecting else { return }
                                open(doc)
                            }
                            .contextMenu {
                                Button(isSelecting && selectedIDs.contains(doc.id) ? "Deselect" : "Select") {
                                    beginOrToggleSelection(doc.id)
                                }
                                Divider()
                                Button("Open") { open(doc) }
                                    .disabled(isSelecting)
                                Button("Rename…") {
                                    renaming = doc
                                    renameText = doc.title
                                }
                                .disabled(isSelecting)
                                Divider()
                                Button("Delete", role: .destructive) {
                                    pendingDeletion = [doc.id]
                                }
                                .disabled(isSelecting)
                            }
                    }
                }
                .padding(28)
                .accessibilityElement(children: .contain)
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .background(.background)
        .navigationTitle("Quikanva")
        .onChange(of: docs.map(\.id)) { _, ids in
            selectedIDs.formIntersection(ids)
            if selectedIDs.isEmpty, docs.isEmpty {
                isSelecting = false
            }
        }
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .primaryAction) {
                    GallerySelectionToolbar(
                        selectedCount: selectedIDs.count,
                        allSelected: allDocumentsSelected,
                        onToggleAll: toggleAllSelection,
                        onDelete: { pendingDeletion = selectedIDs },
                        onDone: finishSelection
                    )
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                    }

                    Button(action: newCanvas) {
                        Label("New Sketch", systemImage: "plus")
                    }
                }
            }
        }
        .alert("Rename Sketch", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let doc = renaming {
                    doc.title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    doc.updatedAt = .now
                    try? context.save()
                }
                renaming = nil
            }
            .keyboardShortcut(.defaultAction)
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { renaming = nil }
                .keyboardShortcut(.cancelAction)
        }
        .confirmationDialog(deletionTitle, isPresented: Binding(
            get: { !pendingDeletion.isEmpty },
            set: { if !$0 { pendingDeletion.removeAll() } }
        )) {
            Button("Delete", role: .destructive) {
                deleteDocuments(with: pendingDeletion)
            }
            Button("Cancel", role: .cancel) { pendingDeletion.removeAll() }
        } message: {
            Text(deletionMessage)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("No sketches yet")
                .font(.title3.weight(.medium))
            Text("Press ⌘N or the + button to start a new canvas.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func newCanvas() {
        let aspectRatio = CanvasPreferences.defaultAspectRatio
        let scene = CanvasScene(background: CanvasPreferences.defaultBackground)
        let doc = CanvasDocument(
            title: CanvasTitle.dated(),
            sceneData: SceneCodec.encode(scene),
            aspectRatio: aspectRatio,
            thumbnail: Thumbnailer.png(for: scene, aspectRatio: aspectRatio)
        )
        context.insert(doc)
        try? context.save()
        open(doc)
    }

    private func open(_ doc: CanvasDocument) {
        CanvasWindowManager.shared.open(doc.id)
    }

    private var deletionTitle: String {
        pendingDeletion.count == 1 ? "Delete Sketch?" : "Delete \(pendingDeletion.count) Sketches?"
    }

    private var deletionMessage: String {
        pendingDeletion.count == 1
            ? "This sketch will be permanently removed from Quikanva."
            : "These sketches will be permanently removed from Quikanva."
    }

    private var allDocumentsSelected: Bool {
        !docs.isEmpty && selectedIDs == Set(docs.map(\.id))
    }

    private func beginOrToggleSelection(_ id: UUID) {
        if isSelecting {
            toggleSelection(id)
        } else {
            isSelecting = true
            selectedIDs = [id]
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleAllSelection() {
        selectedIDs = GallerySelection.togglingAll(selectedIDs, within: docs.map(\.id))
    }

    private func finishSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    private func deleteDocuments(with ids: Set<UUID>) {
        for doc in docs where ids.contains(doc.id) {
            CanvasWindowManager.shared.close(doc.id)
            context.delete(doc)
        }
        try? context.save()
        pendingDeletion.removeAll()
        finishSelection()
    }

}

enum GallerySelection {
    static func togglingAll(_ selected: Set<UUID>, within ids: [UUID]) -> Set<UUID> {
        let all = Set(ids)
        return !all.isEmpty && selected == all ? [] : all
    }
}

struct GalleryGrid<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 252, maximum: 280), spacing: 28, alignment: .top)],
            alignment: .center,
            spacing: 28
        ) {
            content
        }
    }
}

private struct GallerySelectionToolbar: View {
    let selectedCount: Int
    let allSelected: Bool
    let onToggleAll: () -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(selectedCount) selected")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(selectedCount == 0 ? .secondary : .primary)
                .fixedSize()

            separator

            Button(action: onToggleAll) {
                Label(
                    allSelected ? "Deselect All" : "Select All",
                    systemImage: allSelected ? "circle" : "checkmark.circle"
                )
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(allSelected ? "Deselect All" : "Select All")

            Button(role: .destructive, action: onDelete) {
                Label("Delete Selected", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(selectedCount == 0)
            .help("Delete selected sketches")
            .accessibilityLabel("Delete selected sketches")

            separator

            Button("Done", action: onDone)
                .buttonStyle(.borderless)
                .fontWeight(.medium)
                .accessibilityLabel("Done selecting")
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var separator: some View {
        Color.primary.opacity(0.14)
            .frame(width: 1, height: 16)
    }
}

private struct GalleryCard: View {
    let doc: CanvasDocument
    let isSelecting: Bool
    let isSelected: Bool

    private let thumbnail: GalleryThumbnail

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    init(doc: CanvasDocument, isSelecting: Bool, isSelected: Bool) {
        self.doc = doc
        self.isSelecting = isSelecting
        self.isSelected = isSelected
        thumbnail = GalleryThumbnail(data: doc.thumbnail)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            stickyNote
                .frame(maxWidth: .infinity)
            Text(doc.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(doc.updatedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 240, alignment: .leading)
        .padding(6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(doc.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isSelecting ? "Click to toggle selection" : "Double-click to open")
    }

    private var stickyNote: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            thumbnail
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.55))
                .frame(width: 48, height: 10)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.05)))
                .offset(y: -5)
        }
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.7), Color.accentColor)
                    .padding(10)
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(selectionBorder, lineWidth: isSelected ? 3 : 1)
        }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 5))
        .shadow(
            color: .black.opacity(0.16),
            radius: 7,
            y: 4
        )
        .rotationEffect(.degrees(noteRotation))
        .scaleEffect(isHoverLifted ? 1.015 : 1)
        .animation(
            reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 1),
            value: isHoverLifted
        )
    }

    private var isHoverLifted: Bool {
        isHovered && !isSelecting && !reduceMotion
    }

    private var selectionBorder: Color {
        if isSelected { return .accentColor }
        return .primary.opacity(0.08)
    }

    private var previewSize: CGSize {
        doc.aspectRatio.galleryPreviewSize
    }

    private var noteRotation: Double {
        let bytes = doc.id.uuid
        return Double(Int(bytes.0 % 7) - 3) * 0.45
    }

    private var accessibilityValue: String {
        let updated = "Updated \(doc.updatedAt.formatted(.dateTime.month().day().hour().minute()))"
        guard isSelecting else { return updated }
        return "\(isSelected ? "Selected" : "Not selected"), \(updated)"
    }
}

struct GalleryThumbnail: View {
    private let image: NSImage?

    init(data: Data?, decoder: (Data) -> NSImage? = { NSImage(data: $0) }) {
        image = data.flatMap(decoder)
    }

    @ViewBuilder
    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "scribble.variable")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
        }
    }
}
