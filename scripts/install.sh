#!/bin/sh
# Installs (or reinstalls) the latest Livewall release into /Applications and opens it.
# Usage: curl -fsSL https://raw.githubusercontent.com/JohnTenno/livewall-macos/main/scripts/install.sh | sh
# curl does not add the quarantine flag, so macOS opens the app without the "could not verify" warning.
set -e

ZIP_URL="https://github.com/JohnTenno/livewall-macos/releases/latest/download/Livewall.zip"
TARGET="/Applications/Livewall.app"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading the latest Livewall…"
curl -fL --progress-bar "$ZIP_URL" -o "$WORK/Livewall.zip"
ditto -x -k "$WORK/Livewall.zip" "$WORK"
[ -d "$WORK/Livewall.app" ] || { echo "The download does not contain Livewall.app" >&2; exit 1; }

pkill -x Livewall 2>/dev/null && sleep 1 || true
rm -rf "$TARGET"
mv "$WORK/Livewall.app" "$TARGET"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true

echo "Installed $(defaults read "$TARGET/Contents/Info" CFBundleShortVersionString) in $TARGET"
open "$TARGET"
