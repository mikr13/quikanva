#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/quikanva-release.XXXXXX")"
output_dir="$repo_root/dist"
trap 'rm -rf "$build_root"' EXIT

marketing_version="$(xcodebuild -project "$repo_root/Quikanva.xcodeproj" \
    -scheme Quikanva \
    -showBuildSettings 2>/dev/null | awk -F ' = ' '/MARKETING_VERSION/ { print $2; exit }')"
package_name="Quikanva-${marketing_version:-0.1.0}-unsigned"
app_path="$build_root/Build/Products/Release/Quikanva.app"
zip_path="$output_dir/$package_name.zip"

if [[ -e "$zip_path" ]]; then
    printf 'Refusing to overwrite existing package: %s\n' "$zip_path" >&2
    exit 1
fi

xcodebuild \
    -project "$repo_root/Quikanva.xcodeproj" \
    -scheme Quikanva \
    -configuration Release \
    -derivedDataPath "$build_root" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build

if [[ ! -d "$app_path" ]]; then
    printf 'Release app was not produced at %s\n' "$app_path" >&2
    exit 1
fi

mkdir -p "$output_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
printf 'Created %s\n' "$zip_path"
