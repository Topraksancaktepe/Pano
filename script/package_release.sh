#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PANO_BUILD_CONFIGURATION=release PANO_UNIVERSAL=1 ./script/build_and_run.sh --build-only
APP_BUNDLE="$ROOT_DIR/outputs/Pano.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/work/pano-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

codesign --verify --strict "$APP_BUNDLE"
ARCHITECTURES="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/Pano")"
for REQUIRED_ARCH in arm64 x86_64; do
    case " $ARCHITECTURES " in
        *" $REQUIRED_ARCH "*) ;;
        *) printf 'Missing required architecture: %s\n' "$REQUIRED_ARCH" >&2; exit 1 ;;
    esac
done
ditto "$APP_BUNDLE" "$STAGING_DIR/Pano.app"
ln -s /Applications "$STAGING_DIR/Applications"
cat > "$STAGING_DIR/Install Pano.txt" <<'INSTALL'
Install Pano

1. Quit an older running version of Pano before updating.
2. Drag Pano into Applications. Choose Replace if asked.
3. Eject this disk image, then open Pano from Applications.
4. Allow Accessibility and Screen Recording when Pano asks.
   An update may require granting these permissions again.

Use Command-Shift-4 to select an area. Pano copies it immediately and
plays the macOS capture sound. Click the bottom-right preview to edit.

Requires macOS 14 or later. Supports Apple Silicon and Intel Macs.
This build is ad-hoc signed and is not notarized by Apple. macOS may
block the first launch; if you trust this download, review the notice
in System Settings > Privacy & Security and use Open Anyway.

Source and updates: https://github.com/Topraksancaktepe/Pano
INSTALL

DMG_NAME="Pano-${VERSION}-macOS.dmg"
hdiutil create -volname "Pano ${VERSION}" -srcfolder "$STAGING_DIR" \
    -ov -format UDZO "$ROOT_DIR/outputs/$DMG_NAME"
hdiutil verify "$ROOT_DIR/outputs/$DMG_NAME"
cd "$ROOT_DIR/outputs"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
printf 'Release package: %s\n' "$ROOT_DIR/outputs/$DMG_NAME"
