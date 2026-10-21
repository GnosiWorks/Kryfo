// SPDX-License-Identifier: GPL-3.0-or-later
// phones whose makers close background apps beyond what android's battery
// exemption covers, each with its own switch and no api for it. kryfo says
// where the switch is and opens the nearest page (MainActivity,
// openAutostartSettings). steps follow https://dontkillmyapp.com
import 'l10n/l10n.dart';

enum PhoneBrand { xiaomi, huawei, oppo, vivo, samsung, oneplus, other }

/// from android's Build.MANUFACTURER and Build.BRAND. honor is huawei's
/// system, realme and oneplus run oppo's, iqoo is vivo's; oneplus keeps its
/// own words for the page
PhoneBrand brandOf(String manufacturer, String brand) {
  final m = manufacturer.trim().toLowerCase();
  final b = brand.trim().toLowerCase();
  bool any(List<String> names) => names.contains(m) || names.contains(b);
  if (any(['xiaomi', 'redmi', 'poco'])) return PhoneBrand.xiaomi;
  if (any(['huawei', 'honor'])) return PhoneBrand.huawei;
  if (any(['oneplus'])) return PhoneBrand.oneplus;
  if (any(['oppo', 'realme'])) return PhoneBrand.oppo;
  if (any(['vivo', 'iqoo'])) return PhoneBrand.vivo;
  if (any(['samsung'])) return PhoneBrand.samsung;
  return PhoneBrand.other;
}

/// what to switch on, in the phone's own words, or null where the battery
/// exemption alone is enough
String? brandGuide(PhoneBrand b) => switch (b) {
  PhoneBrand.xiaomi => l10n.miuiAutostartXiaomiTurnsOffBackground,
  PhoneBrand.huawei => l10n.batteryGuideHuawei,
  PhoneBrand.oppo => l10n.batteryGuideOppo,
  PhoneBrand.vivo => l10n.batteryGuideVivo,
  PhoneBrand.samsung => l10n.batteryGuideSamsung,
  PhoneBrand.oneplus => l10n.batteryGuideOnePlus,
  PhoneBrand.other => null,
};
