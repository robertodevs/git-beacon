#!/bin/sh
# Wraps the SwiftPM debug build in a minimal .app bundle and launches it via
# `open`. Needed for anything that requires a registered application bundle
# (UNUserNotificationCenter, in particular) — a raw `swift build`/`swift run`
# binary, and Xcode's SwiftPM "Run" for an executableTarget, are both bare
# Mach-O executables with no Info.plist and no Launch Services registration,
# so notification authorization fails on those even though Bundle.main
# reports the right bundle identifier (see Sources/GitBeacon/Info.plist,
# embedded via linker section for that part).
set -e

cd "$(dirname "$0")/.."

swift build

APP=".build/GitBeacon.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/GitBeacon "$APP/Contents/MacOS/GitBeacon"
cp Sources/GitBeacon/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

open "$APP"
