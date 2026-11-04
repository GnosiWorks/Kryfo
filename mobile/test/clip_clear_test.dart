// SPDX-License-Identifier: GPL-3.0-or-later
// a message's words copied are marked sensitive and leave the clipboard
// when another pin could read them: a copy from hidden chats or the decoy
// at the lock and as hidden chats close, any copy at a switch of pin, and
// whatever is there at a wipe. an everyday copy outlives a lock, so it can
// be pasted into another app
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> said;

  setUp(() {
    said = [];
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), (c) async {
      said.add(c);
      return true;
    });
    clipGoesWithLock = () => false;
  });

  tearDown(() async {
    await dropOurClip(wipe: true);
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    clipGoesWithLock = () => false;
  });

  List<Map> clears() => [
    for (final c in said)
      if (c.method == 'clearClip') c.arguments as Map,
  ];

  test('a message copied is sensitive and has no minute\'s clear', () async {
    await copySensitive('meet at six', kept: true);
    expect(said.single.method, 'copySensitive');
    expect(said.single.arguments, {'text': 'meet at six'});
    expect(ourClipForTest, (value: 'meet at six', quiet: false));
  });

  test('an everyday copy stays through a lock and the hidden chats '
      'closing, and goes at a switch of pin', () async {
    await copySensitive('everyday words', kept: true);
    await dropOurClip(quietOnly: true);
    expect(clears(), isEmpty);
    await dropOurClip();
    expect(clears().single, {
      'text': 'everyday words',
      'force': false,
      'any': false,
    });
    expect(ourClipForTest.value, isNull);
  });

  test('a copy from hidden chats goes with the lock, even unread', () async {
    clipGoesWithLock = () => true;
    await copySensitive('hidden words', kept: true);
    expect(ourClipForTest.quiet, isTrue);
    await dropOurClip(quietOnly: true);
    expect(clears().single, {
      'text': 'hidden words',
      'force': true,
      'any': false,
    });
  });

  test('a wipe clears the clipboard whatever is on it', () async {
    await dropOurClip(wipe: true);
    expect(clears().single['any'], isTrue);
    expect(clears().single['force'], isTrue);
  });
}
