#!/bin/bash
# Rebuilds Cota.app/Contents/Resources/AppIcon.icns from the SVGs in Design/.
set -e

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
swift scripts/render-icon.swift Design/icon.svg Design/icon-small.svg "$ICONSET"

mkdir -p Cota.app/Contents/Resources
iconutil -c icns "$ICONSET" -o Cota.app/Contents/Resources/AppIcon.icns
echo "AppIcon.icns atualizado."
