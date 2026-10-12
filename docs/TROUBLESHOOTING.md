# Troubleshooting

## macOS blocks the app

Use downloads from [Quikanva releases](https://github.com/mikr13/quikanva/releases) and move the app to `/Applications`. Unsigned builds may require **System Settings → Privacy & Security → Open Anyway** after a blocked launch. Follow [Apple's instructions](https://support.apple.com/en-us/102445) and verify the source before allowing it.

Do not disable Gatekeeper globally. Report unexpected warnings for a signed release.

## Updates fail

Download the [latest release](https://github.com/mikr13/quikanva/releases/latest), quit Quikanva, and replace the app in `/Applications`. Sketches remain in `~/Library/Application Support/Quikanva/`. Report signature errors; avoid alternate download sources.

## Common issues

| Issue | Check |
| --- | --- |
| No Dock icon | Quikanva lives in the menu bar. |
| Global shortcut fails | Confirm the app is running; change the shortcut in General Settings and check macOS keyboard conflicts. |
| No additional canvas | Raise **Maximum open canvases** or choose Unlimited. |
| Launch at login fails | Approve Quikanva in **System Settings → General → Login Items & Extensions**. |
| Empty sketch disappears | Turn off **Discard empty canvases on close** in General Settings. |
| Transparent PNG looks blank | Enable **Include background** or view it against a contrasting background. |

Back up the application-support folder before moving data, and quit Quikanva before editing its store. For unresolved problems, follow [Support](../SUPPORT.md).
