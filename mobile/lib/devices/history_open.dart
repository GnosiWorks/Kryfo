// SPDX-License-Identifier: GPL-3.0-or-later
// the history copies a phone has open. a chat hidden while one is open must
// not reach the new device, and its rows may already be in the spool: a hide
// ends every open copy, and the device then discards what it took
final _open = <void Function()>{};

/// [end] runs when a hide ends the copy; the returned function takes it off
/// the list once the copy closes by itself
void Function() historyCopyOpened(void Function() end) {
  _open.add(end);
  return () => _open.remove(end);
}

/// a chat went into the vault: every open copy ends
void endHistoryCopies() {
  for (final end in [..._open]) {
    end();
  }
  _open.clear();
}

/// how many copies are open, for tests
int get historyCopiesOpen => _open.length;
