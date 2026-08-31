#!/bin/bash
set -e

killall Cota 2>/dev/null || true
sleep 1

swift build

cp .build/arm64-apple-macosx/debug/Cota Cota.app/Contents/MacOS/Cota

codesign --force --sign - --identifier "com.alissonfelp.Cota" Cota.app

open Cota.app
echo "Cota atualizado e iniciado."
