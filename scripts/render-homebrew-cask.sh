#!/bin/bash

# Print the Homebrew cask for a release. The release workflow writes this to
# Casks/quikanva.rb in the mikr13/homebrew-quikanva tap.
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'Usage: %s <version> <Quikanva-version.zip>\n' "$(basename "$0")" >&2
    exit 64
fi

version="$1"
zip_path="$2"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Expected a semantic version, got: %s\n' "$version" >&2
    exit 1
fi
if [[ "$(basename "$zip_path")" != "Quikanva-$version.zip" ]]; then
    printf 'Expected Quikanva-%s.zip, got: %s\n' "$version" "$zip_path" >&2
    exit 1
fi
sha256="$(shasum -a 256 "$zip_path" | awk '{ print $1 }')"

cat <<CASK
cask "quikanva" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/mikr13/quikanva/releases/download/v#{version}/Quikanva-#{version}.zip"
  name "Quikanva"
  desc "Sketch canvas that is one shortcut away"
  homepage "https://github.com/mikr13/quikanva"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma

  app "Quikanva.app"

  uninstall quit: "com.mihirpandey.quikanva"

  zap trash: [
    "~/Library/Application Support/Quikanva",
    "~/Library/Caches/com.mihirpandey.quikanva",
    "~/Library/HTTPStorages/com.mihirpandey.quikanva",
    "~/Library/HTTPStorages/com.mihirpandey.quikanva.binarycookies",
    "~/Library/Preferences/com.mihirpandey.quikanva.plist",
  ]
end
CASK
