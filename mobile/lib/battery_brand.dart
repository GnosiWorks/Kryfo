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

/// what a maker's guide says: a title, a line, and for xiaomi the steps it
/// takes and what happens if the phone stops Kryfo anyway
class BrandGuide {
  final String title;
  final String line;
  final List<String> steps;
  final String? after;
  const BrandGuide({
    required this.title,
    required this.line,
    this.steps = const [],
    this.after,
  });
}

/// what to switch on, in the phone's own words, or null where the battery
/// exemption alone is enough
BrandGuide? brandGuide(PhoneBrand b) {
  BrandGuide one(String line) =>
      BrandGuide(title: l10n.miuiAutostartLetKryfoRunIn, line: line);
  return switch (b) {
    PhoneBrand.xiaomi => BrandGuide(
      title: l10n.batteryGuideXiaomiTitle,
      line: l10n.batteryGuideXiaomi,
      steps: [
        l10n.batteryGuideXiaomiStep1,
        l10n.batteryGuideXiaomiStep2,
        l10n.batteryGuideXiaomiStep3,
      ],
      after: l10n.batteryGuideXiaomiAfter,
    ),
    PhoneBrand.huawei => one(l10n.batteryGuideHuawei),
    PhoneBrand.oppo => one(l10n.batteryGuideOppo),
    PhoneBrand.vivo => one(l10n.batteryGuideVivo),
    PhoneBrand.samsung => one(l10n.batteryGuideSamsung),
    PhoneBrand.oneplus => one(l10n.batteryGuideOnePlus),
    PhoneBrand.other => null,
  };
}
