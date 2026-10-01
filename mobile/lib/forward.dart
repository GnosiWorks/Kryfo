// SPDX-License-Identifier: GPL-3.0-or-later
// what a forward carries and where it lands

// a forward carries words. a photo, a file, a voice note or a sticker has
// no way across yet, and its caption alone would pass for all of it
bool canForward({
  required String text,
  String? mediaPath,
  String? filePath,
  bool sticker = false,
}) => text.isNotEmpty && mediaPath == null && filePath == null && !sticker;

// the composer a forward opens on: what was already written there stays,
// with the forward under it
String composerWith(String draft, String? forward) {
  if (forward == null || forward.isEmpty) return draft;
  if (draft.trim().isEmpty) return forward;
  // the same forward opened twice is there once; words that merely contain
  // it are not it
  final kept = draft.trimRight();
  if (kept == forward || kept.endsWith('\n$forward')) return draft;
  return '$draft\n$forward';
}
