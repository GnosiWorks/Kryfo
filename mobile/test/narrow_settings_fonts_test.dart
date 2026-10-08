// SPDX-License-Identifier: GPL-3.0-or-later
// the settings pages at 360 wide in the app's own fonts, in every language
// it speaks, up to the largest text size it allows
import 'package:flutter_test/flutter_test.dart';

import 'narrow_settings.dart';

void main() {
  setUpAll(loadAppFonts);
  narrowSettings(
    langs: [
      'en', 'ar', 'de', 'es', 'fa', 'fr', 'id', 'it', //
      'pt', 'ru', 'tr', 'uk', 'vi', 'zh', 'zh_Hant',
    ],
    scales: [1.0, 1.3, 1.6],
    themes: [false],
  );
}
