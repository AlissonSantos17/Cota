#!/bin/bash
# Rewrites Sources, Tests and Package.swift with swift-format.
set -e

swift format format \
  --in-place \
  --recursive \
  --parallel \
  Sources Tests Package.swift \
  "$@"
