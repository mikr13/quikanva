#!/bin/bash

# Signs a packaged release zip for Sparkle and writes a single-item appcast for it.
# Versions come from the app inside the zip, so the feed always describes what ships.
#
# Usage: make-appcast.sh <archive.zip> <download-url> <release-notes.md> <appcast.xml>
# Requires sign_update from the Sparkle tools on PATH and the private EdDSA key in
# SPARKLE_ED_PRIVATE_KEY.

set -euo pipefail

if [[ $# -ne 4 ]]; then
    printf 'Usage: %s <archive.zip> <download-url> <release-notes.md> <appcast.xml>\n' "$0" >&2
    exit 2
fi

archive_path="$1"
download_url="$2"
release_notes_path="$3"
appcast_path="$4"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/quikanva-appcast.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

if [[ -z "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
    printf 'SPARKLE_ED_PRIVATE_KEY is not set\n' >&2
    exit 1
fi

info_plist="$work_dir/Info.plist"
unzip -p "$archive_path" 'Quikanva.app/Contents/Info.plist' > "$info_plist"

read_info() {
    plutil -extract "$1" raw -o - "$info_plist"
}

bundle_version="$(read_info CFBundleVersion)"
short_version="$(read_info CFBundleShortVersionString)"
minimum_system_version="$(read_info LSMinimumSystemVersion)"
public_key="$(read_info SUPublicEDKey)"

signature="$(printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | sign_update --ed-key-file - -p "$archive_path")"
swift "$repo_root/scripts/verify-update-signature.swift" "$archive_path" "$signature" "$public_key"

length="$(stat -f %z "$archive_path")"
pub_date="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
# A literal "]]>" would end the CDATA section early.
release_notes="$(sed 's/]]>/]]]]><![CDATA[>/g' "$release_notes_path")"

cat > "$appcast_path" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Quikanva</title>
    <item>
      <title>Quikanva $short_version</title>
      <pubDate>$pub_date</pubDate>
      <sparkle:version>$bundle_version</sparkle:version>
      <sparkle:shortVersionString>$short_version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$minimum_system_version</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/mikr13/quikanva/releases</sparkle:fullReleaseNotesLink>
      <description sparkle:format="markdown"><![CDATA[
$release_notes
]]></description>
      <enclosure url="$download_url" length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
    </item>
  </channel>
</rss>
XML

xmllint --noout "$appcast_path"
printf 'Created %s for Quikanva %s\n' "$appcast_path" "$short_version"
