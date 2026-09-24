#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# the few words android shows itself (the service's notification and its
# channel) come from the same arb files as the rest, as android string
# resources. every key that starts with "android" in lib/l10n/app_*.arb
# becomes res/values[-xx]/strings.xml.
#
# usage: tool/arb_android.py   (from mobile/, after an arb changes)
import glob
import json
import os
import re
from xml.sax.saxutils import escape

here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(here, 'android/app/src/main/res')


def qualifier(loc):
    # app_zh_Hant -> b+zh+Hant, app_pt_BR -> pt-rBR, app_en -> '' (default)
    parts = loc.split('_')
    if parts == ['en']:
        return ''
    if len(parts) == 2 and len(parts[1]) == 4:
        return 'b+' + '+'.join(parts)
    if len(parts) == 2:
        return f'{parts[0]}-r{parts[1]}'
    return parts[0]


def res_name(key):
    # androidServiceTitle -> service_title
    k = key[len('android'):]
    return re.sub(r'(?<!^)([A-Z])', r'_\1', k).lower()


def android_text(s):
    s = escape(s)
    return s.replace('\\', '\\\\').replace("'", "\\'").replace('"', '\\"').replace('\n', '\\n')


for path in sorted(glob.glob(os.path.join(here, 'lib/l10n/app_*.arb'))):
    loc = os.path.basename(path)[len('app_'):-len('.arb')]
    arb = json.load(open(path, encoding='utf-8'))
    keys = [k for k in arb if k.startswith('android')]
    if not keys:
        continue
    q = qualifier(loc)
    d = os.path.join(res, 'values' + ('-' + q if q else ''))
    os.makedirs(d, exist_ok=True)
    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             '<!-- written by tool/arb_android.py from lib/l10n/app_%s.arb -->' % loc,
             '<resources>']
    for k in keys:
        lines.append(f'    <string name="{res_name(k)}">{android_text(arb[k])}</string>')
    lines.append('</resources>')
    open(os.path.join(d, 'strings.xml'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print(os.path.relpath(os.path.join(d, 'strings.xml'), here))
