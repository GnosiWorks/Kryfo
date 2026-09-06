// SPDX-License-Identifier: GPL-3.0-or-later
// the one log call the app makes. a release build says nothing: a kryfo id,
// an onion or a line of message text in logcat is a leak, and no line here
// is worth that. debug builds keep every line for the desk.
import 'package:flutter/foundation.dart';

void dlog(String line) {
  if (kDebugMode) debugPrint(line);
}
