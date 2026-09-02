# Changelog

## 0.2.1

### Patch Changes

- 3a5032a: Add the open-source README, user documentation, community files, and release guidance.

## 0.2.0

### Minor Changes

- 44f030e: Add a General setting that keeps canvas windows above other apps for presentations and laser mode.
- ecffa6f: Give every new canvas a memorable two-word name such as `Cosmic Ladle`, followed by its creation date and time.
- 4be4259: Add a General setting for choosing system-style or sortable date and time formatting in new canvas titles.
- e416959: Add reduced-motion-aware fluid transitions for canvas tool selection, the style inspector, and gallery card hover.
- b3de097: Adopt native Liquid Glass for the canvas toolbar, Settings, and Gallery with accessible fallbacks on older macOS versions.
- 386b5b4: Add a checked Canvas menu command and configurable global shortcut for keeping canvas windows on top.
- dca85bb: Add smart element, viewport, and grid snapping with visible alignment guides and an Option-drag bypass.

### Patch Changes

- d6e0382: Add automated macOS build, test, unsigned-package, and tag-driven GitHub release workflows.
- 9d92667: Keep Bring to Front and Send to Back changes visible on the live canvas when elements overlap.
- 87087d8: Make gallery cards open or toggle selection when activated with VoiceOver or the keyboard.
- a93171b: Verify PNG and JPEG exports in Preview and complete native accessibility QA across light, dark, and Increased Contrast modes.
- a09d7c3: Restore native opaque Settings surfaces so the window no longer samples Gallery colors behind its forms.

All notable changes to Quikanva are documented here. Pending changes are recorded
as Markdown files in `.changeset/` and folded into this changelog when a release is
versioned.

## 0.1.0

### Added

- Native macOS menu-bar app with instant canvas windows, vector drawing tools,
  sketch-style rendering, autosave, gallery management, and PNG/JPEG export.
- Global keyboard shortcut, URL routes, Raycast commands, configurable canvas
  defaults, and unsigned direct-download packaging.
