# Releasing Quikanva

## Release flow

1. Add a changeset for each user-facing change with `pnpm run changeset`.
2. Merges to `main` collect changes in a **chore: version packages** pull request.
3. Review and merge that pull request to bump versions, tag the release, and run the release workflow.
4. The workflow tests, signs, notarizes, and staples the app and DMG, then publishes the DMG, ZIP, and Sparkle appcast.
5. The workflow then updates `Casks/quikanva.rb` in [mikr13/homebrew-quikanva](https://github.com/mikr13/homebrew-quikanva) from the published ZIP.

Manual tags must match `package.json`. Missing signing credentials stop publication; contributor CI still produces ad hoc signed builds.

## Signing setup

Local packaging requires a **Developer ID Application** certificate with its private key and a validated `notarytool` Keychain profile named `quikanva-notary` (or set `NOTARY_PROFILE`).

It also requires an installed **Developer ID provisioning profile** authorizing the explicit App ID `com.mihirpandey.quikanva`, the container `iCloud.com.mihirpandey.quikanva`, CloudKit in Production, and production push notifications. Set `ICLOUD_PROVISIONING_PROFILE` to that profile's path. Local/contributor builds keep ad hoc signing and omit iCloud entitlements. The signed packaging path validates the profile, selects it for archive/export, and verifies the exported app's embedded profile and entitlements before notarization.

```sh
./scripts/package-signed.sh
```

The script enables hardened runtime, exports through Xcode, requires Apple acceptance, staples the tickets, verifies Gatekeeper, and writes `dist/Quikanva-<version>.zip` and `dist/Quikanva.dmg`. The DMG filename stays stable for the README's latest-download link; Sparkle uses the versioned ZIP. Notarization results are saved in `dist/notary-<version>*.json`.

GitHub Actions requires these repository secrets:

- `DEVELOPER_ID_P12_BASE64`: certificate and private key exported as a base64-encoded `.p12`.
- `DEVELOPER_ID_P12_PASSWORD`: export password.
- `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD`: notarization credentials.
- `SPARKLE_ED_PRIVATE_KEY`: existing update-signing key.
- `HOMEBREW_TAP_TOKEN`: fine-grained token with **Contents: Read and write** on `mikr13/homebrew-quikanva` only.
- `ICLOUD_PROVISIONING_PROFILE_BASE64`: the Developer ID provisioning profile with CloudKit and production push permissions.

Keep credentials out of Git and maintain a secure backup. The workflow removes its temporary signing keychain after each run.

Initialize the development CloudKit schema and deploy it to Production in CloudKit Console before publishing the first sync-enabled release. Production schemas are additive: keep existing entity/attribute names and types stable. Follow [iCloud testing and activation](docs/ICLOUD_SYNC.md); enabling an entitlement alone does not provision the container or prove live sync.

## Updates and publication

The cask sets `auto_updates true`, so `brew upgrade` leaves Sparkle in charge of installed copies. Render the cask locally with `./scripts/render-homebrew-cask.sh <version> dist/Quikanva-<version>.zip`.

Keep the bundle identifier and Sparkle update key stable. `scripts/make-appcast.sh` signs the final ZIP and verifies it against the public key shipped in the app.

Sparkle reads the latest GitHub release's `appcast.xml` and compares build versions. A signed rebuild with an unchanged build version is not a new update.

With immutable releases, attach every asset to a draft before publishing. Assets cannot be added or replaced afterward.

Before shipping, check the version/changelog, tests, downloaded-app Gatekeeper acceptance, canvas/Gallery/export behavior, and upgrading an existing installation.
