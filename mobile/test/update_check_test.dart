// SPDX-License-Identifier: GPL-3.0-or-later
// the update check: who gets it, what it accepts, how often it asks, and
// that it asks nothing with the switch off, in a decoy or without tor
import 'dart:convert';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/update_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

// made by scripts/make-version-key.sh and sign-version.sh with a throwaway
// key: what openssl writes verifies here
const _osslPub = 'pIK5s1cR65PR5RrGhwm2KaQ2yrBhibZKpbLVJZXO5Dw=';
const _osslBody = '{"app":"kryfo","version":"0.5.1"}\n';
const _osslSig =
    'JJ5nrh7bpArFXZ8OrOe4qIqAXMGWEi86q+R5AFK+VUrKPSm9taw69cafSTdZhunLcsGYgvKNrI9qOMrboYlgDw==\n';

class _Signer {
  final ed.KeyPair k = ed.generateKey();
  String get pub => base64.encode(k.publicKey.bytes);
  String sign(String body) =>
      base64.encode(ed.sign(k.privateKey, utf8.encode(body)));
}

String _file(String v) => '{"app":"kryfo","version":"$v"}\n';

void main() {
  group('installer', () {
    bool notice(String? installer, {String? initiator, bool play = false}) =>
        updateNoticeFor(
          InstallInfo(installer: installer, initiator: initiator),
          playBuild: play,
        );

    test('f-droid and its clients: no notice', () {
      for (final p in [
        'org.fdroid.fdroid',
        'org.fdroid.basic',
        'org.fdroid.fdroid.privileged',
        'com.looker.droidify',
        'com.machiav3lli.fdroid',
      ]) {
        expect(notice(p), isFalse, reason: p);
      }
      // installed through the privileged extension, asked for by f-droid
      expect(
        notice(
          'com.google.android.packageinstaller',
          initiator: 'org.fdroid.fdroid',
        ),
        isFalse,
      );
      expect(
        updateNoticeFor(
          const InstallInfo(owner: 'com.looker.droidify'),
          playBuild: false,
        ),
        isFalse,
      );
    });

    test('site, github and obtainium copies get it', () {
      expect(notice(null), isTrue);
      expect(notice('com.google.android.packageinstaller'), isTrue);
      expect(notice('com.android.packageinstaller'), isTrue);
      expect(notice('dev.imranr.obtainium'), isTrue);
      expect(notice('com.example.unknown'), isTrue);
    });

    test('a play build never does', () {
      expect(notice(null, play: true), isFalse);
      expect(notice('dev.imranr.obtainium', play: true), isFalse);
      expect(notice('com.android.vending', play: true), isFalse);
    });
  });

  group('version', () {
    test('compares as numbers', () {
      expect(isNewer('0.5.1', '0.5.0'), isTrue);
      expect(isNewer('0.10.0', '0.9.9'), isTrue);
      expect(isNewer('1.0.0', '0.99.99'), isTrue);
      expect(isNewer('0.5.0', '0.5.0'), isFalse);
      expect(isNewer('0.4.9', '0.5.0'), isFalse);
    });

    test('anything but x.y.z is never newer', () {
      expect(isNewer('0.5.1-beta', '0.5.0'), isFalse);
      expect(isNewer('9', '0.5.0'), isFalse);
      expect(isNewer('0.5.1', null), isFalse);
      expect(isNewer(' 0.5.1', '0.5.0'), isFalse);
      expect(isNewer('0.5.1', '0.5'), isFalse);
      expect(parseVersion('0.5.12'), [0, 5, 12]);
    });
  });

  group('signature', () {
    final s = _Signer();

    test('a signed file gives its version', () {
      final body = _file('0.6.0');
      expect(verifiedVersion(body, s.sign(body), s.pub), '0.6.0');
    });

    test('what openssl signs verifies', () {
      expect(verifiedVersion(_osslBody, _osslSig, _osslPub), '0.5.1');
    });

    test('another key is refused', () {
      final body = _file('0.6.0');
      expect(verifiedVersion(body, _Signer().sign(body), s.pub), isNull);
    });

    test('a changed file is refused', () {
      final sig = s.sign(_file('0.6.0'));
      expect(verifiedVersion(_file('0.7.0'), sig, s.pub), isNull);
      expect(verifiedVersion(_osslBody.trim(), _osslSig, _osslPub), isNull);
    });

    test('no signature, or not one, is refused', () {
      final body = _file('0.6.0');
      expect(verifiedVersion(body, '', s.pub), isNull);
      expect(verifiedVersion(body, 'error: status 404', s.pub), isNull);
      expect(verifiedVersion(body, base64.encode([1, 2, 3]), s.pub), isNull);
    });

    test('a signed file of the wrong shape is refused', () {
      for (final body in [
        '{"app":"kryfo","version":"0.6"}',
        '{"app":"other","version":"0.6.0"}',
        '{"version":"0.6.0"}',
        '["0.6.0"]',
        'not json',
      ]) {
        expect(
          verifiedVersion(body, s.sign(body), s.pub),
          isNull,
          reason: body,
        );
      }
    });

    test('the placeholder verifies nothing', () {
      final body = _file('0.6.0');
      expect(
        verifiedVersion(body, s.sign(body), kVersionKeyPlaceholder),
        isNull,
      );
    });
  });

  group('download page', () {
    test('in the language the site has', () {
      expect(downloadPageFor('en'), 'https://kryfo.app/download');
      expect(downloadPageFor('de'), 'https://kryfo.app/de/download');
      expect(downloadPageFor('zh_Hant'), 'https://kryfo.app/zh-hant/download');
      expect(downloadPageFor('xx'), 'https://kryfo.app/download');
    });
  });

  test('a check is due a day after the last', () {
    final t = DateTime(2026, 10, 11, 12);
    expect(checkDue(null, t), isTrue);
    expect(checkDue(t, t.add(const Duration(hours: 23, minutes: 59))), isFalse);
    expect(checkDue(t, t.add(const Duration(days: 1))), isTrue);
    // a clock set back does not hold the next one off for long
    expect(checkDue(t, t.subtract(const Duration(days: 3))), isTrue);
  });

  group('the notice', () {
    late _Signer s;
    late List<String> asked;
    late DateTime now;
    late bool tor;
    late bool quiet;
    late String served;
    late HaloContainer c;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      s = _Signer();
      asked = [];
      now = DateTime(2026, 10, 11, 9);
      tor = true;
      quiet = false;
      served = '0.5.1';
      c = HaloContainer.everyday;
    });

    UpdateNotice make({
      String? installer,
      bool play = false,
      String running = '0.5.0',
      String Function(String url)? answer,
    }) => UpdateNotice(
      get: (url) async {
        asked.add(url);
        if (answer != null) return answer(url);
        final body = _file(served);
        return url == kVersionUrl ? body : s.sign(body);
      },
      torUp: () => tor,
      quiet: () => quiet,
      container: () => c,
      playBuild: play,
      install: () async => InstallInfo(installer: installer, version: running),
      now: () => now,
      pubKeyB64: s.pub,
    );

    test('a newer signed version shows, over two plain GETs', () async {
      final n = make();
      expect(await n.check(), isTrue);
      expect(asked, [kVersionUrl, kVersionSigUrl]);
      expect(n.shown, '0.5.1');
    });

    test('the same or an older version shows nothing', () async {
      served = '0.5.0';
      final n = make();
      await n.check();
      expect(n.shown, isNull);
      served = '0.4.2';
      now = now.add(const Duration(days: 2));
      await n.check();
      expect(n.shown, isNull);
    });

    test('a file signed by another key shows nothing', () async {
      final other = _Signer();
      final n = make(
        answer: (url) =>
            url == kVersionUrl ? _file('9.9.9') : other.sign(_file('9.9.9')),
      );
      await n.check();
      expect(n.shown, isNull);
    });

    test('once a day', () async {
      final n = make();
      await n.check();
      expect(asked, hasLength(2));
      now = now.add(const Duration(hours: 5));
      expect(await n.check(), isFalse);
      now = now.add(const Duration(hours: 18));
      expect(await n.check(), isFalse);
      expect(asked, hasLength(2));
      now = now.add(const Duration(hours: 1));
      expect(await n.check(), isTrue);
      expect(asked, hasLength(4));
    });

    test('two pokes at once ask once', () async {
      final n = make();
      await Future.wait([n.check(), n.check(), n.check()]);
      expect(asked, [kVersionUrl, kVersionSigUrl]);
    });

    test('the day is kept across starts', () async {
      await make().check();
      final again = make();
      now = now.add(const Duration(hours: 3));
      expect(await again.check(), isFalse);
      expect(asked, hasLength(2));
    });

    test('a dead route tries again in an hour, not a day', () async {
      var up = false;
      final n = make(
        answer: (url) {
          if (!up) return 'error: get: tor circuit failed';
          final body = _file('0.5.1');
          return url == kVersionUrl ? body : s.sign(body);
        },
      );
      await n.check();
      expect(asked, [kVersionUrl]);
      now = now.add(const Duration(minutes: 30));
      expect(await n.check(), isFalse);
      up = true;
      now = now.add(const Duration(minutes: 31));
      expect(await n.check(), isTrue);
      expect(n.shown, '0.5.1');
    });

    test('no request with the switch off', () async {
      final n = make();
      await n.setOn(false);
      expect(await n.check(), isFalse);
      expect(asked, isEmpty);
      await n.setOn(true);
      await pumpEventQueue();
      expect(asked, hasLength(2));
    });

    test('no request without tor', () async {
      tor = false;
      final n = make();
      expect(await n.check(), isFalse);
      expect(asked, isEmpty);
    });

    test('no request in a decoy, and no card there', () async {
      final n = make();
      await n.check();
      expect(n.shown, '0.5.1');
      asked.clear();
      quiet = true;
      c = HaloContainer.decoy;
      now = now.add(const Duration(days: 2));
      expect(await n.check(), isFalse);
      expect(asked, isEmpty);
      expect(n.shown, isNull);
    });

    test('the decoy has a switch of its own', () async {
      c = HaloContainer.decoy;
      final n = make();
      await n.setOn(false);
      c = HaloContainer.everyday;
      expect(await n.isOn(), isTrue);
    });

    test('no request from an f-droid copy or a play build', () async {
      final f = make(installer: 'org.fdroid.fdroid');
      expect(await f.check(), isFalse);
      expect(f.eligible, isFalse);
      final p = make(play: true);
      expect(await p.check(), isFalse);
      expect(asked, isEmpty);
    });

    test('dismissed for this version, back for the next', () async {
      final n = make();
      await n.check();
      await n.dismiss();
      expect(n.shown, isNull);
      // and after a restart
      final later = make();
      await later.ready();
      expect(later.shown, isNull);
      served = '0.5.2';
      now = now.add(const Duration(days: 1));
      await later.check();
      expect(later.shown, '0.5.2');
    });

    test('updated past it: the card goes', () async {
      await make().check();
      final updated = make(running: '0.5.1');
      await updated.ready();
      expect(updated.shown, isNull);
    });
  });
}
