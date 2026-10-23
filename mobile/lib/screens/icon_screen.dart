// SPDX-License-Identifier: GPL-3.0-or-later
// what the phone shows of kryfo: the home screen's icon and name, and what
// a notification says. the icon is the phone's (android keeps it), so a
// decoy or a vault session reads and changes the same one; plain
// notifications are the phone's too, the preview setting the identity's
import 'dart:async';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';

import '../app_icon.dart';
import '../battery_brand.dart' show PhoneBrand, brandOf;
import '../drafts.dart' show restartKeepingDrafts;
import '../l10n/l10n.dart';
import '../lock_guard.dart' show LockGuard, lockGuard;
import '../lock_state.dart';
import '../main.dart' show session;
import '../notifications.dart';
import '../theme.dart';
import '../widgets/app_face_icon.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_rows.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart'
    show haloRoute, kHouseCurve, kHouseTime, motionStill;
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/unfold.dart';
import 'lock_setup_screen.dart';

/// what notifications show, one of three
enum NotifShow { all, newMessage, plain }

String notifShowName(NotifShow s) => switch (s) {
  NotifShow.all => l10n.notifShowAll,
  NotifShow.newMessage => l10n.notifShowNew,
  NotifShow.plain => l10n.notifShowPlain,
};

/// plain wins over the preview setting, as it does in the shade
NotifShow notifShowOf({required bool plain, required bool hidden}) => plain
    ? NotifShow.plain
    : hidden
    ? NotifShow.newMessage
    : NotifShow.all;

/// the phone's own way to hide apps, where kryfo knows it: one line for
/// the brand, or for android 15 and later, else none
String? hideAppsLine(PhoneBrand brand, int sdk) => switch (brand) {
  PhoneBrand.samsung => l10n.iconSheetSecureFolder,
  PhoneBrand.xiaomi => l10n.iconSheetXiaomi,
  _ => sdk >= 35 ? l10n.iconSheetPrivateSpace : null,
};

const _platform = MethodChannel('halo/platform');

Future<String?> _phoneHideLine() async {
  try {
    final m = await _platform.invokeMapMethod<String, String>('phoneMaker');
    return hideAppsLine(
      brandOf(m?['manufacturer'] ?? '', m?['brand'] ?? ''),
      int.tryParse(m?['sdk'] ?? '') ?? 0,
    );
  } catch (_) {
    return null;
  }
}

/// the switch itself: the drafts are written down, kryfo's notifications go
/// (their taps would name the entry that goes off), then android switches
/// and the app opens again. false when it would not
Future<bool> switchAppFace(AppFace face) async {
  await noteFaceChanged();
  await cancelWithRetry(notifPlugin.cancelAll, 'icon shade');
  var ok = false;
  await restartKeepingDrafts(() async {
    ok = await appFaceChannel.switchTo(face);
    return ok;
  });
  if (!ok) await takeFaceChanged();
  return ok;
}

/// after the restart a switch makes, once kryfo is open: a line that says
/// it worked, read out too
Future<void> sayFaceChanged() async {
  if (!await takeFaceChanged()) return;
  final face = await readAppFace();
  showHaloToastAnywhere(l10n.iconChanged(face.label));
}

class IconScreen extends StatefulWidget {
  /// opened from Getting messages: it starts at the notifications part
  final bool toNotifications;
  // the switch; the app's own unless a test hands one
  final Future<bool> Function(AppFace)? onSwitch;
  // the line about the phone's own way to hide apps
  final Future<String?> Function()? hideLine;
  // what shuts its sheets as the lock comes up; the app's unless a test
  // hands one
  final LockGuard? guard;
  const IconScreen({
    super.key,
    this.toNotifications = false,
    this.onSwitch,
    this.hideLine,
    this.guard,
  });

  @override
  State<IconScreen> createState() => _IconScreenState();
}

class _IconScreenState extends State<IconScreen> {
  AppFace? _now = appFaceNow.value;
  AppFace? _picked;
  bool? _plain = notifPlainKnown();
  bool? _hidden = hideNotifContentKnown(session.container);
  bool _switching = false;
  final _notifKey = GlobalKey();
  late final Future<String?> _hideLine = (widget.hideLine ?? _phoneHideLine)();

  AppFace get _shown => _picked ?? _now ?? AppFace.kryfo;

