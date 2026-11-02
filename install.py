#!/usr/bin/env python3
# Copyright (c) 2026 silentrosehill
# SPDX-License-Identifier: GPL-3.0-or-later
import sys
sys.dont_write_bytecode = True
import importlib.util
from pathlib import Path

source = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('updater', source / 'update-overlay.py')
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)
if __name__ == '__main__':
    try:
        support = Path.home() / 'Library/Application Support'
        backup = updater.install_all(source, support / 'Vencord/dist', support / 'DiscordGlass')
        print('Installed. Enable DiscordGlass in Vencord’s Plugins settings if needed.')
        print(f'Previous version: {backup}')
    except Exception as error:
        raise SystemExit(f'Update failed: {error}')
