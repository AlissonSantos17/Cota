#!/bin/bash
set -e

killall Cota 2>/dev/null || true
sleep 1

swift build

cp .build/arm64-apple-macosx/debug/Cota Cota.app/Contents/MacOS/Cota

open Cota.app
echo "Cota atualizado e iniciado."
