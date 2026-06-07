// halo design tokens. mirrors css vars in 08_complete_spec.html.
// keep flat. one source of truth for color, type, spacing.

import 'package:flutter/material.dart';

class _Palette {
  final Color ink, surface, surface2, surface3, line, line2;
  final Color text, text2, text3;
  final Color amber, amberDeep, amberSoft;
  final Color green, greenSoft, violet, rose, onAmber;
  const _Palette({
    required this.ink,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.line2,
    required this.text,
    required this.text2,
    required this.text3,
    required this.amber,
    required this.amberDeep,
    required this.amberSoft,
    required this.green,
    required this.greenSoft,
    required this.violet,
    required this.rose,
    required this.onAmber,
  });
}

const _dark = _Palette(
  ink: Color(0xFF0D0B09),
  surface: Color(0xFF161310),
  surface2: Color(0xFF201C17),
  surface3: Color(0xFF2A251F),
  line: Color(0xFF2F2922),
  line2: Color(0xFF3D3629),
  text: Color(0xFFF5F1EA),
  text2: Color(0xFFA39A8F),
  text3: Color(0xFF6B625A),
  amber: Color(0xFFF59E0B),
  amberDeep: Color(0xFFD97706),
  amberSoft: Color(0x24F59E0B),
  green: Color(0xFF34D399),
  greenSoft: Color(0x2434D399),
  violet: Color(0xFFA78BFA),
  rose: Color(0xFFF472B6),
  onAmber: Color(0xFF1A0F04),
);

const _light = _Palette(
  ink: Color(0xFFF2ECDF),
  surface: Color(0xFFEBE4D5),
  surface2: Color(0xFFE2DAC8),
  surface3: Color(0xFFD8CEB9),
  line: Color(0xFFCBBFA8),
  line2: Color(0xFFBAAC90),
  text: Color(0xFF1C1813),
  text2: Color(0xFF6E655B),
  text3: Color(0xFF9C9388),
  amber: Color(0xFFB66A07),
  amberDeep: Color(0xFF8F5205),
  amberSoft: Color(0x1FB66A07),
  green: Color(0xFF0E9D6C),
  greenSoft: Color(0x1F0E9D6C),
  violet: Color(0xFF6F4FD1),
  rose: Color(0xFFCE3F84),
  onAmber: Color(0xFFFFFBF4),
);

class HaloColors {
  static _Palette _p = _dark;
  static bool get isLight => identical(_p, _light);
  static void setLight(bool v) => _p = v ? _light : _dark;

  static Color get ink => _p.ink;
  static Color get surface => _p.surface;
  static Color get surface2 => _p.surface2;
  static Color get surface3 => _p.surface3;
  static Color get line => _p.line;
  static Color get line2 => _p.line2;
  static Color get text => _p.text;
  static Color get text2 => _p.text2;
  static Color get text3 => _p.text3;
  static Color get amber => _p.amber;
  static Color get amberDeep => _p.amberDeep;
  static Color get amberSoft => _p.amberSoft;
  static Color get green => _p.green;
  static Color get greenSoft => _p.greenSoft;
  static Color get violet => _p.violet;
  static Color get rose => _p.rose;
  static Color get onAmber => _p.onAmber;
}

class HaloType {
  static TextStyle serif({
    double size = 26,
    FontWeight weight = FontWeight.w400,
    Color? color,
    bool italic = false,
    double height = 1.05,
    double letter = -0.015,
  }) => TextStyle(
    fontFamily: 'Fraunces',
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color ?? HaloColors.text,
    height: height,
    letterSpacing: letter,
  );

  static TextStyle sans({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
    double letter = 0,
  }) => TextStyle(
    fontFamily: 'Instrument Sans',
    fontSize: size,
    fontWeight: weight,
    color: color ?? HaloColors.text,
    height: height,
    letterSpacing: letter,
  );

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letter = 0.12,
  }) => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: size,
    fontWeight: weight,
    color: color ?? HaloColors.text2,
    letterSpacing: letter,
  );
}

ThemeData buildHaloTheme() {
  final base = HaloColors.isLight
      ? ThemeData.light(useMaterial3: true)
      : ThemeData.dark(useMaterial3: true);
  final scheme =
      (HaloColors.isLight
              ? const ColorScheme.light()
              : const ColorScheme.dark())
          .copyWith(
            surface: HaloColors.surface,
            onSurface: HaloColors.text,
            primary: HaloColors.amber,
            onPrimary: HaloColors.onAmber,
            secondary: HaloColors.violet,
            error: HaloColors.rose,
          );
  return base.copyWith(
    scaffoldBackgroundColor: HaloColors.surface,
    canvasColor: HaloColors.surface,
    colorScheme: scheme,
    textTheme: base.textTheme.apply(
      fontFamily: 'Instrument Sans',
      bodyColor: HaloColors.text,
      displayColor: HaloColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}

// editorial toast: ink surface, hairline amber edge — reads like part of halo
// rather than a default grey snackbar. clears any in-flight toast first.
void showHaloToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: HaloType.sans(size: 13, color: HaloColors.text),
      ),
      backgroundColor: HaloColors.surface2,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      duration: const Duration(milliseconds: 1800),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HaloColors.amber.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
    ),
  );
}
