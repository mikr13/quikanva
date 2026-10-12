# Privacy

Reviewed October 12, 2026.

Quikanva requires no account and includes no analytics, advertising, or crash-reporting service. Sketches, metadata, and thumbnails stay in `~/Library/Application Support/Quikanva/`; preferences use macOS user defaults.

The app's only network use is [Sparkle](https://sparkle-project.org) updates. It asks about automatic checks on the second launch, checks about daily when enabled, and downloads updates from GitHub. Requests expose standard details such as IP address and app version; sketches, usage data, and system profiles are not sent.

Disable automatic checks in **Settings → General → Updates**. Delete sketches in the Gallery, or remove the application-support folder to erase all sketches. Manage launch at login in Settings or macOS Login Items.

Copying, exporting, and sharing are initiated by you. Other apps handle files you share through them. Raycast commands only invoke local URL routes.
