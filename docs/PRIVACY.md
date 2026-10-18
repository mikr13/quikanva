# Privacy

Reviewed October 14, 2026.

Quikanva requires no account and includes no analytics, advertising, or crash-reporting service. Sketches, metadata, and thumbnails stay in `~/Library/Application Support/Quikanva/`; preferences use macOS user defaults.

Optional iCloud sync uses Apple's CloudKit in your private iCloud database. It is off by default and requires a build signed and provisioned for iCloud. When enabled, it uploads sketch titles, dates, scene contents, pasted images, thumbnails, and deletion markers. Images are stored separately and reused by content hash. Quikanva does not operate a server that receives this content. Checking iCloud availability in Settings contacts Apple's account service.

The working library is in a separate local store. Turning sync off, signing out, or switching Apple Accounts preserves it. Account changes suspend sync; enable it again explicitly to upload the local library to the current account. Turning sync off keeps existing iCloud copies. Deleting a sketch while sync is enabled propagates to other Macs; compact deletion markers and shared image assets are retained to support offline devices. To erase cloud data completely, turn sync off on every Mac, then use your iCloud storage controls.

On upgrade, the app keeps a local copy of the previous store in `Before-iCloud-Migration/` for rollback. This backup can retain earlier sketches after Gallery deletion. Remove it when you no longer need it, or remove the entire application-support folder to erase all local copies.

[Sparkle](https://sparkle-project.org) provides updates. It asks about automatic checks on the second launch, checks about daily when enabled, and downloads updates from GitHub. Requests expose standard details such as IP address and app version; sketches, usage data, and system profiles are not sent to GitHub.

Disable automatic checks in **Settings → General → Updates**. Delete sketches in the Gallery, or turn sync off and remove the application-support folder to erase all local copies. Manage launch at login in Settings or macOS Login Items.

Copying, exporting, and sharing are initiated by you. Other apps handle files you share through them. Raycast commands only invoke local URL routes.
