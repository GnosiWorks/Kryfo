// SPDX-License-Identifier: GPL-3.0-or-later
// what a quiet session answers in place of the network comes after a wait
// like one that went out and found nothing, never at once
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

final _rand = Random.secure();

/// a decoy looks up as the real app does: @names, people search and pair
/// code joins go out read-only over the same tor. what would register the
/// decoy anywhere (a claim, a shared code) still answers as unreachable
const kDecoyLooksUp = true;

// two to eight seconds
@visibleForTesting
Duration Function() quietWait = () =>
    Duration(milliseconds: 2000 + _rand.nextInt(6001));

Future<T> unreachedLater<T>(T answer) async {
  await Future<void>.delayed(quietWait());
  return answer;
}
