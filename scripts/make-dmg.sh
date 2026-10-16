#!/bin/bash
# Builds a release Cota.app and packs it into dist/Cota-<version>.dmg, with an
# Applications shortcut so the app can be dragged in to install.
#
# The app is signed ad hoc, not with a Developer ID, so it is not notarized:
# Gatekeeper blocks it when the DMG is downloaded on another Mac.
set -e

SDK_FLAGS=$(./scripts/sdk-flags.sh)
swift build -c release $SDK_FLAGS
BIN_PATH=$(swift build -c release $SDK_FLAGS --show-bin-path)

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Cota.app/Contents/Info.plist)
STAGING=$(mktemp -d)/Cota

mkdir -p "$STAGING/Cota.app/Contents/MacOS"
cp Cota.app/Contents/Info.plist "$STAGING/Cota.app/Contents/"
cp -R Cota.app/Contents/Resources "$STAGING/Cota.app/Contents/"
cp "$BIN_PATH/Cota" "$STAGING/Cota.app/Contents/MacOS/Cota"
codesign --force --sign - --identifier "com.alissonfelp.Cota" "$STAGING/Cota.app"
ln -s /Applications "$STAGING/Applications"

mkdir -p dist
DMG="dist/Cota-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Cota" -srcfolder "$STAGING" -format UDZO -ov "$DMG" >/dev/null
echo "Instalador gerado: $DMG"
