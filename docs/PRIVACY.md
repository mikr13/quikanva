# Quikanva privacy note

**Last updated:** 2026-09-02

Quikanva is a local-first macOS application. It does not require an account and the application source contains no analytics, advertising, crash-reporting, or network client integration.

## What Quikanva stores

Quikanva stores canvas metadata, scene data, and thumbnails under:

```text
~/Library/Application Support/Quikanva/
```

Preferences such as shortcuts, canvas defaults, launch-at-login, and always-on-top behavior are stored through macOS user defaults.

## What leaves your Mac

Quikanva does not upload sketches or usage data. Data leaves the app only when you choose an operating-system action such as copying an image, exporting a file, sharing that file through another app, or opening the GitHub repository in a browser.

The included Raycast scripts invoke local `quikanva://` routes. They do not send sketch contents to Raycast or a remote service.

## Your control

- Delete individual sketches from the Gallery.
- Remove Quikanva's application-support folder to delete all locally stored sketches.
- Disable launch at login from Quikanva Settings or macOS Login Items.
- Inspect, build, and audit the source under the MIT License.

This is a product privacy statement, not a promise about third-party apps you use to distribute exported images.
