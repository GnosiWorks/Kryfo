// SPDX-License-Identifier: GPL-3.0-or-later
// a message taken back takes its own notification down, not the rest of its
// chat's. android's side is a stand-in that notes what it was asked
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  final up = <int>[];
  final timeouts = <int?>[];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    up.add(id);
    timeouts.add(notificationDetails?.timeoutAfter);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async => up.remove(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only the one taken back leaves the shade', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final shade = _Shade();
    FlutterLocalNotificationsPlatform.instance = shade;
    await showMessageNotification(
      title: 'bob',
      body: 'call me',
      payload: 'bob',
      msgUid: 'u1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await showMessageNotification(
      title: 'bob',
      body: 'at 6',
      payload: 'bob',
      msgUid: 'u2',
    );
    expect(shade.up, hasLength(2));
    final second = shade.up.last;
    await clearMessageNotification('u1');
    expect(shade.up, [second]);
    // asked twice, or for one never shown: nothing more goes
    await clearMessageNotification('u1');
    await clearMessageNotification('nobody');
    expect(shade.up, [second]);
    await clearNotificationsFor('bob');
    expect(shade.up, isEmpty);
  });

  test('a timed message leaves the shade by itself when it burns', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final shade = _Shade();
    FlutterLocalNotificationsPlatform.instance = shade;
    final burnAt = DateTime.now().millisecondsSinceEpoch + 30000;
    await showMessageNotification(
      title: 'bob',
      body: 'gone soon',
      payload: 'bob',
      msgUid: 'b1',
      burnAt: burnAt,
    );
    await showMessageNotification(
      title: 'bob',
      body: 'staying',
      payload: 'bob',
      msgUid: 'b2',
    );
    expect(shade.timeouts.first, inInclusiveRange(28000, 30000));
    expect(shade.timeouts.last, isNull);
    await clearNotificationsFor('bob');
  });
}
