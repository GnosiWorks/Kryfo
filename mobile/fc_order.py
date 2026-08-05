#!/usr/bin/env python3
# the first-contact runner reads the relay list once when it starts. it was
# starting before that list existed, so it found nothing to connect to and
# exited without ever subscribing. run from ~/halo/mobile.
import io

p = 'lib/main.dart'
s = io.open(p, encoding='utf-8').read()

old = """    startOutboxDrain();
    _loadBackupFlags();
    _loadFirstContact();"""
c = s.count(old)
assert c == 1, f"boot anchor x{c}"
s = s.replace(old, """    startOutboxDrain();
    _loadBackupFlags();""")

old = """      'wss://nostr.oxtr.dev',
    );
    await loadDisplayName();"""
c = s.count(old)
assert c == 1, f"nostr init anchor x{c}"
s = s.replace(
    old,
    """      'wss://nostr.oxtr.dev',
    );
    // has to follow the relay list: the runner snapshots it on start and
    // gives up if it is empty.
    _loadFirstContact();
    await loadDisplayName();""",
)

io.open(p, 'w', encoding='utf-8').write(s)
print('order fixed')
