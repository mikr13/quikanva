# Quikkanva — Build Plan & Progress

A blazing-fast **native macOS** quick-canvas app: pop a canvas instantly from a global
hotkey / menu bar / Raycast, sketch with an Excalidraw-comparable **custom vector engine**
(including a hand-drawn *sketchy* look), auto-save with dated titles, manage sketches in a
gallery grid, and export to images.

**Status legend:** `[ ]` todo · `[~]` in progress · `[x]` done

---

## Resolved decisions

- **Name:** Quikkanva · URL scheme `quikkanva://` · bundle id `com.mihirpandey.quikkanva`
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
- [x] `Info.plist`: `LSUIElement = YES`, `CFBundleURLTypes` = `quikkanva`
- [x] Add SPM dependency `sindresorhus/KeyboardShortcuts`
- [x] App scenes wired: `MenuBarExtra` + gallery `Window` + canvas `WindowGroup(for:)`
- [x] `.accessory` activation policy + `NSApp.activate` so windows take focus
- [ ] App icon / assets (deferred)
- [x] **Verify:** `xcodebuild` BUILD SUCCEEDED; bundle signs + registers `quikkanva://`

## Phase 1 — Data model + canvas surface

- [x] `CanvasScene` (Codable): elements + camera (pan/zoom)
- [x] `Element`: kinds (rectangle/ellipse/diamond/line/arrow/freedraw/text),
      geometry, `zIndex`, `style`, `seed`, `roughness`, `fillStyle`
- [x] `CanvasNSView` (layer-backed) + `CanvasRepresentable` bridge
- [x] `Renderer` (Core Graphics) + hit-testing (bbox + point-to-segment distance)
- [ ] Two-layer rendering: committed scene layer + live overlay layer
- [~] Camera pan (scrollWheel + Hand-tool drag) + pinch zoom (magnify); spring smoothing pending
- [ ] Zoom in, zoom out, zoom to fit, zoom to selection tools combined into a single `ZoomTool`
- [ ] **Verify:** smooth pan/zoom in Instruments (500+ elements, no dropped frames)

## Phase 2 — Tools + the sketchy look

- [x] Tool state machine (Select move/delete + Hand pan + Eraser + Text live; marquee/resize in Phase 3)
- [x] Freehand tool — default tool (smoothing refinement pending)
- [x] Shape tools (rect/ellipse/diamond) + line/arrow with arrowheads
- [x] Text tool (inline `NSTextField` editing)
- [x] Eraser tool (click / drag to remove elements)
- [x] `Sketch`/`Renderer`: jittered, double-stroked paths + solid fill (hachure pending)
- [x] Deterministic per-element `seed` (no shimmer on redraw/pan/zoom)
- [ ] Roughened-path cache keyed by geometry+style hash
- [ ] Tool keyboard shortcuts (V/H/R/O/D/L/A/P/T/E)
- [x] Floating translucent toolbar: tools + stroke & background color + Save + Share (press feedback)
- [ ] Image elements (paste/drop)
- [ ] **Verify:** every shape renders with stable sketch style; freehand feels good

## Phase 3 — Selection, manipulation, styling, undo

- [~] Selection: click done; shift-click / marquee pending
- [~] Move (1:1) done; resize (8 handles, shift=aspect) + rotate handle pending
- [~] Delete (⌫) done; z-order / duplicate (⌘D) / copy-paste pending
- [ ] Inspector panel: stroke/fill/opacity/width/font/arrowheads/dash + roughness/fill-style
- [ ] Command-based mutations funneled through `apply()` with `UndoManager`
- [ ] **Verify:** full manipulation + undo/redo correctness

## Phase 4 — Persistence, autosave, gallery

- [x] SwiftData `@Model CanvasDocument` (id/title/createdAt/updatedAt/sceneData/thumbnail)
- [x] `SceneCodec` (scene JSON) + `Thumbnailer` (fitted PNG); private namespaced store
- [~] Autosave on each element commit (time-debounce + thumbnail throttle pending)
- [~] Auto-title `Sketch — <date, time>` on create; discard-empty-untitled pending
- [x] Gallery `LazyVGrid`: create / open (dbl-click) / rename / delete
- [x] Manual **Save** (name this sketch, ⌘S) + canvas background color from toolbar
- [ ] Don't save if canvas not dirty (no elements or no changes)
- [ ] Gallery motion: staggered entrance, spring hover, reduced-motion honored
- [~] **Verify:** store created + clean launch; full GUI round-trip pending manual pass

## Phase 5 — Launch integrations

- [x] `KeyboardShortcuts.Name` (+ default ⌘⇧K) → global hotkey opens instant canvas
- [~] Instant open via `openWindow` (no custom anim); hidden-window prewarm pending
- [x] Settings screen with `KeyboardShortcuts.Recorder`
- [x] URL scheme handler: `quikkanva://new | gallery | open?id=UUID`
- [x] Menu bar menu actions (New Canvas / Open Gallery / Settings / Quit)
- [~] Raycast `silent` script commands (`new` + `gallery`) + setup README
- [~] **Verify:** build + launch + URL open OK; hotkey latency pending manual check

## Phase 6 — Export & polish

- [x] `Exporter`: PNG/JPEG at 2x, background toggle, tight-crop to content
- [x] Copy-to-clipboard export; `NSSavePanel` save flow (toolbar menu + ⌘E / ⌘⇧C)
- [~] Design pass: spring press feedback + translucent toolbar done; deeper pass pending
- [ ] Slow-motion animation review
- [ ] **Verify:** exports open correctly in Preview; a11y (VoiceOver, contrast, dark mode)

## Phase 7 — Stretch (post-v1)

- [ ] Snapping / alignment guides
- [ ] PDF / SVG export
- [ ] Launch at login
- [ ] iCloud sync

---

## Verification checklist

- [ ] `xcodebuild -scheme Quikkanva build` succeeds
- [ ] Unit tests: scene Codable round-trip · hit-testing · `RoughGenerator` determinism ·
      command undo/redo · exporter output · auto-title generation
- [ ] Instruments: no dropped frames at 500+ sketchy elements during draw + pan/zoom
- [ ] Manual pass: every tool, resize/rotate, multi-select, undo chain, close-without-save,
      reopen, exports, hotkey + Raycast + URL launch, dark mode + reduced-motion + VoiceOver

## Out of scope (v1)

Real-time collab · iCloud sync · iOS/iPad · Mac App Store · plugins · shape libraries ·
presentation/laser mode · PDF/SVG export · snapping guides · image elements.
