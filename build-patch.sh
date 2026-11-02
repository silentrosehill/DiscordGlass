#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP='DiscordGlass Patch.app'
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Payload"
swiftc -O -target "$(uname -m)-apple-macos15" -swift-version 5 Patch/main.swift -o "$APP/Contents/MacOS/DiscordGlassPatch"
for name in 'DiscordGlass Overlay.app' Vencord-dist Install.command install.py update-overlay.py; do
  ditto "$name" "$APP/Contents/Resources/Payload/$name"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>local.discordglass.patch</string><key>CFBundleName</key><string>DiscordGlass Patch</string><key>CFBundleExecutable</key><string>DiscordGlassPatch</string><key>CFBundleShortVersionString</key><string>1.0.0</string><key>CFBundleVersion</key><string>1</string><key>NSHumanReadableCopyright</key><string>Copyright © 2026 silentrosehill</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>15.0</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
cp LICENSE UPSTREAM.txt "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
# The Desktop app is the user's canonical updater; refresh it after every completed update.
/usr/bin/python3 - <<'PYREFRESH'
from pathlib import Path
import shutil, tempfile
from datetime import datetime
source=Path('DiscordGlass Patch.app')
target=Path.home()/'Desktop/DiscordGlass Patch.app'
with tempfile.TemporaryDirectory(prefix='.discordglass-patch-', dir=target.parent) as temporary:
    staged=Path(temporary)/source.name
    shutil.copytree(source, staged, symlinks=True)
    backup=None
    if target.exists():
        backup=Path.home()/'Library/Application Support/DiscordGlass/backups'/('patch-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f'))/target.name
        backup.parent.mkdir(parents=True)
        target.rename(backup)
    try: staged.rename(target)
    except BaseException:
        if backup: backup.rename(target)
        raise
PYREFRESH
