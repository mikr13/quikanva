# Quikanva Icon Composer handoff

These transparent SVGs are the final Living Canvas artwork split into Composer-ready groups. They use a 1024 × 1024 view box and keep shadows out of the artwork so Icon Composer can provide the adaptive depth and Liquid Glass treatment.

Import the four numbered folders from bottom to top:

1. `01-background` — deep blue adaptive rear panel.
2. `02-support` — cool slate support panel.
3. `03-canvas-stack` — three square canvas panels, ordered dark, slate, then panel beige.
4. `04-ink` — the raised cyan gesture and identity layer.

Within the canvas stack, use the smallest contact shadow available on each panel. Keep the top panel's default appearance close to Quikanva's canvas beige (`#F5EED9`) and let the ink layer carry the accent tint. Check Light, Dark, Tinted, and monochrome previews at 16, 32, 64, 128, 256, 512, and 1024 pixels.

Save the Composer document as `Quikanva.icon`, add it to the Xcode project, and set the target's App Icon name to `Quikanva`. The temporary in-app prototype can then be removed from the app.
