#!/usr/bin/env bash

set -exu

version="$(cat "$VERSION_FILE")"
appFile="$APP_NAME.app"
zipName="$APP_NAME-$version.zip"
oldPwd="$PWD"

cd "$XCODE_BUILD_PATH"
# --sequesterRsrc stores xattrs (e.g. com.apple.provenance) under __MACOSX/ instead of inline
# ._ AppleDouble entries. Archive Utility can't reapply inline ._ entries to symlinks, so it
# leaves them on disk in Sparkle.framework's root → "unsealed contents present in the root
# directory of an embedded framework" after a normal Finder extraction.
ditto -c -k --sequesterRsrc --keepParent "$appFile" "$zipName"

# request notarization
requestStatus=$("$oldPwd"/scripts/notarytool submit \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  "$zipName" \
  --wait --timeout 15m 2>&1 |
  tee /dev/tty |
  awk -F ': ' '/  status:/ { print $2; }')
if [[ $requestStatus != "Accepted" ]]; then exit 1; fi

# staple build
xcrun stapler staple "$appFile"
ditto -c -k --sequesterRsrc --keepParent "$appFile" "$zipName"
