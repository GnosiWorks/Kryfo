// SPDX-License-Identifier: GPL-3.0-or-later
// the gates the app opens through, and the tor pill

part of '../main.dart';

class _OnboardingGate extends StatefulWidget {
  final Widget child;
  const _OnboardingGate({required this.child});
  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

// when the cold start's splash lets go, set once for the process: a gate
// built again for a switched session holds it to the same moment
DateTime? _splashUntil;

class _OnboardingGateState extends State<_OnboardingGate> {
  // boot is quick enough that the onion is gone before it registers. hold
  // the splash a beat on cold start so it gets seen. warm reopens skip it.
  bool _hold = false;
  // keeps the onboarding's state while it fades out over home
  var _onboardingKey = GlobalKey();
  Widget? _last;
  Widget? _leaving;

  @override
  void initState() {
    super.initState();
    if (!appState.ready) {
      appState.bootWhenWanted();
      _splashUntil ??= DateTime.now().add(const Duration(milliseconds: 2500));
    }
    final left = _splashUntil?.difference(DateTime.now());
    if (left != null && left > Duration.zero) {
      _hold = true;
      Future.delayed(left, () {
        if (mounted) setState(() => _hold = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final Widget before;
        if (appState.bootError != null) {
          before = BootFailedScreen(
            key: const ValueKey('failed'),
            error: appState.bootError!,
            onRetry: () {
              setState(() => _hold = false);
              appState.retryBoot();
            },
            onReopen: appState.bootStuck ? reopenApp : null,
            // a database that will not open stays as it is until one of
            // these is chosen, and start fresh asks twice
            onRestore: () =>
                Navigator.of(context).push(haloRoute(const RestoreScreen())),
            onStartFresh: () => unawaited(wipeHalo()),
          );
        } else if (!appState.ready || _hold || appState.firstRunAsk) {
          before = const TorBootSplash(key: ValueKey('splash'));
        } else if (appState.movedAway && !appState.movedReadOnly) {
          before = const MovedScreen(key: ValueKey('moved'));
        } else if (!appState.onboardingComplete) {
          before = OnboardingScreen(
            key: _onboardingKey,
            appState: appState,
            onComplete: () => appState.markOnboardingComplete(),
          );
        } else {
          // the onboarding fades out over home, once
          if (_last?.key == _onboardingKey) _leaving = _last;
          _last = null;
          return FadeOver(leaving: _leaving, child: widget.child);
        }
        // an onboarding gone another way may still be fading in the switcher
        if (_last?.key == _onboardingKey && before.key != _onboardingKey) {
          _onboardingKey = GlobalKey();
        }
        _last = before;
        _leaving = null;
        // the splash goes out first, then the next screen comes up: no
        // cut, and never both at once
        return AnimatedSwitcher(
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 440),
          switchInCurve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
          switchOutCurve: const Interval(0.65, 1, curve: Curves.easeIn),
          child: before,
        );
      },
    );
  }
}

// a language switch redraws everything below here from scratch, on the
// first screen: whatever was open above it is closed. the lock and the
// navigator stay, so a switch never asks for the pin again.
class _LocaleScope extends StatefulWidget {
  final Widget child;
  const _LocaleScope({required this.child});
  @override
  State<_LocaleScope> createState() => _LocaleScopeState();
}

class _LocaleScopeState extends State<_LocaleScope>
    with SingleTickerProviderStateMixin {
  // the new language comes up out of the background instead of every word
  // changing in one frame
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final _shown = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    localeRevision.addListener(_switched);
  }

