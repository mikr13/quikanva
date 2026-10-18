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

Alternatively, leave the installed app running and add `PRODUCT_BUNDLE_IDENTIFIER=com.mihirpandey.quikanva.sync-tests` to the test command. The XCTest host uses an in-memory local store and does not open your working sketch library.

## iCloud sync

The working `Quikanva.store` always uses `cloudKitDatabase: .none`. `ICloudSyncController` attaches a separate account-specific CloudKit mirror only after opt-in and an available account check. The mirror exchanges whole-canvas revisions and tombstones with the working store. A fresh mirror context receives imports; the local main context publishes them to the Gallery and open editors. Pending edits and active gestures stay local and win on their next save. Idle remote replacements clear the old undo history.

Images live in `CanvasImageAsset` records keyed by SHA-256. Stored JSON contains references; rendering and clipboard scenes hydrate the original bytes. Startup extracts embedded images transactionally without resizing them or changing sketch dates. Shared assets and tombstones are retained; garbage collection needs a separate retention policy for offline clients.

Contributor builds have no iCloud entitlements and remain local. For device testing, enable CloudKit and push notifications for `com.mihirpandey.quikanva`, associate `iCloud.com.mihirpandey.quikanva`, and install a development provisioning profile. Build Debug with your team and these app-specific settings:

```sh
xcodebuild build -project Quikanva.xcodeproj -scheme Quikanva -configuration Debug \
  DEVELOPMENT_TEAM=NDLJGT2AYB CODE_SIGN_IDENTITY='Apple Development' \
  QUIKANVA_ICLOUD_PROFILE='<development profile UUID>' \
  QUIKANVA_ICLOUD_ENTITLEMENTS="$PWD/config/CloudKit-Debug.entitlements"
```

Run the [live acceptance checklist](ICLOUD_SYNC.md) before release. The unit tests use separate local stores to exercise the reconciliation logic; they do not prove a CloudKit upload, APNs delivery, or cross-device sync.

The migration fixture was generated using the 0.3.4 model. Regenerate in a temporary directory with `swiftc -parse-as-library -module-name Quikanva scripts/fixtures/LegacyCanvasStore.swift -o /tmp/legacy-canvas-store`, run it with a store path, and copy the closed/checkpointed `.store` into `QuikanvaTests/Fixtures/LegacyStore/`.

For visible changes, check drawing, selection, undo, autosave/reopen, export, hotkeys, and URL routes. Check appearance, accessibility, and Reduced Motion as relevant. Record user-facing changes with `pnpm run changeset`.
