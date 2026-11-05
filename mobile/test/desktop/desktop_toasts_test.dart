// SPDX-License-Identifier: GPL-3.0-or-later
// a windows toast says what the preview setting gave the post, never what a
// click opens
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  group('the windows session lock', () {
    late ValueNotifier<bool> locked;
    late int clears;
    late ToastLock lock;
    setUp(() {
      locked = ValueNotifier(false);
      clears = 0;
      lock = ToastLock(locked, () async => clears++);
    });
    tearDown(() => lock.dispose());

    test('locked, every named toast is kryfo and new message', () {
      expect(lock.words('Wren', 'meet at the gate'), (
        'Wren',
        'meet at the gate',
      ));
      locked.value = true;
      expect(lock.words('Wren', 'meet at the gate'), (
        'Kryfo',
        l10n.notificationsNewMessage,
      ));
      expect(lock.words('Wren', null), ('Kryfo', l10n.notificationsNewMessage));
      // a plain post keeps its own neutral line
      expect(lock.words(null, 'meet at the gate'), (null, l10n.notifPlainLine));
      locked.value = false;
      expect(lock.words('Wren', 'meet at the gate'), (
        'Wren',
        'meet at the gate',
      ));
    });

    test('the lock clears toasts that may hold text', () async {
      // a run before may have left some
      locked.value = true;
      await Future<void>.delayed(Duration.zero);
      expect(clears, 1);
      locked.value = false;
      lock.words('Kryfo', l10n.notificationsNewMessage);
      lock.words(null, 'meet at the gate');
      locked.value = true;
      await Future<void>.delayed(Duration.zero);
      expect(clears, 1, reason: 'only neutral toasts since the last clear');
      locked.value = false;
      lock.words('Wren', 'meet at the gate');
      locked.value = true;
      await Future<void>.delayed(Duration.zero);
      expect(clears, 2);
      // unlocking clears nothing
      locked.value = false;
      await Future<void>.delayed(Duration.zero);
      expect(clears, 2);
    });

    test('a clear that fails is let go', () async {
      final l = ToastLock(locked, () async => throw StateError('not ready'));
      addTearDown(l.dispose);
      locked.value = true;
      await Future<void>.delayed(Duration.zero);
      expect(l.words('Wren', 'hi'), ('Kryfo', l10n.notificationsNewMessage));
    });

    test('the runner\'s answer and events set the lock', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const ch = MethodChannel('kryfo/desktop');
      final m =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        m.setMockMethodCallHandler(ch, null);
        sessionLocked.value = true;
      });
      expect(sessionLocked.value, isTrue, reason: 'locked until told');
      Object? answer = false;
      m.setMockMethodCallHandler(ch, (call) async {
        expect(call.method, 'sessionLocked');
        return answer;
      });
      await readSessionLock(ch);
      expect(sessionLocked.value, isFalse);
      answer = true;
      await readSessionLock(ch);
      expect(sessionLocked.value, isTrue);
      // no answer: as it was
      sessionLocked.value = true;
      answer = null;
      await readSessionLock(ch);
      expect(sessionLocked.value, isTrue);
      m.setMockMethodCallHandler(ch, (call) async {
        throw PlatformException(code: 'none');
      });
      await readSessionLock(ch);
      expect(sessionLocked.value, isTrue);
      heardSessionLock(false);
      expect(sessionLocked.value, isFalse);
      heardSessionLock(true);
      expect(sessionLocked.value, isTrue);
      heardSessionLock(null);
      expect(sessionLocked.value, isTrue);
    });
  });
}
