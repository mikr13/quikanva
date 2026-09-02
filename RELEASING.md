# Releasing Quikanva

Quikanva releases are unsigned direct-download builds until Developer ID signing and
notarization are introduced. Never describe an unsigned build as Gatekeeper-ready.
Prepare and publish a release from a clean `main` branch:

1. Run `npm ci`.
2. Run `npm run release:version` to consume pending changesets, update
   `CHANGELOG.md` and `package.json`, synchronize `project.yml`, and regenerate the
   Xcode project.
3. Review the version and changelog, then run the test suite and
   `./scripts/package-unsigned.sh`.
4. Launch the packaged app through the same Control-click → Open path documented
   for users. Verify a new sketch, Gallery reopen, and PNG export.
5. Check the README download copy, current screenshots, license, privacy note, and
   release notes for claims that changed in this version.
6. Commit the release metadata as `chore: release v<version>`.
7. Create and push an annotated `v<version>` tag.

The Release workflow rejects tags that do not match `package.json`, rebuilds and
tests the app, extracts the matching `CHANGELOG.md` section, and publishes the
unsigned zip to a GitHub release.

## Before announcing a release

- Confirm the release asset downloads from GitHub and is not only present locally.
- Verify the first-launch warning and recovery steps on a clean macOS account.
- Record the release download baseline before posting.
- Prepare the exact X copy and visuals under `docs/marketing/`.
- Be available to answer install reports during the first three hours.

## Signed distribution milestone

A mainstream release requires a Developer ID Application certificate, hardened
runtime, notarization through `notarytool`, stapling, and a clean-machine Gatekeeper
test. Keep the unsigned workflow available for contributors, but do not silently
substitute it for the signed artifact after signed distribution is introduced.
