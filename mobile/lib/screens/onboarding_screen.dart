// SPDX-License-Identifier: GPL-3.0-or-later
// onboarding, shown once. three things in the first minute, everything else
// when it is needed: your name is three words, nobody gets in unless you let
// them, the first connection takes a minute.
// the steps: welcome, your name and its face, a public @name if wanted, how
// messages reach you, invite someone. the route stays private unless the
// first start took fast; settings change it. play builds pick how messages
// arrive where the others explain the one quiet notification

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/press_scale.dart';
import '../widgets/fit_column.dart';
import '../theme.dart';
import 'restore_screen.dart';
import 'my_kryfo_screen.dart';
import '../main.dart'
    show
        appState,
        AppState,
        AppStateRoute,
        AppStateProfile,
        AppStateSession,
        AppStateRefresh,
        AppStateIdentity,
        AppStateDelivery,
        newJoinFlow;
import '../devices/linked_switch.dart' show kLinkedDevicesOn;
import 'link_screens.dart' show JoinScreen;
import '../widgets/kryfo_link_text.dart' show addScanned, takeOwnLink;
import 'scan_screen.dart';
import 'handle_screen.dart'
    show HandleField, HandleAvailability, HandleSlowLine;
import '../handle_claim.dart';
import '../handle_repoint.dart' show handleRefusalLine;
import '../invite_share.dart' show shareInvite;
import '../miui_autostart.dart' show maybeShowBackgroundPrompt;
import '../widgets/ease_size.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart'
    show haloRoute, motionStill, kHouseCurve, kHouseTime;
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import '../l10n/marked.dart';
import '../l10n/numbers.dart' show twoDigits;
import '../widgets/language_sheet.dart';
import '../delivery_mode.dart';
import '../store.dart' show playBuild;
import '../desktop/desktop_mode.dart' show canShareOut;
import 'helper_sheet.dart' show showHelperSheet;
import '../desktop/desktop_mode.dart' show desktopRun, onDesktop;
import 'desk_run_section.dart';

/// the onboarding's steps, by name: a step is never found by its place
enum OnboardStep { welcome, identity, name, delivery, notify, desk, invite }

/// the steps in order. play asks how messages reach the phone; the others
/// say what the one quiet notification is. a computer has no notification
/// to explain: it says it keeps running in the tray
List<OnboardStep> onboardingSteps({required bool play, bool desk = false}) => [
  OnboardStep.welcome,
  OnboardStep.identity,
  OnboardStep.name,
  desk
      ? OnboardStep.desk
      : play
      ? OnboardStep.delivery
      : OnboardStep.notify,
  OnboardStep.invite,
];

/// the onboarding's column on a computer: a phone's width, centred
const kDeskOnboardWidth = 520.0;

/// the battery and phone maker asks, after the notification step. a test
/// hands in its own
@visibleForTesting
Future<void> Function(BuildContext context) onboardingBackgroundAsk =
    maybeShowBackgroundPrompt;

// the battery exemption and the maker's switch keep messages coming while
// Kryfo is closed. google push wakes the phone itself and needs neither
Future<void> _askBackground(BuildContext context, DeliveryMode mode) async {
  if (mode == DeliveryMode.google) return;
  try {
    await onboardingBackgroundAsk(context);
  } catch (_) {
    // asked again from home and settings
  }
}

class OnboardingScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onComplete;
  const OnboardingScreen({
    super.key,
    required this.appState,
    required this.onComplete,
  });
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<OnboardStep> _steps = onboardingSteps(
    play: playBuild,
    desk: onDesktop && desktopRun != null,
  );
  final _ctrl = PageController();
  int _page = 0;
  // the step being moved to: it settles in while the one left fades out
  int _to = 0;
  // steps already left once: coming back to one, it shows without animation
  final _seen = <OnboardStep>{};

  void _go(int to) {
    if (to < 0 || to >= _steps.length) return;
    setState(() => _to = to);
    // reduced motion: the step without animation
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.jumpToPage(to);
      return;
    }
    _ctrl.animateToPage(
      to,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  int get _at => (_ctrl.page ?? _page.toDouble()).round();

  // this device joins an account on a phone in place of making its own
  void _link() {
    HapticFeedback.selectionClick();
    final nav = Navigator.of(context);
    nav.push(
      haloRoute(
        JoinScreen(
          newFlow: newJoinFlow,
          // onboarding is done already, when the link was: this only
          // leaves the page
          onLinked: () => nav.pop(),
        ),
      ),
    );
  }

  void _next() => _go(_at + 1);

  // system back walks one step back; only the first step leaves the app
  void _back() {
    final to = _at - 1;
    // a claim on its way holds this key: the key step stays out of reach
    if (to < 0 || claimInFlight) return;
    HapticFeedback.selectionClick();
    _go(to);
  }

  @override
  void initState() {
    super.initState();
    // whether the phone has play services, known by the time its step comes
    if (playBuild) unawaited(appState.lookForGoogle());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _step(OnboardStep s) {
    final enter = !_seen.contains(s);
    return switch (s) {
      OnboardStep.welcome => _WelcomeScreen(
        onContinue: _next,
        enter: enter,
        // a computer joins a phone in 0.6; a phone makes its own account
        onLink: kLinkedDevicesOn && onDesktop ? _link : null,
      ),
      OnboardStep.identity => _IdentityScreen(
        appState: widget.appState,
        onContinue: _next,
        enter: enter,
      ),
      OnboardStep.name => _NameScreen(onContinue: _next),
      OnboardStep.delivery => _DeliveryScreen(onContinue: _next),
      OnboardStep.notify => _NotificationScreen(
        onContinue: _next,
        enter: enter,
      ),
      OnboardStep.desk => _DeskRunScreen(onContinue: _next),
      OnboardStep.invite => _InviteScreen(onComplete: widget.onComplete),
    };
  }

  @override
  Widget build(BuildContext context) {
    final count = _steps.length;
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (done, _) {
        if (!done) _back();
      },
      child: Scaffold(
        backgroundColor: HaloColors.ink,
        body: SafeArea(
          child: _deskColumn(
            Column(
              children: [
                _StepBar(pages: _ctrl, step: _to, count: count, onBack: _back),
                Expanded(
                  child: PageView(
                    controller: _ctrl,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() {
                      // the step left is seen: back on it, nothing replays
                      _seen.add(_steps[_page]);
                      _page = i;
                      _to = i;
                    }),
                    children: [
                      for (var i = 0; i < count; i++)
                        _StepFrame(
                          key: ValueKey(_steps[i]),
                          pages: _ctrl,
                          index: i,
                          coming: i == _to,
                          child: _step(_steps[i]),
                        ),
                    ],
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

// a computer's window is wide: the steps keep a phone's column, centred,
// so no line or button runs edge to edge
Widget _deskColumn(Widget child) => !onDesktop
    ? child
    : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDeskOnboardWidth),
          child: child,
        ),
      );

// the pager moves a whole width; each step is pulled back so it only
// shifts a little: the one left fades out first, then the next settles in
class _StepFrame extends StatelessWidget {
  final PageController pages;
  final int index;
  final bool coming;
  final Widget child;
  const _StepFrame({
    super.key,
    required this.pages,
    required this.index,
    required this.coming,
    required this.child,
  });

  static const _shift = 28.0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: pages,
      child: child,
      builder: (context, child) {
        var d = 0.0;
        var w = 0.0;
        if (pages.hasClients && pages.position.haveDimensions) {
          d = pages.page! - index;
          w = pages.position.viewportDimension;
        }
        final q = d.abs().clamp(0.0, 1.0);
        final shown = coming
            ? Curves.easeOut.transform(((0.7 - q) / 0.7).clamp(0.0, 1.0))
            : 1 - Curves.easeIn.transform((q / 0.3).clamp(0.0, 1.0));
        return IgnorePointer(
          // a tap while steps change would land on the wrong one
          ignoring: q > 0.01,
          child: Opacity(
            opacity: shown,
            child: Transform.translate(
              offset: Offset(d * (w - _shift) * (rtl ? -1 : 1), 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// back, the steps as a filling track, and the count. the welcome step
// shows none of them: its language row is on the page
class _StepBar extends StatelessWidget {
  final PageController pages;
  final int step;
  final int count;
  final VoidCallback onBack;
  const _StepBar({
    required this.pages,
    required this.step,
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final counter = AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 0 : 240),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        '${twoDigits(step + 1)} / ${twoDigits(count)}',
        key: ValueKey(step),
        style: HaloType.mono(
          size: 10,
          color: HaloColors.amberText,
        ).copyWith(letterSpacing: track(2), fontWeight: FontWeight.w500),
      ),
    );
    // grows with a large text size rather than squeezing the chip
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: AnimatedBuilder(
        animation: pages,
        builder: (context, _) {
          final pos = pages.hasClients && pages.position.haveDimensions
              ? pages.page!
              : step.toDouble();
          final shown = pos.clamp(0.0, 1.0);
          return Row(
            children: [
              const SizedBox(width: 4),
              IgnorePointer(
                ignoring: shown < 0.5,
                child: Opacity(
                  opacity: shown,
                  child: IconButton(
                    tooltip: l10n.commonBack,
                    onPressed: onBack,
                    icon: Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Opacity(
                  opacity: shown,
                  child: ExcludeSemantics(child: _track(pos)),
                ),
              ),
              const SizedBox(width: 14),
              IgnorePointer(
                child: Opacity(
                  opacity: shown,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: counter,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          );
        },
      ),
    );
  }

  // one short bar a step, filled from the reading side as the step arrives
  Widget _track(double pos) {
    return Row(
      children: [
        for (var k = 0; k < count; k++) ...[
          if (k > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: HaloColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: (pos + 1 - k).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---- 01 welcome ----

class _WelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final bool enter;
  // joins an account on a phone; null where linking is off
  final VoidCallback? onLink;
  const _WelcomeScreen({
    required this.onContinue,
    required this.enter,
    this.onLink,
  });
  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctl;
  // the page comes up in order: the light, the line, the promises, the button
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  bool _glowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // two slow glows as the page opens, then it rests: nothing loops while
    // someone reads
    if (_glowed) return;
    _glowed = true;
    if (!widget.enter || MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
      return;
    }
    _in.forward();
    // a whole number of glows ends where it began
    _ctl.repeat(count: 2).whenComplete(() {
      if (mounted) _ctl.value = 0;
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _in.dispose();
    super.dispose();
  }

  Widget _rise(double from, double to, Widget child, {double by = 14}) {
    final curve = Interval(from, to, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _in,
      child: child,
      builder: (_, child) {
        final v = curve.transform(_in.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * by),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // a short phone keeps the button in view with a smaller light and type
    final tight = MediaQuery.sizeOf(context).height < 720;
    final hero = tight ? 34.0 : 38.0;
    return _StepPage(
      top: tight ? 12 : 20,
      cross: CrossAxisAlignment.start,
      footer: [
        _rise(
          0.68,
          1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // the language first, before a word has to be read
              const LanguageRow(),
              const SizedBox(height: 10),
              _Cta(label: l10n.onboardingBegin, onTap: widget.onContinue),
              const SizedBox(height: 2),
              Center(
                child: _TextLink(
                  label: l10n.onboardingHaveABackupRestore,
                  onTap: () => Navigator.of(
                    context,
                  ).push(haloRoute(const RestoreScreen())),
                ),
              ),
              if (widget.onLink != null)
                Center(
                  child: _TextLink(
                    label: l10n.onboardingLinkToMyPhone,
                    onTap: widget.onLink!,
                  ),
                ),
            ],
          ),
          by: 10,
        ),
      ],
      children: [
        _orb(tight ? 58 : 70),
        SizedBox(height: tight ? 22 : 28),
        _rise(
          0.15,
          0.5,
          Text(
            l10n.onboardingPrivateByDefault,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amberText,
            ).copyWith(letterSpacing: track(4), fontWeight: FontWeight.w500),
          ),
          by: 8,
        ),
        SizedBox(height: tight ? 16 : 20),
        _rise(
          0.22,
          0.65,
          Text.rich(
            TextSpan(
              style: HaloType.serif(
                size: hero,
                weight: FontWeight.w300,
                color: HaloColors.text,
                height: 1.08,
              ),
              children: markedSpans(
                l10n.onboardingPrivateMessaging,
                HaloType.serif(
                  size: hero,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.amberText,
                  height: 1.08,
                ),
              ),
            ),
            textScaler: _headScale(context),
          ),
        ),
        SizedBox(height: tight ? 22 : 28),
        _rise(0.4, 0.78, _bullet(l10n.onboardingYourNameIsThree)),
        SizedBox(height: tight ? 10 : 14),
        _rise(0.48, 0.86, _bullet(l10n.onboardingNobodyGetsInUnless)),
        SizedBox(height: tight ? 10 : 14),
        _rise(0.56, 0.94, _bullet(l10n.onboardingTheFirstConnectionTakes)),
        SizedBox(height: tight ? 14 : 18),
        // the one thing to keep in mind after the three
        _rise(
          0.62,
          1,
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Text(
              l10n.onboardingYourIdentityLivesOnShown,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.warm,
                height: 1.5,
              ),
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(height: 24),
        _rise(
          0.68,
          1,
          Center(
            child: Text(
              l10n.onboardingKryfoIsOpenSource,
              textAlign: TextAlign.center,
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text2,
              ).copyWith(letterSpacing: track(2)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orb(double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctl, _in]),
      builder: (c, _) {
        final op = 0.7 + 0.3 * math.sin(_ctl.value * 2 * math.pi);
        final v = const Interval(0, 0.5).transform(_in.value);
        return Opacity(
          opacity: Curves.easeOut.transform(v),
          child: Transform.scale(
            scale: 0.6 + 0.4 * Curves.easeOutBack.transform(v),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: [HaloColors.amber, HaloColors.amberDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: HaloColors.amber.withValues(alpha: 0.5 * op),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // the lead words carry the weight. the rest is warm, a step brighter than
  // the usual second line: this page has to be read
  Widget _bullet(String msg) {
    const size = 14.0;
    const height = 1.55;
    final line = MediaQuery.textScalerOf(context).scale(size) * height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: EdgeInsetsDirectional.only(top: line / 2 - 3, end: 14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HaloColors.amber,
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: HaloType.sans(
                size: size,
                color: HaloColors.warm,
                height: height,
              ),
              children: markedSpans(
                msg,
                HaloType.sans(
                  size: size,
                  color: HaloColors.text,
                  weight: FontWeight.w600,
                  height: height,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- 02 identity reveal ----

class _IdentityScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onContinue;
  final bool enter;
  const _IdentityScreen({
    required this.appState,
    required this.onContinue,
    required this.enter,
  });
  @override
  State<_IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<_IdentityScreen>
    with TickerProviderStateMixin {
  // the reveal's timeline, in ms
  static const _length = 2400;
  late final AnimationController _shimmer;
  late final AnimationController _reveal;
  late final AnimationController _breath;
  // a new name: the old words lift away, the new ones land one by one
  late final AnimationController _roll;
  late final AnimationController _spin;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _length),
    );
    _roll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      value: 1,
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown) return;
    _shown = true;
    // the name writes itself in, the shine and the ring play twice, then
    // stop. reduced motion, or back on this step: no animation
    if (!widget.enter || MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
      return;
    }
    _reveal.forward(from: 0);
    _shimmer.repeat(count: 2);
    _breath.repeat(count: 2).whenComplete(() {
      if (mounted) _breath.value = 0;
    });
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _reveal.dispose();
    _breath.dispose();
    _roll.dispose();
    _spin.dispose();
    super.dispose();
  }

  // the first key's signal setup may still be running: the arrow turns
  // until the new name is ready, and taps meanwhile change nothing
  bool _busy = false;

  Future<void> _regenerate() async {
    if (_busy || widget.appState.myHandle != null || claimInFlight) return;
    final still = motionStill(context);
    _reveal.value = 1;
    setState(() {
      _busy = true;
      _leaving = !still;
      _held = widget.appState.sessionId;
    });
    if (!still) _spin.repeat();
    try {
      await Future.wait([
        widget.appState.regenerateIdentity(),
        if (!still)
          _roll
              .animateBack(
                0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInCubic,
              )
              .orCancel
              .catchError((_) {}),
      ]);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _leaving = false;
          _held = null;
        });
        if (!still) _land();
      }
    }
  }

  void _land() {
    _roll.forward(from: 0);
    _shimmer.forward(from: 0);
    // the arrow finishes its turn and rests
    _spin
        .animateTo(
          1,
          duration: Duration(milliseconds: (500 * (1 - _spin.value)).round()),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) _spin.value = 0;
        });
  }

  bool _saving = false;

  Future<void> _continue() async {
    if (_busy || _saving) return;
    _saving = true;
    try {
      // the face drawn from the words, kept: the profile changes it
      final id = widget.appState.sessionId;
      if (id.isNotEmpty) {
        await widget.appState.setMyAvatar(autoFace(id));
      }
      if (!await _settleRoute()) return;
    } finally {
      _saving = false;
    }
    if (mounted) widget.onContinue();
  }

  // the route is not asked in setup: private, or fast when the first start
  // took it where nothing got through. written either way, so what this
  // phone starts on is what was said here
  Future<bool> _settleRoute() async {
    final m = widget.appState.sendMode == 'balanced' ? 'balanced' : 'private';
    try {
      await widget.appState.setSendMode(m);
      return true;
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.modesNotChanged);
      return false;
    }
  }

  // the name on screen: the old one stays until the new one lands
  String? _held;
  String get _id => _held ?? widget.appState.sessionId;

  List<String> get _words {
    final id = _id;
    if (id.isEmpty) return ['...', '...', '...'];
    return id.split('-').take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    return _StepPage(
      top: 8,
      cross: CrossAxisAlignment.center,
      footer: [
        _fadeAt(
          1650,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cta(label: l10n.onboardingUseThisName, onTap: _continue),
              // a claimed @name points at this key's invite: a new key would
              // leave it pointing at one nobody holds, so the words stay
              ListenableBuilder(
                listenable: Listenable.merge([widget.appState, claimsInFlight]),
                builder: (_, _) =>
                    widget.appState.myHandle != null || claimInFlight
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _tryAnother(),
                      ),
              ),
            ],
          ),
        ),
      ],
      children: [
        const Spacer(),
        _sigilReveal(),
        const SizedBox(height: 24),
        _fadeAt(
          300,
          child: Text(
            l10n.onboardingYourKryfoId,
            textAlign: TextAlign.center,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amberText,
            ).copyWith(letterSpacing: track(4), fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),
        _shimmerPill(words),
        const SizedBox(height: 22),
        _fadeAt(1300, child: _italicLine()),
        const SizedBox(height: 12),
        _fadeAt(
          1450,
          // a plain SizedBox would let the fit pass measure this at the
          // full width and the page would overflow instead of scroll
          child: FitWidth(
            width: 280,
            child: Text.rich(
              TextSpan(
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.55,
                ),
                children: markedSpans(
                  l10n.onboardingGeneratedFromAKeyShown,
                  HaloType.sans(
                    size: 12.5,
                    color: HaloColors.text,
                    weight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _tryAnother() {
    final still = motionStill(context);
    final b = PressScale(
      scale: 0.97,
      onTap: _regenerate,
      child: AnimatedOpacity(
        // with reduced motion nothing turns: the button dims while it works
        opacity: _busy && still ? 0.5 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: HaloColors.line2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _spin,
                child: Icon(
                  Icons.refresh_rounded,
                  key: _busy ? const ValueKey('regenerating') : null,
                  size: 17,
                  color: HaloColors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.onboardingTryAnother,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 14,
                    color: HaloColors.text,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _button(b);
  }

  Widget _sigilReveal() {
    final still = motionStill(context);
    final seed = _id.isEmpty ? 'Kryfo' : _id;
    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _reveal]),
      // a new name draws a new face: it pops in over the last
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: still ? 0 : 360),
        switchInCurve: kHouseCurve,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(anim),
            child: child,
          ),
        ),
        child: KryfoAvatar(
          key: ValueKey(seed),
          seed: seed,
          size: 56,
          choice: _id.isEmpty ? null : autoFace(seed),
        ),
      ),
      builder: (c, face) {
        final breath = 0.7 + 0.3 * math.sin(_breath.value * 2 * math.pi);
        final rv = (_reveal.value * _length / 1000).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(rv);
        return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // a warm light around the face, faded out before its edge
              Positioned(
                left: -66,
                top: -66,
                right: -66,
                bottom: -66,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: eased,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            HaloColors.amber.withValues(alpha: 0.10),
                            HaloColors.amber.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(88, 88),
                painter: _HaloRingPainter(eased, breath),
              ),
              Opacity(
                opacity: eased,
                child: Transform.scale(
                  scale: 0.72 + 0.28 * Curves.easeOutBack.transform(rv),
                  child: face,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _italicLine() => Text.rich(
    TextSpan(
      style: HaloType.serif(
        size: 20,
        weight: FontWeight.w300,
        color: HaloColors.text,
        height: 1.25,
      ),
      children: markedSpans(
        l10n.onboardingThreeWords,
        HaloType.serif(
          size: 20,
          weight: FontWeight.w300,
          italic: true,
          color: HaloColors.amberText,
          height: 1.25,
        ),
      ),
    ),
    textAlign: TextAlign.center,
  );

  Widget _shimmerPill(List<String> words) {
    final still = motionStill(context);
    // the id reads left to right in every language
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        _wordReveal(words[0], 0, 350),
        _sep(1150),
        _wordReveal(words[1], 1, 600),
        _sep(1150),
        _wordReveal(words[2], 2, 850),
      ],
    );
    return AnimatedBuilder(
      animation: _shimmer,
      // long words at a large text size shrink the pill instead of
      // spilling past the screen
      builder: (c, _) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HaloColors.amber, width: 0.5),
              ),
              // the pill eases to the new name's width. a zero-length
              // size animation would relayout inside its own layout
              child: still
                  ? name
                  : AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: name,
                    ),
            ),
            if (_shimmer.isAnimating)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: IgnorePointer(
                    child: ShaderMask(
                      blendMode: BlendMode.dstATop,
                      shaderCallback: (rect) {
                        final w = rect.width;
                        final t = _shimmer.value;
                        final x = -w + (w * 3) * t;
                        return LinearGradient(
                          begin: Alignment(x / w * 2 - 1, 0),
                          end: Alignment((x + w) / w * 2 - 1, 0),
                          colors: [
                            Colors.transparent,
                            HaloColors.amber.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ).createShader(rect);
                      },
                      child: Container(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wordReveal(String word, int i, int delayMs) {
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _roll]),
      builder: (c, _) {
        // the first time: written in from blur. a new name: the words
        // lift away together, then land one after another
        var v = ((_reveal.value * _length - delayMs) / 650).clamp(0.0, 1.0);
        var dy = (1 - v) * 10;
        if (_reveal.value >= 1) {
          if (_leaving) {
            v = Curves.easeIn.transform(_roll.value);
            dy = -(1 - v) * 8;
          } else {
            final t = ((_roll.value * 720 - i * 110) / 480).clamp(0.0, 1.0);
            v = Curves.easeOutCubic.transform(t);
            dy = (1 - Curves.easeOutBack.transform(t)) * 12;
          }
        }
        final blur = (1 - v) * 6;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: ImageFiltered(
              enabled: blur > 0.05,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: Text(
                word,
                style: HaloType.mono(size: 15, color: HaloColors.amberText)
                    .copyWith(
                      letterSpacing: track(0.4),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sep(int delayMs) => _fadeAt(
    delayMs,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Text('·', style: HaloType.mono(size: 15, color: HaloColors.text2)),
    ),
  );

  Widget _fadeAt(int delayMs, {required Widget child}) {
    return AnimatedBuilder(
      animation: _reveal,
      child: child,
      builder: (c, child) {
        final t = (_reveal.value * _length - delayMs) / 650;
        final v = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

class _HaloRingPainter extends CustomPainter {
  final double sweep; // 0..1 of a full circle
  final double glow; // 0..1 pulse
  _HaloRingPainter(this.sweep, this.glow);
  @override
  void paint(Canvas canvas, Size size) {
    if (sweep <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = HaloColors.amber.withValues(alpha: 0.92)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + 3.5 * glow);
    canvas.drawArc(rect, -math.pi / 2, sweep * 2 * math.pi, false, p);
  }

  @override
  bool shouldRepaint(_HaloRingPainter old) =>
      old.sweep != sweep || old.glow != glow;
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String cost;
  // null: one line says it all
  final String? gain;
  // a word beside the title: the one most people want
  final String? tag;
  final bool on;
  // null: the only way, shown as a card with no radio
  final VoidCallback? onTap;
  // there, but not on this route: faded, its line says why
  final bool dim;
  const _ModeCard({
    super.key,
    required this.title,
    required this.cost,
    this.gain,
    this.tag,
    this.on = false,
    this.onTap,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final tap = onTap;
    final card = AnimatedContainer(
      duration: Duration(milliseconds: still ? 0 : 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: on
            ? Color.alphaBlend(
                HaloColors.amber.withValues(alpha: 0.10),
                HaloColors.surface2,
              )
            : HaloColors.surface2,
        border: Border.all(
          color: on ? HaloColors.amber : HaloColors.line,
          width: on ? 1.2 : 0.5,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: HaloColors.amber.withValues(alpha: on ? 0.16 : 0),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tap != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _Radio(on: on),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: HaloType.serif(size: 18, color: HaloColors.text),
                    ),
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: HaloColors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag!,
                          style: HaloType.mono(
                            size: 10,
                            letter: 0.06,
                            color: HaloColors.amberText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                // the cost first, then what it buys: a card that lists
                // only benefits sends everyone to the fastest one
                Text(
                  cost,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text,
                    height: 1.45,
                  ),
                ),
                if (gain != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    gain!,
                    style: HaloType.sans(
                      size: 13,
                      color: dim ? HaloColors.amberText : HaloColors.text2,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (dim) {
      return MergeSemantics(
        child: Semantics(
          enabled: false,
          child: AnimatedOpacity(
            opacity: 0.5,
            duration: Duration.zero,
            child: card,
          ),
        ),
      );
    }
    if (tap == null) return MergeSemantics(child: card);
    // read as one radio: the title, the cost, the gain, and whether it is on
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        child: PressScale(scale: 0.98, onTap: tap, child: card),
      ),
    );
  }
}

// a ring, and a dot that springs in when it is the one
class _Radio extends StatelessWidget {
  final bool on;
  const _Radio({required this.on});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedContainer(
      duration: Duration(milliseconds: still ? 0 : 200),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? HaloColors.amber : HaloColors.text3,
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: still ? Duration.zero : kHouseTime,
        curve: on ? kHouseCurve : Curves.easeInCubic,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HaloColors.amber,
          ),
        ),
      ),
    );
  }
}

// ---- how messages reach you, play builds ----
//
// google push first and picked already: instant and light, with what
// google sees said plainly. the other ways are a tap away here and later
// in notifications. phones without play services do not see it.

/// the ways the step lists, in order
List<DeliveryMode> onboardingModes({required bool google}) => [
  if (google) DeliveryMode.google,
  DeliveryMode.always,
  DeliveryMode.checkins,
  DeliveryMode.helper,
];

/// what the step starts on: google push where it can be used now. it and
/// the helper app register over the onion route only
DeliveryMode onboardingPick({required bool google, required bool onion}) =>
    google && onion ? DeliveryMode.google : DeliveryMode.always;

class _DeliveryScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const _DeliveryScreen({required this.onContinue});
  @override
  State<_DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<_DeliveryScreen> {
  // null until a card is tapped: the step's own pick holds till then
  DeliveryMode? _chosen;
  bool _busy = false;

  DeliveryMode get _pick =>
      _chosen ??
      onboardingPick(
        google: appState.googleOffered,
        onion: appState.sendMode == 'private',
      );

  // the background sheets are up: a second tap waits for them
  bool _asking = false;

  Future<void> _go() async {
    if (_busy || _asking) return;
    final m = _pick;
    setState(() => _busy = true);
    var ok = true;
    switch (m) {
      case DeliveryMode.google:
        ok = await appState.useGoogle();
        if (!ok && mounted) {
          HapticFeedback.heavyImpact();
          showHaloToast(context, l10n.notificationsGoogleNoStart);
        }
      case DeliveryMode.helper:
        // set up by the sheet once a helper app answers; none, and the step
        // stays
        ok = await showHelperSheet(context) != null;
      case DeliveryMode.always:
      case DeliveryMode.checkins:
        await appState.setDeliveryMode(m);
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _busy = false);
    // the battery and the maker's switch, right after the way is picked
    _asking = true;
    await _askBackground(context, m);
    _asking = false;
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final onion = appState.sendMode == 'private';
        final modes = onboardingModes(google: appState.googleOffered);
        Widget card(DeliveryMode m) {
          final needsOnion =
              (m == DeliveryMode.google || m == DeliveryMode.helper) && !onion;
          final (title, body, tag) = switch (m) {
            DeliveryMode.google => (
              l10n.deliveryModeGooglePush,
              l10n.notificationsGoogleBody,
              l10n.notificationsRecommended,
            ),
            DeliveryMode.always => (
              l10n.gettingMessagesAlwaysOn,
              onion
                  ? l10n.gettingMessagesMessagesArriveInstantlyNothing
                  : l10n.gettingMessagesArriveInstantlyFast,
              null,
            ),
            DeliveryMode.checkins => (
              l10n.gettingMessagesCheckIns,
              l10n.gettingMessagesKryfoLooksForMessages,
              null,
            ),
            DeliveryMode.helper => (
              l10n.deliveryModeThroughAHelperApp,
              l10n.gettingMessagesHelperBody,
              null,
            ),
          };
          return _ModeCard(
            key: ValueKey('deliveryCard-${m.name}'),
            title: title,
            cost: body,
            tag: tag,
            gain: needsOnion ? l10n.gettingMessagesHelperOnionOnly : null,
            dim: needsOnion,
            on: _pick == m,
            onTap: needsOnion
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => _chosen = m);
                  },
          );
        }

        return _StepPage(
          footer: [
            _Cta(
              label: _busy
                  ? l10n.notificationsGoogleStarting
                  : l10n.onboardingContinue,
              onTap: _go,
            ),
          ],
          children: [
            _Headline(l10n.onboardingDeliveryHeadline),
            const SizedBox(height: 12),
            _lead(l10n.onboardingDeliveryLead),
            const SizedBox(height: 24),
            ...staggerAll([
              for (var i = 0; i < modes.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                card(modes[i]),
              ],
              // always on listens with one quiet notification: said under
              // the cards while it is the pick
              EaseSize(
                child: AnimatedSwitcher(
                  duration: motionStill(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: _pick == DeliveryMode.always
                      ? Padding(
                          key: const ValueKey('quiet'),
                          padding: const EdgeInsets.only(top: 16),
                          child: _Card(
                            icon: Icons.notifications_none_rounded,
                            title: l10n.onboardingSilentAndAtThe,
                            desc: l10n.onboardingItNeverBuzzesTurn,
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('none'),
                          width: double.infinity,
                        ),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}

// ---- 06 one notification ----
//
// the one android fact worth a page: a background listener needs a visible
// notification, so the tray will show one. two lines and the shade, then on.

class _NotificationScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final bool enter;
  const _NotificationScreen({required this.onContinue, required this.enter});

  @override
  State<_NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<_NotificationScreen> {
  bool _asking = false;

  // then the battery and the maker's switch, which keep it listening
  Future<void> _go() async {
    if (_asking) return;
    _asking = true;
    await _askBackground(context, DeliveryMode.always);
    _asking = false;
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final enter = widget.enter;
    return _StepPage(
      footer: [_Cta(label: l10n.onboardingGotIt, onTap: _go)],
      children: [
        _Headline(l10n.onboardingOneQuiet),
        const SizedBox(height: 12),
        _lead(l10n.onboardingAndroidNeedsAVisible),
        const SizedBox(height: 24),
        Center(child: _ShadeArt(enter: enter)),
        const SizedBox(height: 16),
        ...staggerAll([
          _Card(
            icon: Icons.notifications_none_rounded,
            title: l10n.onboardingSilentAndAtThe,
            desc: l10n.onboardingItNeverBuzzesTurn,
          ),
        ], from: 1),
      ],
    );
  }
}

// ---- 06 on a computer: keep running ----
//
// where the phone explains its one notification, a computer says it stays
// in the tray, and offers the two switches the notifications page keeps

class _DeskRunScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const _DeskRunScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      footer: [_Cta(label: l10n.onboardingGotIt, onTap: onContinue)],
      children: [
        _Headline(l10n.onboardingDeskRunTitle),
        const SizedBox(height: 12),
        _lead(l10n.onboardingDeskRunLead),
        const SizedBox(height: 20),
        ...staggerAll([DeskRunSection(run: desktopRun!, edge: 0)], from: 1),
      ],
    );
  }
}

// the shade as the phone shows it: a message as kryfo posts it, its preview
// hidden, and under it the quiet one folded to a line. it pulls down once as
// the step comes in, then rests
class _ShadeArt extends StatefulWidget {
  final bool enter;
  const _ShadeArt({required this.enter});
  @override
  State<_ShadeArt> createState() => _ShadeArtState();
}

class _ShadeArtState extends State<_ShadeArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // reduced motion, or back on this step: no animation
    if (!widget.enter || MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
      return;
    }
    _in.forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  // a piece fades in and slides into place between [from] and [to]
  Widget _part(double from, double to, double by, Widget child) {
    final curve = Interval(from, to, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _in,
      child: child,
      builder: (_, child) {
        final v = curve.transform(_in.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * by),
            child: child,
          ),
        );
      },
    );
  }

  // the small icon as android draws it: the ring on the notification colour
  Widget _icon(double d) => Container(
    width: d,
    height: d,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: HaloColors.amber),
    child: Container(
      width: d * 0.5,
      height: d * 0.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HaloColors.onAmber, width: d * 0.08),
      ),
    ),
  );

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: HaloColors.line2,
      borderRadius: BorderRadius.circular(h / 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // a picture: its words grow less than the page's
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final title = HaloType.sans(
      size: 12.5,
      color: HaloColors.text,
      weight: FontWeight.w600,
      height: 1.3,
    );
    final line = HaloType.sans(size: 12, color: HaloColors.text2, height: 1.35);
    final status = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 10),
      child: Row(
        children: [
          _bar(24, 6),
          const Spacer(),
          _bar(8, 6),
          const SizedBox(width: 4),
          _bar(8, 6),
          const SizedBox(width: 4),
          _bar(14, 7),
        ],
      ),
    );
    final message = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        border: Border.all(color: HaloColors.line, width: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _icon(24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kryfo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scale,
                  style: title,
                ),
                Text(
                  l10n.notificationsNewMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scale,
                  style: line,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final quiet = Row(
      children: [
        _icon(18),
        const SizedBox(width: 9),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l10n.androidServiceTitle, style: title),
                TextSpan(text: '  ${l10n.androidServiceText}', style: line),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: scale,
          ),
        ),
      ],
    );
    // the quiet one lands last and glows once to be seen
    const glow = Interval(0.62, 1);
    final art = Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border.all(color: HaloColors.line, width: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          status,
          _part(0.18, 0.55, -10, message),
          const SizedBox(height: 8),
          _part(
            0.45,
            0.85,
            10,
            AnimatedBuilder(
              animation: _in,
              child: quiet,
              builder: (_, child) {
                final g = math.sin(glow.transform(_in.value) * math.pi);
                return Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 9, 12, 9),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      HaloColors.amberSoft,
                      HaloColors.surface2,
                    ),
                    border: Border.all(
                      color: HaloColors.amber.withValues(alpha: 0.55),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: HaloColors.amber.withValues(alpha: 0.3 * g),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Center(child: _bar(28, 3)),
        ],
      ),
    );
    // read as the notification's own words
    return Semantics(
      container: true,
      image: true,
      label: '${l10n.androidServiceTitle}. ${l10n.androidServiceText}',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _part(0, 0.4, -14, art),
        ),
      ),
    );
  }
}

// ---- 05 invite someone ----
//
// the link goes out in whatever messenger they already share: it opens
// Kryfo, or a page that says what Kryfo is and where to get it. the code and
// the @name are the other ways, under it

class _InviteScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const _InviteScreen({required this.onComplete});
  @override
  State<_InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<_InviteScreen> {
  bool _sharing = false;

  Future<void> _invite() async {
    if (_sharing) return;
    // no share sheet here: the code page copies the link instead
    if (!canShareOut) return _everyWay();
    setState(() => _sharing = true);
    final sent = await shareInvite(context);
    if (!mounted) return;
    setState(() => _sharing = false);
    if (sent) widget.onComplete();
  }

  Future<void> _everyWay() async {
    // open the page first, then finish onboarding once it returns.
    // completing first rebuilds the tree to home and eats the nav.
    final nav = Navigator.of(context);
    await nav.push(haloRoute(const MyKryfoScreen()));
    widget.onComplete();
  }

  Future<void> _scan() async {
    final nav = Navigator.of(context);
    final raw = await nav.push<String>(haloRoute<String>(const ScanScreen()));
    // the scanner only hands the code back; takeOwnLink is what adds the
    // contact, and a room shows its link first
    if (raw != null && mounted) {
      final status = await takeOwnLink(context, raw, act: addScanned);
      await appState.refreshContacts();
      if (status != null && mounted) showHaloToast(context, status);
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      footer: [
        _Cta(
          label: _sharing
              ? l10n.onboardingInviteGettingReady
              : l10n.onboardingInviteSomeone,
          onTap: _invite,
        ),
        const SizedBox(height: 2),
        Center(
          child: _TextLink(
            label: l10n.onboardingNotNowAddPeople,
            onTap: widget.onComplete,
          ),
        ),
      ],
      children: [
        _Headline(l10n.onboardingInviteHeadline),
        const SizedBox(height: 12),
        _lead(l10n.onboardingInviteLead),
        const SizedBox(height: 24),
        ...staggerAll([
          _Path(
            icon: Icons.qr_code_2_outlined,
            title: l10n.onboardingEveryWayToAdd,
            desc: l10n.onboardingShowYourCodeSend,
            onTap: _everyWay,
          ),
          if (!onDesktop) ...[
            const SizedBox(height: 10),
            _Path(
              icon: Icons.center_focus_weak,
              title: l10n.onboardingScanTheirs,
              desc: l10n.onboardingPointTheCameraAt,
              onTap: _scan,
            ),
          ],
        ], from: 1),
      ],
    );
  }
}

// ---- 03 a public @name ----
//
// for everyone, and skipped unless wanted: skipping is the way on until a
// free name is typed. the same checks as the handle screen, through the
// same claimer

class _NameScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const _NameScreen({required this.onContinue});
  @override
  State<_NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<_NameScreen> {
  final _ctrl = TextEditingController();
  late final _c = HandleClaimer(_ctrl)..addListener(_redraw);

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _skip() {
    FocusScope.of(context).unfocus();
    widget.onContinue();
  }

  Future<void> _claim() async {
    final h = _c.typed;
    FocusScope.of(context).unfocus();
    final r = await _c.claim();
    if (r == null || !mounted) return;
    if (r == 'ok') {
      HapticFeedback.mediumImpact();
      showHaloToast(context, l10n.handleYouAre(h));
      widget.onContinue();
    } else {
      HapticFeedback.heavyImpact();
      showHaloToast(context, handleRefusalLine(r, h));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = appState.myHandle;
    // claimed, then back on this step: it says so and moves on
    if (mine != null) {
      return _StepPage(
        footer: [
          _Cta(label: l10n.onboardingContinue, onTap: widget.onContinue),
        ],
        children: [
          _Headline(l10n.onboardingNameHeadline),
          const SizedBox(height: 24),
          _Card(
            icon: Icons.alternate_email_rounded,
            title: l10n.handleYouAre(mine),
            desc: l10n.onboardingNameLine,
          ),
        ],
      );
    }
    final busy = _c.busy;
    final claimable = _c.free || busy;
    return _StepPage(
      footer: [
        _Cta(
          label: busy
              ? l10n.handleClaiming
              : claimable
              ? l10n.onboardingNameClaim(_c.typed)
              : l10n.onboardingNameSkip,
          onTap: claimable ? _claim : _skip,
        ),
        // skipping stays a tap away once a name can be claimed
        EaseSize(
          child: AnimatedSwitcher(
            duration: motionStill(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: claimable
                ? Padding(
                    key: const ValueKey('skip'),
                    padding: const EdgeInsets.only(top: 2),
                    child: Center(
                      child: _TextLink(
                        label: l10n.onboardingNameSkip,
                        onTap: _skip,
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('none'), width: double.infinity),
          ),
        ),
      ],
      children: [
        _Headline(l10n.onboardingNameHeadline),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingNameLine,
          style: HaloType.sans(size: 14, color: HaloColors.warm, height: 1.55),
        ),
        const SizedBox(height: 24),
        ...staggerAll([
          HandleField(
            ctrl: _ctrl,
            hint: l10n.handleHintName,
            prefix: '@',
            onChanged: _c.onTyped,
            max: 20,
          ),
          const SizedBox(height: 8),
          HandleAvailability(state: _c.state, slow: _c.slow),
          HandleSlowLine(show: busy && _c.slow),
        ], from: 1),
      ],
    );
  }
}

// ---- shared pieces ----

// every step sits under the step bar with the same margins
const _pagePad = EdgeInsets.fromLTRB(28, 16, 28, 20);

// a step: what it says scrolls when it has to, its buttons stay in reach
// at the bottom
class _StepPage extends StatelessWidget {
  final double top;
  final CrossAxisAlignment cross;
  final List<Widget> children;
  final List<Widget> footer;
  const _StepPage({
    this.top = 16,
    this.cross = CrossAxisAlignment.stretch,
    required this.children,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // what scrolls under the bar or the buttons fades out at the
          // edge instead of being cut
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
              stops: [
                0,
                math.min(8 / r.height, 0.2),
                math.max(1 - 16 / r.height, 0.8),
                1,
              ],
            ).createShader(r),
            child: FitColumn(
              padding: _pagePad.copyWith(top: top, bottom: 16),
              crossAxisAlignment: cross,
              children: children,
            ),
          ),
        ),
        // its own node with a node for each piece: a lone button here
        // would otherwise lend its tap and words to the whole page
        Semantics(
          container: true,
          explicitChildNodes: true,
          child: Padding(
            padding: _pagePad.copyWith(top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: footer,
            ),
          ),
        ),
      ],
    );
  }
}

// big type grows less with the text size: a long word at the full scale
// would not fit the line
TextScaler _headScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);

class _Headline extends StatelessWidget {
  final String msg;
  const _Headline(this.msg);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: HaloType.serif(
          size: 30,
          weight: FontWeight.w300,
          color: HaloColors.text,
          height: 1.1,
        ),
        children: markedSpans(
          msg,
          HaloType.serif(
            size: 30,
            weight: FontWeight.w300,
            italic: true,
            color: HaloColors.amberText,
            height: 1.1,
          ),
        ),
      ),
      textScaler: _headScale(context),
    );
  }
}

Widget _lead(String msg) => Text(
  msg,
  style: HaloType.sans(size: 14, color: HaloColors.text2, height: 1.55),
);

// the amber tile a card leads with: its number or its icon
class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.amberSoft,
        border: Border.all(
          color: HaloColors.amber.withValues(alpha: 0.55),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _Card({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    // read as one: its title and its line
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 15),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          border: Border.all(color: HaloColors.line, width: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Badge(child: Icon(icon, size: 17, color: HaloColors.amber)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 1),
                  Text(
                    title,
                    style: HaloType.sans(
                      size: 14,
                      color: HaloColors.text,
                      weight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: HaloType.sans(
                      size: 13,
                      color: HaloColors.text2,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Path extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _Path({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // one button, read as its title and its line
    final card = PressScale(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 15, 14, 15),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          border: Border.all(color: HaloColors.line, width: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _Badge(child: Icon(icon, size: 17, color: HaloColors.amber)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HaloType.sans(
                      size: 14,
                      color: HaloColors.text,
                      weight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text2,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // points the way reading goes
            ExcludeSemantics(
              child: Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: Text(
                  '→',
                  style: HaloType.sans(size: 18, color: HaloColors.text2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return MergeSemantics(child: Semantics(button: true, child: card));
  }
}

// the main button of a step. a new label crossfades in
class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return _button(
      PressScale(
        scale: 0.97,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: HaloColors.amber,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: still ? 0 : 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 15,
                color: HaloColors.onAmber,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// a button with its own node, sized to itself and named by its words
Widget _button(Widget child) =>
    Semantics(container: true, button: true, child: child);

// the quiet way past a step: plain words, a full finger's height
class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextLink({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return _button(
      PressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 13,
              color: HaloColors.text2,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
