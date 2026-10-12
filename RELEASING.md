# Releasing Quikanva

## Release flow

1. Add a changeset for each user-facing change with `pnpm run changeset`.
2. Merges to `main` collect changes in a **chore: version packages** pull request.
3. Review and merge that pull request to bump versions, tag the release, and run the release workflow.
4. The workflow tests, signs, notarizes, and staples the app, then publishes its ZIP and Sparkle appcast.

Manual tags must match `package.json`. Missing signing credentials stop publication; contributor CI still produces ad hoc signed builds.

## Signing setup

Local packaging requires a **Developer ID Application** certificate with its private key and a validated `notarytool` Keychain profile named `quikanva-notary` (or set `NOTARY_PROFILE`).

```sh
./scripts/package-signed.sh
```

The script enables hardened runtime, exports through Xcode, requires Apple acceptance, staples the ticket, verifies Gatekeeper, and writes `dist/Quikanva-<version>.zip`. Notarization results are saved in `dist/notary-<version>.json`.

GitHub Actions requires these repository secrets:

- `DEVELOPER_ID_P12_BASE64`: certificate and private key exported as a base64-encoded `.p12`.
- `DEVELOPER_ID_P12_PASSWORD`: export password.
- `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD`: notarization credentials.
- `SPARKLE_ED_PRIVATE_KEY`: existing update-signing key.

Keep credentials out of Git and maintain a secure backup. The workflow removes its temporary signing keychain after each run.

## Updates and publication

Keep the bundle identifier and Sparkle update key stable. `scripts/make-appcast.sh` signs the final ZIP and verifies it against the public key shipped in the app.

Sparkle reads the latest GitHub release's `appcast.xml` and compares build versions. A signed rebuild with an unchanged build version is not a new update.

With immutable releases, attach every asset to a draft before publishing. Assets cannot be added or replaced afterward.

Before shipping, check the version/changelog, tests, downloaded-app Gatekeeper acceptance, canvas/Gallery/export behavior, and upgrading an existing installation.
