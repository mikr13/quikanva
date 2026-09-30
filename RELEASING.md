# Releasing Quikanva

Quikanva releases are unsigned direct-download builds until Developer ID signing and
notarization are introduced. Never describe an unsigned build as Gatekeeper-ready.
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
   rebuilds and tests the app, extracts the matching `CHANGELOG.md` section, and
   publishes the unsigned zip to a GitHub release.

Before merging the version pull request:

- Review the version and changelog.
- Run the test suite and `./scripts/package-unsigned.sh`, then launch the packaged app
  through the same Control-click → Open path documented for users. Verify a new
  sketch, Gallery reopen, and PNG export.
- Check the README download copy, current screenshots, license, privacy note, and
  release notes for claims that changed in this version.

GitHub does not run CI for pull requests opened with the workflow token, so the
version pull request shows no checks. The Release workflow builds and tests before it
publishes. The repository must allow GitHub Actions to create pull requests
(Settings → Actions → General → Workflow permissions).

Pushing a `v<version>` tag by hand still runs the Release workflow, which rejects tags
that do not match `package.json`.

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
