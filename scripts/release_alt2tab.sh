#!/usr/bin/env bash

# Builds, notarizes, tags and publishes an Alt²Tab release from main.
# Usage: scripts/release_alt2tab.sh <version>   (e.g. 1.2.0)
# Requires: Xcode, gh (authenticated), a "Developer ID Application" identity in the keychain,
# and a notarytool keychain profile named "alt2tab" (xcrun notarytool store-credentials alt2tab --team-id <TEAM_ID>).

set -eu

version="${1:?usage: $0 <version>}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version: $version" >&2; exit 1; }
[[ "$(git branch --show-current)" == "main" ]] || { echo "Run from main" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Working tree is not clean" >&2; exit 1; }
tag="alt2tab-v$version"
! git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "Tag $tag already exists" >&2; exit 1; }

sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $version/" config/alt2tab.xcconfig
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -derivedDataPath DerivedData | scripts/xcbeautify

productsDir="DerivedData/Build/Products/Release"
zipName="Alt2Tab-$version.zip"
(
    cd "$productsDir"
    rm -f "$zipName"
    ditto -c -k --sequesterRsrc --keepParent Alt2Tab.app "$zipName"
    xcrun notarytool submit "$zipName" --keychain-profile alt2tab --wait --timeout 15m
    xcrun stapler staple Alt2Tab.app
    rm "$zipName"
    ditto -c -k --sequesterRsrc --keepParent Alt2Tab.app "$zipName"
    spctl -a -t exec Alt2Tab.app
)

upstreamTag="$(git describe --tags --match 'v*' --abbrev=0)"
git commit -q -am "chore(release): $version"
git tag "$tag"
git push -q origin main "$tag"
gh release create "$tag" "$productsDir/$zipName" --title "Alt²Tab $version" \
    --notes "Based on upstream AltTab $upstreamTag: https://github.com/lwouis/alt-tab-macos/releases/tag/$upstreamTag"
