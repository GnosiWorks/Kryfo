// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/marked.dart';

void main() {
  const accent = TextStyle(fontStyle: FontStyle.italic);

  test('marked words get the accent style', () {
    final s = markedSpans('Keep kryfo *independent*', accent);
    expect(s.map((t) => t.text), ['Keep kryfo ', 'independent']);
    expect(s[0].style, isNull);
    expect(s[1].style, accent);
    final m = markedSpans(l10n.onboardingPrivateMessaging, accent);
    expect(m.map((t) => t.text), [
      'Private messaging,\n',
      'without the catch',
      '.',
    ]);
    expect(m.map((t) => t.style), [null, accent, null]);
  });

  test('a message may start with its mark', () {
    final s = markedSpans(l10n.chatOf(5, 2), accent);
    expect(s.map((t) => t.text), ['2', ' of 5 matches']);
    expect(s.first.style, accent);
    expect(unmarked(l10n.chatOf(1, 1)), '1 of 1 match');
  });

  test('splits the text around a widget slot', () {
    expect(aroundSlot(l10n.roomLinkEndsIn), ('Ends in ', ''));
    expect(aroundSlot((t) => l10n.groupChatHere(3, t)), ('', ' · 3 here'));
  });

  test('a handle keeps its @ in rtl text', () {
    expect(ltr('@wren'), '\u2066@wren\u2069');
  });
}