  @override
  void dispose() {
    localeRevision.removeListener(_switched);
    _shown.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _switched() {
    if (lockGuard.isLocked()) {
      // under the lock nothing animates, so nothing may be left mid-pop:
      // a new navigator, home only
      renewRootNavigator();
    } else {
      rootNavKey.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() {});
    if (!reduceMotion(context)) _fade.forward(from: 0);
    unawaited(appState.languageChanged());
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: HaloColors.surface,
    child: FadeTransition(
      opacity: _shown,
      child: KeyedSubtree(
        key: ValueKey(localeRevision.value),
        child: widget.child,
      ),
    ),
  );
}

class _LockGate extends StatefulWidget {
  final Widget child;
  const _LockGate({required this.child});
  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  @override
  Widget build(BuildContext context) => LockGate(
    app: widget.child,
    lock: lockState,
    loaded: () => lockState.loaded,
    locked: () => lockState.locked,
    load: lockState.load,
    leaving: lockState.leaving,
    returned: lockState.returned,
    left: lockState.left,
    guard: lockGuard,
    quiet: () => sessionQuiet,
    pad: (_) => const LockScreen(),
    lockingUp: appState.lockingUp,
    inFront: (front) {
      appState.appInFront(front);
      // back in front with no lock to lift: kryfo is open, so the plain
      // line has said its piece
      if (front && !lockState.locked) _plainSeen();
      // a read that failed is asked again: until android answers, the app
      // keeps the plain look
      if (front && appFaceNow.value == null) unawaited(readAppFace());
    },
    localesChanged: systemLocalesChanged,
    revealed: () {
      appRevealed = true;
      homeRevealed();
      _plainSeen();
      unawaited(sayFaceChanged());
    },
  );
}

// a decoy clears the whole shade itself, and the plain line stands for
// nothing of its own
void _plainSeen() {
  if (!sessionQuiet) unawaited(clearPlainNotification());
}

class TorHalo extends StatefulWidget {
  final bool label;
  const TorHalo({super.key, this.label = false});
  @override
  State<TorHalo> createState() => TorHaloState();
}

/// rebuilds with the connection's reading (link_view.dart): on every change
/// of the app state, and at the moment it changes by time alone
class LinkViewBuilder extends StatefulWidget {
  const LinkViewBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, LinkView view) builder;
  @override
  State<LinkViewBuilder> createState() => _LinkViewBuilderState();
}

class _LinkViewBuilderState extends State<LinkViewBuilder> {
  final _clock = LinkClock();

  @override
  void initState() {
    super.initState();
    appState.addListener(_changed);
  }

  @override
  void dispose() {
    appState.removeListener(_changed);
    _clock.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final v = appState.linkView;
    _clock.arm(v.recheckAt, _changed);
    return widget.builder(context, v);
  }
}

class TorHaloState extends State<TorHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _clock = LinkClock();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    appState.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  // a few pulses each time tor starts, then still: where tor is blocked it
  // can sit in starting for minutes, and nothing here may run that long.
  // each new way automatic tries gets a few more
  bool _pulsed = false;
  int _attempt = 0;

  void _tick() {
    if (!mounted) return;
    setState(() {});
    _sync();
  }

  void _sync() {
    final v = appState.linkView;
    _clock.arm(v.recheckAt, _tick);
    // pulses only while tor is still coming up. a route up with no relay
    // through rests, and so does a bounce inside the grace
    if (!v.pulsing) {
      _pulsed = false;
      if (_c.isAnimating) _c.stop();
      return;
    }
    final a = appState.bridgeStatus.attempt;
    if (a != _attempt) {
      _attempt = a;
      if (a > 1) _pulsed = false;
    }
    if (_pulsed || _c.isAnimating) return;
    _pulsed = true;
    if (mounted && motionStill(context)) return;
    _c.repeat(count: _attempt > 1 ? 3 : 8);
  }

  // tor blocked or nothing got through: the way out is the bridges page
  void _tap() {
    final s = appState.bridgeStatus;
    if (!appState.inDecoyView && (s.exhausted || s.tryingAnother)) {
      Navigator.of(context).push(haloRoute(const BridgesScreen()));
      return;
    }
    _explain();
  }

  @override
  void dispose() {
    appState.removeListener(_sync);
    _clock.cancel();
    _c.dispose();
    super.dispose();
  }

  void _explain() {
    // capped and scrolling: on a small phone the words run taller than the
    // room above the navigation bar
    showHaloSheet(context, builder: (_) => const TorSheet());
  }

