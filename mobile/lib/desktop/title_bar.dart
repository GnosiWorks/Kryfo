// SPDX-License-Identifier: GPL-3.0-or-later
// windows draws the title bar: it follows the app's theme, said once per switch
import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('kryfo/desktop');
bool? _said;

void windowTitleDark(bool dark) {
  if (!Platform.isWindows || _said == dark) return;
  _said = dark;
  _channel.invokeMethod<void>('titleDark', dark).catchError((_) {
    _said = null;
  });
}
