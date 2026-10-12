#!/usr/bin/env bash

# Fails when a merge has dropped an Alt²Tab invariant: forced Pro, the fork's own app identity,
# or the fail-safes that keep upstream's commercial services unreachable.
# Reads the resolved Release build settings rather than config/alt2tab.xcconfig, so a lost
# #include or an overriding local.xcconfig is caught too. The Test targets cannot cover this:
# they never include alt2tab.xcconfig (see its header comment).
# Usage: scripts/verify_fork_invariants.sh

set -euo pipefail

settings="$(xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -configuration Release -showBuildSettings)"
status=0

fail() { echo "FAIL: $*" >&2; status=1; }
setting() { sed -n "s/^ *$1 = //p" <<<"$settings"; }

expect() {
    local actual
    actual="$(setting "$1")"
    [[ "$actual" == "$2" ]] || fail "$1 is '$actual', expected '$2'"
}

expect PRODUCT_NAME Alt2Tab
expect PRODUCT_BUNDLE_IDENTIFIER com.vingt-douze.alt2tab
expect DOMAIN github.com/vingt-douze/alt2tab
expect API_DOMAIN alt2tab.invalid

for condition in ALT2TAB ALT2TAB_FORCE_PRO; do
    [[ " $(setting SWIFT_ACTIVE_COMPILATION_CONDITIONS) " == *" $condition "* ]] \
        || fail "SWIFT_ACTIVE_COMPILATION_CONDITIONS is missing $condition"
done

# xcodebuild omits a setting whose value is empty, so a re-introduced secret is what shows up.
for secret in APPCENTER_SECRET SPARKLE_PUBLIC_ED_KEY; do
    [[ -z "$(setting "$secret")" ]] || fail "$secret is not empty"
done

# The build setting alone does not prove the flag is still read; the early return is the unlock.
grep -qE '#if +ALT2TAB_FORCE_PRO *$' src/pro/license/LicenseManager.swift \
    || fail "LicenseManager.swift no longer guards computeState() with ALT2TAB_FORCE_PRO"

if [[ $status -ne 0 ]]; then
    exit 1
fi
echo "Alt²Tab invariants OK"
