// SPDX-License-Identifier: GPL-3.0-or-later
// the licences screen: the rust list is made from the Cargo.lock in the
// tree and names libsignal's AGPL crates, the engine list from the go vendor
// dir and go-libtor, the data list from the assets' licence files, the GPL
// text is the repository's. the screen opens every list and text, with and
// without motion, says when a list fails, and holds still while it loads
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/licences.dart';
import 'package:kryfo/screens/licences_screen.dart';
import 'package:kryfo/translate/hub_live.dart' show kOfflineTranslation;
import 'package:kryfo/voice/voice_transcripts.dart' show kVoiceTranscripts;

const _lock = 'native/kryfo_signal/Cargo.lock';
const _manifest = 'native/kryfo_signal/Cargo.toml';
final _asset = File(kRustLicencesAsset);
final _engineAsset = File(kEngineLicencesAsset);
final _nativeAsset = File(kNativeLicencesAsset);
const _libtor = '../engine/vendor/github.com/alexballas/go-libtor';

String _sha(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

const _agplCrates = [
  'libsignal-core',
  'libsignal-protocol',
  'signal-crypto',
  'libsignal-debug',
  'spqr',
];

// motion, direction and text size for every page the screen opens, not
// only the first
Widget _host(
  Widget child, {
  bool still = false,
  bool rtl = false,
  double scale = 1,
}) => MaterialApp(
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: page!,
    ),
  ),
  home: child,
);

// a load that fails, as an asset that will not open or parse does
Future<T> _fail<T>(String why) => Future<T>.error(StateError(why))..ignore();

