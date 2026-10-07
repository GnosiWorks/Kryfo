// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

bool _inFront() =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

// whether a cold start boots now: the app is in front, or [setUp] finds the
// phone set up. the state is read again after the check, since a resume that
// lands while it runs reaches no listener
Future<bool> bootsNow(Future<bool> Function() setUp) async =>
    _inFront() || await setUp() || _inFront();
