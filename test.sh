#!/usr/bin/env bash
set -euo pipefail

# Runs the CrosshairCore unit tests.
#
# swift-testing ships inside CommandLineTools, but `swift test` on a CLT-only
# toolchain (no full Xcode) builds the test bundle and then skips the execute
# phase unless a -Xswiftc flag is present on the command line. Package.swift
# already points the test target at the framework and the lib_TestingInterop
# dylib; the redundant -Xswiftc -F below is what makes the driver actually run
# the tests.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

readonly FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

exec swift test -Xswiftc -F -Xswiftc "$FRAMEWORKS"
