import sys
s = open('main.dart', encoding='utf-8').read()
orig = s

def swap(name, old, new, marker):
    global s
    if marker in s:
        print(f'{name}: already applied'); return
    if s.count(old) != 1:
        print(f'{name}: MISS ({s.count(old)})'); sys.exit(1)
    s = s.replace(old, new, 1); print(f'{name}: ok')

# BUG 1: upsertContact update branch never writes accepted. re-pairing over a
# back-paired stub (accepted:0) leaves it stuck as a pending request forever -
# the asymmetric "their messages don't come through after delete + re-pair".
# an explicit accept must win; and it must never DOWNGRADE an accepted contact.
swap(
    'upsert-accepted',
    """      await db.update(
        'contacts',
        {
          'onion': onion,
          'xpub': xpub,
          'last_seen': now,
          if (changed) 'key_changed': 1,
          if (changed) 'verified': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );""",
    """      // only ever raise accepted (0->1 on an explicit re-pair), never lower
      // it: a back-pair passing accepted:0 must not demote a real contact.
      final priorAccepted = (existing.first['accepted'] as int?) ?? 0;
      final nextAccepted = accepted == 1 ? 1 : priorAccepted;
      await db.update(
        'contacts',
        {
          'onion': onion,
          'xpub': xpub,
          'last_seen': now,
          'accepted': nextAccepted,
          if (changed) 'key_changed': 1,
          if (changed) 'verified': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );""",
    marker="final priorAccepted = (existing.first['accepted']",
)

if s != orig:
    open('main.dart', 'w', encoding='utf-8').write(s)
print('main audit2 ok')
