# Contributing

Keep changes focused on Quikanva's native, local sketch workflow. Search [issues](https://github.com/mikr13/quikanva/issues) first; discuss substantial features before implementing them. Report vulnerabilities privately through [Security](SECURITY.md).

Follow the [Development Guide](docs/DEVELOPMENT.md) for setup and tests.

Before opening a pull request:

- Branch from `main` and follow existing Swift/macOS patterns.
- Test regressions and exercise changed UI in the app.
- Check keyboard access, VoiceOver, appearance, and Reduced Motion where relevant.
- Update affected docs and run `pnpm run changeset` for user-facing changes.
- Regenerate the Xcode project when changing `project.yml`; include both files.

A maintainer approves each CI run. The latest commit must pass before merge; new pushes require another approval.

Contributions use the repository's [MIT License](LICENSE).
