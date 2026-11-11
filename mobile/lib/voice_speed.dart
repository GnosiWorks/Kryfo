// SPDX-License-Identifier: GPL-3.0-or-later
// how fast received voice notes play: one choice per identity, the decoy
// keeps its own. own notes always play at their own speed
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'container.dart';
import 'desktop/desktop_mode.dart' show onDesktop;
import 'dlog.dart';
import 'secure_store.dart';

const kVoiceSpeedKey = 'voice_speed';

/// the steps a tap goes through
const kVoiceSpeeds = [1.0, 1.5, 2.0];

/// the desktop players play at one speed only
bool get voiceSpeedWorks => !onDesktop;

/// the step after [now], back to 1x after the last
double nextVoiceSpeed(double now) {
  final i = kVoiceSpeeds.indexOf(now);
  return kVoiceSpeeds[(i + 1) % kVoiceSpeeds.length];
}

class VoiceSpeed {
  VoiceSpeed._();

  /// the open identity's speed for received notes
  static final now = ValueNotifier<double>(1.0);
  static HaloContainer? _of;
  static final Map<String, double> _known = {};
  static FlutterSecureStorage _store = secureStore;

  @visibleForTesting
  static void reset({FlutterSecureStorage? storage}) {
    _of = null;
    _known.clear();
    now.value = 1.0;
    _store = storage ?? secureStore;
  }

  /// [c] is the identity whose chats show now
  static Future<void> use(HaloContainer c) async {
    _of = c;
    final had = _known[c.id];
    if (had != null) {
      now.value = had;
      return;
    }
    now.value = 1.0;
    double v = 1.0;
    try {
      v =
          double.tryParse(
            await _store.read(key: c.key(kVoiceSpeedKey)) ?? '',
          ) ??
          1.0;
    } catch (e) {
      dlog('voice speed: not read (${e.runtimeType})');
    }
    if (!kVoiceSpeeds.contains(v)) v = 1.0;
    // a set made while the read was out wins
    _known.putIfAbsent(c.id, () => v);
    if (identical(_of, c)) now.value = _known[c.id]!;
  }

  static Future<void> set(double v) async {
    now.value = v;
    final c = _of;
    if (c == null) return;
    _known[c.id] = v;
    try {
      await _store.write(key: c.key(kVoiceSpeedKey), value: '$v');
    } catch (e) {
      dlog('voice speed: not kept (${e.runtimeType})');
    }
  }
}
