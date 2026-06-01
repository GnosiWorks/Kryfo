// halo design tokens. mirrors css vars in 08_complete_spec.html.
// keep flat. one source of truth for color, type, spacing.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HaloColors {
  static const ink = Color(0xFF0D0B09);
  static const surface = Color(0xFF161310);
  static const surface2 = Color(0xFF201C17);
  static const surface3 = Color(0xFF2A251F);
  static const line = Color(0xFF2F2922);
  static const line2 = Color(0xFF3D3629);

  static const text = Color(0xFFF5F1EA);
  static const text2 = Color(0xFFA39A8F);
  static const text3 = Color(0xFF6B625A);

  static const amber = Color(0xFFF59E0B);
  static const amberDeep = Color(0xFFD97706);
  static const amberSoft = Color(0x24F59E0B);

  static const green = Color(0xFF34D399);
  static const greenSoft = Color(0x2434D399);
  static const violet = Color(0xFFA78BFA);
  static const rose = Color(0xFFF472B6);

  static const onAmber = Color(0xFF1A0F04);
}

class HaloType {
  static TextStyle serif({
    double size = 26,
    FontWeight weight = FontWeight.w400,
    Color color = HaloColors.text,
    bool italic = false,
    double height = 1.05,
    double letter = -0.015,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color,
    height: height,
    letterSpacing: letter,
  );

  static TextStyle sans({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = HaloColors.text,
    double height = 1.5,
    double letter = 0,
  }) => GoogleFonts.instrumentSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letter,
  );

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color color = HaloColors.text2,
    double letter = 0.12,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letter,
  );
}

ThemeData buildHaloTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: HaloColors.surface,
    canvasColor: HaloColors.surface,
    colorScheme: const ColorScheme.dark(
      surface: HaloColors.surface,
      onSurface: HaloColors.text,
      primary: HaloColors.amber,
      onPrimary: HaloColors.onAmber,
      secondary: HaloColors.violet,
      error: HaloColors.rose,
    ),
    textTheme: GoogleFonts.instrumentSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: HaloColors.text, displayColor: HaloColors.text),
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
