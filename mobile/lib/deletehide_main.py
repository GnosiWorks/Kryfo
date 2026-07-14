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

# THE REAL BUG: our relay subscription is per-contact, built at boot from the
# contact rows. dropping the row means we never subscribe to that peer's
# conversation address again - their messages go to a relay nobody is
# listening on. deleting a chat was silently a permanent block.
# so: keep the row (xpub intact, subscription alive), wipe the history, and
# park it as archived+unaccepted so it shows nowhere until they write again.
swap(
    'db-delete-keeps-row',
    """      await t.delete(
        'messages',
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      await t.delete('contacts', where: 'halo_id = ?', whereArgs: [haloId]);""",
    """      await t.delete(
        'messages',
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      // the row stays: it carries the xpub our nostr subscription is built
      // from. archived + unaccepted = invisible everywhere until they write.
      await t.update(
        'contacts',
        {'accepted': 0, 'archived': 1, 'unread': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );""",
    marker='// the row stays: it carries the xpub',
)

# requests must not list a parked row before they actually message us
swap(
    'requests-skip-archived',
    "      where: 'accepted = 0 AND blocked = 0',",
    "      where: 'accepted = 0 AND blocked = 0 AND archived = 0',",
    marker="where: 'accepted = 0 AND blocked = 0 AND archived = 0',",
)

swap(
    'requestcount-skip-archived',
    "      'SELECT COUNT(*) c FROM contacts WHERE accepted = 0 AND blocked = 0',",
    "      'SELECT COUNT(*) c FROM contacts WHERE accepted = 0 AND blocked = 0 AND archived = 0',",
    marker="FROM contacts WHERE accepted = 0 AND blocked = 0 AND archived = 0",
)

# a message from a parked peer un-parks them straight into requests
swap(
    'unpark-on-message',
    """    final burnOk = isGroup || await db.isAccepted(senderHaloId);""",
    """    // a deleted (parked) peer writing again surfaces as a fresh request.
    if (!isGroup) await db.unparkIfArchived(senderHaloId);
    final burnOk = isGroup || await db.isAccepted(senderHaloId);""",
    marker='unparkIfArchived(senderHaloId);',
)

swap(
    'db-unpark',
    """  Future<void> setArchived(String haloId, bool archived) async {""",
    """  // they wrote after we deleted them: bring the row back as a request.
  Future<void> unparkIfArchived(String haloId) async {
    final d = await open();
    final r = await d.query(
      'contacts',
      columns: ['archived', 'accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (r.isEmpty) return;
    final arch = (r.first['archived'] as int?) ?? 0;
    final acc = (r.first['accepted'] as int?) ?? 0;
    if (arch == 1 && acc == 0) {
      await d.update(
        'contacts',
        {'archived': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> setArchived(String haloId, bool archived) async {""",
    marker='Future<void> unparkIfArchived(',
)

# the app-level delete no longer needs to strip the xpub map - the row lives
swap(
    'app-delete-keeps-map',
    """    await db.deleteConversation(haloId);
    _xPubToHaloId.removeWhere((_, v) => v == haloId);
    await refreshContacts();
    notifyListeners();""",
    """    await db.deleteConversation(haloId);
    // keep _xPubToHaloId: the subscription and the row both survive so they
    // can still reach us, they just land in requests instead of a live chat.
    await refreshContacts();
    notifyListeners();""",
    marker='keep _xPubToHaloId: the subscription',
)

if s != orig:
    open('main.dart', 'w', encoding='utf-8').write(s)
print('main deletehide ok')
