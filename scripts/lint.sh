#!/bin/bash
# Fails if swift-format or SwiftLint report issues.
set -e

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "SwiftLint não encontrado. Instale com: brew install swiftlint" >&2
  exit 1
fi

echo "==> swift-format"
swift format lint \
  --strict \
  --recursive \
  --parallel \
  Sources Tests Package.swift

echo "==> SwiftLint"
# SourceKit is missing on Command Line Tools-only setups (no full Xcode).
# Most rules do not need it.
swiftlint lint --strict --disable-sourcekit
