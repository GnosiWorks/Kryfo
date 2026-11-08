// SPDX-License-Identifier: GPL-3.0-or-later
// windows toasts. what a toast says is what the phone's preview setting gave
// the post, and what a click opens stays in this process
import 'dart:async';
import 'dart:ffi';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/l10n.dart';
import 'desktop_mode.dart' show deskSound;
import 'desktop_trace.dart' show trace;
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
/// the answer, null when ole32 could not be asked
int? joinComApartment({DynamicLibrary Function(String name)? open}) {
  try {
    final ole = (open ?? openSystemDll)('ole32.dll');
    // S_FALSE when already in it; another apartment stays as it is
    final hr = ole.lookupFunction<_CoInitC, _CoInit>('CoInitializeEx')(
      nullptr,
      0,
    );
    // RPC_E_CHANGED_MODE says the thread was in a single threaded one
    trace('toast com 0x${(hr & 0xffffffff).toRadixString(16)}');
    return hr;
  } catch (_) {
    trace('toast com not asked');
    return null;
  }
}

/// a plain post comes without a title and keeps its neutral line. any other
/// says what the post says: previews off, a hidden chat, the vault and a
/// chat that blocks screenshots come as kryfo and new message already.
/// while the windows session is [locked], every toast is kryfo and new
/// message, as on the phone's lock screen
@visibleForTesting
(String?, String) toastWords(
  String? title,
  String? body, {
  bool locked = false,
}) => title == null
    ? (null, l10n.notifPlainLine)
    : locked
    ? ('Kryfo', l10n.notificationsNewMessage)
    : (title, body ?? l10n.notificationsNewMessage);

/// the windows session's lock, as the runner tells it. locked until it
/// answers: a start on the lock screen shows no text
final sessionLocked = ValueNotifier<bool>(true);

/// asks the runner whether the session is locked now. no answer keeps it
/// locked until the first unlock comes
Future<void> readSessionLock(MethodChannel channel) async {
  try {
    final locked = await channel.invokeMethod<bool>('sessionLocked');
    if (locked != null) sessionLocked.value = locked;
  } catch (_) {}
}

/// the runner's word on a lock or an unlock
void heardSessionLock(Object? locked) => sessionLocked.value = locked != false;

/// toasts and the session's lock. a toast with text shown before the lock
/// stays in action center, readable on the lock screen: the lock clears
/// kryfo's toasts when one may hold text
@visibleForTesting
class ToastLock {
  ToastLock(this.locked, this.clear) {
    locked.addListener(_changed);
  }

  final ValueListenable<bool> locked;
  final Future<void> Function() clear;

  // a run before may have left toasts with text
  bool _texted = true;

  /// what a toast says now
  (String?, String) words(String? title, String? body) {
    final w = toastWords(title, body, locked: locked.value);
    if (w.$1 != null &&
        (w.$1 != 'Kryfo' || w.$2 != l10n.notificationsNewMessage)) {
      _texted = true;
    }
    return w;
  }

  void _changed() {
    if (!locked.value || !_texted) return;
    _texted = false;
    unawaited(_clear());
  }

  Future<void> _clear() async {
    try {
      await clear();
    } catch (_) {}
  }

  void dispose() => locked.removeListener(_changed);
}

/// a toast's details: silent when the notifications page's sound switch
/// is off, windows' own sound otherwise
@visibleForTesting
WindowsNotificationDetails? toastDetails() => deskSound.value
    ? null
    : WindowsNotificationDetails(audio: WindowsNotificationAudio.silent());

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

/// the windows plugin with hidden payloads. a click
/// raises the window first
class QuietWindowsNotifications extends FlutterLocalNotificationsWindows {
  QuietWindowsNotifications({
    required this.raise,
    ValueListenable<bool>? locked,
  }) {
    // unpackaged, only clearing all of kryfo's toasts takes them from
    // action center: the plugin's cancel of one id needs a package
    _lock = ToastLock(locked ?? sessionLocked, cancelAll);
  }

  final Future<void> Function() raise;
  final _payloads = ToastPayloads();
  late final ToastLock _lock;

  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) {
    joinComApartment();
    return super.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) {
        trace('toast clicked');
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
    final (t, b) = _lock.words(title, body);
    return toastBoundary(
      () => super.show(
        id: id,
        title: t,
        body: b,
        notificationDetails: toastDetails(),
        payload: _payloads.hide(payload),
      ),
    );
  }

  @override
  Future<void> cancelAll() => toastBoundary(super.cancelAll, what: 'clear');
}

/// a toast's native call between its trace lines: with the trace on, a
/// crash in it leaves "call" with no "back", a crash after it leaves both.
/// a failure is said and thrown on as before
@visibleForTesting
Future<void> toastBoundary(
  Future<void> Function() native, {
  String what = 'shown',
}) async {
  trace('toast $what');
  trace('toast native call');
  // the plugin's ffi call runs synchronously inside its async body, before
  // the future comes back: back means the call returned, windows has it
  final done = native();
  trace('toast native back');
  try {
    await done;
  } catch (e) {
    trace('toast failed: ${e.runtimeType}');
    rethrow;
  }
}
