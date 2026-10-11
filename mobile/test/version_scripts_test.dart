// SPDX-License-Identifier: GPL-3.0-or-later
// the release scripts around the version key: a release refuses the
// placeholder, and signing refuses any key but the one the app pins
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/update_check.dart';
import 'package:path/path.dart' as p;

final _scripts = p.normalize(p.join(Directory.current.path, '..', 'scripts'));
final _noOpenssl =
    Process.runSync('sh', ['-c', 'command -v openssl']).exitCode != 0;

ProcessResult _run(String script, List<String> args, {String? stdin}) {
  if (stdin == null) {
    return Process.runSync(
      script,
      args,
      environment: {'KRYFO_VERSION_KEY_PASS': ''},
    );
  }
  return Process.runSync('sh', [
    '-c',
    'printf "%s" "\$0" | "\$1" -',
    stdin,
    script,
  ]);
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('kryfo-version-'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String key(String name) {
    final f = p.join(tmp.path, name);
    final r = Process.runSync('openssl', [
      'genpkey',
      '-algorithm',
      'ed25519',
      '-out',
      f,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return f;
  }

  String pub(String keyFile) {
    final r = _run(p.join(_scripts, 'sign-version.sh'), ['--pubkey', keyFile]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return (r.stdout as String).trim();
  }

  group('the pinned key', () {
    final check = p.join(_scripts, 'check-version-key.sh');

    test('the placeholder is refused', () {
      final src = File('lib/update_check.dart').readAsStringSync();
      final r = _run(check, [], stdin: src);
      if (kVersionPubKeyB64 == kVersionKeyPlaceholder) {
        expect(r.exitCode, isNot(0));
      } else {
        expect(r.exitCode, 0);
      }
    });

    test('32 bytes pass, anything else does not', () {
      final good = pub(key('a.pem'));
      final ok = _run(check, [], stdin: "const kVersionPubKeyB64 = '$good';\n");
      expect(ok.exitCode, 0);
      expect((ok.stdout as String).trim(), good);
      final short = good.substring(0, 40);
      expect(
        _run(
          check,
          [],
          stdin: "const kVersionPubKeyB64 = '$short';\n",
        ).exitCode,
        isNot(0),
      );
    });
  }, skip: _noOpenssl ? 'no openssl' : false);

  group('signing', () {
    // a checkout of its own: the two scripts, the app's pin and a site
    late String root, sign, site;
    setUp(() {
      root = tmp.path;
      Directory(p.join(root, 'scripts')).createSync();
      for (final s in ['sign-version.sh', 'check-version-key.sh']) {
        final to = p.join(root, 'scripts', s);
        File(p.join(_scripts, s)).copySync(to);
        Process.runSync('chmod', ['+x', to]);
      }
      sign = p.join(root, 'scripts', 'sign-version.sh');
      site = p.join(root, 'site');
      Directory(p.join(site, 'static')).createSync(recursive: true);
      Directory(p.join(site, 'l10n')).createSync();
      File(p.join(site, 'build.py')).writeAsStringSync('');
      File(
        p.join(site, 'l10n', 'release.json'),
      ).writeAsStringSync('{"version": "0.5.1"}');
    });

    void pin(String b64) {
      final f = File(p.join(root, 'mobile', 'lib', 'update_check.dart'));
      f.parent.createSync(recursive: true);
      f.writeAsStringSync("const kVersionPubKeyB64 = '$b64';\n");
    }

    test('a key the app does not pin writes nothing', () {
      final pinned = key('pinned.pem');
      final other = key('other.pem');
      pin(pub(pinned));
      final r = _run(sign, ['0.5.1', other, site]);
      expect(r.exitCode, isNot(0));
      expect(Directory(p.join(site, 'static')).listSync(), isEmpty);
    });

    test('the pinned key signs what the app accepts', () {
      final pinned = key('pinned.pem');
      final b64 = pub(pinned);
      pin(b64);
      final r = _run(sign, ['0.5.1', pinned, site]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final body = File(
        p.join(site, 'static', 'version.json'),
      ).readAsStringSync();
      final sig = File(
        p.join(site, 'static', 'version.json.sig'),
      ).readAsStringSync();
      expect(verifiedVersion(body, sig, b64), '0.5.1');
    });
  }, skip: _noOpenssl ? 'no openssl' : false);
}
