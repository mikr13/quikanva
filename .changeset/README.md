# Changesets

Add one release-note fragment for every user-facing feature or fix:

```sh
pnpm run changeset
```

Choose `patch`, `minor`, or `major` for the private `quikanva` release metadata and
write the summary in user-facing language. Commit the generated Markdown file with
the feature it describes.

To prepare a release, run:

```sh
pnpm run release:version
```

This consumes pending fragments, updates `CHANGELOG.md` and `package.json`, syncs
the version into `project.yml`, and regenerates the Xcode project.
