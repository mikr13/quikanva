# Development

Requires macOS 14+, Xcode 16+, Node.js 24, and pnpm 11. Use [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+ when changing `project.yml`.

```sh
git clone https://github.com/mikr13/quikanva.git
cd quikanva
pnpm install --frozen-lockfile
open Quikanva.xcodeproj
```

The generated project is committed. After changing `project.yml`, run `xcodegen generate` and commit both files.

## Code layout

| Directory | Responsibility |
| --- | --- |
| `Quikanva/App` | Lifecycle, windows, shortcuts, routing, updates |
| `Quikanva/UI` | SwiftUI canvas shell, toolbar, Gallery, Settings |
| `Quikanva/Canvas` | AppKit interaction, rendering, thumbnails, export |
| `Quikanva/Model` | Scenes, elements, styles, persistence |
| `QuikanvaTests` | Models, canvas behavior, lifecycle, release metadata |

`CanvasNSView` owns input and undo; `CanvasRepresentable` bridges SwiftUI state. Preserve this boundary.

## Verify

```sh
xcodebuild test -project Quikanva.xcodeproj -scheme Quikanva -destination 'platform=macOS'
./scripts/package-unsigned.sh
```

Packaging writes an ad hoc signed ZIP to `dist/`. For signed distribution, see [Releasing](../RELEASING.md).

If tests cannot launch with `IDELaunchErrorDomain Code 20`, quit an already-running Quikanva instance and retry. Test launch failure is not a test result.

For visible changes, check drawing, selection, undo, autosave/reopen, export, hotkeys, and URL routes. Check appearance, accessibility, and Reduced Motion as relevant. Record user-facing changes with `pnpm run changeset`.
