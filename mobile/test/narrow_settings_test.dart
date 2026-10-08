// SPDX-License-Identifier: GPL-3.0-or-later
// the settings pages at 360 wide in the test font, where every letter is a
// full square: wider than any real font, so a row that fits here fits

import 'narrow_settings.dart';

void main() {
  narrowSettings(langs: ['en', 'de', 'ru', 'fa', 'ar'], scales: [1.0, 1.3]);
}
