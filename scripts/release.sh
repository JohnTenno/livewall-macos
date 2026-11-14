#!/bin/sh
# Builds Livewall at the given version and publishes it as a GitHub release the in-app updater picks up.
# Usage: ./scripts/release.sh 0.2.0
#
# Optional, with a paid Apple Developer account (removes the "could not verify… malware" warning):
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"  signs with Developer ID + hardened runtime
#   NOTARY_PROFILE=livewall                                   notarizes and staples; create the profile once with
#     xcrun notarytool store-credentials livewall --apple-id <id> --team-id <TEAMID> --password <app-specific password>
set -e
cd "$(dirname "$0")/.."
VERSION="${1:?usage: release.sh <version, e.g. 0.2.0>}"
case "$VERSION" in *[!0-9.]*|"") echo "Version must be digits and dots" >&2; exit 1 ;; esac
[ -z "$(git status --porcelain)" ] || { echo "Commit your changes first" >&2; exit 1; }
if [ -n "$NOTARY_PROFILE" ] && [ -z "$SIGN_IDENTITY" ]; then
    echo "NOTARY_PROFILE needs SIGN_IDENTITY: Apple only notarizes Developer ID signed apps" >&2; exit 1
fi

./scripts/test.sh
VERSION="$VERSION" BUILD="$(git rev-list --count HEAD)" ./scripts/bundle-app.sh
rm -f build/Livewall.zip
ditto -c -k --keepParent build/Livewall.app build/Livewall.zip

if [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool submit build/Livewall.zip --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple build/Livewall.app
    spctl --assess --type execute --verbose build/Livewall.app
    # Re-zip so the published app carries the stapled ticket and opens offline without a warning.
    rm -f build/Livewall.zip
    ditto -c -k --keepParent build/Livewall.app build/Livewall.zip
fi

git tag "v$VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" build/Livewall.zip --title "Livewall $VERSION" --generate-notes
