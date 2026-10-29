// SPDX-License-Identifier: GPL-3.0-or-later
// one spoken line for a screen reader, for a change that has no node of
// its own to live in (a wrong pin, a countdown that starts, a message in)
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../lock_guard.dart' show lockGuard;

void sayOnce(BuildContext context, String words) {
  final view = View.maybeOf(context);
  if (view == null || words.isEmpty) return;
  SemanticsService.sendAnnouncement(view, words, Directionality.of(context));
}

/// new messages in the chat on screen, said once per batch while a screen
/// reader is on. never under the lock, never from behind another page or
/// with the app away, and never the words themselves
void sayArrivals(BuildContext context, int count) {
  if (count <= 0) return;
  if (!(MediaQuery.maybeAccessibleNavigationOf(context) ?? false)) return;
  if (lockGuard.isLocked()) return;
  final life = WidgetsBinding.instance.lifecycleState;
  if (life != null && life != AppLifecycleState.resumed) return;
  if (ModalRoute.of(context)?.isCurrent == false) return;
  sayOnce(context, l10n.a11yNewMessages(count));
}
