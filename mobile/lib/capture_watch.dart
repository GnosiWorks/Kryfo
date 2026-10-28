// SPDX-License-Identifier: GPL-3.0-or-later
// android's word that this window was screenshotted (14 and later) or is
// in a screen recording (15 and later). the chat in front says so in one
// quiet line on this phone. nothing about it leaves the phone, and it is a
// hint only: older phones and other ways of capturing say nothing
import 'package:flutter/services.dart';

enum Capture { shot, recording }

const _channel = BasicMessageChannel<String>('kryfo/capture', StringCodec());

typedef CaptureSeen = void Function(Capture what);

class CaptureWatch {
  CaptureWatch._();

  final List<CaptureSeen> _seen = [];
  bool _listening = false;

  /// [seen] hears each capture while it is the newest one registered: the
  /// screen on top. the returned call lets go
  VoidCallback watch(CaptureSeen seen) {
    if (!_listening) {
      _listening = true;
      _channel.setMessageHandler((m) async {
        take(m);
        return '';
      });
    }
    _seen.add(seen);
    return () => _seen.remove(seen);
  }

  /// a word from android: 'shot', 'rec:1' or 'rec:0'
  void take(String? m) {
    final what = switch (m) {
      'shot' => Capture.shot,
      'rec:1' => Capture.recording,
      _ => null,
    };
    if (what == null || _seen.isEmpty) return;
    _seen.last(what);
  }
}

final captureWatch = CaptureWatch._();
