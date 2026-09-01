#!/bin/bash
# swift-testing ships inside Xcode. On a machine with only the Command Line
# Tools the framework is present but off the search and runtime paths, so
# `swift test` fails to build and then fails to load. These flags point at it.
set -e

FRAMEWORKS=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIBS=/Library/Developer/CommandLineTools/Library/Developer/usr/lib

swift test \
  -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
  -Xlinker -F -Xlinker "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$LIBS" \
  "$@"
