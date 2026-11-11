// SPDX-License-Identifier: GPL-3.0-or-later
// linux notifications while the screen is locked: no name and no words, and
// what was shown with words is taken down as the lock goes up. the runner
// reads the lock from the inhibit portal; unknown reads as unlocked
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_linux/flutter_local_notifications_linux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_start.dart';
import 'package:kryfo/desktop/desktop_toasts.dart';
import 'package:kryfo/l10n/l10n.dart';

class _Caught extends QuietLinuxNotifications {
  _Caught(ValueListenable<bool> locked) : super(locked: locked);
  final posted = <(String, String)>[];
  var dropped = 0;

  @override
  Future<void> post({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async => posted.add((title, body));

  @override
  Future<void> dropAll() async => dropped++;
}

Future<void> _show(_Caught n, String? title, String? body) =>
    n.show(id: 1, title: title, body: body);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unlocked: the words as the preview setting gave them', () async {
    final n = _Caught(ValueNotifier(false));
    await _show(n, 'Wren', 'meet at the north gate');
    await _show(n, null, null);
    expect(n.posted, [
      ('Wren', 'meet at the north gate'),
      ('Kryfo', l10n.notificationsNewMessage),
    ]);
  });

  test('locked: kryfo and new message, whatever the post says', () async {
    final n = _Caught(ValueNotifier(true));
    await _show(n, 'Wren', 'meet at the north gate');
    await _show(n, 'Wren', null);
    expect(n.posted, [
      ('Kryfo', l10n.notificationsNewMessage),
      ('Kryfo', l10n.notificationsNewMessage),
    ]);
  });

  test('the lock takes down what was shown with words, once', () async {
    final locked = ValueNotifier(false);
    final n = _Caught(locked);
    await _show(n, 'Wren', 'meet at the north gate');
    locked.value = true;
    await pumpEventQueue();
    expect(n.dropped, 1);
    // nothing with words since: the next lock leaves the list alone
    await _show(n, 'Wren', 'later');
    locked.value = false;
    locked.value = true;
    await pumpEventQueue();
    expect(n.dropped, 1);
    expect(n.posted.last, ('Kryfo', l10n.notificationsNewMessage));
  });

  test('the runner\'s word, asked and heard; unknown stays unlocked', () async {
    const ch = MethodChannel('kryfo/desktop');
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Object? answer;
    m.setMockMethodCallHandler(ch, (call) async {
      expect(call.method, 'screenLocked');
      return answer;
    });
    addTearDown(() => m.setMockMethodCallHandler(ch, null));
    screenLocked.value = false;
    answer = null;
    await readScreenLock(ch);
    expect(screenLocked.value, isFalse);
    answer = true;
    await readScreenLock(ch);
    expect(screenLocked.value, isTrue);
    heardScreenLock(false);
    expect(screenLocked.value, isFalse);
    heardScreenLock(true);
    expect(screenLocked.value, isTrue);
    heardScreenLock(null);
    expect(screenLocked.value, isFalse);
  });

  test('the flatpak asks for no bus name beyond notifications', () {
    final yml = File(
      '../packaging/flatpak/app.kryfo.Kryfo.yml',
    ).readAsLinesSync().where((l) => l.trim().startsWith('- --')).toList();
    expect(yml.where((l) => l.contains('talk-name')), [
      '  - --talk-name=org.freedesktop.Notifications',
    ]);
    expect(yml.where((l) => l.contains('system-talk-name')), isEmpty);
  });

  test('the runner watches the portal, not logind', () {
    final cc = File('linux/runner/my_application.cc').readAsStringSync();
    expect(cc, contains('"CreateMonitor"'));
    expect(cc, contains('"screensaver-active"'));
    expect(cc, contains('"screenLocked"'));
    expect(cc, isNot(contains('org.freedesktop.login1')));
  });
}
