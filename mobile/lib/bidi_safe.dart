// SPDX-License-Identifier: GPL-3.0-or-later
// direction controls out of what other people write, before kryfo keeps or
// shows it.
//
// they come out of messages, names, file names, link titles, room names,
// and out of anything pasted, captioned or edited before it is kept. the
// words read the same without them, and each message is laid out in the
// direction of its own words anyway, by its first letter. nobody needs them
// in a message, so every one goes: isolates, embeddings, overrides and the
// plain marks. the joiners stay, persian needs them. an override is also
// how a file called "gpj.exe" reads as "exe.jpg". each message is laid out
// in its own direction anyway (writtenDir). the app's own sentences carry
// their isolates in the translations, kept to one plain shape by a test,
// and never pass through here.
import 'package:flutter/services.dart';

final _controls = RegExp('[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]');

/// [s] without direction controls
String unmarked(String s) =>
    _controls.hasMatch(s) ? s.replaceAll(_controls, '') : s;

/// every string in a decoded json value, [skip] keys left as they are
/// (base64 blobs, which cannot hold the controls and are long)
Object? unmarkedJson(Object? v, {Set<String> skip = const {}}) {
  if (v is String) return unmarked(v);
  if (v is List) return [for (final e in v) unmarkedJson(e, skip: skip)];
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        e.key.toString(): skip.contains(e.key)
            ? e.value
            : unmarkedJson(e.value, skip: skip),
    };
  }
  return v;
}

/// for a field: pasted text loses the controls as it lands
class UnmarkedInput extends TextInputFormatter {
  const UnmarkedInput();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!_controls.hasMatch(newValue.text)) return newValue;
    final text = unmarked(newValue.text);
    // the caret keeps its place among the characters that stay
    int at(int i) => i < 0
        ? i
        : unmarked(
            newValue.text.substring(0, i.clamp(0, newValue.text.length)),
          ).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: at(newValue.selection.baseOffset),
        extentOffset: at(newValue.selection.extentOffset),
      ),
    );
  }
}
