// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

// a sentence that carries two styles is still one message. the accented
// words are marked with asterisks, "Keep kryfo *independent*.", so the
// translator sets the word order and the accent lands wherever their
// language puts those words.

/// [msg] as spans: the *marked* stretches in [marked], the rest in the
/// paragraph's own style.
List<TextSpan> markedSpans(String msg, TextStyle marked) {
  final parts = msg.split('*');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        TextSpan(text: parts[i], style: i.isOdd ? marked : null),
  ];
}

/// [msg] without its marks, for a place that shows it in one style.
String unmarked(String msg) => msg.replaceAll('*', '');

// a sentence with a live widget in it (a countdown) is one message with a
// placeholder where the widget goes. the text either side comes back here,
// in the language's own order.
const _slot = '\u{E000}';

/// the text before and after the widget in [msg], which is asked for with
/// the placeholder the widget stands in for.
(String, String) aroundSlot(String Function(String slot) msg) {
  final s = msg(_slot);
  final i = s.indexOf(_slot);
  if (i < 0) return (s, '');
  return (s.substring(0, i), s.substring(i + _slot.length));
}

/// a row of [style] text with [slot] where [msg] puts it
class SlotLine extends StatelessWidget {
  const SlotLine({
    super.key,
    required this.msg,
    required this.slot,
    required this.style,
  });

  final String Function(String slot) msg;
  final Widget slot;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final (before, after) = aroundSlot(msg);
    return Row(
      children: [
        if (before.isNotEmpty) Text(before, style: style),
        slot,
        if (after.isNotEmpty) Text(after, style: style),
      ],
    );
  }
}
