// SPDX-License-Identifier: GPL-3.0-or-later
// what may leave a chat from the viewer and from a selection: saved to the
// device, forwarded or copied. never from a chat that blocks screenshots or
// a burner room, never a timed message, a marked photo or a spoiler; and a
// hidden chat's never goes to the gallery or another app. forwarding from a
// hidden chat may only reach hidden chats, which the picker here does not
// keep apart, so it is left out there too
library;

/// it may be forwarded or copied out of the chat
bool mayLeave({
  required bool blocking,
  bool room = false,
  bool timed = false,
  bool marked = false,
  bool spoiler = false,
  bool hidden = false,
}) => !blocking && !room && !timed && !marked && !spoiler && !hidden;

/// the name a photo is saved under: when it was sent, never its own file's
String savedPhotoName(String path, DateTime when) {
  String two(int n) => n.toString().padLeft(2, '0');
  final dot = path.lastIndexOf('.');
  final ext = dot > path.lastIndexOf('/') && dot >= 0
      ? path.substring(dot).toLowerCase()
      : '.jpg';
  return 'Kryfo-${when.year}${two(when.month)}${two(when.day)}-'
      '${two(when.hour)}${two(when.minute)}${two(when.second)}$ext';
}

/// it may be saved to the device
bool maySaveOut({
  required bool blocking,
  bool room = false,
  bool timed = false,
  bool marked = false,
  bool spoiler = false,
  bool hidden = false,
}) => mayLeave(
  blocking: blocking,
  room: room,
  timed: timed,
  marked: marked,
  spoiler: spoiler,
  hidden: hidden,
);
