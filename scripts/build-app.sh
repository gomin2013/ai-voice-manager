#!/bin/bash
# Assembles build/AIVoiceManager.app from `swift build` (no .xcodeproj, no helper — ADR-001).
# Usage: scripts/build-app.sh [debug|release]
#   SIGN_ID="Developer ID Application: ..." to sign for distribution (default: ad-hoc "-").
set -euo pipefail

CONFIG="${1:-release}"
SIGN_ID="${SIGN_ID:--}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/AIVoiceManager.app"

cd "$ROOT"
# SwiftPM stamps the binary "sdk 14.0" (the deployment target) whatever SDK compiled it, and macOS 26 then draws it
# the pre-26 way — no Liquid Glass. Stamp the real SDK; the minimum stays macOS 14 (same fix as hosts-manager).
SDK_VERSION="$(xcrun --show-sdk-version)"
LINK_SDK=(-Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker "$SDK_VERSION")
swift build -c "$CONFIG" "${LINK_SDK[@]}"
BIN="$(swift build -c "$CONFIG" "${LINK_SDK[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp Sources/AIVoiceManagerApp/Info.plist "$APP/Contents/Info.plist"
cp "$BIN/AIVoiceManager" "$APP/Contents/MacOS/"
# .lproj at the bundle root, where Bundle.main looks (SwiftPM's resource bundle alone isn't found by a .app)
cp -R Sources/AIVoiceManagerApp/Resources/*.lproj "$APP/Contents/Resources/"
# Icons (regenerate: swift scripts/make-icon.swift): Assets.car for macOS 26+, AppIcon.icns for 14–15
cp Packaging/Assets.car Packaging/AppIcon.icns "$APP/Contents/Resources/"
# Voice portraits, expression and style icons (cut from the prototype's sheets, .claude/docs/design/)
cp -R Sources/AIVoiceManagerApp/Art "$APP/Contents/Resources/"

codesign --force --options runtime --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP"

echo "Built $APP"
