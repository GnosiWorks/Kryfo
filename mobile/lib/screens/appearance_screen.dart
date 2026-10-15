// SPDX-License-Identifier: GPL-3.0-or-later
// the accent the app wears, picked over a small chat that shows it at once,
// one choice for the whole phone like the theme; and the wallpaper every
// chat without one of its own shows, this identity's own
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atmosphere.dart';
import '../l10n/l10n.dart';
import '../main.dart' show appState, kPhotoWall, session;
import '../theme.dart';
import '../wallpaper.dart';
import '../widgets/chat_backdrop.dart';
import '../widgets/halo_rows.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import '../widgets/nav_bar.dart' show HaloTab, navTabIcon;
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/stroke_icon.dart';
import 'wallpaper_sheet.dart';

String accentName(HaloAccent a) => switch (a) {
  HaloAccent.yellow => l10n.accentYellow,
  HaloAccent.grey => l10n.accentGrey,
  HaloAccent.purple => l10n.accentPurple,
  HaloAccent.lime => l10n.accentLime,
  HaloAccent.velvet => l10n.accentVelvet,
  HaloAccent.blue => l10n.accentBlue,
};

class AppearanceScreen extends StatefulWidget {
  // what the accent is set with; the app's own unless a test hands one
  final Future<void> Function(HaloAccent)? onPick;
  // where the default wallpaper is read; the session's unless a test
  // hands one
  final Future<ChatWall> Function()? readDefault;
  const AppearanceScreen({super.key, this.onPick, this.readDefault});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  ChatWall _default = ChatWall.none;

  @override
  void initState() {
    super.initState();
    _readDefault();
  }

  void _readDefault() {
    (widget.readDefault ?? defaultWall)().then((w) {
      if (mounted) setState(() => _default = w);
    });
  }

  String get _defaultName => _default.photo != null
      ? l10n.wallpaperYourPhoto
      : atmoLabel(_default.atmo);

  // the sheet previews live behind it, on the small chat; backing out puts
  // the old one back
  Future<void> _pickDefault() async {
    final before = _default;
    final picked = await showWallpaperSheet(
      context,
      before.atmo,
      allowPhoto: true,
      hasPhoto: before.photo != null,
      onPreview: (a) {
        if (mounted) setState(() => _default = ChatWall(a));
      },
    );
    if (!mounted) return;
    if (picked is WallpaperFromPhotos) {
      setState(() => _default = before);
      final r = await pickWallpaperPhoto(
        context,
        save: (at, photo) async {
          await at.setDefaultWallpaper(kPhotoWall, photo);
          return true;
        },
        failed: (_) {
          if (mounted) showHaloToast(context, l10n.cameraCouldNotStripThat);
        },
      );
      if (r != Picked.kept) return;
    } else if (picked is Atmo) {
      await session.setDefaultWallpaper(picked.name);
    } else {
      setState(() => _default = before);
      return;
    }
    HapticFeedback.selectionClick();
    wallpaperRevision.value++;
    _readDefault();
  }

  Future<void> _pick(HaloAccent a) async {
    if (a == HaloColors.accent) return;
    HapticFeedback.selectionClick();
    await (widget.onPick ?? appState.setAccent)(a);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(l10n.settingsAppearance, style: HaloType.pageTitle()),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: staggerAll([
          AccentPreview(background: ChatBackdrop(_default, chat: 'appearance')),
          HaloSection(l10n.settingsAccentColour),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HaloColors.line, width: 0.5),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 12,
              children: [
                for (final a in HaloAccent.values)
                  AccentSwatch(
                    accent: a,
                    on: a == HaloColors.accent,
                    onTap: () => _pick(a),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 6, 0),
            child: Text(
              l10n.appearanceAccentHint,
              style: HaloType.sans(size: 12.5, color: HaloColors.text2),
            ),
          ),
          HaloSection(l10n.appearanceChatWallpaper),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.wallpaper_outlined,
                label: l10n.appearanceEveryChat,
                value: _defaultName,
                onTap: _pickDefault,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 6, 0),
            child: Text(
              l10n.appearanceWallpaperHint,
              style: HaloType.sans(size: 12.5, color: HaloColors.text2),
            ),
          ),
        ]),
      ),
    );
  }
}

