// SPDX-License-Identifier: GPL-3.0-or-later
// what a computer may hand the developer's phone to send: words with a
// reply, a link's title or a timer, or one word on a message. anything
// else, or two words at once, is no answer
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/own_answer.dart';

String _f(Map<String, Object?> j) => 'halo/1:${jsonEncode(j)}';

void main() {
  test('words, with a reply, a link\'s title and a timer', () {
    final a = ownAnswerOf(
      _f({
        'm': 'see the site',
        'u': 'u-1',
        'q': 'u-0',
        'b': 30,
        'pv': {'url': 'https://kryfo.app', 'title': 'Kryfo', 'by': 'sender'},
        'w': 1,
        'h': 'me',
        'pw': 3,
      }),
    )!;
    expect(a.kind, AnswerKind.text);
    expect(a.uid, 'u-1');
    expect(a.reply, 'u-0');
    expect(a.burn, 30);
    expect(a.preview!['title'], 'Kryfo');
  });

  test('one word on a message: a reaction, an edit, a take-back', () {
    expect(
      ownAnswerOf(
        _f({
          'm': '',
          'r': {'u': 'u-1', 'e': '👍'},
        }),
      )!.kind,
      AnswerKind.reaction,
    );
    expect(
      ownAnswerOf(
        _f({
          'm': '',
          'ed': {'u': 'u-1', 'm': 'new'},
        }),
      )!.text,
      'new',
    );
    expect(ownAnswerOf(_f({'m': '', 'un': 'u-1'}))!.kind, AnswerKind.takeBack);
  });

  test('never two words at once, nor words beside one', () {
    for (final j in <Map<String, Object?>>[
      {
        'm': '',
        'r': {'u': 'u-1', 'e': '1'},
        'un': 'u-1',
      },
      {
        'm': '',
        'ed': {'u': 'u-1', 'm': 'x'},
        'r': {'u': 'u-1', 'e': '1'},
      },
      {'m': 'hi', 'u': 'u-2', 'un': 'u-1'},
      {
        'm': '',
        'u': 'u-2',
        'r': {'u': 'u-1', 'e': '1'},
      },
    ]) {
      expect(ownAnswerOf(_f(j)), isNull, reason: '$j');
    }
  });

  test('nothing else: files, stickers, polls, cards, groups, odd shapes', () {
    for (final j in <Map<String, Object?>>[
      {'m': 'f', 'u': 'u-1', 'f': 'AAAA'},
      {'m': 'f', 'u': 'u-1', 'st': 'fokia:1'},
      {'m': 'f', 'u': 'u-1', 'pi': 1},
      {'m': 'f', 'u': 'u-1', 'g': 'g1'},
      {
        'm': 'f',
        'u': 'u-1',
        'pv': {'url': 'x', 'img': 'AAAA'},
      },
      {'m': 'f', 'u': 'u-1', 'pv': 'x'},
      {'m': 'f', 'u': 'u:1'},
      {'m': 'f'},
      {'m': '  ', 'u': 'u-1'},
      {'m': 'f', 'u': 'u-1', 'q': 'a b'},
      {'m': 'f', 'u': 'u-1', 'b': 0},
      {'m': 'f', 'u': 'u-1', 'b': kAnswerBurnMost + 1},
      {
        'm': '',
        'r': {'u': 'u-1', 'e': 'x' * 33},
      },
      {
        'm': '',
        'ed': {'u': 'u-1', 'm': ' '},
      },
    ]) {
      expect(ownAnswerOf(_f(j)), isNull, reason: '$j');
    }
    expect(ownAnswerOf('not a frame'), isNull);
    expect(ownAnswerOf('halo/1:[1]'), isNull);
  });
}
