# Contributing to Quikanva

Thanks for helping make quick visual thinking on macOS better. Quikanva is intentionally focused: contributions should strengthen the native, local, shortcut-first canvas rather than turn it into a general collaboration suite.

## Before you start

- Search existing issues before opening a new one.
- Use the bug or feature issue form so reports include the context needed to act.
- For a substantial feature or architecture change, open an issue before writing code.
- Security vulnerabilities must follow [SECURITY.md](SECURITY.md), not a public issue.

## Development setup

You need macOS 14 or later, Xcode 16 or later, Node.js 24, pnpm, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
git clone https://github.com/mikr13/quikanva.git
cd quikanva
pnpm install --frozen-lockfile
xcodegen generate
open Quikanva.xcodeproj
```

Build and test from Terminal:

```sh
xcodebuild test \
  -project Quikanva.xcodeproj \
  -scheme Quikanva \
  -destination 'platform=macOS'
```

For architecture and project conventions, read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Make a focused change

1. Create a branch from `main`.
2. Keep the change as small as the user-visible outcome allows.
3. Match existing Swift and native macOS patterns.
4. Add or update tests for subtle behavior and regressions.
5. Run the full test command above.
6. Manually exercise visible behavior in the built app.
7. Update user documentation when behavior, shortcuts, installation, or privacy changes.

For a user-facing change, record release notes with:

```sh
pnpm run changeset
```

Choose patch, minor, or major for the private `quikanva` release metadata and write the summary for users, not maintainers.

## Pull request checklist

- The change has one clear purpose.
- Tests pass locally.
- Visible behavior was checked in the live macOS app.
- New UI works with keyboard access and VoiceOver labels.
- Reduced Motion, dark mode, and Increased Contrast were considered where relevant.
- User-facing changes include a changeset and documentation update.
- No unrelated formatting or generated-file churn is included.

By contributing, you agree that your contribution is licensed under the repository's [MIT License](LICENSE).
