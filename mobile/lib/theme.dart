// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo design tokens: colour and type, in one place.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dlog.dart';
import 'l10n/l10n.dart';

class _Palette {
  final Color ink, surface, surface2, surface3, line, line2;
  final Color text, text2, text3, warm;
  final Color amber, amberDeep, amberSoft;
  final Color green, greenSoft, violet, rose, onAmber;
  final Color bubbleIn;
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
    required this.warm,
    required this.amber,
    required this.amberDeep,
    required this.amberSoft,
    required this.green,
    required this.greenSoft,
    required this.violet,
    required this.rose,
    required this.onAmber,
    required this.bubbleIn,
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
  text2: Color(0xFFC8C0B5),
  text3: Color(0xFFA79E92),
  warm: Color(0xFFD6CCBE),
  amber: Color(0xFFF59E0B),
  amberDeep: Color(0xFFD97706),
  amberSoft: Color(0x24F59E0B),
  green: Color(0xFF34D399),
  greenSoft: Color(0x2434D399),
  violet: Color(0xFFA78BFA),
  rose: Color(0xFFF472B6),
  onAmber: Color(0xFF1A0F04),
  bubbleIn: Color(0xFF3B332A),
);

const _light = _Palette(
  ink: Color(0xFFF2ECDF),
  surface: Color(0xFFEBE4D5),
  surface2: Color(0xFFE2DAC8),
  surface3: Color(0xFFD8CEB9),
  line: Color(0xFFCBBFA8),
  line2: Color(0xFFBAAC90),
  text: Color(0xFF1C1813),
  text2: Color(0xFF57503F),
  text3: Color(0xFF554E44),
  warm: Color(0xFF5F4E38),
  amber: Color(0xFFB66A07),
  amberDeep: Color(0xFF8F5205),
  amberSoft: Color(0x1FB66A07),
  green: Color(0xFF0E9D6C),
  greenSoft: Color(0x1F0E9D6C),
  violet: Color(0xFF6F4FD1),
  rose: Color(0xFFCE3F84),
  onAmber: Color(0xFFFFFBF4),
  bubbleIn: Color(0xFFDDD3BE),
);

class HaloColors {
  static const Color amberBright = Color(0xFFE8960B);
  static const Color amberBrightDeep = Color(0xFFCC7006);
  static const Color amberInk = Color(0xFF1A0F04);
  static const Color qrPaper = Color(0xFFF5F1EA);
  static const Color qrInk = Color(0xFF161310);
  static const Color qrAmber = Color(0xFF8A4B0E);
  static const Color qrViolet = Color(0xFF4C2F9E);

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
  static Color get warm => _p.warm;
  static Color get amber => _p.amber;
  static Color get bubbleIn => _p.bubbleIn;
  static Color get amberDeep => _p.amberDeep;
  static Color get amberSoft => _p.amberSoft;
  static Color get green => _p.green;
  static Color get greenSoft => _p.greenSoft;
  static Color get violet => _p.violet;
  static Color get rose => _p.rose;
  static Color get onAmber => _p.onAmber;
}

// persian and arabic join their letters. letter spacing pulls the joins
// apart, and their fonts have no italic, so a slant would be faked: in
// those languages text is set with no tracking and upright (the accent
// words keep their colour).
bool get _joinedScript => const {'fa', 'ar'}.contains(l10nLocale.languageCode);

/// letter spacing, or none where the script joins its letters
double track(double v) => _joinedScript ? 0 : v;

/// italic, or upright where the script has no italic
FontStyle slant() => _joinedScript ? FontStyle.normal : FontStyle.italic;

class HaloType {
  // what draws the letters our own fonts do not have. flutter asks these,
  // in order, for any character the family lacks, before the phone's fonts;
  // they carry only cyrillic and arabic, so latin never reaches them.
  // jetbrains mono has cyrillic itself; nothing monospaced has arabic.
  static const serifFallback = ['Noto Serif Cyrillic', 'Noto Naskh Arabic'];
  static const sansFallback = ['Noto Sans Cyrillic', 'Noto Sans Arabic'];
  static const monoFallback = ['Noto Sans Arabic'];

  // instrument sans has no vietnamese letters with stacked or hooked accents
  // (ế, ự, ỹ...), and a fallback letter mid-word shows in another typeface,
  // so vietnamese uses noto sans throughout. fraunces and jetbrains mono
  // have them.
  static String get sansFamily => _joinedScript
      ? 'Noto Sans Arabic'
      : l10nLocale.languageCode == 'vi'
      ? 'Noto Sans Vietnamese'
      : 'Instrument Sans';

  // in persian and arabic the arabic-script font leads and ours follow for
  // the latin words. led by fraunces, a zero-width non-joiner leaves the
  // letters after it unjoined.
  static String get serifFamily =>
      _joinedScript ? 'Noto Naskh Arabic' : 'Fraunces';
  static String get monoFamily =>
      _joinedScript ? 'Noto Sans Arabic' : 'JetBrains Mono';
  static List<String> get serifFallbackNow =>
      _joinedScript ? const ['Fraunces', 'Noto Serif Cyrillic'] : serifFallback;
  static List<String> get sansFallbackNow => _joinedScript
      ? const ['Instrument Sans', 'Noto Sans Cyrillic']
      : sansFallback;
  static List<String> get monoFallbackNow =>
      _joinedScript ? const ['JetBrains Mono'] : monoFallback;

