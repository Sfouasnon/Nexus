#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK_ROOT="/Applications/Blackmagic ATEM Switchers/Developer SDK/Mac OS X"
INCLUDE="$SDK_ROOT/include"
STAGING_ROOT="build/.Nexus-build"
APP="$STAGING_ROOT/Nexus.app/Contents"
rm -rf "$STAGING_ROOT"
mkdir -p build/objects "$APP/MacOS" "$APP/Resources" "$APP/Helpers"
python3 Tools/generate_video_modes.py --header "$INCLUDE/BMDSwitcherAPI.h" --output Sources/ATEM/ATEMVideoModeTable.inc
arch="$(uname -m)"
for source in Sources/ATEM/*Controller.mm Sources/NexusBridge.mm "$INCLUDE/BMDSwitcherAPIDispatch.cpp"; do
    object="build/objects/$(basename "${source%.*}").o"
    xcrun clang++ -std=c++17 -fobjc-arc -fblocks -Wno-deprecated-declarations -arch "$arch" -mmacosx-version-min=14.0 -I"$INCLUDE" -ISources -ISources/ATEM -c "$source" -o "$object"
done
xcrun swiftc -parse-as-library -swift-version 5 -D DEBUG -import-objc-header Sources/NexusBridge.h \
    -module-name Nexus -target "$arch-apple-macos14.0" \
    Sources/NexusApp.swift $(find Sources/Videohub Sources/HyperDeck -name '*.swift' -print) build/objects/*.o \
    -framework Cocoa -framework CoreFoundation -framework Network -lc++ -o "$APP/MacOS/Nexus"
xcrun clang++ -std=c++17 -fobjc-arc -fblocks -Wno-deprecated-declarations -arch "$arch" -mmacosx-version-min=14.0 \
    -I"$INCLUDE" -ISources/ATEM Sources/ATEM/CameraHelperMain.mm "$INCLUDE/BMDSwitcherAPIDispatch.cpp" \
    -framework Cocoa -framework CoreFoundation -o "$APP/Helpers/ATEMCameraHelper"
cp Resources/Info.plist "$APP/Info.plist"
cp Resources/Nexus.icns "$APP/Resources/"
cp Resources/Brand/Nexus-AppIcon.png "$APP/Resources/"
ASSET_CATALOG="build/NexusAssets.xcassets"
APP_ICON_SET="$ASSET_CATALOG/AppIcon.appiconset"
mkdir -p "$APP_ICON_SET"
iconutil -c iconset Resources/Nexus.icns -o build/Nexus.iconset
cp build/Nexus.iconset/*.png "$APP_ICON_SET/"
cp Resources/AppIconContents.json "$APP_ICON_SET/Contents.json"
xcrun actool "$ASSET_CATALOG" --compile "$APP/Resources" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon AppIcon \
    --output-partial-info-plist build/AppIcon.plist
codesign --force --sign - "$APP/Helpers/ATEMCameraHelper"
codesign --force --deep --sign - "$STAGING_ROOT/Nexus.app"
codesign --verify --deep --strict "$STAGING_ROOT/Nexus.app"
plutil -lint "$APP/Info.plist"
rm -rf build/Nexus.app
mv "$STAGING_ROOT/Nexus.app" build/Nexus.app
touch build/Nexus.app