/// one accent as a round of its own colour in the theme in use. the one in
/// use wears a ring a gap away and a tick, popped in on the house spring
class AccentSwatch extends StatelessWidget {
  final HaloAccent accent;
  final bool on;
  final VoidCallback onTap;
  const AccentSwatch({
    super.key,
    required this.accent,
    required this.on,
    required this.onTap,
  });

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final spring = still ? Duration.zero : kHouseTime;
    final tones = accent.tones(HaloColors.isLight);
    final name = accentName(accent);
    return Semantics(
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.92,
        haptic: false,
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _size + 10,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: AnimatedScale(
                        scale: on || still ? 1 : 0.86,
                        duration: spring,
                        curve: kHouseCurve,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: tones.accent, width: 2),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [tones.accent, tones.deep],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedOpacity(
                        opacity: on ? 1 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: AnimatedScale(
                          scale: on || still ? 1 : 0.3,
                          duration: spring,
                          curve: kHouseCurve,
                          child: Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: tones.on,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: HaloType.sans(
                  size: 11.5,
                  weight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on ? HaloColors.text : HaloColors.text2,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// the colours the preview is drawn in, eased from one accent to the next
class _Tones {
  final Color accent, on;
  const _Tones(this.accent, this.on);
  static _Tones now() => _Tones(HaloColors.amber, HaloColors.onAmber);
  @override
  bool operator ==(Object o) => o is _Tones && o.accent == accent && o.on == on;
  @override
  int get hashCode => Object.hash(accent, on);
  static _Tones lerp(_Tones a, _Tones b, double t) =>
      _Tones(Color.lerp(a.accent, b.accent, t)!, Color.lerp(a.on, b.on, t)!);
}

class _TonesTween extends Tween<_Tones> {
  _TonesTween({required super.begin, required super.end});
  @override
  _Tones lerp(double t) => _Tones.lerp(begin!, end!, t);
}

/// a small chat in the accent in use: their bubble, yours, a button and the
/// home bar's pill. drawn only, never tapped, and read as one picture
class AccentPreview extends StatelessWidget {
  // behind the bubbles, where a chat's wallpaper goes
  final Widget? background;
  const AccentPreview({super.key, this.background});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Semantics(
      container: true,
      label: l10n.appearancePreview,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: TweenAnimationBuilder<_Tones>(
            tween: _TonesTween(begin: _Tones.now(), end: _Tones.now()),
            duration: still ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => _PreviewBody(t, background),
          ),
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  final _Tones t;
  final Widget? background;
  const _PreviewBody(this.t, this.background);

  @override
  Widget build(BuildContext context) {
    final bg = background;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HaloColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              if (bg != null) Positioned.fill(child: bg),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                child: Column(
                  children: [
                    _bubble(
                      context,
                      l10n.appearanceSampleIn,
                      mine: false,
                      fill: HaloColors.bubbleIn,
                      ink: HaloColors.text,
                    ),
                    const SizedBox(height: 6),
                    _bubble(
                      context,
                      l10n.appearanceSampleOut,
                      mine: true,
                      fill: t.accent,
                      ink: t.on,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 44,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: t.accent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        l10n.appearanceSampleButton,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HaloType.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: t.on,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // the home bar, its chats tab in use
          Container(
            decoration: BoxDecoration(
              color: HaloColors.surface,
              border: Border(
                top: BorderSide(color: HaloColors.line, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Row(
              children: [
                for (final tab in const [
                  HaloTab.chats,
                  HaloTab.tools,
                  HaloTab.me,
                ])
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 54,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: tab == HaloTab.chats
                            ? BoxDecoration(
                                color: t.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              )
                            : null,
                        child: StrokeIcon(
                          [navTabIcon(tab)],
                          size: 20,
                          color: tab == HaloTab.chats
                              ? t.accent
                              : HaloColors.warm,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    String text, {
    required bool mine,
    required Color fill,
    required Color ink,
  }) {
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.62,
        ),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(14),
            topEnd: const Radius.circular(14),
            bottomStart: Radius.circular(mine ? 14 : 4),
            bottomEnd: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: HaloType.sans(size: 14, color: ink, height: 1.35),
            ),
            if (mine) ...[
              const SizedBox(height: 2),
              Icon(Icons.done_all_rounded, size: 13, color: ink),
            ],
          ],
        ),
      ),
    );
  }
}
