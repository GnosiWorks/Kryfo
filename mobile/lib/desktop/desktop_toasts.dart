// SPDX-License-Identifier: GPL-3.0-or-later
// windows toasts. windows keeps every toast in its own history on the disk,
// so a toast says only that something came, and what a click opens stays in
// this process
import 'dart:async';
import 'dart:ffi';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/l10n.dart';
import 'seal_windows.dart' show openSystemDll;

/// the start menu shortcut's id (kryfo.iss), so toasts and the taskbar
/// group under it
const kToastAppId = 'app.kryfo';

/// the class windows hands a toast click to. fixed: windows keeps it
const kToastClass = '66dbbf7b-dcb7-4bc5-a958-45171a969471';

WindowsInitializationSettings windowsToastSettings() =>
    const WindowsInitializationSettings(
      appName: 'Kryfo',
      appUserModelId: kToastAppId,
      guid: kToastClass,
    );

typedef _CoInitC = Int32 Function(Pointer<Void>, Uint32);
typedef _CoInit = int Function(Pointer<Void>, int);

/// dart runs on a thread of its own on windows (the runner's ui thread
/// policy), one com was never set up on, and the plugin's toast calls are
/// com. this thread joins the multithreaded apartment first: a click comes
/// in on com's own threads and needs no message loop here
void joinComApartment({DynamicLibrary Function(String name)? open}) {
  try {
    final ole = (open ?? openSystemDll)('ole32.dll');
    // S_FALSE when already in it; another apartment stays as it is
    ole.lookupFunction<_CoInitC, _CoInit>('CoInitializeEx')(nullptr, 0);
  } catch (_) {}
}

/// a plain post comes without a title and keeps its neutral line. every
/// other toast says only that a message came, whatever the setting
@visibleForTesting
(String?, String) toastWords(String? title) => title == null
    ? (null, l10n.notifPlainLine)
    : ('Kryfo', l10n.notificationsNewMessage);

/// a toast carries a random token, the payload it stands for stays here
@visibleForTesting
class ToastPayloads {
  ToastPayloads({this.keep = 256});

  final int keep;
  final _byToken = <String, String>{};
  final _r = Random.secure();

  String? hide(String? payload) {
    if (payload == null) return null;
    final t = List.generate(16, (_) => _r.nextInt(16).toRadixString(16)).join();
    _byToken[t] = payload;
    while (_byToken.length > keep) {
      _byToken.remove(_byToken.keys.first);
    }
    return t;
  }

  NotificationResponse restore(NotificationResponse r) => NotificationResponse(
    notificationResponseType: r.notificationResponseType,
    id: r.id,
    actionId: r.actionId,
    input: r.input,
    payload: r.payload == null ? null : _byToken[r.payload],
    data: r.data,
  );
}

/// the windows plugin with neutral words and hidden payloads. a click
/// raises the window first
class QuietWindowsNotifications extends FlutterLocalNotificationsWindows {
  QuietWindowsNotifications({required this.raise});

  final Future<void> Function() raise;
  final _payloads = ToastPayloads();

  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) {
    joinComApartment();
    return super.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) {
        unawaited(raise());
        onDidReceiveNotificationResponse?.call(_payloads.restore(r));
      },
    );
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) {
    final (t, b) = toastWords(title);
    return super.show(
      id: id,
      title: t,
      body: b,
      payload: _payloads.hide(payload),
    );
  }
}
