#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('updater', root / 'update-overlay.py')
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)
source = root / 'DiscordGlass Overlay.app'
with tempfile.TemporaryDirectory() as directory:
    target = Path(directory) / source.name
    try:
        updater.update_overlay(source, target)
    except RuntimeError:
        pass
    else:
        raise AssertionError('Allowed missing initial installation')
    shutil.copytree(source, target)
    (target / 'old-build-marker').write_text('preserve')
    backup = updater.update_overlay(source, target)
    assert (backup / 'old-build-marker').read_text() == 'preserve'
    assert not (target / 'old-build-marker').exists()
    executable = target / 'Contents/MacOS/DiscordGlassOverlay'
    assert executable.is_file()
    try:
        updater.update_overlay(Path(directory) / 'missing-source.app', target)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    else:
        raise AssertionError('Allowed invalid source')
    assert executable.is_file()
print('Overlay-only update checks passed')

from unittest.mock import patch
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    old1, old2 = root / 'installed-one', root / 'installed-two'
    new1, new2 = root / 'new-one', root / 'new-two'
    for path, text in [(old1, 'old1'), (old2, 'old2'), (new1, 'new1'), (new2, 'new2')]:
        path.mkdir(); (path / 'value').write_text(text)
    rename = Path.rename
    def fail_second_stage(self, target):
        if self.name == 'new' and target == old2:
            raise OSError('simulated second artifact failure')
        return rename(self, target)
    with patch.object(Path, 'rename', fail_second_stage):
        try:
            updater.replace_artifacts([(new1, old1, 'one'), (new2, old2, 'two')], root / 'support')
        except OSError:
            pass
        else:
            raise AssertionError('Expected simulated failure')
    assert (old1 / 'value').read_text() == 'old1'
    assert (old2 / 'value').read_text() == 'old2'
    link = root / 'linked'; link.symlink_to(old1, target_is_directory=True)
    try:
        updater.replace_artifacts([(new1, link, 'link')], root / 'support')
    except RuntimeError:
        pass
    else:
        raise AssertionError('Allowed symlink target')
    assert (old1 / 'value').read_text() == 'old1'
print('Transaction rollback and linked-target checks passed')
