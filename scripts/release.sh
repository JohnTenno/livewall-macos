#!/bin/sh
# Builds Livewall at the given version and publishes it as a GitHub release the in-app updater picks up.
# Usage: ./scripts/release.sh 0.2.0
set -e
cd "$(dirname "$0")/.."
VERSION="${1:?usage: release.sh <version, e.g. 0.2.0>}"
case "$VERSION" in *[!0-9.]*|"") echo "Version must be digits and dots" >&2; exit 1 ;; esac
[ -z "$(git status --porcelain)" ] || { echo "Commit your changes first" >&2; exit 1; }

./scripts/test.sh
VERSION="$VERSION" BUILD="$(git rev-list --count HEAD)" ./scripts/bundle-app.sh
rm -f build/Livewall.zip
ditto -c -k --keepParent build/Livewall.app build/Livewall.zip

git tag "v$VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" build/Livewall.zip --title "Livewall $VERSION" --generate-notes
