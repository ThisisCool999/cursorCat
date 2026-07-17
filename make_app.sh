#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="Mochi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -swift-version 5 -O src/*.swift -o "$APP/Contents/MacOS/Mochi"

codesign --force --sign - "$APP" 2>/dev/null

echo "built $APP"
echo "run:   open \"$PWD/$APP\""
