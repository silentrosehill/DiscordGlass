#!/usr/bin/env python3
import json, subprocess
from pathlib import Path
binary = Path(__file__).resolve().parent / 'DiscordGlass Overlay.app/Contents/MacOS/DiscordGlassOverlay'
valid = dict(version=1, channel='Test', corner='topRight', people=[dict(id='1', name='<plain text>', speaking=True, muted=False, deaf=False)])
cases = [(valid, True), (dict(valid, version=2), False), (dict(valid, corner='invalid'), False),
         (dict(valid, people=[dict(valid['people'][0], name='x'*257)]), False),
         (dict(valid, people=[dict(valid['people'][0], speaking='yes')]), False),
         (dict(valid, people=valid['people']*101), False)]
cases += [(dict(valid, corner='custom', glassOpacity=0, editPosition=True), True),
          (dict(valid, glassOpacity=1), True), (dict(valid, glassOpacity=-0.1), False),
          (dict(valid, glassOpacity=1.1), False), (dict(valid, editPosition='yes'), False)]
cases += [(dict(valid, people=[dict(valid['people'][0], avatarURL='https://cdn.discordapp.com/embed/avatars/0.png')]), True),
          (dict(valid, people=[dict(valid['people'][0], avatarURL='x'*2049)]), False)]
cases += [(dict(valid, channelId='voice', canSetVolume=True, people=[dict(valid['people'][0], volume=75, isSelf=False)]), True),
          (dict(valid, people=[dict(valid['people'][0], volume=-1)]), False),
          (dict(valid, people=[dict(valid['people'][0], volume=201)]), False),
          (dict(valid, channelId='x'*65), False), (dict(valid, canSetVolume='yes'), False)]
for packet, expected in cases:
    result = subprocess.run([str(binary), '--validate'], input=json.dumps(packet), text=True, capture_output=True)
    assert (result.returncode == 0) == expected, result.stderr
subprocess.run([str(binary), '--test-placement'], check=True)
print(f'{len(cases)} native protocol checks passed')
