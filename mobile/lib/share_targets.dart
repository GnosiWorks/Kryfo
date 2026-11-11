// SPDX-License-Identifier: GPL-3.0-or-later
// everyday chats in android's share menu, when the person turns it on (off
// by default): a few of the latest 1:1 chats, by the name the chat shows
// and a drawn initial, never a photo. never a hidden chat, a room, a
// blocked or archived one, never the decoy's. while the app lock is up
// there are none: they go the moment it locks and come back at the unlock.
// a hidden or deleted chat leaves with the next change of the list. groups
// wait until a share can land in one. android 13 and later only, where the
// menu's targets can be kept off the launcher's long press. a computer has
// none of it
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';
import 'desktop/desktop_mode.dart' show onDesktop;
import 'lock_state.dart' show lockState;
import 'main.dart' show appState, session, AppStateSession;
import 'screens/home_screen.dart' show ContactPreview;
import 'theme.dart' show HaloColors;

const _onKey = 'kryfo.share_menu.on';
// a random word the ids are made with, so none names a kryfo id
const _saltKey = 'kryfo.share_menu.salt';

/// how many chats the menu gets
const kShareTargetsMost = 4;

/// whether the person turned it on for [c]. off until they do
Future<bool> loadShareMenuOn([HaloContainer c = HaloContainer.everyday]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_onKey)) ?? false;
}

/// a decoy's or a vault's switch is its own and publishes nothing
Future<void> saveShareMenuOn(
  bool on, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_onKey), on);
  if (c == HaloContainer.everyday) shareTargets.everydayOn(on);
}

/// one chat in the menu
@immutable
class ShareTarget {
  final String id;
  final String chat;
  final String name;
  const ShareTarget(this.id, this.chat, this.name);

  Map<String, Object> toMap() => {
    'id': id,
    'name': name,
    'initial': initialOf(name),
  };

  @override
  bool operator ==(Object other) =>
      other is ShareTarget &&
      other.id == id &&
      other.chat == chat &&
      other.name == name;
  @override
  int get hashCode => Object.hash(id, chat, name);
}

/// the first letter the drawn icon carries, a whole character
String initialOf(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  final r = t.runes.first;
  return String.fromCharCode(r).toUpperCase();
}

/// android's side: whether the menu can take them, and the list
abstract class ShareTargetsIo {
  Future<bool> supported();
  Future<void> publish(List<ShareTarget> list);
  Future<void> clear();
}

class _ChannelIo implements ShareTargetsIo {
  static const _ch = MethodChannel('kryfo/share_targets');
  @override
  Future<bool> supported() async =>
      await _ch.invokeMethod<bool>('supported') ?? false;
  @override
  Future<void> publish(List<ShareTarget> list) => _ch.invokeMethod('publish', {
    'targets': [for (final t in list) t.toMap()],
    'bg': HaloColors.ink.toARGB32(),
    'fg': HaloColors.yellow.toARGB32(),
  });
  @override
  Future<void> clear() => _ch.invokeMethod('clear');
}

/// what the list is made from, as the app is now
class ShareFacts {
  final bool on;
  final bool locked;
  final bool everyday;
  final List<ContactPreview> contacts;
  const ShareFacts({
    required this.on,
    required this.locked,
    required this.everyday,
    required this.contacts,
  });
}

/// the chats the menu should hold now, the latest first, none when it may
/// hold none
List<ShareTarget> shareTargetsFor(ShareFacts f, String salt) {
  if (!f.on || f.locked || !f.everyday) return const [];
  final chats = [
    for (final c in f.contacts)
      if (!c.hidden && !c.blocked && !c.archived) c,
  ];
  int at(ContactPreview c) => c.when?.millisecondsSinceEpoch ?? 0;
  chats.sort((a, b) => at(b).compareTo(at(a)));
  return [
    for (final c in chats.take(kShareTargetsMost))
      ShareTarget(
        shareTargetId(salt, c.haloId),
        c.haloId,
        c.nickname ?? c.haloId,
      ),
  ];
}

/// a chat's id in the menu: no kryfo id in it, the same for the same chat
String shareTargetId(String salt, String chat) =>
    'c${sha256.convert(utf8.encode('$salt:$chat')).toString().substring(0, 24)}';

