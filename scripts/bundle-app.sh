#!/bin/sh
# Builds a release binary and wraps it in build/Livewall.app (ad-hoc signed).
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Livewall.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Livewall "$APP/Contents/MacOS/Livewall"
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
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>es</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Done: $APP"
