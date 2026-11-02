#!/usr/bin/env python3
# Copyright (c) 2026 silentrosehill
# SPDX-License-Identifier: GPL-3.0-or-later
"""Backed-up atomic overlay/full installs. No settings or account data are changed."""
import os
import fcntl
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import tempfile
from contextlib import ExitStack
from datetime import datetime


def verify_helper(source):
    with (source / 'Contents/Info.plist').open('rb') as file:
        info = plistlib.load(file)
    if info.get('CFBundleIdentifier') != 'local.discordglass.overlay' or info.get('CFBundleExecutable') != 'DiscordGlassOverlay':
        raise RuntimeError('This is not a DiscordGlass overlay bundle.')
    subprocess.run(['codesign', '--verify', '--strict', str(source)], check=True)


def replace_artifacts(items, support, record=False):
    support.mkdir(parents=True, exist_ok=True)
    fd = os.open(support / '.update.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another DiscordGlass update is in progress.')
        return replace_locked(items, support, record)


def replace_locked(items, support, record):
    backup = support / 'backups' / (datetime.now().strftime('%Y%m%d-%H%M%S-%f') + f'-{os.getpid()}')
    backup.mkdir(parents=True, mode=0o700)
    replaced = []
    with ExitStack() as cleanup:
        staged = []
        for source, target, label in items:
            if target.is_symlink() or target.parent.is_symlink():
                raise RuntimeError('Refusing to replace a linked installation folder.')
            if not source.is_dir() or any(p.is_symlink() for p in source.rglob('*')):
                raise RuntimeError('Invalid or linked update files.')
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = cleanup.enter_context(tempfile.TemporaryDirectory(prefix='.discordglass-', dir=target.parent))
            copy = Path(temp) / 'new'
            shutil.copytree(source, copy)
            if source.suffix == '.app':
                verify_helper(copy)
            staged.append((copy, target, label))
        try:
            for copy, target, label in staged:
                old = backup / label if target.exists() else None
                if old:
                    target.rename(old)
                replaced.append((target, old))
                copy.rename(target)
            if record:
                receipt = support / 'latest-backup.txt'
                with tempfile.NamedTemporaryFile(mode='w', dir=support, delete=False) as file:
                    temporary_receipt = Path(file.name)
                    file.write(str(backup) + '\n')
                try:
                    temporary_receipt.replace(receipt)
                finally:
                    temporary_receipt.unlink(missing_ok=True)
        except BaseException:
            for target, old in reversed(replaced):
                if target.exists():
                    shutil.rmtree(target)
                if old:
                    old.rename(target)
            raise
    return backup


def update_overlay(source, target):
    if not target.is_dir() or target.is_symlink():
        raise RuntimeError('Install DiscordGlass with the patch app first.')
    verify_helper(source)
    binary = 'Contents/MacOS/DiscordGlassOverlay'
    expected = str(target / binary)
    processes = subprocess.run(['ps', '-axo', 'pid=,comm='], capture_output=True, text=True, check=True).stdout
    pids = [int(parts[0]) for line in processes.splitlines()
            if len(parts := line.strip().split(None, 1)) == 2 and parts[1] == expected]
    backup = replace_artifacts([(source, target, target.name)], target.parent)
    for pid in pids:
        current = subprocess.run(['ps', '-p', str(pid), '-o', 'comm='], capture_output=True, text=True).stdout.strip()
        if current in (expected, str(backup / target.name / binary)):
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
    return backup / target.name


def install_all(source, vencord, support):
    result = subprocess.run(['pgrep', '-f', r'/Discord( PTB| Canary)?\.app/Contents/MacOS/Discord'], capture_output=True)
    if result.returncode == 0:
        raise RuntimeError('Quit Discord completely before updating the plugin.')
    if result.returncode != 1:
        raise RuntimeError('Could not check whether Discord is running.')
    if not (vencord / 'patcher.js').is_file():
        raise RuntimeError('Install Vencord for Discord Desktop first: https://vencord.dev/download/')
    for name in ['patcher.js', 'preload.js', 'renderer.js', 'renderer.css', 'package.json']:
        if not (source / 'Vencord-dist' / name).is_file():
            raise RuntimeError('The plugin update is incomplete.')
    helper = source / 'DiscordGlass Overlay.app'
    verify_helper(helper)
    backup = replace_artifacts([(helper, support / helper.name, helper.name),
                                (source / 'Vencord-dist', vencord, 'Vencord-dist')], support, record=True)
    return backup


if __name__ == '__main__':
    source = Path(__file__).resolve().parent / 'DiscordGlass Overlay.app'
    target = Path.home() / 'Library/Application Support/DiscordGlass/DiscordGlass Overlay.app'
    try:
        backup = update_overlay(source, target)
        print('Overlay updated. Discord stays open; an active overlay returns automatically in a moment.')
        print(f'Previous overlay: {backup}')
    except Exception as error:
        raise SystemExit(f'Overlay update failed: {error}')
