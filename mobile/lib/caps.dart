// SPDX-License-Identifier: GPL-3.0-or-later
// what a person's Kryfo can do, as bits on every envelope it sends ('cp').
// kept per person with the time of the envelope that said it, and the
// newest word wins: a message from them without the bits, written after
// the newest one with them, is from an app that cannot, so a move back to
// an older version is seen
const kCapsWire = 'cp';

/// it blocks screenshots in groups (group_shots.dart)
const kCapGroupShots = 1 << 0;

/// what this version can do
const kCapsMine = kCapGroupShots;

// past this it is no bit list of ours
const _kCapsMost = (1 << 31) - 1;

/// the bits as the wire carries them, or null for none or a broken word
int? capsOf(Object? raw) =>
    raw is int && raw >= 0 && raw <= _kCapsMost ? raw : null;

bool capsHave(int caps, int bit) => caps & bit == bit;

/// what a person's bits and their stamp become after an envelope written
/// at [written] that carried [carried], or null when they stay. [counts]:
/// a message of theirs, which every app that has bits stamps, so one
/// without them is from an app that has none. a copy written before the
/// newest one changes nothing
({int caps, int at})? capsAfter(
  int caps,
  int at, {
  required int? carried,
  required bool counts,
  int? written,
}) {
  if (carried == null && !counts) return null;
  if (written == null || written <= 0) {
    // no time on it: bits are taken only where none were ever heard
    if (carried == null || at > 0 || carried == caps) return null;
    return (caps: carried, at: at);
  }
  if (written < at) return null;
  final next = carried ?? 0;
  // on a tie the one that carried bits stands
  if (written == at && (carried == null || next == caps)) return null;
  return (caps: next, at: written);
}