  @override
  void initState() {
    super.initState();
    readAppFace().then((f) {
      if (mounted) setState(() => _now = f);
    });
    _readNotifs();
    hideNotifRevision.addListener(_readNotifs);
    if (widget.toNotifications) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _notifKey.currentContext;
        if (c == null || !mounted) return;
        Scrollable.ensureVisible(
          c,
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    hideNotifRevision.removeListener(_readNotifs);
    super.dispose();
  }

  Future<void> _readNotifs() async {
    final plain = await loadNotifPlain();
    final hidden = await loadHideNotifContent(session.container);
    if (mounted) {
      setState(() {
        _plain = plain;
        _hidden = hidden;
      });
    }
  }

  void _pick(AppFace f) {
    if (_switching || f == _shown) return;
    HapticFeedback.selectionClick();
    setState(() => _picked = f == _now ? null : f);
  }

  Future<void> _setShow(NotifShow s) async {
    if (_plain == null || _hidden == null) return;
    if (notifShowOf(plain: _plain!, hidden: _hidden!) == s) return;
    HapticFeedback.selectionClick();
    final plain = s == NotifShow.plain;
    setState(() {
      _plain = plain;
      if (!plain) _hidden = s == NotifShow.newMessage;
    });
    // plain leaves the preview setting as it was, for when it goes off
    if (!plain) await setHideNotifContent(_hidden!, session.container);
    await setNotifPlain(plain);
  }

  Future<void> _confirm() async {
    final face = _picked;
    if (face == null || _switching) return;
    final String? go;
    if (lockState.lockOn) {
      go =
          await showConfirmSheet(
            context,
            title: l10n.iconConfirmTitle(face.label),
            line: l10n.iconConfirmLine(face.label),
            yes: l10n.iconConfirmButton,
            rose: false,
            shutOnLock: widget.guard ?? lockGuard,
          )
          ? 'yes'
          : null;
    } else {
      // offered, never asked for: without a PIN the icon opens kryfo
      go = await showConfirmOrMoreSheet(
        context,
        title: l10n.iconConfirmTitle(face.label),
        line: l10n.iconConfirmLine(face.label),
        detail: l10n.iconNoPinLine,
        yes: l10n.iconConfirmButton,
        more: l10n.iconSetPin,
        rose: false,
        shutOnLock: widget.guard ?? lockGuard,
      );
    }
    if (!mounted) return;
    if (go == 'more') {
      await Navigator.of(context).push(haloRoute(const LockSetupScreen()));
      if (mounted) setState(() {});
      return;
    }
    if (go != 'yes') return;
    HapticFeedback.mediumImpact();
    setState(() => _switching = true);
    final ok = await (widget.onSwitch ?? switchAppFace)(face);
    if (!mounted) return;
    if (!ok) {
      setState(() => _switching = false);
      showHaloToast(context, l10n.commonTryAgain);
    }
  }

  Future<void> _whatChanges() async {
    final line = await _hideLine;
    if (!mounted) return;
    await showHaloSheet<void>(
      context,
      builder: (ctx) => _ChangesSheet(hideLine: line),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final show = _plain == null || _hidden == null
        ? null
        : notifShowOf(plain: _plain!, hidden: _hidden!);
    final still = motionStill(context);
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          l10n.settingsIconAndNotifications,
          style: HaloType.pageTitle(),
        ),
      ),
      body: AnimatedOpacity(
        // the app closes on a switch: it fades rather than vanishing
        opacity: _switching ? 0 : 1,
        duration: still ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeInCubic,
        child: FitColumn(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomePreview(face: _shown),
            HaloSection(l10n.iconSectionTitle),
            _FaceGrid(picked: _shown, known: _now != null, onPick: _pick),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 12, 6, 0),
              child: AnimatedSwitcher(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: Text(
                  _shown == AppFace.kryfo ? l10n.iconHintKryfo : l10n.iconHint,
                  key: ValueKey(_shown == AppFace.kryfo),
                  style: HaloType.sans(
                    size: 12.5,
                    color: HaloColors.text2,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PressScale(
                onTap: _whatChanges,
                scale: 0.96,
                label: l10n.iconWhatChanges,
                child: Padding(
                  // a full finger's height, though the words are small
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 14,
                  ),
                  child: Text(
                    l10n.iconWhatChanges,
                    style: HaloType.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: HaloColors.amberText,
                    ),
                  ),
                ),
              ),
            ),
            KeyedSubtree(
              key: _notifKey,
              child: HaloSection(l10n.settingsNotifications),
            ),
            _ShowChoices(
              show: show,
              lockOn: lockState.lockOn,
              face: _now ?? AppFace.kryfo,
              onPick: _setShow,
            ),
            const Spacer(),
            Unfold(
              open: picked != null,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: HaloPrimaryButton(
                  label: l10n.iconConfirmButton,
                  onTap: _switching ? null : _confirm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// a small home screen: the picked icon with its name under it, on a
// wallpaper's colour. a screen reader hears one line for it
class _HomePreview extends StatelessWidget {
  final AppFace face;
  const _HomePreview({required this.face});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final light = HaloColors.isLight;
    return Semantics(
      label: l10n.iconPreviewLabel(face.label),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HaloColors.line, width: 0.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: light
                ? const [Color(0xFFDCE3EA), Color(0xFFEDE4D6)]
                : const [Color(0xFF26303A), Color(0xFF2E2620)],
          ),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: still
                ? const Duration(milliseconds: 120)
                : const Duration(milliseconds: 280),
            // the spring goes past its end, so it moves the scale only and
            // the fade keeps a curve of its own
            transitionBuilder: (child, a) {
              final fade = FadeTransition(
                opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
                child: child,
              );
              if (still) return fade;
              return ScaleTransition(
                scale: a.drive(
                  Tween(
                    begin: 0.85,
                    end: 1.0,
                  ).chain(CurveTween(curve: kHouseCurve)),
                ),
                child: fade,
              );
            },
            child: Column(
              key: ValueKey(face),
              mainAxisSize: MainAxisSize.min,
              children: [
                // the preview gives way first when the words grow
                AppFaceIcon(
                  face: face,
                  size:
                      64 /
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
                ),
                const SizedBox(height: 8),
                _SlideUp(
                  still: still,
                  child: Text(
                    face.label,
                    textAlign: TextAlign.center,
                    style:
                        HaloType.sans(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: light ? const Color(0xFF1F2428) : Colors.white,
                        ).copyWith(
                          shadows: light
                              ? null
                              : const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 4,
                                  ),
                                ],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// the name rises 6 into place as its icon settles
class _SlideUp extends StatelessWidget {
  final bool still;
  final Widget child;
  const _SlideUp({required this.still, required this.child});

  @override
  Widget build(BuildContext context) {
    if (still) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 6, end: 0),
      duration: kHouseTime,
      curve: kHouseCurve,
      builder: (_, dy, c) =>
          Transform.translate(offset: Offset(0, dy), child: c),
      child: child,
    );
  }
}

// the icons, five across, three from 1.5 times the text, two from twice
// it. one ring marks the picked one and springs from icon to icon
class _FaceGrid extends StatelessWidget {
  final AppFace picked;
  // the phone's icon is read: until then no ring
  final bool known;
  final void Function(AppFace) onPick;
  const _FaceGrid({
    required this.picked,
    required this.known,
    required this.onPick,
  });

  static const _icon = 52.0;
  static const _ring = _icon + 10;

  static TextStyle get _label =>
      HaloType.sans(size: 11.5, weight: FontWeight.w600, height: 1.25);

  static double _widestWord(BuildContext context, TextScaler scaler) {
    var most = 0.0;
    for (final f in AppFace.values) {
      for (final w in f.label.split(' ')) {
        final p = TextPainter(
          text: TextSpan(text: w, style: _label),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (p.width > most) most = p.width;
        p.dispose();
      }
    }
    return most;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1);
    final width = MediaQuery.sizeOf(context).width - 40;
    // a name wraps between words, never inside one: five across only while
    // the longest word of any name fits its tile
    final word = _widestWord(context, scaler);
    final cols = scale >= 2
        ? 2
        : scale >= 1.5 || word > width / 5 - 6
        ? 3
        : 5;
    final tileW = width / cols;
    final labelH = MediaQuery.textScalerOf(context).scale(11.5) * 1.3 * 2;
    final tileH = 8 + _ring + 6 + labelH + 8;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const faces = AppFace.values;
    final rows = (faces.length / cols).ceil();
    Offset at(int i) {
      final col = i % cols;
      final x = (rtl ? cols - 1 - col : col) * tileW;
      return Offset(x, (i ~/ cols) * tileH);
    }

    final ringAt = at(faces.indexOf(picked));
    final still = motionStill(context);
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: SizedBox(
        height: rows * tileH,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: still ? Duration.zero : kHouseTime,
              curve: kHouseCurve,
              left: ringAt.dx + (tileW - _ring) / 2,
              top: ringAt.dy + 8,
              width: _ring,
              height: _ring,
              child: AnimatedOpacity(
                opacity: known ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_ring * 0.32),
                      border: Border.all(color: HaloColors.amber, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < faces.length; i++)
              Positioned(
                left: at(i).dx,
                top: at(i).dy,
                width: tileW,
                height: tileH,
                child: _FaceTile(
                  face: faces[i],
                  on: known && faces[i] == picked,
                  onTap: () => onPick(faces[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FaceTile extends StatelessWidget {
  final AppFace face;
  final bool on;
  final VoidCallback onTap;
  const _FaceTile({required this.face, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      label: l10n.iconButtonLabel(face.label),
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.92,
        haptic: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              SizedBox.square(
                dimension: _FaceGrid._ring,
                child: Center(child: AppFaceIcon(face: face)),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  face.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                    size: 11.5,
                    weight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? HaloColors.text : HaloColors.text2,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// the three things a notification may show, one picked, read as a radio
// group. a preview of the plain one opens under it
class _ShowChoices extends StatelessWidget {
  final NotifShow? show;
  final bool lockOn;
  final AppFace face;
  final void Function(NotifShow) onPick;
  const _ShowChoices({
    required this.show,
    required this.lockOn,
    required this.face,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: HaloGroup(
        children: [
          _ShowRow(
            label: l10n.notifShowAll,
            on: show == NotifShow.all,
            onTap: show == null ? null : () => onPick(NotifShow.all),
            // a pin turns previews off. if someone turns them back on,
            // say what that gives away
            warn: lockOn && show == NotifShow.all
                ? l10n.gettingMessagesShowsMessageTextIn
                : null,
          ),
          _ShowRow(
            label: l10n.notifShowNew,
            hint: l10n.gettingMessagesAGenericAlertWith,
            on: show == NotifShow.newMessage,
            onTap: show == null ? null : () => onPick(NotifShow.newMessage),
          ),
          _ShowRow(
            label: l10n.notifShowPlain,
            hint: l10n.notifPlainHint,
            on: show == NotifShow.plain,
            onTap: show == null ? null : () => onPick(NotifShow.plain),
            more: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(child: _PlainLook(face: face)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.notifHeaderLimit,
                    style: HaloType.sans(
                      size: 12,
                      color: HaloColors.text2,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowRow extends StatelessWidget {
  final String label;
  final String? hint;
  final bool on;
  final VoidCallback? onTap;
  final String? warn;
  // opens under the row while it is picked
  final Widget? more;
  const _ShowRow({
    required this.label,
    this.hint,
    required this.on,
    required this.onTap,
    this.warn,
    this.more,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      button: true,
      child: InkWell(
        onTap: onTap,
        splashColor: HaloColors.amber.withValues(alpha: 0.08),
        highlightColor: HaloColors.amber.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _RadioMark(on: on, still: still),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: HaloType.sans(
                        size: 14,
                        weight: on ? FontWeight.w600 : FontWeight.w400,
                        color: HaloColors.text,
                      ),
                    ),
                    if (hint != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          hint!,
                          style: HaloType.sans(
                            size: 12.5,
                            color: HaloColors.text2,
                            height: 1.35,
                          ),
                        ),
                      ),
                    Unfold(
                      open: warn != null,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          warn ?? '',
                          style: HaloType.sans(
                            size: 12,
                            color: HaloColors.rose,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    if (more != null) Unfold(open: on, child: more!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  final bool on;
  final bool still;
  const _RadioMark({required this.on, required this.still});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 160),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? HaloColors.amber : HaloColors.line2,
          width: on ? 2 : 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: still ? Duration.zero : kHouseTime,
        curve: kHouseCurve,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: HaloColors.amber,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// what a plain notification looks like in the shade: the header android
// keeps, the glyph, one line
class _PlainLook extends StatelessWidget {
  final AppFace face;
  const _PlainLook({required this.face});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: HaloColors.surface3,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: HaloColors.text2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppFaceGlyph(
              face: face,
              size: 15,
              color: HaloColors.surface3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kryfo',
                  style: HaloType.sans(size: 11.5, color: HaloColors.text2),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.notifPlainLine,
                  style: HaloType.sans(size: 13.5, color: HaloColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangesSheet extends StatelessWidget {
  final String? hideLine;
  const _ChangesSheet({this.hideLine});

  @override
  Widget build(BuildContext context) {
    Widget head(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        t,
        style: HaloType.sans(
          size: 13.5,
          weight: FontWeight.w600,
          color: HaloColors.text,
        ),
      ),
    );
    Widget body(String t) => Text(
      t,
      style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.45),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              l10n.iconWhatChanges,
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            head(l10n.iconSheetChangesTitle),
            body(l10n.iconSheetChanges),
            head(l10n.iconSheetStaysTitle),
            body(l10n.iconSheetStays),
            const SizedBox(height: 8),
            body(l10n.iconSheetOthers),
            const SizedBox(height: 8),
            body(l10n.iconSheetSaves),
            const SizedBox(height: 14),
            Text(
              l10n.iconSheetGlance,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text,
                height: 1.45,
              ),
            ),
            if (hideLine != null) ...[
              const SizedBox(height: 10),
              body(hideLine!),
            ],
            const SizedBox(height: 18),
            HaloPrimaryButton(
              label: l10n.commonDone,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
