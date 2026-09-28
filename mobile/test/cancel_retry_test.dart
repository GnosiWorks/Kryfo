// SPDX-License-Identifier: GPL-3.0-or-later
// a notification that must go when chats go out of sight: a cancel that
// fails gets one more try a beat later, and a second failure is only logged.
// android's side is a stand-in
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/notifications.dart';
import 'package:kryfo/vault_life.dart';

class _Shade extends FlutterLocalNotificationsPlatform {
  // how many cancels in a row fail
  int fails = 0;
  int asked = 0;

  @override
  Future<void> cancelAll() async {
    asked++;
    if (fails > 0) {
      fails--;
      throw PlatformException(code: 'shade');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('one more try', () {
    test('a cancel that goes is asked once', () async {
      var asked = 0;
      await cancelWithRetry(() async => asked++, 'test');
      expect(asked, 1);
    });

    test('one that fails once goes on the second try', () async {
      var asked = 0;
      final at = <Duration>[];
      final clock = Stopwatch()..start();
      await cancelWithRetry(() async {
        at.add(clock.elapsed);
        if (++asked == 1) throw PlatformException(code: 'shade');
      }, 'test');
      expect(asked, 2);
      expect(at[1] - at[0], greaterThanOrEqualTo(kCancelRetryAfter));
    });

    test('one that keeps failing is tried twice and throws nothing', () async {
      var asked = 0;
      await cancelWithRetry(() async {
        asked++;
        throw PlatformException(code: 'shade');
      }, 'test');
      expect(asked, 2);
    });
  });

  test('hiding chats clears the shade even when it says no once', () async {
    final shade = _Shade()..fails = 1;
    FlutterLocalNotificationsPlatform.instance = shade;
    await const LiveVaultHost().clearShade(const ['a-chat']);
    expect(shade.asked, 2);
    shade.fails = 2;
    await const LiveVaultHost().clearShade(const ['a-chat']);
    expect(shade.asked, 4);
  });
}
