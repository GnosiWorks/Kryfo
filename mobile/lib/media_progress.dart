// SPDX-License-Identifier: GPL-3.0-or-later
// live progress for chunked media sends over tor.
//
// an 8mb file is ~680 sequential 16k chunks; over tor that is easily 20+
// minutes. without feedback that reads as "broken". the chunk loops report
// here and the sending bubble shows a percentage.
//
// plain ValueNotifiers keyed by msgUid: only the little label listens, so
// updating every chunk causes no rebuild storm, and cleanup is idempotent
// no matter which path a send exits through.
import 'package:flutter/material.dart';

import 'theme.dart';

final Map<String, ValueNotifier<double>> mediaSendProgress = {};

void mediaProgressStart(String msgUid) {
  mediaSendProgress[msgUid] ??= ValueNotifier<double>(0);
}

void mediaProgressUpdate(String msgUid, double v) {
  mediaSendProgress[msgUid]?.value = v;
}

void mediaProgressEnd(String msgUid) {
  final n = mediaSendProgress.remove(msgUid);
  if (n != null) {
    // dispose next frame - a label may still be listening this frame
    WidgetsBinding.instance.addPostFrameCallback((_) => n.dispose());
  }
}

/// "42%" beside the send pill while a chunked media send is running.
class SendProgressLabel extends StatelessWidget {
  final ValueNotifier<double> notifier;
  const SendProgressLabel({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (_, v, __) => Text(
        '${(v * 100).round()}%',
        style: HaloType.mono(size: 9.5, color: HaloColors.text3),
      ),
    );
  }
}
