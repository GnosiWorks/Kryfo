// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes being recorded right now. what would take the screen away
// from one waits until it ends
import 'dart:async';

import 'package:flutter/foundation.dart';

final voiceRecording = ValueNotifier<int>(0);

/// [unguard] counted as a recording until it is called, once
VoidCallback recordingUntil(VoidCallback unguard) {
  voiceRecording.value++;
  var done = false;
  return () {
    if (done) return;
    done = true;
    voiceRecording.value--;
    unguard();
  };
}

/// done once no voice note is being recorded
Future<void> voiceNotesDone() {
  if (voiceRecording.value == 0) return Future.value();
  final done = Completer<void>();
  void check() {
    if (voiceRecording.value > 0 || done.isCompleted) return;
    voiceRecording.removeListener(check);
    done.complete();
  }

  voiceRecording.addListener(check);
  return done.future;
}
