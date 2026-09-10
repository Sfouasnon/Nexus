#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK_ROOT="/Applications/Blackmagic ATEM Switchers/Developer SDK/Mac OS X"
INCLUDE="$SDK_ROOT/include"
APP="build/Nexus.app/Contents"
mkdir -p build/objects "$APP/MacOS" "$APP/Resources" "$APP/Helpers"
python3 Tools/generate_video_modes.py --header "$INCLUDE/BMDSwitcherAPI.h" --output Sources/ATEM/ATEMVideoModeTable.inc
arch="$(uname -m)"
for source in Sources/ATEM/*Controller.mm Sources/NexusBridge.mm "$INCLUDE/BMDSwitcherAPIDispatch.cpp"; do
    object="build/objects/$(basename "${source%.*}").o"
    xcrun clang++ -std=c++17 -fobjc-arc -fblocks -Wno-deprecated-declarations -arch "$arch" -mmacosx-version-min=14.0 -I"$INCLUDE" -ISources -ISources/ATEM -c "$source" -o "$object"
done
xcrun swiftc -parse-as-library -swift-version 5 -D DEBUG -import-objc-header Sources/NexusBridge.h \
    -module-name Nexus -target "$arch-apple-macos14.0" \
    Sources/NexusApp.swift $(find Sources/Videohub -name '*.swift' -print) build/objects/*.o \
    -framework Cocoa -framework CoreFoundation -lc++ -o "$APP/MacOS/Nexus"
xcrun clang++ -std=c++17 -fobjc-arc -fblocks -Wno-deprecated-declarations -arch "$arch" -mmacosx-version-min=14.0 \
    -I"$INCLUDE" -ISources/ATEM Sources/ATEM/CameraHelperMain.mm "$INCLUDE/BMDSwitcherAPIDispatch.cpp" \
    -framework Cocoa -framework CoreFoundation -o "$APP/Helpers/ATEMCameraHelper"
cp Resources/Info.plist "$APP/Info.plist"
cp Resources/Nexus.icns "$APP/Resources/"
cp Resources/Brand/Nexus-AppIcon.png "$APP/Resources/"
codesign --force --sign - "$APP/Helpers/ATEMCameraHelper"
codesign --force --deep --sign - build/Nexus.app
codesign --verify --deep --strict build/Nexus.app
plutil -lint "$APP/Info.plist"
