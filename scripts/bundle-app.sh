#!/bin/sh
# Builds a release binary and wraps it in build/Livewall.app.
# Signs ad-hoc, or with Developer ID when SIGN_IDENTITY is set (e.g. "Developer ID Application: Name (TEAMID)").
set -e
cd "$(dirname "$0")/.."
DEFAULT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.3.2")
VERSION="${VERSION:-$DEFAULT_VERSION}"
swift build -c release
APP="build/Livewall.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Livewall "$APP/Contents/MacOS/Livewall"
cp -R Localization/*.lproj "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Livewall</string>
  <key>CFBundleDisplayName</key><string>Livewall</string>
  <key>CFBundleIdentifier</key><string>com.tenno.livewall</string>
  <key>CFBundleExecutable</key><string>Livewall</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION:-0.1.0}</string>
  <key>CFBundleVersion</key><string>${BUILD:-1}</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
if [ -n "$SIGN_IDENTITY" ]; then
    # Developer ID + hardened runtime: what notarization requires.
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
echo "Done: $APP"
