#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="DiscordGlass Overlay.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -target "$(uname -m)-apple-macos15" -swift-version 5 Overlay/*.swift -o "$APP/Contents/MacOS/DiscordGlassOverlay"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>local.discordglass.overlay</string><key>CFBundleName</key><string>DiscordGlass Overlay</string><key>CFBundleExecutable</key><string>DiscordGlassOverlay</string><key>CFBundleShortVersionString</key><string>1.0.1</string><key>CFBundleVersion</key><string>2</string><key>NSHumanReadableCopyright</key><string>Copyright © 2026 silentrosehill</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/><key>LSMinimumSystemVersion</key><string>15.0</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