  static TextStyle serif({
    double size = 26,
    FontWeight weight = FontWeight.w400,
    Color? color,
    bool italic = false,
    double height = 1.05,
    double letter = -0.015,
  }) => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbackNow,
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? slant() : FontStyle.normal,
    color: color ?? HaloColors.text,
    height: height,
    letterSpacing: track(letter),
  );

  static TextStyle sans({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
    double letter = 0,
  }) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbackNow,
    fontSize: size,
    fontWeight: weight,
    color: color ?? HaloColors.text,
    height: height,
    letterSpacing: track(letter),
  );

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letter = 0.12,
  }) => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallbackNow,
    fontSize: size,
    fontWeight: weight,
    color: color ?? HaloColors.text2,
    letterSpacing: track(letter),
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
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: HaloColors.surface,
    canvasColor: HaloColors.surface,
    colorScheme: scheme,
    textTheme: base.textTheme.apply(
      fontFamily: HaloType.sansFamily,
      fontFamilyFallback: HaloType.sansFallbackNow,
      bodyColor: HaloColors.text,
      displayColor: HaloColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // a page scrolled under a bar leaves it plain: material would tint it
    // with the amber and lift it
    appBarTheme: const AppBarThemeData(
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    // every app bar's back is the same chevron the custom bars draw
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(Icons.chevron_left, size: 26),
    ),
  );
}

// ids and crypto addresses are worth stealing, and any app the user pastes
// into can read the clipboard, so they come back out after a minute. only
// if they are still what we put there: the user may have copied since.
Timer? _clipTimer;

Future<void> copySensitive(String value) async {
  // marked sensitive for the keyboard's history and the android 13
  // preview; the plain clipboard is the fallback
  var done = false;
  try {
    done =
        await const MethodChannel(
          'halo/platform',
        ).invokeMethod<bool>('copySensitive', {'text': value}) ??
        false;
  } catch (_) {
    // no such call here: the plain clipboard below
  }
  if (!done) await Clipboard.setData(ClipboardData(text: value));
  _clipTimer?.cancel();
  _clipTimer = Timer(const Duration(seconds: 60), () async {
    try {
      final now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (e) {
      dlog('clipboard: not cleared (${e.runtimeType})');
    }
  });
}

// the app's scaffold messenger, set on the MaterialApp. toasts use the root
// overlay below
final GlobalKey<ScaffoldMessengerState> haloMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// the root overlay, set at start. a toast lives there, over every route
/// and sheet, so it never depends on the screen that asked for it
OverlayState? Function()? haloToastOverlay;

OverlayEntry? _toastEntry;
// every toast on the overlay, drawn yet or not, until it is off it
final _toastKeys = <OverlayEntry, GlobalKey<_ToastState>>{};

void _dropToast(OverlayEntry e) {
  if (_toastKeys.remove(e) != null) e.remove();
}

/// the app lock's say, set at start: a toast shown while it is up waits
/// for it to lift
Future<void> Function(Future<void> Function() act)? haloWhenOpen;

void showHaloToast(BuildContext context, String message) {
  // nothing to say, nothing shown: a link that opened a chat says it so
  if (message.isEmpty) return;
  final later = haloWhenOpen;
  if (later == null) {
    _showHaloToast(context, message);
  } else {
    unawaited(later(() async => _showHaloToast(context, message)));
  }
}

/// the lock is going up: no toast stays on screen
void haloClearToasts() {
  _toastEntry = null;
  for (final e in List.of(_toastKeys.keys)) {
    _dropToast(e);
  }
  haloMessengerKey.currentState?.clearSnackBars();
}

void _showHaloToast(BuildContext context, String message) {
  var overlay = haloToastOverlay?.call();
  if (overlay == null) {
    if (!context.mounted) return;
    try {
      overlay = Overlay.maybeOf(context, rootOverlay: true);
    } catch (_) {
      return;
    }
  }
  if (overlay == null) return;
  final prev = _toastEntry;
  if (prev != null) {
    final shown = _toastKeys[prev]?.currentState;
    if (shown != null) {
      shown.leave();
    } else {
      _dropToast(prev);
    }
  }
  final key = GlobalKey<_ToastState>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      key: key,
      message: message,
      onGone: () {
        _dropToast(entry);
        if (identical(_toastEntry, entry)) _toastEntry = null;
      },
    ),
  );
  _toastKeys[entry] = key;
  _toastEntry = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final VoidCallback onGone;
  const _Toast({super.key, required this.message, required this.onGone});
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 180),
  );
  Timer? _timer;
  bool _leaving = false;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 3500), leave);
  }

  void leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    _c.reverse().whenComplete(widget.onGone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final still = mq.disableAnimations;
    return Positioned(
      left: 16,
      right: 16,
      top: mq.padding.top + 58,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          if (still) return Opacity(opacity: t, child: child);
          // in: a drop with a little overshoot. out: up and gone
          final e = _leaving
              ? Curves.easeIn.transform(t)
              : Curves.easeOutBack.transform(t);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - e) * -14 + _drag),
              child: Transform.scale(scale: 0.96 + 0.04 * e, child: child),
            ),
          );
        },
        child: GestureDetector(
          onTap: leave,
          onVerticalDragUpdate: (d) =>
              setState(() => _drag = (_drag + d.delta.dy).clamp(-80.0, 0.0)),
          onVerticalDragEnd: (d) {
            if (_drag < -24 || d.velocity.pixelsPerSecond.dy < -300) {
              leave();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HaloColors.amber.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HaloColors.ink.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: HaloType.sans(size: 13, color: HaloColors.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
