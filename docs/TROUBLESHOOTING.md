# Troubleshooting Quikanva

## macOS says the app cannot be opened

Current downloads are unsigned, so Gatekeeper warns on first launch.

1. Confirm you downloaded the zip from <https://github.com/mikr13/quikanva/releases>.
2. Move Quikanva to `/Applications`.
3. Control-click the app in Finder and choose **Open**.
4. Confirm **Open** in the dialog.

Do not disable Gatekeeper globally. If you do not want to approve an unsigned build, build Quikanva from source or wait for a signed and notarized release.

## I cannot find Quikanva in the Dock

That is expected. Quikanva is a menu-bar accessory app. Look for its icon in the menu bar, or use the global new-canvas shortcut.

## The global shortcut does not work

- Confirm Quikanva is running.
- Open **Settings → General** and record a different shortcut.
- Check **System Settings → Keyboard → Keyboard Shortcuts** for a conflict.
- Quit and relaunch Quikanva after changing a conflicting system shortcut.

## A second canvas does not open

Open **Settings → General → Maximum open canvases**. When the limit is reached, Quikanva activates an existing canvas rather than opening another one. Choose Unlimited if you regularly use several.

## Launch at login is not taking effect

Open Quikanva Settings and use **Open Login Items Settings** if macOS requires approval. Confirm Quikanva is allowed under **System Settings → General → Login Items & Extensions**.

## I closed an empty canvas and it disappeared

By default, Quikanva discards empty sketches on close. Disable **Discard empty canvases on close** in General Settings if blank canvases should remain in the Gallery.

## I cannot see an exported transparent PNG

Transparent content can look blank in viewers with a white background. Re-export with **Include background** enabled, or inspect the PNG in Preview with a contrasting window background.

## Where are my sketches?

Quikanva stores its catalog under:

```text
~/Library/Application Support/Quikanva/
```

Back up that folder before moving data manually. Do not edit the SwiftData store while Quikanva is running.

## Report a reproducible problem

Open a [bug report](https://github.com/mikr13/quikanva/issues/new/choose) with the Quikanva version, macOS version, installation source, reproduction steps, and a screenshot or short recording when relevant.
