# Quikanva user guide

Quikanva is a native Mac canvas for capturing and explaining an idea quickly. It is designed for architecture sketches, product flows, meeting notes, annotations, and diagrams that need shapes and relationships without a full whiteboard setup.

## Open Quikanva

Quikanva is a menu-bar accessory app, so it does not show a Dock icon.

- Press <kbd>⌘</kbd><kbd>⇧</kbd><kbd>K</kbd> anywhere to create a sketch.
- Use the menu-bar icon for **New Canvas**, **Open Gallery**, **Settings**, or **Quit**.
- While Quikanva is active, press <kbd>⌘</kbd><kbd>N</kbd> for a new canvas or <kbd>⌘</kbd><kbd>G</kbd> for the Gallery.
- Use the included Raycast commands or a `quikanva://` route for automation.

## Build a useful diagram

Start with structure, then annotate:

1. Use an ellipse for a starting state or concept.
2. Use rectangles for steps, systems, or outputs.
3. Use diamonds for decisions.
4. Connect the structure with arrows and lines.
5. Add text labels after the geometry is in place.
6. Use freehand ink for emphasis, a quick correction, or a note that should feel informal.

The examples below were made with that sequence:

![A product launch workflow made in Quikanva, shown in a macOS window](assets/product/macos-product-launch-flow.png)

![A native app architecture map made in Quikanva, shown in a macOS window](assets/product/macos-native-app-architecture.png)

## Draw and navigate

Select a tool from the floating toolbar or press its single-letter shortcut. New canvases begin with Freehand selected.

- Scroll or use the Hand tool to pan.
- Pinch to zoom, or use the zoom commands in the ellipsis menu.
- Paste or drag an image onto the canvas to add it as an editable element.
- Click the canvas background and start typing with the Text tool to add a label.

See [Shortcut Reference](SHORTCUTS.md) for every default key.

## Select and edit

Switch to Select with <kbd>V</kbd>.

- Click an element to select it.
- Shift-click or drag a marquee to select more than one.
- Drag the selection to move it.
- Use the eight handles to resize and the rotation handle to rotate.
- Use arrow keys for precise movement; add Shift for 10-point steps.
- Press <kbd>⌘</kbd><kbd>D</kbd> to duplicate.
- Press <kbd>⌘</kbd><kbd>[</kbd> or <kbd>⌘</kbd><kbd>]</kbd> to change stacking order.
- Select a line or arrow and press <kbd>⌘</kbd><kbd>Return</kbd> to edit its endpoints and midpoint.

Quikanva records canvas mutations in the native undo manager. <kbd>⌘</kbd><kbd>Z</kbd> and <kbd>⌘</kbd><kbd>⇧</kbd><kbd>Z</kbd> follow the active canvas.

## Style a diagram

Use the ellipsis menu to set the style for new elements or the current selection:

- Stroke, fill, and canvas background colors
- Hand-drawn or precise rendering
- Solid or hachure fill
- Solid, dashed, or dotted strokes
- Stroke width, opacity, and roughness
- Arrowhead style and placement
- Font family, weight, size, alignment, and decoration
- Optional shadow for image elements
- Curve amount for a selected line or arrow

Set reusable defaults in **Settings → Canvas**.

## Save and organize

Canvas changes autosave after a short delay. New sketches receive a two-word title with their creation date. Press <kbd>⌘</kbd><kbd>S</kbd> to give a sketch a deliberate name.

The Gallery shows each canvas at its real aspect ratio. Double-click a card to open it. Right-click for Open, Rename, Export, Delete, or **Select**.

Selection mode supports selecting multiple cards, selecting all, and batch delete. Deletion is permanent, so Quikanva asks for confirmation.

## Export and share

Open the share menu on a canvas or Gallery card:

- **Copy as Image** puts a rendered image on the pasteboard.
- **Export PNG** preserves crisp lossless output and can omit the canvas background.
- **Export JPEG** creates a smaller flattened image.

Exports are rendered at 2× scale and cropped to the sketch content. Toggle **Include background** when the destination needs transparency.

## Keep a canvas visible

Enable **Keep Canvas Windows on Top** in Settings or the Canvas menu when presenting, screen sharing, or referencing a sketch while working in another app. The default global toggle is <kbd>⌃</kbd><kbd>⌥</kbd><kbd>T</kbd>.

## Choose canvas defaults

In **Settings → Canvas**, choose:

- Portrait (9:16), Square (1:1), Standard (4:3), or Widescreen (16:9)
- Default background, stroke, fill, drawing style, and fill style
- Arrowhead, stroke, and text defaults
- A key for every drawing tool

In **Settings → General**, choose launch-at-login behavior, maximum simultaneous canvases, title date format, global shortcuts, and always-on-top behavior.

## Automate with URLs and Raycast

```sh
open 'quikanva://new'
open 'quikanva://gallery'
open 'quikanva://open?id=<UUID>'
```

The repository includes silent Raycast script commands in [`integrations/raycast`](../integrations/raycast/README.md).

## Local data and privacy

Sketches live under `~/Library/Application Support/Quikanva/`. Quikanva does not upload them. Read [Privacy](PRIVACY.md) before sharing exported files through another service.
