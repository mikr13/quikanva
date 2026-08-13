# Releasing Quikanva

Quikanva releases are unsigned direct-download builds until Developer ID signing is
introduced. Prepare and publish a release from a clean `main` branch:

1. Run `npm ci`.
2. Run `npm run release:version` to consume pending changesets, update
   `CHANGELOG.md` and `package.json`, synchronize `project.yml`, and regenerate the
   Xcode project.
3. Review the version and changelog, then run the test suite and
   `./scripts/package-unsigned.sh`.
4. Commit the release metadata as `chore: release v<version>`.
5. Create and push an annotated `v<version>` tag.

The Release workflow rejects tags that do not match `package.json`, rebuilds and
tests the app, extracts the matching `CHANGELOG.md` section, and publishes the
unsigned zip to a GitHub release.
