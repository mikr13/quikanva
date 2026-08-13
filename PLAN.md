# Quikanva — Build Plan & Progress

A blazing-fast **native macOS** quick-canvas app: pop a canvas instantly from a global
hotkey / menu bar / Raycast, sketch with an Excalidraw-comparable **custom vector engine**
(including a hand-drawn *sketchy* look), auto-save with dated titles, manage sketches in a
gallery grid, and export to images.

**Status legend:** `[ ]` todo · `[~]` in progress · `[x]` done

---

## Resolved decisions

- **Name:** Quikanva · URL scheme `quikanva://` · bundle id `com.mihirpandey.quikanva`
- **UI:** SwiftUI shell + native AppKit `NSView` canvas (`NSViewRepresentable`)
- **Canvas engine:** custom vector engine (Excalidraw parity). **Not** PencilKit
  (its editable canvas is UIKit/Catalyst-only; can't be native + parity).
- **Min OS:** macOS 14+ (Sonoma) · **Swift 6**
- **Distribution:** Direct Developer ID, unsandboxed
- **App presence:** `.accessory` / `LSUIElement` — menu-bar-only, no Dock icon
- **Default quick-open tool:** Freehand pen
- **Sketchy hand-drawn rendering:** in v1 (deterministic per-element path perturbation)
- **Export v1:** PNG + JPEG + copy-to-clipboard (PDF/SVG deferred)
- **Storage:** SwiftData catalog + on-disk canvas files (scene JSON + PNG thumbnail)
- **Global hotkey:** `sindresorhus/KeyboardShortcuts` (SPM)

---

## Phase 0 — Project scaffold & shell

- [x] Create Xcode project (XcodeGen `project.yml`, SwiftUI app, macOS 14+ target)
- [x] Configure signing (local dev: ad-hoc "Sign to Run Locally"; Developer ID for release later)
- [x] `Info.plist`: `LSUIElement = YES`, `CFBundleURLTypes` = `quikanva`
- [x] Add SPM dependency `sindresorhus/KeyboardShortcuts`
- [x] App scenes wired: `MenuBarExtra` + gallery `Window` + canvas `WindowGroup(for:)`
- [x] `.accessory` activation policy + `NSApp.activate` so windows take focus
- [x] **Verify:** `xcodebuild` BUILD SUCCEEDED; bundle signs + registers `quikanva://`

## Phase 1 — Data model + canvas surface

- [x] `CanvasScene` (Codable): elements + camera (pan/zoom)
- [x] `Element`: kinds (rectangle/ellipse/diamond/line/arrow/freedraw/text),
      geometry, `zIndex`, `style`, `seed`, `roughness`, `fillStyle`
- [x] `CanvasNSView` (layer-backed) + `CanvasRepresentable` bridge
- [x] `Renderer` (Core Graphics) + hit-testing (bbox + point-to-segment distance)
- [x] Two-layer rendering: committed scene layer + live overlay layer
- [x] Camera pan (scrollWheel + Hand-tool drag) + pinch zoom (magnify); programmatic zoom transitions use an interruptible spring-like settle
- [x] Zoom in, zoom out, zoom to fit, zoom to selection, and reset tools combined into the ellipsis menu
- [x] Default canvas window scales to a portrait 9:16 frame within the available screen
- [x] **Verify:** smooth pan/zoom in Instruments (500+ elements, no dropped frames)

## Phase 2 — Tools + the sketchy look

- [x] Tool state machine (Select move/delete + Hand pan + Eraser + Text live; marquee/resize in Phase 3)
- [x] Freehand tool — default tool with commit-time smoothing
- [x] Shape tools (rect/ellipse/diamond) + line/arrow with arrowheads
- [x] Text tool (inline `NSTextField` editing)
- [x] Eraser tool (click / drag to remove elements)
- [x] `Sketch`/`Renderer`: jittered, double-stroked paths + solid and hachure fills
- [x] Deterministic per-element `seed` (no shimmer on redraw/pan/zoom)
- [x] Roughened-path cache keyed by deterministic element hash
- [x] Tool keyboard shortcuts (V/H/R/O/D/L/A/P/T/E) and arrow-key movement
- [x] Floating translucent toolbar: responsive tool overflow + stroke/fill/background color + Save + Share
- [x] Image elements (paste/drop)
- [x] Image presentation: optional subtle shadow; selection overlay shown only in Select mode
- [x] **Verify:** every shape renders with stable sketch style; freehand feels good

## Phase 3 — Selection, manipulation, styling, undo

- [x] Selection: click, shift-click, and marquee
- [x] Move (1:1), resize (8 handles, shift=aspect), and rotate handle
- [x] Delete (⌫), z-order, duplicate (⌘D), and copy-paste
- [x] Inspector panel: stroke/fill/opacity/width/font-size + roughness/fill-style
- [x] Command-based mutations use the view's native `UndoManager` and app-level Edit commands
- [~] **Verify:** full manipulation + undo/redo correctness

## Phase 4 — Persistence, autosave, gallery

- [x] SwiftData `@Model CanvasDocument` (id/title/createdAt/updatedAt/sceneData/thumbnail)
- [x] `SceneCodec` (scene JSON) + `Thumbnailer` (fitted PNG); private namespaced store
- [x] Autosave on each element/camera commit with dirty-only persistence, 300 ms debounce, and close-time flush
- [x] Auto-title `Sketch — <date, time>` on create; discard-empty-untitled on close
- [x] Gallery `LazyVGrid`: create / open (dbl-click) / rename / delete
- [x] Manual **Save** (name this sketch, ⌘S) + canvas background color from toolbar
- [x] Don't save if canvas is not dirty (no changes)
- [x] Gallery motion: staggered entrance, spring hover, reduced-motion honored
- [~] **Verify:** store created + clean launch; full GUI round-trip pending manual pass

## Phase 5 — Launch integrations

- [x] `KeyboardShortcuts.Name` (+ default ⌘⇧K) → global hotkey opens instant canvas
- [x] Instant open via `openWindow` (no custom anim) with a hidden-window prewarm
- [x] Settings screen with `KeyboardShortcuts.Recorder`
- [x] URL scheme handler: `quikanva://new | gallery | open?id=UUID`
- [x] Menu bar menu actions (New Canvas / Open Gallery / Settings / Quit)
- [x] Raycast `silent` script commands (`new` + `gallery`) + setup README
- [~] **Verify:** build + launch + URL open OK; hotkey latency pending manual check

## Phase 6 — Export & polish

- [x] `Exporter`: PNG/JPEG at 2x, background toggle, tight-crop to content
- [x] Copy-to-clipboard export; `NSSavePanel` save flow (toolbar menu + ⌘E / ⌘⇧C)
- [x] Design pass: spring press feedback + translucent toolbar + native extra-tools menu
- [x] Slow-motion animation review
- [x] Setup changeset for Changelog / Release Notes
- [x] Setup GitHub Actions for CI / build / release
- [x] **Verify:** exports open correctly in Preview; a11y (VoiceOver, contrast, dark mode)

## Phase 7 — More polish

- [x] 3D App icon with layers / assets (using Apple Icon Composer)
- [x] Bundle the unsigned app for direct download (Developer ID signing deferred until v2)
- [x] Send elements in canvas to back/front (z-order)
- [x] Choose stroke style (solid, dashed, dotted)
- [x] Choose arrowhead style (open, closed, filled)
- [x] Allow bending / curving of lines and arrows with default draggable endpoints/midpoint; bent paths retain resize/rotate selection handles
- [x] Choose text font + weight + alignment + style (comic sans, serif, monospace, etc.)
- [x] Setting: Default canvas background color, default stroke/fill color, default roughness/fill style, default text font/weight/size, default arrowhead style, default stroke style, max canvas window panel number that can be open at once (e.g., 1, 2, 3, 4, unlimited)
- [x] **Verify:** full manual pass of element z-order, stroke/fill/arrowhead/text/font, bending and settings panel

## Phase 8 — More ideas

- [x] Dual random word paired naming for auto-titles (e.g., "Cosmic Ladle - Aug 5th, 2026 at 14:30")
- [x] Configure date-time format for auto-titles in settings (e.g., "Aug 5th, 2026 at 14:30" vs "2026-08-05 14:30")
- [x] Always-on-top canvas window (for presentations / laser mode), with Canvas menu toggle and configurable global shortcut
- [ ] Apple liquid glass treatment of the toolbar, settings and gallery windows
- [ ] Apple liquid glass fluid animations for tool selection, inspector panel, morphing toolbar buttons and gallery item hover
- [ ] Snapping / alignment guides

## Phase 9 — Production Readiness

- [ ] Make every canvas tool shortcut configurable in Settings
- [ ] PDF / SVG export
- [ ] Support importing Excalidraw plugin files
- [ ] Launch at login
- [ ] iCloud sync

---

## Verification checklist

- [x] `xcodebuild -scheme Quikanva build` succeeds
- [x] Unit tests: scene Codable round-trip · hit-testing · `RoughGenerator` determinism ·
      command undo/redo · exporter output · auto-title generation
- [ ] Instruments: no dropped frames at 500+ sketchy elements during draw + pan/zoom
- [ ] Manual pass: every tool, resize/rotate, multi-select, undo chain, close-without-save,
      reopen, exports, hotkey + Raycast + URL launch, dark mode + reduced-motion + VoiceOver

## Out of scope (v1)

Real-time collab · iCloud sync · iOS/iPad · Mac App Store · plugins · shape libraries ·
presentation/laser mode · PDF/SVG export · snapping guides.
