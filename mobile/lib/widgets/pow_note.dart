// SPDX-License-Identifier: GPL-3.0-or-later
// the line under the composer while a first message grinds its proof of
// work. a million hashes is seconds on a fast phone and up to a minute on
// a slow one; without this line the message just sat there.
import 'dart:async';

import 'package:flutter/material.dart';

import '../message_envelope.dart' show powBusy;
import '../theme.dart';

class PowNote extends StatefulWidget {
  const PowNote({super.key});
  @override
  State<PowNote> createState() => _PowNoteState();
}

class _PowNoteState extends State<PowNote> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    powBusy.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    powBusy.removeListener(_sync);
    _tick?.cancel();
    super.dispose();
  }

  void _sync() {
    _tick?.cancel();
    _tick = null;
    if (powBusy.value != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final since = powBusy.value;
    if (since == null) return const SizedBox.shrink();
    final s = DateTime.now().difference(since).inSeconds;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'First message to someone new \u00b7 proving it is real \u00b7 ${s}s'
        '${s >= 20 ? " \u00b7 up to a minute on a slow phone" : ""}',
        style: HaloType.mono(size: 10, color: HaloColors.amber),
        maxLines: 2,
      ),
    );
  }
}
