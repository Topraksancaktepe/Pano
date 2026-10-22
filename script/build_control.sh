#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_BUNDLE="$ROOT_DIR/outputs/Pano Kontrol.app"
./script/swift.sh build --product PanoControl
BUILD_DIR="$(./script/swift.sh build --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/PanoControl" "$APP_BUNDLE/Contents/MacOS/PanoControl"
chmod +x "$APP_BUNDLE/Contents/MacOS/PanoControl"
cp /Applications/Pano.app/Contents/Resources/Pano.icns "$APP_BUNDLE/Contents/Resources/Pano.icns"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PanoControl</string>
<key>CFBundleIdentifier</key><string>local.toprak.PanoControl</string>
<key>CFBundleName</key><string>Pano</string>
<key>CFBundleDisplayName</key><string>Pano</string>
<key>CFBundleIconFile</key><string>Pano</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.2</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.toprak.PanoControl "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
if [ "${1:---build-only}" = "--run" ]; then open "$APP_BUNDLE"; fi
