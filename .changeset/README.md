# Changesets

Add one release-note fragment for every user-facing feature or fix:

```sh
pnpm run changeset
```

Choose `patch`, `minor`, or `major` for the private `quikanva` release metadata and
write the summary in user-facing language. Commit the generated Markdown file with
the feature it describes.

Changesets that are not user-facing can be empty:

```sh
pnpm run changeset --empty
```

After fragments land on `main`, the Version workflow collects them into a
`chore: version packages` pull request. Merging it tags and publishes the release, as
described in [RELEASING.md](../RELEASING.md).
