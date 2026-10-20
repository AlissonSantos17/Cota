#!/bin/bash
set -e

killall Cota 2>/dev/null || true
sleep 1

SDK_FLAGS=$(./scripts/sdk-flags.sh)
swift build $SDK_FLAGS
# The output directory depends on the build system (native wrote to
# arm64-apple-macosx/debug, swiftbuild writes to out/Products/Debug). Copying a
# fixed path shipped a stale binary once the toolchain changed.
BIN_PATH=$(swift build $SDK_FLAGS --show-bin-path)

mkdir -p Cota.app/Contents/MacOS
cp "$BIN_PATH/Cota" Cota.app/Contents/MacOS/Cota
# The strings ship in CotaKit's resource bundle. Bundle.module looks for it in
# Contents/Resources first; without it the app shows raw keys.
rm -rf Cota.app/Contents/Resources/Cota_CotaKit.bundle
cp -R "$BIN_PATH/Cota_CotaKit.bundle" Cota.app/Contents/Resources/

codesign --force --sign - --identifier "com.alissonfelp.Cota" Cota.app

open Cota.app
echo "Cota atualizado e iniciado."
