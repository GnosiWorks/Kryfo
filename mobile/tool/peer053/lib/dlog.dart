// SPDX-License-Identifier: GPL-3.0-or-later
// release builds log nothing: a kryfo id, an onion or message text in logcat
// is a leak.
import 'package:flutter/foundation.dart';

void dlog(String line) {
  if (kDebugMode) debugPrint(line);
}
