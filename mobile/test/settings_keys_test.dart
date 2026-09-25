// SPDX-License-Identifier: GPL-3.0-or-later
// every setting the app keeps outside its database is placed: an identity's
// own (a decoy keeps its own copy) or the phone's (every identity shares
// it). a new key on neither list fails here before it can leak between
// identities.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';

// the lock, the database keys and the list of containers are kept apart
// from settings on purpose
const _apart = {
  'halo.db.passphrase',
  'halo.d.key',
  'halo.containers',
  'halo.lock.enabled',
  'halo.lock.table',
  'halo.lock.state',
  'halo.lock.biometric',
  'halo.lock.panic_enabled',
  'halo.lock.pin_hash',
  'halo.lock.pin_salt',
  'halo.lock.panic_hash',
  'halo.lock.panic_salt',
  'halo.lock.misses',
  'halo.lock.until',
  // legacy keys a sweep deletes, and a backup field
  'push_mode',
  'ntfy_topic',
  'ntfy_server',
  'onboarding.complete',
};

void main() {
  test('every settings key is on a list', () {
    final keys = <String, String>{};
    // secure storage by name, and shared preferences on `prefs` or on the
    // instance straight from getInstance(). a map's remove is not a setting
    final call = RegExp(
      r"""(?:(?:read|write|delete|containsKey)\(\s*key:\s*|(?:prefs|\))\.(?:get\w*|set\w*|remove|containsKey)\(\s*)'([^'$]+)'""",
    );
    final constant = RegExp(
      r"""const\s+(?:String\s+)?(?:_?k[A-Z]\w*Key|_\w*Key)\s*=\s*'([^'$]+)'""",
    );
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/l10n/')) continue;
      final src = f.readAsStringSync();
      for (final m in call.allMatches(src)) {
        keys[m.group(1)!] = f.path;
      }
      for (final m in constant.allMatches(src)) {
        keys[m.group(1)!] = f.path;
      }
    }
    final unplaced = [
      for (final e in keys.entries)
        if (!containerKeys.contains(e.key) &&
            !deviceKeys.contains(e.key) &&
            !_apart.contains(e.key))
          '${e.key} (${e.value})',
    ];
    expect(keys.length, greaterThan(40));
    expect(unplaced, isEmpty);
  });

  test('a key on neither list is refused', () {
    expect(() => HaloContainer.decoy.key('something_new'), throwsArgumentError);
    expect(HaloContainer.decoy.key('my_avatar'), 'd.my_avatar');
    expect(HaloContainer.everyday.key('my_avatar'), 'my_avatar');
    expect(HaloContainer.decoy.key('theme_light'), 'theme_light');
  });

  test('no key is on both lists', () {
    expect(containerKeys.intersection(deviceKeys), isEmpty);
  });
}
