// SPDX-License-Identifier: GPL-3.0-or-later
// a windows toast says what the preview setting gave the post, never what a
// click opens
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show deskSound;
import 'package:kryfo/desktop/desktop_toasts.dart';
import 'package:kryfo/l10n/l10n.dart';

void main() {
  test('a named post says what it was given', () {
    expect(toastWords('Wren', 'meet at the gate'), (
      'Wren',
      'meet at the gate',
    ));
    expect(toastWords('Kryfo', l10n.notificationsNewMessage), (
      'Kryfo',
      l10n.notificationsNewMessage,
    ));
    expect(toastWords('Wren', null), ('Wren', l10n.notificationsNewMessage));
  });

  test('a plain post keeps its neutral line and no title', () {
    expect(toastWords(null, 'meet at the gate'), (null, l10n.notifPlainLine));
    expect(toastWords(null, null), (null, l10n.notifPlainLine));
  });

  test('the settings windows needs are there and well formed', () {
    final s = windowsToastSettings();
    expect(s.appName, 'Kryfo');
    expect(s.appUserModelId, 'app.kryfo');
    // the plugin's own check, which throws at initialize otherwise
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(s.guid),
      isTrue,
    );
  });

  test('the sound switch off makes every toast silent', () {
    addTearDown(() => deskSound.value = true);
    deskSound.value = true;
    expect(toastDetails(), isNull);
    deskSound.value = false;
    expect(toastDetails()!.audio!.isSilent, isTrue);
  });

  test('a toast holds a token, the click gets the payload back', () {
    final p = ToastPayloads();
    final t = p.hide('chat:abc')!;
    expect(t, isNot(contains('abc')));
    expect(t, matches(RegExp(r'^[0-9a-f]{16}$')));
    final r = p.restore(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 7,
        payload: t,
      ),
    );
    expect(r.payload, 'chat:abc');
    expect(r.id, 7);
    expect(p.hide(null), isNull);
  });

  test('an unknown token opens nothing, old ones are let go', () {
    final p = ToastPayloads(keep: 2);
    final first = p.hide('a')!;
    p.hide('b');
    p.hide('c');
    NotificationResponse click(String? t) => p.restore(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: t,
      ),
    );
    expect(click(first).payload, isNull);
    expect(click('chat:abc').payload, isNull);
    expect(click(null).payload, isNull);
  });
}
