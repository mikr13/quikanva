import SwiftUI
import SwiftData
import AppKit

struct GalleryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CanvasDocument.updatedAt, order: .reverse) private var docs: [CanvasDocument]

    @State private var renaming: CanvasDocument?
    @State private var renameText = ""
    @State private var deleting: CanvasDocument?
    @State private var hasAppeared = false

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 20)]

    var body: some View {
        ScrollView {
            if docs.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Array(docs.enumerated()), id: \.element.id) { item in
                        GalleryCard(doc: item.element)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 8)
                            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.92)
                                .delay(Double(item.offset) * 0.035), value: hasAppeared)
                            .onTapGesture(count: 2) { open(item.element) }
                            .contextMenu {
                                Button("Open") { open(item.element) }
                                Button("Rename…") {
                                    renaming = item.element
                                    renameText = item.element.title
                                }
                                Divider()
                                Button("Delete", role: .destructive) { deleting = item.element }
                            }
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .background(.background)
        .navigationTitle("Quikanva")
        .onAppear { hasAppeared = true }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }

                Button(action: newCanvas) { Label("New Sketch", systemImage: "plus") }
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
        .confirmationDialog("Delete Sketch?", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let doc = deleting { delete(doc) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("This sketch will be permanently removed from Quikanva.")
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
        let doc = CanvasDocument(title: CanvasTitle.dated(), sceneData: SceneCodec.encode(CanvasScene()))
        context.insert(doc)
        try? context.save()
        open(doc)
    }

    private func open(_ doc: CanvasDocument) {
        CanvasWindowManager.shared.open(doc.id)
    }

    private func delete(_ doc: CanvasDocument) {
        CanvasWindowManager.shared.close(doc.id)
        context.delete(doc)
        try? context.save()
    }
}

private struct GalleryCard: View {
    let doc: CanvasDocument
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor))
                if let data = doc.thumbnail, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(6)
                } else {
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 150)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(isHovered ? 0.22 : 0.1)))

            Text(doc.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(doc.updatedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 1), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(doc.title)
        .accessibilityValue("Updated \(doc.updatedAt.formatted(.dateTime.month().day().hour().minute()))")
        .accessibilityHint("Double-click to open")
    }
}
