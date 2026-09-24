// SPDX-License-Identifier: GPL-3.0-or-later
// the language sheet: match phone first, then every language kryfo has by
// its own name, with its name in the language kryfo is in now under it, so
// someone who landed in a script they cannot read still finds their way
// back. one sheet, from onboarding and from settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import 'halo_sheet.dart';
import 'press_scale.dart';
import 'sheet_handle.dart';
import 'stroke_icon.dart';

/// the language row's value: the chosen language's own name, or match
/// phone and the language that is
String languageValue() => appLocalePref == 'system'
    ? l10n.languageMatchPhoneValue(kLanguageNames[systemLanguage]!)
    : kLanguageNames[currentLanguage]!;

/// [tag]'s name in the language kryfo is in now
String languageNameHere(String tag) => switch (tag) {
  'en' => l10n.languageNameEn,
  'de' => l10n.languageNameDe,
  'fr' => l10n.languageNameFr,
  'es' => l10n.languageNameEs,
  'pt' => l10n.languageNamePt,
  'it' => l10n.languageNameIt,
  'ru' => l10n.languageNameRu,
  'uk' => l10n.languageNameUk,
  'tr' => l10n.languageNameTr,
  'zh' => l10n.languageNameZh,
  'zh_Hant' => l10n.languageNameZhHant,
  'vi' => l10n.languageNameVi,
  'id' => l10n.languageNameId,
  'fa' => l10n.languageNameFa,
  'ar' => l10n.languageNameAr,
  _ => kLanguageNames[tag] ?? tag,
};

// a letter each language is known by, drawn like the initial on an avatar.
// upright where a slant would be faked (chinese, arabic, persian).
const _glyph = <String, (String, bool)>{
  'en': ('&', true),
  // upright: a slanted ß in fraunces reads as a greek beta
  'de': ('ß', false),
  'fr': ('ç', true),
  'es': ('ñ', true),
  'pt': ('ã', true),
  'it': ('è', true),
  'ru': ('Я', true),
  'uk': ('ї', true),
  'tr': ('ş', true),
  'zh': ('简', false),
  'zh_Hant': ('繁', false),
  'vi': ('ư', true),
  'id': ('ng', true),
  'fa': ('پ', false),
  'ar': ('ض', false),
};

/// [fromSettings]: the switch takes the person back to their chats, and the
/// sheet says so. in onboarding it says the choice can be changed later.
Future<void> pickLanguage(
  BuildContext context, {
  bool fromSettings = true,
}) async {
  final choice = await showHaloSheet<String>(
    context,
    scroll: true,
    builder: (_) => _LanguageSheet(fromSettings: fromSettings),
  );
  if (choice == null || choice == appLocalePref) return;
  await setAppLocale(choice);
}

