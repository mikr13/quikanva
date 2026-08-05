# Quikkanva × Raycast

Script commands that open Quikkanva instantly from Raycast.

## Setup

1. Make the scripts executable (once): run `chmod +x *.sh` in this folder.
2. In Raycast: **Extensions → Script Commands → Add Directories**, then pick this
   `integrations/raycast` folder.
3. Run **New Quikkanva Sketch** (or bind it to a hotkey / alias) to pop a canvas.

Both commands run in `silent` mode, so they fire without opening a Raycast window.
They simply invoke the app's URL scheme:

- `quikkanva://new` — new dated canvas
- `quikkanva://gallery` — the sketch gallery
- `quikkanva://open?id=<UUID>` — a specific sketch
