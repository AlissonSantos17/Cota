#!/bin/bash
# Runs the test suite. On a machine with only the Command Line Tools the app
# target needs an older SDK to build; see sdk-flags.sh. The current Command
# Line Tools find swift-testing on their own, and the -F/-rpath flags this
# script used to pass now load a copy whose macro plugin cannot be found.
#
# The Command Line Tools keep swift-testing's macro plugin in a subdirectory
# (plugins/testing). The build system passes that path to the compiler on
# some builds and leaves it out on others, with no source change in between,
# and those builds fail with "plugin for module 'TestingMacros' not found".
# Passing the path ourselves makes every build find it. With Xcode selected
# the directory does not exist and nothing is added.
set -e

PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
EXTRA=()
if [ "$(xcode-select -p 2>/dev/null)" = /Library/Developer/CommandLineTools ] && [ -d "$PLUGINS" ]; then
  EXTRA=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS")
fi

swift test $("$(dirname "$0")"/sdk-flags.sh) "${EXTRA[@]}" "$@"
