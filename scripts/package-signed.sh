#!/bin/bash

# Archive/export with Xcode so nested Sparkle helpers are signed correctly, then
# notarize and staple the app before creating the archive signed by Sparkle.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
team_id="NDLJGT2AYB"
identity="Developer ID Application"
notary_profile="${NOTARY_PROFILE:-quikanva-notary}"
notary_args=(--keychain-profile "$notary_profile")
if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then
    notary_args+=(--keychain "$SIGNING_KEYCHAIN")
fi

if ! security find-identity -v -p codesigning | grep -E "Developer ID Application: .*\($team_id\)" >/dev/null; then
    printf 'Install a Developer ID Application certificate and private key for team %s first.\n' "$team_id" >&2
    exit 1
fi
xcrun notarytool history "${notary_args[@]}" --output-format json >/dev/null

version="$(plutil -extract CFBundleShortVersionString raw -o - "$repo_root/Quikanva/Resources/Info.plist")"
output_dir="$repo_root/dist"
zip_path="$output_dir/Quikanva-$version.zip"
dmg_path="$output_dir/Quikanva.dmg"
for package in "$zip_path" "$dmg_path"; do
    if [[ -e "$package" ]]; then
        printf 'Refusing to overwrite existing package: %s\n' "$package" >&2
        exit 1
    fi
done
build_root="$(mktemp -d "${TMPDIR:-/tmp}/quikanva-signed.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT
mkdir -p "$output_dir"

if [[ -z "${ICLOUD_PROVISIONING_PROFILE:-}" || ! -f "$ICLOUD_PROVISIONING_PROFILE" ]]; then
    printf 'Set ICLOUD_PROVISIONING_PROFILE to an installed Developer ID profile with CloudKit and push support.\n' >&2
    exit 1
fi
security cms -D -i "$ICLOUD_PROVISIONING_PROFILE" > "$build_root/profile.plist"
profile_uuid="$(python3 "$repo_root/scripts/validate-icloud-profile.py" \
    "$build_root/profile.plist" "$repo_root/config/CloudKit-Release.entitlements")"

cat > "$build_root/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>developer-id</string>
    <key>destination</key><string>export</string>
    <key>teamID</key><string>$team_id</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>$identity</string>
    <key>iCloudContainerEnvironment</key><string>Production</string>
    <key>provisioningProfiles</key><dict>
        <key>com.mihirpandey.quikanva</key><string>$profile_uuid</string>
    </dict>
</dict></plist>
PLIST

xcodebuild -project "$repo_root/Quikanva.xcodeproj" -scheme Quikanva \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$build_root/DerivedData" -archivePath "$build_root/Quikanva.xcarchive" \
    archive DEVELOPMENT_TEAM="$team_id" CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$identity" ENABLE_HARDENED_RUNTIME=YES \
    QUIKANVA_ICLOUD_ENTITLEMENTS="$repo_root/config/CloudKit-Release.entitlements" \
    QUIKANVA_ICLOUD_PROFILE="$profile_uuid" \
    OTHER_CODE_SIGN_FLAGS=--timestamp ONLY_ACTIVE_ARCH=NO
xcodebuild -exportArchive -archivePath "$build_root/Quikanva.xcarchive" \
    -exportPath "$build_root/export" -exportOptionsPlist "$build_root/ExportOptions.plist"

app_path="$build_root/export/Quikanva.app"
codesign --verify --deep --strict "$app_path"
if [[ ! -f "$app_path/Contents/embedded.provisionprofile" ]]; then
    printf 'Exported iCloud app is missing its provisioning profile.\n' >&2
    exit 1
fi
security cms -D -i "$app_path/Contents/embedded.provisionprofile" > "$build_root/exported-profile.plist"
exported_profile_uuid="$(python3 "$repo_root/scripts/validate-icloud-profile.py" \
    "$build_root/exported-profile.plist" "$repo_root/config/CloudKit-Release.entitlements")"
if [[ "$exported_profile_uuid" != "$profile_uuid" ]]; then
    printf 'Exported app contains a different provisioning profile.\n' >&2
    exit 1
fi
codesign -d --entitlements :- "$app_path" > "$build_root/exported-entitlements.plist" 2>/dev/null
python3 - "$build_root/exported-entitlements.plist" "$repo_root/config/CloudKit-Release.entitlements" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as source: actual = plistlib.load(source)
with open(sys.argv[2], 'rb') as source: required = plistlib.load(source)
for key, value in required.items():
    if actual.get(key) != value:
        sys.exit(f'Exported app has an unexpected iCloud entitlement: {key}')
PY
signature="$(codesign -dv --verbose=4 "$app_path" 2>&1)"
if ! printf '%s\n' "$signature" | grep -Fx "TeamIdentifier=$team_id" >/dev/null || \
   ! printf '%s\n' "$signature" | grep -F 'Authority=Developer ID Application:' >/dev/null || \
   ! printf '%s\n' "$signature" | grep -F '(runtime)' >/dev/null || \
   ! printf '%s\n' "$signature" | grep -E '^Timestamp=' >/dev/null; then
    printf 'Exported app is missing the expected Developer ID, team, runtime, or timestamp.\n' >&2
    exit 1
fi
notarize_and_staple() {
    local submission="$1" target="$2" result_path="$3"
    local notary_exit=0 status submission_id
    xcrun notarytool submit "$submission" "${notary_args[@]}" \
        --wait --timeout 45m --output-format json > "$result_path" || notary_exit=$?
    status="$(plutil -extract status raw -o - "$result_path" 2>/dev/null || true)"
    submission_id="$(plutil -extract id raw -o - "$result_path" 2>/dev/null || true)"
    if [[ "$status" != Accepted || "$notary_exit" -ne 0 ]]; then
        if [[ -n "$submission_id" && "$status" == Invalid ]]; then
            xcrun notarytool log "$submission_id" "${notary_args[@]}" "${result_path%.json}-log.json" || true
        fi
        printf 'Notarization did not succeed (status: %s). See %s and any matching log.\n' "${status:-unknown}" "$result_path" >&2
        return 1
    fi
    xcrun stapler staple "$target"
    xcrun stapler validate "$target"
}

ditto -c -k --sequesterRsrc --keepParent "$app_path" "$build_root/submission.zip"
notarize_and_staple "$build_root/submission.zip" "$app_path" "$output_dir/notary-$version.json"
codesign --verify --deep --strict "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"

# The stable DMG filename enables GitHub's latest-release direct-download URL.
mkdir "$build_root/dmg"
ditto "$app_path" "$build_root/dmg/Quikanva.app"
ln -s /Applications "$build_root/dmg/Applications"
hdiutil create -volname Quikanva -srcfolder "$build_root/dmg" \
    -format UDZO "$build_root/Quikanva.dmg"
codesign --sign "$identity" --timestamp "$build_root/Quikanva.dmg"
notarize_and_staple "$build_root/Quikanva.dmg" "$build_root/Quikanva.dmg" "$output_dir/notary-$version-dmg.json"
codesign --verify --strict -R="anchor apple generic and certificate leaf[subject.OU] = \"$team_id\"" "$build_root/Quikanva.dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$build_root/Quikanva.dmg"

# ZIPs cannot be stapled. Repackage the stapled app, then use this final ZIP in
# make-appcast.sh; signing the pre-stapling archive would break Sparkle updates.
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$build_root/Quikanva-$version.zip"
mv "$build_root/Quikanva-$version.zip" "$zip_path"
mv "$build_root/Quikanva.dmg" "$dmg_path"
printf 'Created signed and notarized packages: %s and %s\n' "$zip_path" "$dmg_path"
