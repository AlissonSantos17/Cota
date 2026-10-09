#!/bin/bash
# Runs the test suite. On a machine with only the Command Line Tools the app
# target needs an older SDK to build; see sdk-flags.sh. The current Command
# Line Tools find swift-testing on their own, and the -F/-rpath flags this
# script used to pass now load a copy whose macro plugin cannot be found.
set -e

swift test $("$(dirname "$0")"/sdk-flags.sh) "$@"
