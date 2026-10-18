# iCloud sync testing and activation

Sync is opt-in in **Settings → iCloud**. The local SwiftData library remains authoritative; CloudKit manages a separate account-specific replica. Signing out cannot clear the working store. Switching accounts suspends sync and requires a new opt-in before the local library uploads to that account.

Concurrent saves use the latest whole-canvas revision, with a stable revision-ID tiebreaker. This does not merge individual elements or guarantee recovery of a losing edit. Prefer one Mac at a time for each canvas. CloudKit transfers run in the background; the Settings status does not claim that all uploads have completed.

## Apple setup

1. In Certificates, Identifiers & Profiles, enable iCloud/CloudKit and push notifications for the explicit Quikanva App ID and associate `iCloud.com.mihirpandey.quikanva`.
2. Create and install development and Developer ID profiles with these capabilities. Signed Debug uses `config/CloudKit-Debug.entitlements`; signed distribution uses `config/CloudKit-Release.entitlements`. The macOS push entitlement is `com.apple.developer.aps-environment`.
3. Initialize the Development schema using a provisioned Debug build: add `QUIKANVA_INITIALIZE_CLOUDKIT_SCHEMA=1` to its Xcode run environment, launch, then remove the variable. The initializer uses a disposable store and never runs in Release.
4. Verify both `CD_CanvasDocument` and `CD_CanvasImageAsset` in CloudKit Console, deploy the schema to Production, and supply `ICLOUD_PROVISIONING_PROFILE_BASE64` to release CI.

Apple documents [SwiftData model and capability requirements](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) and [CloudKit synchronization diagnostics](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer).

## Live acceptance checklist

Use two signed Macs on the same test Apple Account. Keep test sketches separate from valuable work.

- Upgrade a copy of a 0.3.4 library containing images; confirm titles, dates, thumbnails, original image pixels, and exports survive. The app saves the old store and external data in `Before-iCloud-Migration/` before opening it. For rollback, quit Quikanva, retain the current library separately, restore those backup files into the application-support directory, and run the old app. An old app cannot read asset references introduced by this version.
- Leave sync off: create, reopen, rename, export, and delete sketches without an iCloud account.
- Enable sync on both Macs: create on A and verify the Gallery, thumbnail, image, and open canvas on B. Confirm cloud records in Console and successful import/export events in macOS Console; Settings is not an upload receipt.
- Edit and rename on B. Confirm A's Gallery and already-open idle canvas update. Undo on A must not restore a pre-import scene.
- Deliver a remote update while A has a pending autosave, drag, or inline text edit. Confirm A keeps its edit and both Macs converge after the latest save. Repeat with both Macs offline, reconnect in each order, and check whole-canvas conflict behavior.
- Paste the same large image into multiple canvases and inspect CloudKit asset records. Moving, drawing, and renaming must not rewrite the image record. Confirm late-arriving image records never produce a blank saved scene.
- Delete on A while B is offline. Reconnect B and confirm its Gallery removes the sketch and its open editor cannot resurrect it.
- Turn sync off, quit/relaunch, sign out, disable iCloud for the app, and switch accounts. Confirm local sketches remain. Account changes must suspend sync before uploading local data to the new account; explicitly enabling again permits that upload.
- Test a Production-signed exported app, APNs delivery, and background propagation. Verify Developer ID signature, embedded profile, notarization, stapling, and Gatekeeper acceptance using the release script.

Automated tests cover the release-store migration, image extraction/deduplication, late assets, whole-canvas conflicts, tombstones, local retention, failed saves, and native-view reload. A signed single-Mac probe using independent stores can additionally verify live CloudKit transport. Launch that probe as a normal macOS app through LaunchServices: a command-line process may fail to register CloudKit background tasks. Account transitions, APNs delivery, and two-Mac behavior still need the provisioned acceptance run above.
