// SPDX-License-Identifier: GPL-3.0-or-later
// a desktop notification never carries a name or a word of a message
import 'package:flutter_local_notifications_linux/flutter_local_notifications_linux.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_start.dart';
import 'package:kryfo/l10n/l10n.dart';

class _Caught extends QuietLinuxNotifications {
  final posted = <(String, String, String?)>[];
  @override
  Future<void> post({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async => posted.add((title, body, payload));
}

void main() {
  test('title and words are replaced, the tap target stays', () async {
    final n = _Caught();
    await n.show(
      id: 7,
      title: 'Wren',
      body: 'meet at the north gate',
      notificationDetails: const LinuxNotificationDetails(),
      payload: 'chat:abc',
    );
    expect(n.posted, [('Kryfo', l10n.notificationsNewMessage, 'chat:abc')]);
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
}