class ShareTargets {
  ShareTargets({
    ShareTargetsIo? io,
    ShareFacts Function(bool on)? facts,
    Future<bool> Function()? loadOn,
    Future<String> Function()? salt,
    this.settle = const Duration(milliseconds: 300),
    bool? android,
  }) : _io = io ?? _ChannelIo(),
       _facts = facts ?? _liveFacts,
       _loadOn = loadOn ?? loadShareMenuOn,
       _saltOf = salt ?? _liveSalt,
       _android = android ?? (!kIsWeb && Platform.isAndroid && !onDesktop);

  final ShareTargetsIo _io;
  final ShareFacts Function(bool on) _facts;
  final Future<bool> Function() _loadOn;
  final Future<String> Function() _saltOf;
  final bool _android;

  /// how long a change of the list waits for the next one
  final Duration settle;

  bool _on = false;
  bool _started = false;
  bool? _supported;
  String? _salt;
  // what android holds, null until told once in this process
  List<ShareTarget>? _held;
  Timer? _soon;
  // one call to android at a time, in order
  Future<void> _chain = Future.value();

  static ShareFacts _liveFacts(bool on) => ShareFacts(
    on: on,
    locked: lockState.locked,
    everyday:
        !lockState.inDecoy &&
        !appState.inDecoyView &&
        session.container == HaloContainer.everyday,
    contacts: appState.contacts,
  );

  static Future<String> _liveSalt() async {
    final prefs = await SharedPreferences.getInstance();
    final had = prefs.getString(_saltKey);
    if (had != null && had.isNotEmpty) return had;
    final r = Random.secure();
    final s = [
      for (var i = 0; i < 16; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await prefs.setString(_saltKey, s);
    return s;
  }

  /// whether this phone's menu can take them: the switch shows only then
  Future<bool> supported() async {
    if (!_android) return false;
    try {
      return _supported ??= await _io.supported();
    } catch (_) {
      return false;
    }
  }

  /// once, after the app starts: the lock and the chats are followed from
  /// here, and what an earlier run left is put right
  Future<void> start() async {
    if (!_android || _started) return;
    _started = true;
    try {
      _on = await _loadOn();
    } catch (_) {
      _on = false;
    }
    lockState.addListener(changed);
    appState.addListener(changed);
    changed();
  }

  @visibleForTesting
  Future<void> startForTest() async {
    _started = true;
    _on = await _loadOn();
    changed();
  }

  /// the everyday switch moved
  void everydayOn(bool on) {
    _on = on;
    changed();
  }

  /// the lock, the session or the chats changed: an empty list goes at
  /// once, anything else after [settle]
  void changed() {
    if (!_android || !_started) return;
    final f = _facts(_on);
    if (!f.on || f.locked || !f.everyday) {
      _soon?.cancel();
      _soon = null;
      _send(const []);
      return;
    }
    _soon?.cancel();
    _soon = Timer(settle, () {
      _soon = null;
      unawaited(_publishNow());
    });
  }

  Future<void> _publishNow() async {
    final salt = _salt ??= await _saltOf();
    // the lock may have come while the salt was read
    _send(shareTargetsFor(_facts(_on), salt));
  }

  void _send(List<ShareTarget> want) {
    _chain = _chain.then((_) async {
      if (_held != null && listEquals(_held, want)) return;
      try {
        if (want.isEmpty) {
          await _io.clear();
        } else {
          if (!await supported()) return;
          await _io.publish(want);
        }
        _held = want;
      } catch (_) {
        // told again at the next change
        _held = null;
      }
    });
  }

  /// done telling android
  @visibleForTesting
  Future<void> get idle async {
    while (true) {
      final c = _chain;
      await c;
      if (identical(c, _chain) && _soon == null) return;
      if (_soon != null) await Future<void>.delayed(settle);
    }
  }

  /// the chat a share picked in the menu went to, when it may go there
  /// now: an everyday chat in the list as it stands, the lock down, no
  /// decoy. null sends the share through the picker
  Future<String?> chatFor(String? shortcutId) async {
    if (shortcutId == null || shortcutId.isEmpty || !_android) return null;
    final f = _facts(_on);
    final salt = _salt ??= await _saltOf();
    if (!f.on || f.locked || !f.everyday) return null;
    for (final c in f.contacts) {
      if (c.hidden || c.blocked) continue;
      if (shareTargetId(salt, c.haloId) == shortcutId) return c.haloId;
    }
    return null;
  }
}

final shareTargets = ShareTargets();
