// SPDX-License-Identifier: GPL-3.0-or-later
// a linked computer's start: before a chat shows or anything goes out, its
// phone's pair is read on the relays to the bottom and what came is
// opened, so a removal sent while it was closed wipes it first. a check
// that cannot finish lets the chats show read only after a while, sending
// still held, and goes on until it does
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'linked_lock.dart' show LinkedEnd;

/// where a linked computer's start check is: the gate, or the chats read
/// only while it goes on. null once its phone's list named it, and on a
/// phone
enum LinkCheckStage { checking, readOnly }

/// the check of this start; nothing leaves while it is not null
final linkCheck = ValueNotifier<LinkCheckStage?>(null);

/// the gate shows at least this long before the chats show read only
const kLinkGateLeast = Duration(seconds: 20);

/// once the route is up, the fetch gets this long
const kLinkGateFetch = Duration(seconds: 20);

/// the longest the gate shows: tor's start and the fetch together
const kLinkGateMost = Duration(seconds: 45);

/// how far my phone's pair was walked: by none of our stores, by some, or
/// by all of them with every line it brought opened
enum LinkCaught { none, some, all }

/// one store walked counts only after this: the phone's send ends at the
/// first store that took it, so the other may hold its last word while
/// this one is down or slow
const kLinkOneStore = Duration(minutes: 2);

/// whether the gate gives way to the chats, read only: never before
/// [kLinkGateLeast], at once then with no network, else once the route
/// was up [kLinkGateFetch], and at [kLinkGateMost] whatever happens
bool linkGateEnds({
  required Duration since,
  required bool online,
  Duration? routeUpFor,
}) {
  if (since >= kLinkGateMost) return true;
  if (since < kLinkGateLeast) return false;
  if (!online) return true;
  return routeUpFor != null && routeUpFor >= kLinkGateFetch;
}

class LinkCheck {
  LinkCheck({
    required this.stage,
    required this.standing,
    required this.caught,
    required this.drained,
    required this.removed,
    required this.confirmed,
    required this.over,
    required this.online,
    required this.routeUp,
    DateTime Function()? clock,
    Future<void> Function(Duration)? wait,
  }) : clock = clock ?? DateTime.now,
       wait = wait ?? ((d) => Future<void>.delayed(d));

  final ValueNotifier<LinkCheckStage?> stage;

  /// removed once my phone's list without this device was taken
  final Future<LinkedEnd?> Function() standing;

  /// how far my phone's pair was walked, every address of it
  final Future<LinkCaught> Function() caught;

  /// what the walk brought was opened; false when that did not finish
  final Future<bool> Function() drained;

  /// the removal: the wipe and the page that says so
  final Future<void> Function(LinkedEnd why) removed;

  /// still linked: what was held goes
  final void Function() confirmed;

  /// a wipe or an end under way: nothing left to check
  final bool Function() over;

  final bool Function() online;
  final bool Function() routeUp;
  final DateTime Function() clock;
  final Future<void> Function(Duration) wait;

  /// how often it looks while the gate shows, and later
  static const every = Duration(seconds: 1);
  static const later = Duration(seconds: 5);
  static const laterAfter = Duration(minutes: 2);

  Future<void> run() async {
    final start = clock();
    DateTime? routeAt;
    stage.value ??= LinkCheckStage.checking;
    while (true) {
      if (over()) return;
      try {
        final end = await standing();
        if (end != null) return await removed(end);
        final c = await caught();
        final enough =
            c == LinkCaught.all ||
            (c == LinkCaught.some &&
                clock().difference(start) >= kLinkOneStore);
        if (enough && await drained()) {
          // the walk may have brought the removal
          final after = await standing();
          if (after != null) return await removed(after);
          if (over()) return;
          stage.value = null;
          confirmed();
          return;
        }
      } catch (_) {
        // looked at again on the next turn
      }
      final now = clock();
      if (routeUp()) {
        routeAt ??= now;
      } else {
        routeAt = null;
      }
      if (stage.value == LinkCheckStage.checking &&
          linkGateEnds(
            since: now.difference(start),
            online: online(),
            routeUpFor: routeAt == null ? null : now.difference(routeAt),
          )) {
        stage.value = LinkCheckStage.readOnly;
      }
      await wait(now.difference(start) < laterAfter ? every : later);
    }
  }
}
