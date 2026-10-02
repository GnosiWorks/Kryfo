// SPDX-License-Identifier: GPL-3.0-or-later
// the group composer's mic, as the 1:1 one: a finger that comes up while the
// recorder is still starting leaves no recording and no bar behind, and a
// recorder that will not start leaves the mic ready for the next hold. the
// recorder is a stand-in over its channel
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/widgets/media_bubbles.dart' show HoldToTalkMic;
import 'package:kryfo/widgets/voice_parts.dart' show VoiceRecordBar;

import 'dev_chat_fakes.dart';

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

const _rec = 'com.llfbandit.record/messages';

void main() {
  late Directory tmp;
  // what the recorder was asked, in order
  late List<String> asked;
  // the start answers once this is let go
  late Completer<void> starting;
  // a start that fails
  late bool broken;
  String? recording;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('group_mic');
    asked = [];
    starting = Completer<void>();
    broken = false;
    recording = null;
    // a recording runs only over an unlocked app
    lockState.openForTest();
    _mock('plugins.flutter.io/path_provider', (_) async => tmp.path);
    _mock(_rec, (c) async {
      asked.add(c.method);
      switch (c.method) {
        // its state comes over a channel of its own, quiet here
        case 'create':
          final id = (c.arguments as Map)['recorderId'];
          _mock('com.llfbandit.record/events/$id', (_) async => null);
        case 'hasPermission':
          return true;
        case 'start':
          if (broken) throw PlatformException(code: 'busy');
          recording = (c.arguments as Map)['path'] as String;
          File(recording!).writeAsBytesSync(List.filled(64, 1));
          await starting.future;
          return null;
        case 'stop':
          return recording;
      }
      return null;
    });
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock(_rec, null);
    tmp.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester t, List<bool> done) => devOpen(
    t,
    Scaffold(
      body: Center(
        child: HoldToTalkMic(
          disguise: false,
          onToggleDisguise: () {},
          onComplete: (_, _, cancelled) => done.add(cancelled),
        ),
      ),
    ),
  );

  Future<TestGesture> hold(WidgetTester t) async {
    final g = await t.startGesture(t.getCenter(find.byType(HoldToTalkMic)));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await t.pump();
    return g;
  }

  // real file work runs outside the test's clock
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  // turns of the real clock until [f] shows, or the last one
  Future<void> until(WidgetTester t, Finder f) async {
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('let go while the recorder starts, it stops and leaves nothing', (
    t,
  ) async {
    final done = <bool>[];
    await open(t, done);
    final g = await hold(t);
    expect(asked, contains('start'));
    await g.up();
    await t.pump();
    starting.complete();
    await settle(t);
    // stopped after it started, its file shredded, no bar and no note
    expect(asked.lastIndexOf('stop'), greaterThan(asked.indexOf('start')));
    expect(File(recording!).existsSync(), isFalse);
    expect(find.byType(VoiceRecordBar), findsNothing);
    expect(done.where((c) => !c), isEmpty);
    await devClose(t);
    // the recorder lets go of the plugin's one lock before the next test
    await settle(t);
  });

  testWidgets('a recorder that will not start leaves the mic ready', (t) async {
    broken = true;
    final done = <bool>[];
    await open(t, done);
    var g = await hold(t);
    await g.up();
    final toast = find.textContaining(l10n.chatTheMicWouldNot);
    await until(t, toast);
    expect(toast, findsOneWidget);
    expect(find.byType(VoiceRecordBar), findsNothing);
    await t.pump(const Duration(seconds: 4));
    // the next hold reaches the recorder again
    broken = false;
    starting.complete();
    g = await hold(t);
    await settle(t);
    expect(asked.where((m) => m == 'hasPermission'), hasLength(2));
    expect(find.byType(VoiceRecordBar), findsOneWidget);
    await g.up();
    await settle(t);
    expect(find.byType(VoiceRecordBar), findsNothing);
    await devClose(t);
    // the recorder lets go of the plugin's one lock before the next test
    await settle(t);
  });
}
