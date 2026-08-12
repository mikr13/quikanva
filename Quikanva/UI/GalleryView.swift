import SwiftUI
import SwiftData
import AppKit

struct GalleryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CanvasDocument.updatedAt, order: .reverse) private var docs: [CanvasDocument]

    @State private var renaming: CanvasDocument?
    @State private var renameText = ""
    @State private var pendingDeletion = Set<UUID>()
    @State private var selectedIDs = Set<UUID>()
    @State private var isSelecting = false
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            if docs.isEmpty {
                emptyState
            } else {
                MasonryLayout(minimumColumnWidth: 210, spacing: 28) {
                    ForEach(docs) { doc in
                        GalleryCard(
                            doc: doc,
                            isSelecting: isSelecting,
                            isSelected: selectedIDs.contains(doc.id)
                        )
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 8)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.92),
                                value: hasAppeared
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
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .background(.background)
        .navigationTitle("Quikanva")
        .onAppear {
            hasAppeared = true
            migrateLegacyPreviews()
        }
        .onChange(of: docs.map(\.id)) { _, ids in
            selectedIDs.formIntersection(ids)
            if selectedIDs.isEmpty, docs.isEmpty {
                isSelecting = false
            }
        }
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .automatic) {
                    Label("\(selectedIDs.count) selected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(selectedIDs.isEmpty ? .secondary : .primary)
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Select All", systemImage: "checkmark.circle") {
                        selectedIDs = Set(docs.map(\.id))
                    }
                    .disabled(selectedIDs.count == docs.count)

                    Button("Delete Selected", systemImage: "trash", role: .destructive) {
                        pendingDeletion = selectedIDs
                    }
                    .disabled(selectedIDs.isEmpty)

                    Button("Done", action: finishSelection)
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

    private func migrateLegacyPreviews() {
        let legacyDocuments = docs.filter { $0.aspectRatioRawValue == nil }
        guard !legacyDocuments.isEmpty else { return }
        for doc in legacyDocuments {
            doc.aspectRatio = .portrait
            doc.thumbnail = Thumbnailer.png(
                for: SceneCodec.decode(doc.sceneData),
                aspectRatio: doc.aspectRatio
            )
        }
        try? context.save()
    }
}

private struct GalleryCard: View {
    let doc: CanvasDocument
    let isSelecting: Bool
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            stickyNote
            Text(doc.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(doc.updatedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 1), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(doc.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isSelecting ? "Click to toggle selection" : "Double-click to open")
    }

    private var stickyNote: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)

            if let data = doc.thumbnail, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "scribble.variable")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(doc.aspectRatio.widthToHeight, contentMode: .fit)
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
            color: .black.opacity(isHovered ? 0.24 : 0.16),
            radius: isHovered ? 12 : 7,
            y: isHovered ? 7 : 4
        )
        .rotationEffect(.degrees(isHovered ? 0 : noteRotation))
        .scaleEffect(isHovered ? 1.015 : 1)
    }

    private var selectionBorder: Color {
        if isSelected { return .accentColor }
        return .primary.opacity(isHovered ? 0.2 : 0.08)
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

private struct MasonryLayout: Layout {
    let minimumColumnWidth: CGFloat
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? minimumColumnWidth
        return layout(width: width, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        guard !subviews.isEmpty else { return (.zero, []) }
        let columnCount = max(1, Int((width + spacing) / (minimumColumnWidth + spacing)))
        let columnWidth = (width - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        var columnHeights = [CGFloat](repeating: 0, count: columnCount)
        var frames = [CGRect]()
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let frame = CGRect(
                x: CGFloat(column) * (columnWidth + spacing),
                y: columnHeights[column],
                width: columnWidth,
                height: size.height
            )
            frames.append(frame)
            columnHeights[column] += size.height + spacing
        }

        let height = max(0, (columnHeights.max() ?? 0) - spacing)
        return (CGSize(width: width, height: height), frames)
    }
}