  Widget _ring(double size, Color color, double w) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: w),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // nothing to explain outside onion: no bootstrap, no circuit, no
    // descriptor
    final tappable = appState.sendMode == 'private';
    return GestureDetector(
      onTap: tappable ? _tap : null,
      behavior: HitTestBehavior.opaque,
      // the tap is on the labelled node below, one stop for a screen reader
      excludeFromSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([appState, _c]),
        builder: (context, _) {
          final v = appState.linkView;
          final dim = v.kind == LinkKind.off;
          final secured =
              v.kind == LinkKind.ready &&
              !v.held &&
              v.status == TorStatus.reachable;
          final still = motionStill(context);
          // relay does not go through tor, so tor being off never greys it.
          // one route, one colour: onion stays violet whether tor is merely
          // usable or fully published
          final accent = switch (v.kind) {
            LinkKind.relay => HaloColors.sky,
            LinkKind.off => HaloColors.text2,
            LinkKind.offline => HaloColors.warn,
            LinkKind.fast => HaloColors.greenText,
            LinkKind.ready => HaloColors.violetText,
            _ => HaloColors.warnText,
          };
          final t = _c.value;
          Widget dot(Color accent) => SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (v.pulsing)
                  Transform.scale(
                    scale: 0.5 + t,
                    child: Opacity(
                      opacity: (1 - t) * 0.7,
                      child: _ring(12, accent, 1.4),
                    ),
                  ),
                _ring(
                  12,
                  dim
                      ? HaloColors.text3.withValues(alpha: 0.4)
                      : accent.withValues(alpha: secured ? 1.0 : 0.85),
                  1.4,
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              ],
            ),
          );
          // the state changes are the most watched thing on the screen: the
          // colour slides to the new one and the words cross-fade, rather
          // than both snapping
          Widget tinted(Widget Function(Color) build) =>
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: accent),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, c, _) => build(c ?? accent),
              );
          final Widget shown;
          if (!widget.label) {
            shown = tinted(
              (c) =>
                  SizedBox(width: 20, height: 20, child: Center(child: dot(c))),
            );
          } else {
            // the header keeps room for its buttons and the id beside them:
            // the words grow with large text up to a point, take two lines,
            // and never shrink below the header's smallest text (pill_fit)
            final room = MediaQuery.sizeOf(context).width * 0.24;
            final fit = fitPill(
              text: v.text,
              short: v.shortText,
              style: HaloType.mono(size: kPillPx),
              room: room,
              userScale:
                  MediaQuery.textScalerOf(context).scale(kPillPx) / kPillPx,
              direction: Directionality.of(context),
            );
            shown = tinted(
              (c) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dot(c),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: room),
                    child: AnimatedSwitcher(
                      duration: still
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (now, before) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [...before, ?now],
                      ),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      // the words change in place within a kind and cross
                      // over between kinds
                      child: Text(
                        fit.text,
                        key: ValueKey(v.kind),
                        maxLines: 2,
                        textScaler: TextScaler.linear(fit.scale),
                        style: HaloType.mono(size: kPillPx, color: c),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // heard once per change of state, not per percent, and a tap
          // explains it
          return Semantics(
            container: true,
            liveRegion: true,
            button: tappable,
            label: v.spoken,
            onTap: tappable ? _tap : null,
            child: ExcludeSemantics(child: shown),
          );
        },
      ),
    );
  }
}

/// the sheet behind the pill: tor's route and what it means now, from the
/// same reading as the pill
class TorSheet extends StatelessWidget {
  const TorSheet({super.key});

  @override
  Widget build(BuildContext context) => LinkViewBuilder(
    builder: (context, v) {
      final detail = v.detail;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 8),
              Text(
                l10n.appTor,
                style: HaloType.serif(
                  size: 20,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 16),
              TorWarmupGraph(
                status: v.graphStatus,
                bootstrapPct: v.pct,
                hold: v.graph,
                carries: v.graphCarries,
              ),
              const SizedBox(height: 16),
              Semantics(
                container: true,
                liveRegion: true,
                label: v.spokenLine,
                child: ExcludeSemantics(
                  child: Text(
                    v.line,
                    style: HaloType.mono(size: 12, color: HaloColors.text),
                  ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 16),
                Text(
                  detail,
                  style: HaloType.sans(
                    size: 12.5,
                    color: HaloColors.text,
                  ).copyWith(height: 1.5),
                ),
                if (v.offerModes) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.appRelayAndFastModes,
                    style: HaloType.sans(size: 11, color: HaloColors.text2),
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}
