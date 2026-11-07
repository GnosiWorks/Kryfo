// SPDX-License-Identifier: GPL-3.0-or-later
// a desktop notification follows the phone's preview setting: kryfo and new
// message unless previews are on, and never a word of a hidden chat or the
// vault, or anything while a decoy is open
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_linux/flutter_local_notifications_linux.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_start.dart';
import 'package:kryfo/desktop/desktop_toasts.dart' show toastWords;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Caught extends QuietLinuxNotifications {
  final posted = <(String, String, String?)>[];
  // what the post asked for, before the desktop's words
  final asked = <(String?, String?)>[];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    LinuxNotificationDetails? notificationDetails,
    String? payload,
  }) {
    asked.add((title, body));
    return super.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  @override
  Future<void> post({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async => posted.add((title, body, payload));
}

// the phone's preview setting as stored, and a decoy open or not
_Caught _desk({bool? hide, bool plain = false, bool quiet = false}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  SharedPreferences.setMockInitialValues({
    HaloContainer.everyday.key('notif_hide_content'): ?hide,
    if (plain) HaloContainer.everyday.key('notif_plain'): true,
  });
  FlutterSecureStorage.setMockInitialValues({
    if (quiet) 'halo.lock.state': '{"q":true}',
  });
  final n = _Caught();
  FlutterLocalNotificationsPlatform.instance = n;
  return n;
}

Future<void> _ring({bool hidden = false}) => showMessageNotification(
  title: 'Wren',
  body: 'meet at the north gate',
  chat: 'abc',
  tag: 't-abc',
  hidden: hidden,
);

// what a windows toast would say for the same post
(String?, String) _toast(_Caught n) =>
    toastWords(n.asked.single.$1, n.asked.single.$2);

// a post the server answers late, and what is taken down, in order
class _Slow extends QuietLinuxNotifications {
  final events = <String>[];
  final answer = Completer<void>();

  @override
  Future<void> post({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    events.add('post $id');
    await answer.future;
    events.add('posted $id');
  }

  @override
  Future<void> drop(int id) async => events.add('drop $id');

  @override
  Future<void> dropAll() async => events.add('drop all');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('halo/platform'),
          (_) async => true,
        );
  });

  test('previews on: the name and the words, as on the phone', () async {
    final n = _desk(hide: false);
    await _ring();
    expect(n.posted.single.$1, 'Wren');
    expect(n.posted.single.$2, 'meet at the north gate');
    expect(_toast(n), ('Wren', 'meet at the north gate'));
  });

  test('previews off by default: kryfo and new message', () async {
    final n = _desk();
    await _ring();
    expect(n.posted.single.$1, 'Kryfo');
    expect(n.posted.single.$2, l10n.notificationsNewMessage);
    expect(_toast(n), ('Kryfo', l10n.notificationsNewMessage));
  });

  test('a hidden chat or the vault never says whose or what', () async {
    final n = _desk(hide: false);
    await _ring(hidden: true);
    expect(n.posted.single.$1, 'Kryfo');
    expect(n.posted.single.$2, l10n.notificationsNewMessage);
    expect(_toast(n), ('Kryfo', l10n.notificationsNewMessage));
  });

  test('plain says nothing of the message', () async {
    final n = _desk(hide: false, plain: true);
    await _ring();
    expect(n.posted.single.$1, 'Kryfo');
    expect(n.posted.single.$2, l10n.notificationsNewMessage);
    expect(_toast(n), (null, l10n.notifPlainLine));
  });

  test('a decoy open shows nothing at all', () async {
    final n = _desk(hide: false, quiet: true);
    await _ring();
    expect(n.posted, isEmpty);
  });

  test('a post with a name keeps it and its tap target', () async {
    final n = _Caught();
    await n.show(
      id: 7,
      title: 'Wren',
      body: 'meet at the north gate',
      notificationDetails: const LinuxNotificationDetails(),
      payload: 'chat:abc',
    );
    expect(n.posted, [('Wren', 'meet at the north gate', 'chat:abc')]);
  });

  test('with nothing given it still says only that', () async {
    final n = _Caught();
    await n.show(id: 1);
    expect(n.posted.single.$1, 'Kryfo');
    expect(n.posted.single.$2, l10n.notificationsNewMessage);
  });

  test('a click raises the window, then opens what it names', () async {
    final seen = <String>[];
    final f = windowFirst(
      (r) => seen.add('open ${r.payload}'),
      show: () async => seen.add('window'),
    );
    f(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'chat:abc',
      ),
    );
    expect(seen, ['window', 'open chat:abc']);
  });

  test('a cancel waits for the post before it to be recorded', () async {
    final n = _Slow();
    final shown = n.show(id: 7, title: 'Wren', body: 'hi');
    final gone = n.cancel(id: 7);
    final all = n.cancelAll();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(n.events, ['post 7']);
    n.answer.complete();
    await Future.wait([shown, gone, all]);
    expect(n.events, ['post 7', 'posted 7', 'drop 7', 'drop all']);
  });
}
