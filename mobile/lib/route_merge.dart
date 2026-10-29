// SPDX-License-Identifier: GPL-3.0-or-later
// relay and fast are one route now, kept under the relay's old id
// 'balanced' and shown as fast: our two servers, nothing else in the clear.
// whoever was on either moves there, and hears of it once.

/// the route the app starts on, whatever an older version or a backup kept
String routeAtBoot(String? stored) => switch (stored) {
  'balanced' || 'fast' => 'balanced',
  _ => 'private',
};

/// a mode the app is asked for, as the app runs it
String routeOf(String m) => m == 'fast' ? 'balanced' : m;

/// where the one-time card about the merge stands. 'due' until it is seen
const kRouteMergeNote = 'route_merge_note';

/// the card's state at a start that found none: due for whoever was on
/// relay or fast before, never for anyone else
String routeMergeNoteAt(String? stored) =>
    stored == 'balanced' || stored == 'fast' ? 'due' : 'done';
