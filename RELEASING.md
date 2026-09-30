# Releasing Quikanva

Quikanva releases are unsigned direct-download builds until Developer ID signing and
notarization are introduced. They are signed ad hoc, which Sparkle needs to install
updates, but that is not a Developer ID signature. Never describe an unsigned build as
Gatekeeper-ready.
Releases come from changesets merged into `main`:

1. Every pull request with a user-facing change includes a changeset from
   `pnpm run changeset`.
2. When changesets land on `main`, the Version workflow opens a
   `chore: version packages` pull request. It runs `pnpm run release:version`, which
   consumes the pending changesets, updates `CHANGELOG.md` and `package.json`,
   synchronizes `project.yml`, and regenerates the Xcode project. Every later merge to
   `main` refreshes the same pull request, so it can collect one change or many.
3. Merge the version pull request when you want to ship.
4. The Version workflow then tags `v<version>` and runs the Release workflow, which
   rebuilds and tests the app, extracts the matching `CHANGELOG.md` section, signs the
   zip for Sparkle, and publishes the zip and `appcast.xml` to a GitHub release.

Before merging the version pull request:

- Review the version and changelog.
- Run the test suite and `./scripts/package-unsigned.sh`, then launch the packaged app
  through the same Control-click → Open path documented for users. Verify a new
  sketch, Gallery reopen, and PNG export.
- Check the README download copy, current screenshots, license, privacy note, and
  release notes for claims that changed in this version.

CI skips the version pull request because it only changes release metadata; the
Release workflow builds and tests before it publishes. CI also runs only on pull
requests, not again when they merge into `main`. The repository must allow GitHub
Actions to create pull requests (Settings → Actions → General → Workflow
permissions).

Pushing a `v<version>` tag by hand still runs the Release workflow, which rejects tags
that do not match `package.json`.

## Updates

Installed copies update themselves with [Sparkle](https://sparkle-project.org). The
app reads its feed from
`https://github.com/mikr13/quikanva/releases/latest/download/appcast.xml`, which GitHub
redirects to the `appcast.xml` asset on the newest non-prerelease release.
`./scripts/make-appcast.sh` writes that feed with a single item for the release. It
reads the versions from the packaged app, signs the zip with EdDSA, and checks the
signature against the `SUPublicEDKey` inside the app before anything is published.

Sparkle compares `CFBundleVersion`, so `scripts/sync-release-version.sh` sets it to
the release version together with `CFBundleShortVersionString`. A release with an
unchanged `CFBundleVersion` would never be offered as an update.

One-time key setup:

1. Build the app once so Xcode downloads the Sparkle package. The tools are in
   `SourcePackages/artifacts/sparkle/Sparkle/bin` under the project's DerivedData
   folder.
2. Run `generate_keys`. It stores the private key in your login keychain and prints
   the public key.
3. Put the public key in `SUPublicEDKey` in `project.yml` and run `xcodegen generate`.
4. Run `generate_keys -x sparkle-private-key.txt`, save the file contents as the
   `SPARKLE_ED_PRIVATE_KEY` repository secret, then delete the file.

Never replace the key pair. Every installed copy trusts only the public key it
shipped with, so a new key stops those copies from updating. Keep a backup of the
private key outside GitHub.

## Before announcing a release

- Confirm the release asset downloads from GitHub and is not only present locally.
- Verify the first-launch warning and recovery steps on a clean macOS account.
- Record the release download baseline before posting.
- Prepare the exact X copy and visuals under `docs/marketing/`.
- Be available to answer install reports during the first three hours.

## Signed distribution milestone

A mainstream release requires a Developer ID Application certificate, hardened
runtime, notarization through `notarytool`, stapling, and a clean-machine Gatekeeper
test. Keep the same Sparkle EdDSA key; Sparkle accepts the change from ad hoc to
Developer ID signing when the EdDSA signature is valid. Keep the unsigned workflow available for contributors, but do not silently
substitute it for the signed artifact after signed distribution is introduced.
