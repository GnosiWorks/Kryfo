// SPDX-License-Identifier: GPL-3.0-or-later
// adding someone between 0.5.3 and this version, on real payloads from
// both: fixtures/invites_053/from_053.json is made by 0.5.3's own code
// (make_invites_053.sh) from the forms in from_06.json, which this file
// writes with COMPAT_06_OUT=1. a new contact needs both phones on 0.6: no
// form either side makes starts a session with the other, and each side
// says so in words the person can act on
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/contact_card.dart' show cardShareText;
import 'package:kryfo/invite_share.dart';
import 'package:kryfo/invites.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show bundleFault, parseHaloUri;
import 'package:kryfo/pair_flow.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/pair_join.dart' show pairLineText;

import 'mem_db.dart';
import 'signal_kit.dart';

const _dir = 'test/fixtures/invites_053';

final _p = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

bool _lifts(List<int> x) {
  final v = BigInt.parse(_hex(x), radix: 16);
  if (v >= _p) return false;
  final a = (v.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
  final y = a.modPow((_p + BigInt.one) >> 2, _p);
  return y.modPow(BigInt.two, _p) == a;
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _fcPkOf(Uint8List sk) {
  final x = sha256.convert(sk).bytes;
  return _lifts(x) ? _hex(x) : 'error: not a key';
}

final _faceKeys = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 7)));
final _onionKeys = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 9)));

final _face = InviteFace(
  onionKey: Uint8List.fromList(ed.public(_onionKeys).bytes),
  face: Uint8List.fromList(ed.public(_faceKeys).bytes),
  sign: (m) => Uint8List.fromList(ed.sign(_faceKeys, m)),
);

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_dir/$name').readAsStringSync()) as Map<String, dynamic>;

// a form up to where its payload starts: what 0.5.3's reading turns on
String _shape(String s) {
  final at = s.indexOf(RegExp(r'i[=#]'));
  return at < 0 ? s : s.substring(0, at + 2);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // what this version hands a 0.5.3 phone: the qr, the link, the invite
  // page and the share text, and a code as the sharer reads it out
  Future<Map<String, Object>> forms06() async {
    final db = MemDb();
    final ss = await testStore(db: db);
    final row = await makeInvite(
      db,
      ss,
      kind: kInviteMain,
      fcPkOf: _fcPkOf,
      face: _face,
    );
    final link = inviteLink(row.link);
    return {
      'links': {
        'qr': inviteLink(row.qr!),
        'link': link,
        'web': webInviteOf(link)!,
        'share_text': inviteShareText('amber-otter-lake', link, lang: 'en'),
      },
      'code': pairCodeShown('07123456'),
    };
  }

  test('the forms this version shows are the ones 0.5.3 was given', () async {
    final now = await forms06();
    if (Platform.environment['COMPAT_06_OUT'] == '1') {
      File('$_dir/from_06.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(now)}\n',
      );
    }
    final given = _json('from_06.json');
    final links = now['links']! as Map<String, String>;
    for (final e in (given['links'] as Map<String, dynamic>).entries) {
      expect(_shape(links[e.key]!), _shape(e.value as String), reason: e.key);
    }
    expect(now['code'], given['code']);
    // and the share text and a shared card say what the link needs; a
    // 0.5.x link, as a decoy's, gets no such line
    expect(links['share_text'], endsWith(l10n.inviteNeeds06));
    expect(
      cardShareText('amber-otter-lake', links['link']!),
      endsWith('\n${l10n.inviteNeeds06}'),
    );
    expect(
      cardShareText('amber-otter-lake', _json('from_053.json')['qr'] as String),
      l10n.contactCardMessageMeOnKryfo('amber-otter-lake'),
    );
  });

  group('0.5.3 reading this version', () {
    late final made = _json('from_053.json');

    test('every qr and link of this version is an invalid link there: '
        'nothing parsed, nothing added', () {
      final reads = made['reads_06'] as Map<String, dynamic>;
      expect(reads.keys, containsAll(['qr', 'link', 'web', 'share_text']));
      for (final e in reads.entries) {
        final r = e.value as Map<String, dynamic>;
        expect(r['parsed'], isFalse, reason: e.key);
        expect(r['said'], made['invalid_line'], reason: e.key);
      }
      expect(made['invalid_line'], 'Invalid uri');
    });

    test('this version\'s eight digits never fit its six digit field', () {
      final typed = made['types_06_code'] as Map<String, dynamic>;
      expect(typed, hasLength(2));
      for (final e in typed.entries) {
        final r = e.value as Map<String, dynamic>;
        final digits = r['digits'] as String;
        // never the whole code: 0.5.3 asks for six, or looks up six it
        // was not given
        expect(digits, isNot('07123456'), reason: e.key);
        expect(digits.length, lessThan(8), reason: e.key);
      }
      // and six digits are never something this version looks up or shares
      expect(pairOldCode('071234'), isTrue);
    });
  });

  group('this version reading 0.5.3', () {
    late final made = _json('from_053.json');

    test('its qr and link are v3 cards with a first-contact address, on a '
        'card no session starts on', () {
      for (final k in ['qr', 'link_v3']) {
        final p = parseHaloUri(made[k] as String)!;
        expect(p['id'], made['id'], reason: k);
        expect(p['v'], '3', reason: k);
        expect(p['fc'], hasLength(64), reason: k);
        expect(p['bundle'], made['card'], reason: k);
      }
      expect(parseHaloUri(made['link_v2'] as String)!['fc'], isNull);
      // no kyber prekey: refused before the shim, nothing is built
      expect(bundleFault(made['card'] as String), isA<ClassicRefused>());
    });

    test('its six digit code is said to be an older Kryfo\'s', () {
      final shown = made['code_shown'] as String;
      expect(shown, '482 913');
      expect(pairDigits(shown), '482913');
      expect(pairOldCode(shown), isTrue);
      expect(
        pairLineText(PairLine.oldCode, sharer: false),
        l10n.pairCodeOldCodeShown,
      );
      expect(l10n.pairCodeOldCode, contains('0.6'));
    });
  });
}
