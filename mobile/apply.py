#!/usr/bin/env python3
# just the two missing pieces: group sent-tick + unread debug line.
# (chunk + caption fixes already applied.) run from ~/halo/mobile.
import os, subprocess, sys
assert os.path.exists('lib/main.dart'), 'run from ~/halo/mobile'
for s in ['fix_tick.py', 'dbg_unread.py']:
    subprocess.run([sys.executable, s], check=True)
print('tick + debug applied')
