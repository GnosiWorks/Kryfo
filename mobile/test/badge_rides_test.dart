// SPDX-License-Identifier: GPL-3.0-or-later
// a contact's badge is set from each chat row they send and cleared by one
// that comes without it (state_arrivals). so every frame with a row id
// carries the shared badge, or a send path that forgot it clears the badge
// at every contact. the only rows without it are the two notices for old
// versions, which this version drops before the badge is read
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// the call's arguments, from its open paren to the one that closes it
String _args(String src, int open) {
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')' && --depth == 0) return src.substring(open, i + 1);
  }
  return src.substring(open);
}

void main() {
  test('every row a contact gets carries the shared badge', () {
    final missing = <String>[];
    var rows = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('message_envelope.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r'(?<!un)wrapMessage\(').allMatches(src)) {
        final a = _args(src, m.end - 1);
        if (!a.contains('msgUid:')) continue;
        rows++;
        if (a.contains('supporterBadge:')) continue;
        if (a.contains('shotsNudge: true') || a.contains('endNotice: true')) {
          continue;
        }
        missing.add('${f.path}: ${a.split('\n').first}');
      }
      // the retry of a stored row passes it on too
      if (src.contains('wrapRedelivery(') && !f.path.endsWith('outbox.dart')) {
        for (final m in RegExp(r'wrapRedelivery\(').allMatches(src)) {
          final a = _args(src, m.end - 1);
          if (!a.contains('badge:')) missing.add('${f.path}: retry');
        }
      }
    }
    expect(rows, greaterThan(5));
    expect(missing, isEmpty);
  });

  test('the two notices without it are dropped before the badge is read', () {
    final src = File('lib/app/state_arrivals.dart').readAsStringSync();
    final badge = src.indexOf('db.setContactBadge(senderHaloId');
    final end = src.indexOf('if (env.endNotice) {');
    final nudge = src.indexOf('if (env.shotsNudge) {');
    expect(badge, greaterThan(0));
    expect(end, inInclusiveRange(0, badge));
    expect(nudge, inInclusiveRange(0, badge));
  });
}
