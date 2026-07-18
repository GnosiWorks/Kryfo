#!/usr/bin/env python3
# parity 5c: the four pending patches + the jump-system rewrite that fixes the
# sliver crash and the stuck sends it was causing. p17 already landed on the
# device tree. run from ~/halo/mobile.
import os, subprocess, sys
assert os.path.exists('lib/main.dart'), 'run from ~/halo/mobile'
for st in ['p18_jump_keys.py', 'p19_pin_sync.py', 'p20_preview_fill.py',
           'p21_audit_fixes.py', 'p22_jump_by_uid.py']:
    subprocess.run([sys.executable, st], check=True)
print('parity 5c applied')
