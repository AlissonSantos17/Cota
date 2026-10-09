#!/bin/bash
# Prints `--sdk <path>` when only the Command Line Tools are selected.
#
# From the macOS 27 SDK, SwiftUI's @State is a macro whose plugin
# (SwiftUIMacros) ships with Xcode and not with the Command Line Tools, so the
# app target fails to build. The 26 SDK, which the Command Line Tools still
# carry, declares it as a property wrapper. With Xcode selected this prints
# nothing and the default SDK is used.
CLT=/Library/Developer/CommandLineTools
SDK="$CLT/SDKs/MacOSX26.sdk"

if [ "$(xcode-select -p 2>/dev/null)" = "$CLT" ] && [ -d "$SDK" ]; then
  echo "--sdk $SDK"
fi
