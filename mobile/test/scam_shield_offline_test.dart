// SPDX-License-Identifier: GPL-3.0-or-later
// nothing the scam shield reads leaves the phone: its files import no io,
// no network and no engine, and the check on the receive side touches only
// the switch, the database and the rules. shield_arrival_test shows the
// same from the outside: on or off, the same goes out
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _import = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);

Set<String> _imports(String path) => {
  for (final m in _import.allMatches(File(path).readAsStringSync())) m[1]!,
};

// the body of a method, from its name to the brace that closes it
String _body(String src, String head) {
  final at = src.indexOf(head);
  expect(at, isNot(-1), reason: head);
  var depth = 0;
  for (var i = src.indexOf('{', at); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  fail('no end to $head');
}

void main() {
  test('the rules import nothing that can reach out', () {
    expect(_imports('lib/scam_shield.dart'), {
      'dart:convert',
      'l10n/l10n.dart',
    });
    expect(_imports('lib/scam_prefs.dart'), {
      'package:shared_preferences/shared_preferences.dart',
      'container.dart',
    });
    expect(_imports('lib/widgets/shield_note.dart'), {
      'package:flutter/material.dart',
      'package:flutter/services.dart',
      '../l10n/l10n.dart',
      '../scam_shield.dart',
      '../theme.dart',
      'burn_fade.dart',
      'notice_banner.dart',
    });
  });

  test('the check on arrival calls nothing that sends', () {
    final run = _body(
      File('lib/app/state.dart').readAsStringSync(),
      'Future<void> _runShield(',
    );
    final calls = {
      for (final m in RegExp(r'([A-Za-z_][\w.]*)\s*\(').allMatches(run)) m[1]!,
    };
    // anything new in here has to be added by hand, and looked at first
    const allowed = {
      '_runShield',
      'if',
      'for',
      'catch',
      'loadScamShieldOn',
      'db.shieldFor',
      'shieldRowOpen',
      'db.contacts',
      'shieldCheck',
      'ShieldContact',
      'db.setShield',
      'jsonEncode',
      'toJson',
      'h.toJson',
      'dlog',
      'r.hits.map',
      'join',
      'notifyListeners',
    };
    expect(calls.difference(allowed), isEmpty);
    expect(calls, containsAll(['loadScamShieldOn', 'shieldCheck']));
  });
}