class _LanguageSheet extends StatefulWidget {
  final bool fromSettings;
  const _LanguageSheet({required this.fromSettings});
  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet>
    with SingleTickerProviderStateMixin {
  late String _picked = appLocalePref;
  // the row that was chosen when the sheet opened, scrolled into view
  late final String _opened = appLocalePref;
  final _openedKey = GlobalKey();
  bool _leaving = false;
  // the rows come in one after another, quickly
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _in.value = 1;
      } else {
        _in.forward();
      }
      _reveal();
    });
  }

  // a language low in the list opens in view
  void _reveal() {
    final c = _openedKey.currentContext;
    if (mounted && c != null) Scrollable.ensureVisible(c, alignment: 0.5);
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  Future<void> _choose(String tag) async {
    if (_leaving) return;
    _leaving = true;
    HapticFeedback.selectionClick();
    setState(() => _picked = tag);
    // the tick lands before the sheet goes, so the choice is seen
    if (!MediaQuery.of(context).disableAnimations) {
      await Future.delayed(const Duration(milliseconds: 230));
    }
    if (mounted) Navigator.pop(context, tag);
  }

  Widget _stagger(int i, Widget child) {
    final start = (i * 0.045).clamp(0.0, 0.5);
    final curve = Interval(start, start + 0.5, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _in,
      builder: (_, c) {
        final v = curve.transform(_in.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final langs = availableLanguages;
    final phone = systemLanguage;
    final line = widget.fromSettings
        ? l10n.languageRedrawLine
        : l10n.languageLaterLine;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(22, 10, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HaloColors.amberSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: StrokeIcon(
                      _globe,
                      size: 20,
                      color: HaloColors.amber,
                      stroke: 1.5,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.languageTitle,
                          style: HaloType.serif(
                            size: 22,
                            color: HaloColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          line,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              // rows scroll out under the title through a short fade
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x00000000),
                  ],
                  stops: [0, 14 / r.height, 1 - 14 / r.height, 1],
                ).createShader(r),
                // sixteen rows, all built: a lazy list does not have the
                // chosen one yet when it sits far down, so nothing to
                // scroll to
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _stagger(
                        0,
                        _Row(
                          key: _opened == 'system' ? _openedKey : null,
                          badge: StrokeIcon(
                            _phone,
                            size: 19,
                            color: _picked == 'system'
                                ? HaloColors.amber
                                : HaloColors.text2,
                            stroke: 1.5,
                          ),
                          title: l10n.languageMatchPhone,
                          sub: kLanguageNames[phone]!,
                          on: _picked == 'system',
                          onTap: () => _choose('system'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final (i, t) in langs.indexed) ...[
                        _stagger(
                          i + 1,
                          _Row(
                            key: _opened == t ? _openedKey : null,
                            badge: _Glyph(tag: t, on: _picked == t),
                            title: kLanguageNames[t]!,
                            sub: _sub(t),
                            on: _picked == t,
                            onTap: () => _choose(t),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // the name in the language kryfo is in, unless it says the same thing
  String? _sub(String tag) {
    final here = languageNameHere(tag);
    return here.toLowerCase() == kLanguageNames[tag]!.toLowerCase()
        ? null
        : here;
  }
}

class _Row extends StatelessWidget {
  final Widget badge;
  final String title;
  final String? sub;
  final bool on;
  final VoidCallback onTap;
  const _Row({
    super.key,
    required this.badge,
    required this.title,
    required this.sub,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // one node: its name, its name here, and whether it is the one chosen
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: on,
      label: sub == null ? title : '$title, $sub',
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.98,
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
          decoration: BoxDecoration(
            color: on
                ? HaloColors.amber.withValues(alpha: 0.07)
                : HaloColors.surface3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? HaloColors.amber : HaloColors.line,
              width: on ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on
                      ? HaloColors.amber.withValues(alpha: 0.14)
                      : HaloColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on
                        ? HaloColors.amber.withValues(alpha: 0.35)
                        : HaloColors.line,
                    width: 0.5,
                  ),
                ),
                child: badge,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: HaloType.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: HaloType.sans(
                          size: 12.5,
                          color: on ? HaloColors.amber : HaloColors.text2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Radio(on: on),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  final String tag;
  final bool on;
  const _Glyph({required this.tag, required this.on});
  @override
  Widget build(BuildContext context) {
    final (g, slanted) = _glyph[tag] ?? (tag, false);
    return MediaQuery.withNoTextScaling(
      child: Text(
        g,
        textDirection: TextDirection.ltr,
        style: HaloType.serif(
          size: g.length > 1 ? 17 : 21,
          weight: FontWeight.w500,
          italic: slanted,
          color: on ? HaloColors.amber : HaloColors.text,
          height: 1.0,
        ),
      ),
    );
  }
}

// a ring that fills with a tick, with a little overshoot
class _Radio extends StatelessWidget {
  final bool on;
  const _Radio({required this.on});
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: on ? HaloColors.amber : HaloColors.line2,
                width: 1.4,
              ),
            ),
          ),
          AnimatedScale(
            scale: on ? 1 : 0,
            duration: Duration(milliseconds: still ? 0 : 320),
            curve: Curves.easeOutBack,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HaloColors.amber,
              ),
              child: StrokeIcon(
                _tick,
                size: 14,
                color: HaloColors.onAmber,
                stroke: 2.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _globe = [
  'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z',
  'M3.5 9h17M3.5 15h17',
  'M12 3c-2.4 2.5-3.6 5.5-3.6 9s1.2 6.5 3.6 9',
  'M12 3c2.4 2.5 3.6 5.5 3.6 9s-1.2 6.5-3.6 9',
];

const _phone = [
  'M8 2.5h8a2 2 0 0 1 2 2v15a2 2 0 0 1-2 2h-8a2 2 0 0 1-2-2v-15a2 2 0 0 1 2-2z',
  'M10.5 18.5h3',
];

const _tick = ['M5 12.5l4.5 4.5l9.5-10'];

/// the small language button on the first onboarding screen: the language
/// kryfo is in, by its own name
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context) {
    final name = kLanguageNames[currentLanguage]!;
    return PressScale(
      label: l10n.languageButton(name),
      onTap: () => pickLanguage(context, fromSettings: false),
      // the chip is drawn small; the finger gets 48
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(9),
        child: _chip(name),
      ),
    );
  }

  Widget _chip(String name) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StrokeIcon(_globe, size: 14, color: HaloColors.amber, stroke: 1.5),
          const SizedBox(width: 6),
          ExcludeSemantics(
            child: Text(
              name,
              style: HaloType.sans(
                size: 12,
                weight: FontWeight.w500,
                color: HaloColors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