// a phone-wide view tall enough that every row of the screen is built
Future<void> _show(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(360, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
}

RustLicences _fakeRust() => const RustLicences('v0.99.4', [
  LicencedPart(
    'libsignal-protocol',
    ['GNU AFFERO GENERAL PUBLIC LICENSE\n\nVersion 3'],
    version: '0.1.0',
    licence: 'AGPL-3.0-only',
  ),
  LicencedPart(
    'zeroize',
    ['MIT text'],
    version: '1.9.1',
    licence: 'Apache-2.0 OR MIT',
  ),
], 'GNU AFFERO GENERAL PUBLIC LICENSE\n\nVersion 3, 19 November 2007');

List<LicencedPart> _fakeDart() => const [
  LicencedPart('ffi', ['BSD text']),
  LicencedPart('flutter', ['flutter text one', 'flutter text two']),
];

EngineLicences _fakeEngine() => const EngineLicences(
  [
    LicencedPart(
      'golang.org/x/net',
      ['Go BSD text'],
      version: 'v0.60.0',
      licence: 'BSD-3-Clause',
    ),
    LicencedPart(
      'tor',
      ['This file contains the license for Tor'],
      version: '0.4.9.12',
      licence: 'BSD-3-Clause',
    ),
  ],
  [
    LicencedPart('OpenCC', ['OpenCC Apache text'], licence: 'Apache-2.0'),
  ],
);

const _gplText = 'GNU GENERAL PUBLIC LICENSE\n\nVersion 3, 29 June 2007';

NativeLicences _fakeNative() => const NativeLicences(
  [
    LicencedPart(
      'whisper.cpp and ggml',
      ['ggml MIT text'],
      version: 'v1.9.5',
      licence: 'MIT',
    ),
  ],
  [
    LicencedPart(
      'Bergamot translator',
      ['MPL text'],
      version: 'eea6e5a8',
      licence: 'MPL-2.0',
    ),
    LicencedPart('zlib', ['zlib text'], version: '1.2.11', licence: 'Zlib'),
  ],
);

LicencesScreen _screen({
  Future<RustLicences>? rust,
  Future<List<LicencedPart>>? dart,
  Future<EngineLicences>? engine,
  Future<String>? gpl,
  Future<NativeLicences>? native,
  bool voice = false,
  bool translation = false,
}) => LicencesScreen(
  rust: rust ?? Future.value(_fakeRust()),
  dart: dart ?? Future.value(_fakeDart()),
  engine: engine ?? Future.value(_fakeEngine()),
  gpl: gpl ?? Future.value(_gplText),
  native: native ?? Future.value(_fakeNative()),
  voice: voice,
  translation: translation,
);

// the module paths in vendor/modules.txt that bring at least one package
List<String> _goModules() {
  final mods = <String>[];
  String? cur;
  var used = false;
  void done() {
    if (cur != null && used) mods.add(cur);
  }

  for (final l in File('../engine/vendor/modules.txt').readAsLinesSync()) {
    if (l.startsWith('# ')) {
      done();
      final f = l.substring(2).split(' ');
      cur = f.length >= 2 && f[1] != '=>' ? f[0] : null;
      used = false;
    } else if (l.isNotEmpty && !l.startsWith('#')) {
      used = true;
    }
  }
  done();
  return mods;
}

void main() {
  group('the rust list', () {
    test('was made from the Cargo.lock in this tree', () {
      final j = jsonDecode(_asset.readAsStringSync()) as Map<String, dynamic>;
      final lock = sha256.convert(File(_lock).readAsBytesSync()).toString();
      expect(
        j['lock'],
        lock,
        reason:
            'Cargo.lock changed: run native/kryfo_signal/acknowledgments.sh',
      );
      final tag = RegExp(
        r'^# libsignal (v[0-9.]+), named by its commit',
        multiLine: true,
      ).firstMatch(File(_manifest).readAsStringSync())![1];
      expect(j['libsignal'], tag);
      expect(kLibsignalTag, tag, reason: 'the screen names this tag');
    });

    test('names the AGPL crates and a text for every crate', () {
      final r = parseRustLicences(_asset.readAsStringSync());
      final byName = {for (final c in r.crates) c.name: c};
      for (final n in _agplCrates) {
        expect(byName[n]?.licence, contains('AGPL-3.0'), reason: n);
      }
      for (final c in r.crates) {
        expect(c.texts, isNotEmpty, reason: c.name);
        expect(c.version, isNotEmpty, reason: c.name);
      }
      expect(r.agpl, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
      // the shim itself is ours, under the GPL, and not listed
      expect(byName.containsKey('kryfo_signal'), isFalse);
    });
  });

  group('the engine list', () {
    final j =
        jsonDecode(_engineAsset.readAsStringSync()) as Map<String, dynamic>;
    const stale = 'out of date: run engine/acknowledgments.sh';

    test('was made from the vendor dir, go-libtor and go in this tree', () {
      expect(j['modules'], _sha('../engine/vendor/modules.txt'), reason: stale);
      expect(j['libtor'], _sha('$_libtor/lock.json'), reason: stale);
      final goMod = File('../engine/go.mod').readAsStringSync();
      expect(
        j['go'],
        RegExp(r'^go (\S+)$', multiLine: true).firstMatch(goMod)![1],
        reason: stale,
      );
    });

    test('names every go module, go, tor, its c libraries and libopus', () {
      final e = parseEngineLicences(_engineAsset.readAsStringSync());
      final names = {for (final p in e.parts) p.name};
      final mods = _goModules();
      expect(mods, isNotEmpty);
      expect(names, containsAll(mods));
      expect(
        names,
        containsAll(['Go', 'tor', 'OpenSSL', 'libevent', 'zlib', 'libopus']),
      );
      expect(names.length, mods.length + 6);
      // the libopus in engine/opus, as vendor.sh left it
      final opus = e.parts.singleWhere((p) => p.name == 'libopus');
      expect(
        opus.version,
        File('../engine/opus/libopus/VERSION').readAsStringSync().trim(),
        reason: stale,
      );
      expect(opus.licence, 'BSD-3-Clause');
      for (final p in e.parts) {
        expect(p.texts, isNotEmpty, reason: p.name);
        expect(p.licence, isNotEmpty, reason: p.name);
        expect(p.version, isNotEmpty, reason: p.name);
      }
    });

    test('names every third-party data licence the app ships', () {
      final files = <String, String>{
        for (final d in Directory('assets').listSync().whereType<Directory>())
          if (!d.path.endsWith('licences'))
            for (final f in d.listSync().whereType<File>())
              if (RegExp(
                r'^(licen[cs]e|copying|notice)',
                caseSensitive: false,
              ).hasMatch(f.uri.pathSegments.last))
                f.path.replaceAll(r'\', '/'): _sha(f.path),
      };
      final listed = <String, String>{
        for (final d in j['data'] as List)
          (d as Map)['file'] as String: d['sha256'] as String,
      };
      expect(listed, files, reason: stale);
    });

    test('the GPL text is the repository\'s LICENSE', () {
      expect(
        File(kGplAsset).readAsStringSync(),
        File('../LICENSE').readAsStringSync(),
      );
    });
  });

  group('the voice and translation lists', () {
    final j =
        jsonDecode(_nativeAsset.readAsStringSync()) as Map<String, dynamic>;
    const stale = 'out of date: run engine/native-acknowledgments.sh';

    test('were made from the pins in this tree', () {
      expect(
        j['whisper'],
        _sha('../engine/voice/native/whisper.lock'),
        reason: stale,
      );
      expect(j['models'], _sha('../engine/voice/models.json'), reason: stale);
      expect(
        j['weights'],
        _sha('../engine/voice/licences/weights-LICENSE'),
        reason: stale,
      );
      expect(
        j['bergamot'],
        _sha('../engine/translate/native/bergamot.lock'),
        reason: stale,
      );
      expect(
        j['translationModels'],
        _sha('../engine/translate/models.json'),
        reason: stale,
      );
    });

    test(
      'voice: whisper.cpp and ggml, the YaRN notice, the weights word for word',
      () {
        final n = parseNativeLicences(_nativeAsset.readAsStringSync());
        final by = {for (final p in n.voice) p.name: p};
        expect(by.keys, [
          'whisper.cpp and ggml',
          'YaRN rope scaling, in ggml',
          'Whisper base speech model',
        ]);
        final lock = File(
          '../engine/voice/native/whisper.lock',
        ).readAsStringSync();
        expect(
          by['whisper.cpp and ggml']!.version,
          RegExp(
            r'^WHISPER_VERSION=(\S+)$',
            multiLine: true,
          ).firstMatch(lock)![1],
        );
        expect(
          by['whisper.cpp and ggml']!.texts.single,
          contains('The ggml authors'),
        );
        expect(
          by['YaRN rope scaling, in ggml']!.texts.first,
          'MIT licensed. Copyright (c) 2023 Jeffrey Quesnelle and Bowen Peng.',
        );
        expect(
          by['Whisper base speech model']!.texts.single,
          File('../engine/voice/licences/weights-LICENSE').readAsStringSync(),
        );
        for (final p in n.voice) {
          expect(p.licence, 'MIT', reason: p.name);
        }
      },
    );

    test('translation: bergamot and every part its library builds in', () {
      final n = parseNativeLicences(_nativeAsset.readAsStringSync());
      final by = {for (final p in n.translation) p.name: p};
      expect(by['Bergamot translator']!.licence, 'MPL-2.0');
      expect(
        by['Bergamot translator']!.texts.single,
        contains('Mozilla Public License Version 2.0'),
      );
      expect(
        by.keys,
        containsAll([
          'Marian', 'SentencePiece', 'intgemm', 'ruy', 'cpuinfo', 'PCRE2', //
          'simd_utils', 'ssplit-cpp', 'yaml-cpp', 'spdlog', 'faiss', 'zlib',
          'Protocol Buffers lite, in SentencePiece', 'Abseil, in SentencePiece',
        ]),
      );
      // the lock's commits name the versions
      final lock = File(
        '../engine/translate/native/bergamot.lock',
      ).readAsStringSync();
      for (final pin in ['intgemm', 'ruy', 'sentencepiece', 'cpuinfo']) {
        final c = RegExp(
          '^$pin\\s+\\S+\\s+([0-9a-f]{8})',
          multiLine: true,
        ).firstMatch(lock)![1];
        final part = n.translation.singleWhere(
          (p) => p.name.toLowerCase() == pin,
        );
        expect(part.version, c, reason: pin);
      }
      // the model files are mozilla's under the mpl 2.0 too, one row a pair,
      // named by the first bytes of the model's sha256
      final models =
          jsonDecode(
                File('../engine/translate/models.json').readAsStringSync(),
              )['pairs']
              as List<dynamic>;
      const lang = {'en': 'English', 'zh': 'Chinese'};
      for (final m in models.cast<Map<String, dynamic>>()) {
        final name =
            'Translation model, ${lang[m['from']]} to ${lang[m['to']]}';
        final model = (m['files'] as List<dynamic>).singleWhere(
          (f) => f['kind'] == 'model',
        );
        expect(by[name]!.licence, 'MPL-2.0', reason: name);
        expect(by[name]!.version, (model['sha256'] as String).substring(0, 8));
        expect(by[name]!.texts.single, by['Bergamot translator']!.texts.single);
      }
      for (final p in n.translation) {
        expect(p.texts, isNotEmpty, reason: p.name);
        expect(p.licence, isNotEmpty, reason: p.name);
      }
      expect(
        n.translation.map((p) => p.name.toLowerCase()).toList(),
        [...n.translation.map((p) => p.name.toLowerCase())]..sort(),
      );
    });

    test('the screen shows them with their switches', () {
      const s = LicencesScreen();
      expect(s.voice, kVoiceTranscripts);
      expect(s.translation, kOfflineTranslation);
    });
  });

  testWidgets('the app bundles every list and text it loads', (t) async {
    final n = await t.runAsync(loadNativeLicences);
    expect(n!.voice, isNotEmpty);
    expect(n.translation, isNotEmpty);
    final e = await t.runAsync(loadEngineLicences);
    expect(e!.parts, isNotEmpty);
    final gpl = await t.runAsync(loadGpl);
    expect(gpl, contains('GNU GENERAL PUBLIC LICENSE'));
    final r = await t.runAsync(loadRustLicences);
    expect(r!.crates, isNotEmpty);
  });

  test('data parts sit among the dart packages by name', () {
    final all = appParts(_fakeDart(), _fakeEngine().data);
    expect(all.map((p) => p.name), ['ffi', 'flutter', 'OpenCC']);
  });

  test('dart licences come one entry per package, sorted', () async {
    final parts = await loadDartLicences(
      Stream.fromIterable([
        const LicenseEntryWithLineBreaks(['zeta', 'alpha'], 'shared text'),
        const LicenseEntryWithLineBreaks(['Beta'], 'beta text'),
        const LicenseEntryWithLineBreaks(['alpha'], 'alpha own text'),
      ]),
    );
    expect(parts.map((p) => p.name), ['alpha', 'Beta', 'zeta']);
    expect(parts.first.texts, ['shared text', 'alpha own text']);
  });

  for (final still in [false, true]) {
    testWidgets('the screen opens each list and text, still: $still', (
      t,
    ) async {
      await _show(t, _host(_screen(), still: still));
      await t.pumpAndSettle();
      expect(find.textContaining('GNU General Public License'), findsOneWidget);
      expect(find.textContaining('libsignal v0.99.4'), findsOneWidget);
      expect(find.text('2 parts'), findsNWidgets(2));
      expect(find.text('3 parts'), findsOneWidget);

      await t.tap(find.text('GNU GPL 3.0, full text'));
      await t.pumpAndSettle();
      expect(find.text('Version 3, 29 June 2007'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('In the Signal library'));
      await t.tap(find.text('In the Signal library'));
      await t.pumpAndSettle();
      expect(find.text('libsignal-protocol'), findsOneWidget);
      expect(find.text('0.1.0 · AGPL-3.0-only'), findsOneWidget);
      await t.tap(find.text('libsignal-protocol'));
      await t.pumpAndSettle();
      expect(find.text('libsignal-protocol 0.1.0'), findsOneWidget);
      expect(find.text('GNU AFFERO GENERAL PUBLIC LICENSE'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('In the app'));
      await t.tap(find.text('In the app'));
      await t.pumpAndSettle();
      expect(find.text('Apache-2.0'), findsOneWidget);
      await t.tap(find.text('flutter'));
      await t.pumpAndSettle();
      expect(find.text('flutter text one'), findsOneWidget);
      expect(find.text('flutter text two'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.text('OpenCC'));
      await t.pumpAndSettle();
      expect(find.text('OpenCC Apache text'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('In the network engine'));
      await t.tap(find.text('In the network engine'));
      await t.pumpAndSettle();
      expect(find.text('0.4.9.12 · BSD-3-Clause'), findsOneWidget);
      await t.tap(find.text('tor'));
      await t.pumpAndSettle();
      expect(find.text('tor 0.4.9.12'), findsOneWidget);
      expect(
        find.text('This file contains the license for Tor'),
        findsOneWidget,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('GNU AGPL 3.0, full text'));
      await t.tap(find.text('GNU AGPL 3.0, full text'));
      await t.pumpAndSettle();
      expect(find.text('Version 3, 19 November 2007'), findsOneWidget);
    });
  }

  testWidgets('a licence text stays left to right in an rtl app', (t) async {
    await _show(t, _host(_screen(), rtl: true));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('GNU AGPL 3.0, full text'));
    await t.tap(find.text('GNU AGPL 3.0, full text'));
    await t.pumpAndSettle();
    final text = t.widget<Text>(find.text('Version 3, 19 November 2007'));
    expect(text.textDirection, TextDirection.ltr);
  });

  testWidgets('a list row points the way it opens in an rtl app', (t) async {
    await _show(t, _host(_screen(), rtl: true));
    await t.pumpAndSettle();
    // chevron_right mirrors itself in rtl, so the settings rows use it plain
    final rowChevron = t.widget<Icon>(find.byIcon(Icons.chevron_right).first);
    expect(rowChevron.icon!.matchTextDirection, isTrue);
    await t.ensureVisible(find.text('In the Signal library'));
    await t.tap(find.text('In the Signal library'));
    await t.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('libsignal-protocol'),
      matching: find.byType(InkWell),
    );
    final icon = t.widget<Icon>(
      find.descendant(of: row, matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.chevron_right);
  });

  testWidgets('rows wait for the lists and do not open early', (t) async {
    await _show(
      t,
      _host(
        _screen(
          rust: Future<RustLicences>.delayed(
            const Duration(seconds: 1),
            _fakeRust,
          ),
        ),
      ),
    );
    await t.pump();
    await t.ensureVisible(find.text('In the Signal library'));
    await t.tap(find.text('In the Signal library'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('libsignal-protocol'), findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('2 parts'), findsNWidgets(2));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('nothing moves when the lists arrive, text x$scale', (t) async {
      Future<T> late<T>(T Function() v) =>
          Future<T>.delayed(const Duration(seconds: 1), v);
      await _show(
        t,
        _host(
          _screen(
            rust: late(_fakeRust),
            dart: late(_fakeDart),
            engine: late(_fakeEngine),
            gpl: late(() => _gplText),
          ),
          still: true,
          scale: scale,
        ),
      );
      await t.pump();
      final at = {
        for (final s in [
          'Signal protocol',
          'Open source parts',
          // a stacked count under large text wraps by its digits, which a
          // made-up one-digit list does not match
          if (scale == 1) 'In the network engine',
        ])
          s: t.getTopLeft(find.text(s)),
      };
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('3 parts'), findsOneWidget);
      for (final e in at.entries) {
        expect(t.getTopLeft(find.text(e.key)), e.value, reason: e.key);
      }
    });
  }

  testWidgets('off, no voice or translation rows', (t) async {
    await _show(t, _host(_screen()));
    await t.pumpAndSettle();
    expect(find.text('In voice transcription'), findsNothing);
    expect(find.text('In message translation'), findsNothing);
  });

  for (final still in [false, true]) {
    testWidgets('on, their rows open their parts, still: $still', (t) async {
      await _show(
        t,
        _host(_screen(voice: true, translation: true), still: still),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('In voice transcription'));
      expect(find.text('1 part'), findsOneWidget);
      await t.tap(find.text('In voice transcription'));
      await t.pumpAndSettle();
      expect(find.text('v1.9.5 · MIT'), findsOneWidget);
      await t.tap(find.text('whisper.cpp and ggml'));
      await t.pumpAndSettle();
      expect(find.text('whisper.cpp and ggml v1.9.5'), findsOneWidget);
      expect(find.text('ggml MIT text'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('In message translation'));
      await t.tap(find.text('In message translation'));
      await t.pumpAndSettle();
      expect(find.text('eea6e5a8 · MPL-2.0'), findsOneWidget);
      await t.tap(find.text('zlib'));
      await t.pumpAndSettle();
      expect(find.text('zlib text'), findsOneWidget);
    });
  }

  testWidgets('on, a list that fails says so and does not open', (t) async {
    await _show(
      t,
      _host(_screen(voice: true, native: _fail('no native.json'))),
    );
    await t.pumpAndSettle();
    expect(find.text('Could not load'), findsOneWidget);
    await t.ensureVisible(find.text('In voice transcription'));
    await t.tap(find.text('In voice transcription'));
    await t.pumpAndSettle();
    expect(find.text('whisper.cpp and ggml'), findsNothing);
  });

  group('when a list fails to load', () {
    late List<String> copied;
    setUp(() {
      copied = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (c) async {
            if (c.method == 'Clipboard.setData') {
              copied.add((c.arguments as Map)['text'] as String);
            }
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    for (final still in [false, true]) {
      testWidgets('it says so and the texts become links, still: $still', (
        t,
      ) async {
        await _show(
          t,
          _host(
            _screen(
              rust: _fail('no rust.json'),
              engine: _fail('no engine.json'),
              gpl: _fail('no gpl'),
            ),
            still: still,
          ),
        );
        await t.pumpAndSettle();
        // the app list needs the engine's data files too
        expect(find.text('Could not load'), findsNWidgets(3));
        expect(find.textContaining(RegExp(r'^\d+ parts')), findsNothing);
        expect(find.text('gnu.org/licenses/gpl-3.0.txt'), findsOneWidget);
        await t.tap(find.text('GNU GPL 3.0, full text'));
        await t.pump();
        expect(copied, ['https://www.gnu.org/licenses/gpl-3.0.txt']);
        await t.pumpAndSettle(const Duration(seconds: 5));
        await t.ensureVisible(find.text('GNU AGPL 3.0, full text'));
        await t.tap(find.text('GNU AGPL 3.0, full text'));
        await t.pump();
        expect(copied.last, 'https://www.gnu.org/licenses/agpl-3.0.txt');
        await t.pumpAndSettle(const Duration(seconds: 5));
        // a failed list does not open
        await t.ensureVisible(find.text('In the network engine'));
        await t.tap(find.text('In the network engine'));
        await t.pumpAndSettle();
        expect(find.text('tor'), findsNothing);
      });
    }

    testWidgets('the others still open', (t) async {
      await _show(t, _host(_screen(rust: _fail('no rust.json'))));
      await t.pumpAndSettle();
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('3 parts'), findsOneWidget);
      expect(find.text('2 parts'), findsOneWidget);
    });
  });

  testWidgets('a screen reader hears that a source row copies its link', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await _show(t, _host(_screen()));
    await t.pumpAndSettle();
    for (final label in ['Source code', 'libsignal source code']) {
      await t.ensureVisible(find.text(label));
      expect(
        t.getSemantics(find.text(label)),
        isSemantics(hasTapAction: true, onTapHint: 'Copy link'),
        reason: label,
      );
    }
    h.dispose();
  });
}
