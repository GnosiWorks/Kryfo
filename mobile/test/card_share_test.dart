// SPDX-License-Identifier: GPL-3.0-or-later
// a contact card goes out as any shared file does: through a copy the share
// rules keep and shred, a decoy's or a hidden chat's with the next lock.
// nothing named after the identity stays in the cache
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/contact_card.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/open_file.dart' show shareGoesWithLock;

import 'shred_twin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  late Directory twins;
  final asked = <Map<Object?, Object?>>[];
  final read = <String>[];

  setUp(() {
    // a phone with no lock, open
    lockState.openForTest();
    cache = Directory.systemTemp.createTempSync('card_share');
    twins = Directory.systemTemp.createTempSync('card_twins');
    asked.clear();
    read.clear();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => cache.path,
    );
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), (
      call,
    ) async {
      if (call.method != 'shareFile') return null;
      final args = call.arguments as Map<Object?, Object?>;
      asked.add(args);
      // the native side copies it before it answers
      read.add(File(args['path']! as String).readAsStringSync());
      return true;
    });
  });

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    shareGoesWithLock = () => false;
    cache.deleteSync(recursive: true);
    twins.deleteSync(recursive: true);
  });

  for (final quiet in [false, true]) {
    test(
      quiet
          ? 'a decoy\'s card goes with the next lock, and leaves nothing'
          : 'a card goes out under its name and leaves nothing behind',
      () async {
        shareGoesWithLock = () => quiet;
        await shareContactVcf(haloId: 'quiet-otter-lamp', uri: 'kryfo://x');
        expect(asked, hasLength(1));
        expect(asked.single['name'], 'kryfo-quiet-otter-lamp.vcf');
        expect(asked.single['quiet'], quiet);
        expect(asked.single['path'] as String, isNot(contains('quiet-otter')));
        expect(read.single, contains('BEGIN:VCARD'));
        expect(cache.listSync(), isEmpty);
      },
    );
  }

  test('cards an older version left are shredded at start, the rest of '
      'the cache stays', () async {
    final old = File('${cache.path}/kryfo-quiet-otter-lamp.png')
      ..writeAsBytesSync(List.filled(20000, 7), flush: true);
    final twin = twinOf(old.path, twins);
    final vcf = File('${cache.path}/kryfo-quiet-otter-lamp.vcf')
      ..writeAsStringSync('BEGIN:VCARD');
    final other = File('${cache.path}/vn_1.wav')..writeAsStringSync('keep');
    await sweepCardLeftovers(cache);
    expect(old.existsSync(), isFalse);
    expect(vcf.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
    expect(other.existsSync(), isTrue);
  });
}
