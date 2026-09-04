# Quikanva development guide

Quikanva is a native macOS 14+ application built with Swift 6, SwiftUI, AppKit, Core Graphics, SwiftData, and the KeyboardShortcuts package.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- Node.js 24 and pnpm 11 for changesets
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46 or later when changing `project.yml`

## Set up the project

```sh
git clone https://github.com/mikr13/quikanva.git
cd quikanva
pnpm install --frozen-lockfile
xcodegen generate
open Quikanva.xcodeproj
```

The generated Xcode project is committed. Regenerate it whenever `project.yml` changes and include both files in the same pull request.

## Architecture

- `Quikanva/App` owns lifecycle, menu-bar commands, URL routing, global shortcuts, and canvas windows.
- `Quikanva/UI` contains the SwiftUI gallery, settings, canvas shell, and toolbar.
- `Quikanva/Canvas` contains the AppKit `CanvasNSView`, SwiftUI bridge, renderer, thumbnailer, and exporter.
- `Quikanva/Model` contains scenes, elements, documents, styles, and serialization.
- `QuikanvaTests` covers model, rendering, input behavior, persistence utilities, release-sensitive metadata, and app lifecycle boundaries.

The canvas is intentionally AppKit-backed. `CanvasNSView` owns direct interaction and the native undo manager; `CanvasRepresentable` synchronizes it with SwiftUI state. Preserve that ownership boundary when changing tools or commands.

## Build and test

```sh
xcodebuild test \
  -project Quikanva.xcodeproj \
  -scheme Quikanva \
  -destination 'platform=macOS'
```

If the test runner fails with `IDELaunchErrorDomain Code 20`, quit an already-running Quikanva app with the same bundle identifier and rerun. Treat compilation, test launch, and manual UI verification as separate results.

Create an unsigned release artifact with:

```sh
./scripts/package-unsigned.sh
```

The script builds Release with code signing disabled and writes a versioned zip under `dist/`.

## Validate visible behavior

For a UI or lifecycle change, run the app and verify the matching surface rather than relying on a build alone. Useful checks include:

- Menu-bar new canvas, Gallery, Settings, and Quit
- Global shortcut from another active app
- `quikanva://new`, `quikanva://gallery`, and a valid/invalid open route
- Drawing, selection, undo/redo, close-time autosave, Gallery reopen, and export
- Light/dark appearance, Increased Contrast, Reduced Motion, keyboard access, and VoiceOver labels

## Release notes

Use `pnpm run changeset` for every user-facing feature or fix. Release preparation and tag automation are documented in [RELEASING.md](../RELEASING.md).
