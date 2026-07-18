#!/usr/bin/env python3
# group parity batch 5 (fix round): media delivery revert (waves dropped
# chunks), search red-box fix (per-index jump keys), discord-style shared
# pins, preview card fills the bubble. run from ~/halo/mobile.
import os, subprocess, sys
assert os.path.exists('lib/main.dart'), 'run from ~/halo/mobile'
for st in ['p17_chunk_revert.py', 'p18_jump_keys.py', 'p19_pin_sync.py',
           'p20_preview_fill.py',
           'p21_audit_fixes.py']:
    subprocess.run([sys.executable, st], check=True)
print('parity batch 5 applied')
