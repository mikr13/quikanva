# User Guide

Quikanva lives in the menu bar. Press **⌘⇧K** anywhere for a new canvas, or use the menu for Gallery, Settings, updates, and Quit. New canvases start with Freehand selected.

## Draw and edit

Choose a toolbar tool or use its [shortcut](SHORTCUTS.md). Scroll or use Hand to pan; pinch or use View commands to zoom. Paste/drop images, or paste text to create notes.

Use Select (**V**) to click or marquee-select elements; Shift-click adds/removes selections. Drag to move, use handles to resize/rotate, and hold Shift while resizing to preserve proportions. Arrow keys nudge; Shift-arrow moves 10 points. Option-drag bypasses snapping.

Select a line/arrow and press **⌘Return** to edit endpoints and its midpoint. Duplicate, reorder, copy/paste, delete, and undo/redo follow the active canvas.

## Text and style

Double-click empty canvas or use Text to add a note; drag with Text to set its wrapping width. Double-click a note or select it and press Return to edit. Return adds a line; Escape, ⌘Return, or clicking the canvas finishes editing. Side handles rewrap text; corner handles scale it.

The ellipsis menu changes colors, drawing/fill style, strokes, arrowheads, typography, image shadows, and line curves. It applies to selected elements or new ones. Save defaults in **Settings → Canvas**.

## Save and export

Changes autosave. Press **⌘S** to name a sketch. In the Gallery, double-click to open or right-click to rename, export, select, or delete. Selection mode supports batch deletion, which is permanent after confirmation.

The share menu copies an image or exports PNG/JPEG at 2× scale, cropped to content. Omit the background for transparent PNGs.

## Sync across Macs

1. Sign in to the same Apple Account in System Settings on each Mac.
2. Open Quikanva's **Settings → iCloud** and enable **Sync sketches with iCloud** on each Mac.
3. Create a test sketch with an image, then check that it appears in the other Mac's Gallery. Transfers run in the background and may take time.

Sync requires a Quikanva build signed with iCloud support. Concurrent edits use the latest whole-canvas save; individual elements are not merged. Turning sync off or signing out keeps your local sketches. After switching accounts, enable sync again only when you want to upload the local library to that account.

## Settings and updates

**Canvas** sets aspect ratio, styles, and tool keys. **General** controls launch at login, canvas limits, naming dates, global shortcuts, always-on-top windows, and updates.

Choose **Check for Updates…** from the menu bar. Configure automatic checks and downloads in **Settings → General → Updates**; automatic installation happens when Quikanva quits. A pending scheduled update appears in the menu until you inspect it.

## Automation and data

```sh
open 'quikanva://new'
open 'quikanva://gallery'
open 'quikanva://open?id=<UUID>'
```

[Raycast commands](../integrations/raycast/README.md) use these local routes. Sketches stay in `~/Library/Application Support/Quikanva/`; see [Privacy](PRIVACY.md) and [Troubleshooting](TROUBLESHOOTING.md).
