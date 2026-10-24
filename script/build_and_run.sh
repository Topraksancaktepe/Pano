#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
APP_NAME="Pano"
BUNDLE_ID="local.toprak.Pano"
APP_BUNDLE="$ROOT_DIR/outputs/Pano.app"
case "$MODE" in run|--verify|--logs|--telemetry|--debug|--build-only) ;; *) exit 2 ;; esac
if [ "$MODE" != "--build-only" ]; then
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi
./script/swift.sh build
BUILD_DIR="$(./script/swift.sh build --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/Pano" "$APP_BUNDLE/Contents/MacOS/Pano"
chmod +x "$APP_BUNDLE/Contents/MacOS/Pano"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/work/clang-cache"
swift script/make_icon.swift "$ROOT_DIR/work/Pano.iconset"
iconutil -c icns "$ROOT_DIR/work/Pano.iconset" -o "$APP_BUNDLE/Contents/Resources/Pano.icns"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Pano</string>
<key>CFBundleIdentifier</key><string>local.toprak.Pano</string>
<key>CFBundleName</key><string>Pano</string>
<key>CFBundleDisplayName</key><string>Pano</string>
<key>CFBundleIconFile</key><string>Pano</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.4.1</string>
<key>CFBundleVersion</key><string>8</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>Toprak · 2026</string>
<key>NSScreenCaptureUsageDescription</key><string>Pano copies the screen area you select to your clipboard.</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
case "$MODE" in
  --build-only) ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/Pano" ;;
  --logs|--telemetry)
    open "$APP_BUNDLE"
    /usr/bin/log stream --level info --style compact --predicate 'subsystem == "local.toprak.Pano"'
    ;;
  --verify)
    open "$APP_BUNDLE"
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  run) open "$APP_BUNDLE" ;;
esac
