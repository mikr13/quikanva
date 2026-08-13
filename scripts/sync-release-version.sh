#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_version="$(node -p "require('$repo_root/package.json').version")"
project_spec="$repo_root/project.yml"

ruby - "$project_spec" "$release_version" <<'RUBY'
path, version = ARGV
contents = File.read(path)
updated = contents
  .sub(/MARKETING_VERSION: "[^"]+"/, %(MARKETING_VERSION: "#{version}"))
  .sub(/CFBundleShortVersionString: "[^"]+"/, %(CFBundleShortVersionString: "#{version}"))

abort "Could not find version fields in #{path}" if updated == contents && !contents.include?(%("#{version}"))
File.write(path, updated)
RUBY

cd "$repo_root"
xcodegen generate
printf 'Synced Quikanva release version %s\n' "$release_version"
