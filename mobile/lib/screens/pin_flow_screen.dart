// SPDX-License-Identifier: GPL-3.0-or-later
// setting up an extra pin step by step: what it does, the current pin, the
// new pin twice. the words change above the pad; the pad stays where it is.
// hidden chats go on from there: the forget page, the vault made, the chats
// to hide, a backup that holds them.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../lock_state.dart';
import '../main.dart' show appState, session;
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/pin_pad.dart';
import '../widgets/press_scale.dart';
import '../wipe.dart';
import 'backup_screen.dart';
import 'hide_picker.dart';

enum PinFlow { wipe, decoy, vault }

enum _Step { intro, check, choose, confirm, forget, making, pick, backup, done }

// what App lock and its flows reach of the app: the app's own, or stand-ins
// in the tests
class PinsHost {
  const PinsHost();

  Listenable get changes => appState;
  bool get hasDecoy => appState.hasDecoy;
  Future<bool> setDecoyPin(String pin) => appState.setDecoyPin(pin);
  Future<void> removeDecoy() => appState.removeDecoy();
  Future<bool> createVault(String pin) => appState.createVault(pin);
  Future<int> hideChats({
    List<String> people = const [],
    List<String> groups = const [],
  }) => appState.hideChats(people: people, groups: groups);
  Future<void> vaultSetupDone() => appState.vaultSetupDone();
  Future<void> removeVault() => appState.removeVault();
  Future<void> destroyVault() => appState.destroyVault();

  // what can be hidden: the groups and chats on show that are not hidden
  // already. rooms, requests and blocked people stay where they are
  List<HideChoice> hideable() => [
    for (final g in appState.groups)
      if (g.expiresAt == null && !session.isHidden(g.groupId))
        HideChoice(
          id: g.groupId,
          name: g.name,
          group: true,
          members: g.memberCount,
        ),
    for (final c in appState.contacts)
      if (!c.blocked && !session.isHidden(c.haloId))
        HideChoice(
          id: c.haloId,
          name: c.nickname ?? c.haloId,
          avatar: c.avatar,
        ),
  ];

  Future<void> backup(BuildContext context) =>
      Navigator.of(context).push(haloRoute(const BackupScreen()));
}

class PinFlowScreen extends StatefulWidget {
  const PinFlowScreen({
    super.key,
    required this.flow,
    this.skipIntro = false,
    this.lock,
    this.host = const PinsHost(),
  });
  final PinFlow flow;
  // a change of an existing pin: they have read it all once already
  final bool skipIntro;
  // the app's own lock when null
  final LockState? lock;
  final PinsHost host;
  @override
  State<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends State<PinFlowScreen>
    with SingleTickerProviderStateMixin {
  late _Step _step = widget.skipIntro ? _Step.check : _Step.intro;
  String _pin = '';
  String _first = '';
  // the hidden chats pin being changed, as the check took it
  String _old = '';
  // the forget page was read: a pin in use sends them back to choosing only
  bool _understood = false;
  String? _error;
  bool _busy = false;
  // forward or back, for the direction the next page comes in from
  bool _forward = true;
  late final AnimationController _shake;

  LockState get _lock => widget.lock ?? lockState;
  bool get _wipe => widget.flow == PinFlow.wipe;
  bool get _vault => widget.flow == PinFlow.vault;
  // a new pin for the hidden chats already there, from inside them
  bool get _changing => _vault && widget.skipIntro;
  Color get _tint => _wipe
      ? HaloColors.rose
      : _vault
      ? HaloColors.violet
      : HaloColors.amber;
  // a hidden chats pin takes six digits. the pin that lets them in takes
  // what any pin does
  int get _min => _vault && (_step == _Step.choose || _step == _Step.confirm)
      ? kVaultPinMin
      : kPinMin;
  bool get _still => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    // the new vault's key goes however the flow ends
    if (_vault && !widget.skipIntro) unawaited(widget.host.vaultSetupDone());
    super.dispose();
  }

  void _go(_Step s, {bool forward = true}) {
    setState(() {
      _forward = forward;
      _step = s;
      _pin = '';
      _error = null;
    });
    if (s == _Step.done && _vault && !widget.skipIntro) {
      unawaited(widget.host.vaultSetupDone());
    }
  }

  Future<void> _fail(String why) async {
    HapticFeedback.heavyImpact();
    setState(() => _error = why);
    if (!_still) await _shake.forward(from: 0);
    if (mounted) setState(() => _pin = '');
  }

  // the new pin did not take: back to choosing it, saying why
  Future<void> _again(String why) async {
    await _fail(why);
    if (!mounted) return;
    _go(_Step.choose, forward: false);
    setState(() => _error = why);
  }

  void _onDigit(String d) {
    if (_busy || _pin.length >= kPinMax) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_busy || _pin.length < _min) return;
    setState(() => _busy = true);
    try {
      switch (_step) {
        case _Step.check:
          final r = await _lock.confirmPin(_pin, changesVault: _changing);
          if (r == PinResult.panic) {
            await wipeHalo();
            return;
          }
          if (r != PinResult.normal) {
            await _fail(
              r == PinResult.throttled
                  ? l10n.lockTooManyTriesS(
                      whole(_lock.throttleLeft.inSeconds + 1),
                    )
                  : l10n.lockNotIt,
            );
            return;
          }
          if (_changing) _old = _pin;
          HapticFeedback.selectionClick();
          _go(_Step.choose);
        case _Step.choose:
          _first = _pin;
          HapticFeedback.selectionClick();
          _go(_Step.confirm);
        case _Step.confirm:
          if (_pin != _first) {
            await _again(l10n.panicSetupThoseWereDifferentFrom);
            return;
          }
          if (_vault) {
            await _vaultPin();
            return;
          }
          final ok = _wipe
              ? await _lock.setupPanicPin(_pin)
              : _lock.inDecoy
              ? await _lock.setupDecoyPin(_pin)
              : await widget.host.setDecoyPin(_pin);
          if (!ok) {
            await _again(l10n.pinPickDifferent);
            return;
          }
          HapticFeedback.mediumImpact();
          _go(_Step.done);
        case _Step.intro:
        case _Step.forget:
        case _Step.making:
        case _Step.pick:
        case _Step.backup:
        case _Step.done:
          break;
      }
    } catch (e) {
      await _again(l10n.flowNotSet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // the hidden chats pin, confirmed. a change seals the same key under it;
  // a setup says what forgetting it means, once, before anything is made
  Future<void> _vaultPin() async {
    if (_changing) {
      if (!await _lock.rewrapVaultPin(_old, _first)) {
        await _again(l10n.pinPickDifferent);
        return;
      }
      _old = '';
      _first = '';
      HapticFeedback.mediumImpact();
      _go(_Step.done);
      return;
    }
    if (_understood) {
      await _make();
      return;
    }
    HapticFeedback.mediumImpact();
    _go(_Step.forget);
  }

  // any old vault goes and the new one is made. a pin already in use shows
  // only here, once the old one is gone: back to choosing another
  Future<void> _make() async {
    _go(_Step.making);
    setState(() => _busy = true);
    try {
      final ok = await widget.host.createVault(_first);
      if (!mounted) return;
      if (!ok) {
        await _rechoose(l10n.pinPickDifferent);
        return;
      }
      _first = '';
      HapticFeedback.lightImpact();
      _go(_Step.pick);
    } catch (e) {
      if (mounted) await _rechoose(l10n.flowNotSet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rechoose(String why) async {
    HapticFeedback.heavyImpact();
    _go(_Step.choose, forward: false);
    setState(() => _error = why);
    if (!_still) await _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // a new page comes in from the side reading goes towards
    final from = (_forward ? 1.0 : -1.0) * (rtl ? -1 : 1);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: HaloColors.ink,
        appBar: AppBar(
          backgroundColor: HaloColors.ink,
          elevation: 0,
          // the page scrolls under it on a small screen: no tint comes in
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: HaloColors.text2),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) {
              final entering = child.key == ValueKey(_step);
              return FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset((entering ? 0.18 : -0.18) * from, 0),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(key: ValueKey(_step), child: _page()),
          ),
        ),
      ),
    );
  }

  Widget _page() => switch (_step) {
    _Step.intro => _intro(),
    _Step.forget => _forget(),
    _Step.making => _making(),
    _Step.pick => HidePicker(
      chats: widget.host.hideable(),
      line: l10n.flowVaultPickLine,
      onBusy: (b) => setState(() => _busy = b),
      onHide: (people, groups) =>
          widget.host.hideChats(people: people, groups: groups),
      // nothing hidden yet: a backup would hold nothing of it
      onDone: (n) => _go(n > 0 ? _Step.backup : _Step.done),
    ),
    _Step.backup => _backupOffer(),
    _Step.done => _done(),
    _ => _pad(),
  };

  Widget _intro() {
    final lines = switch (widget.flow) {
      PinFlow.wipe => [
        (Icons.delete_sweep_outlined, l10n.flowWipe1),
        (Icons.layers_clear_outlined, l10n.flowWipe2),
        (Icons.gavel_outlined, l10n.flowLaw),
      ],
      PinFlow.decoy => [
        (Icons.inbox_outlined, l10n.flowDecoy1),
        (Icons.fingerprint, l10n.flowDecoyFinger),
        (Icons.dialpad_outlined, l10n.flowDecoyDigits),
        (Icons.notifications_off_outlined, l10n.flowDecoyShade),
        (Icons.gavel_outlined, l10n.flowLaw),
      ],
      PinFlow.vault => [
        (Icons.visibility_off_outlined, l10n.flowVault1),
        (Icons.notifications_off_outlined, l10n.flowVault2),
        (Icons.fingerprint, l10n.flowVaultFinger),
        (Icons.dialpad_outlined, l10n.flowVaultDigits),
        (Icons.autorenew_rounded, l10n.flowVaultReplace),
        (Icons.gavel_outlined, l10n.flowLaw),
      ],
    };
    return FitColumn(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _tint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            switch (widget.flow) {
              PinFlow.wipe => Icons.local_fire_department_outlined,
              PinFlow.decoy => Icons.theater_comedy_outlined,
              PinFlow.vault => Icons.visibility_off_outlined,
            },
            color: _tint,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        Text(switch (widget.flow) {
          PinFlow.wipe => l10n.flowWipeTitle,
          PinFlow.decoy => l10n.flowDecoyTitle,
          PinFlow.vault => l10n.flowVaultTitle,
        }, style: HaloType.serif(size: 30, color: HaloColors.text)),
        const SizedBox(height: 18),
        for (final (icon, line) in lines) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: _tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line,
                  style: HaloType.sans(
                    size: 14,
                    color: HaloColors.text,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        const Spacer(),
        const SizedBox(height: 12),
        _button(l10n.commonContinue, () {
          HapticFeedback.selectionClick();
          _go(_Step.check);
        }),
      ],
    );
  }

  Widget _pad() {
    final title = switch (_step) {
      _Step.check => l10n.flowEnterYourPin,
      _Step.confirm => l10n.panicSetupOnceMore,
      _ => switch (widget.flow) {
        PinFlow.wipe => l10n.flowWipeChoose,
        PinFlow.decoy => l10n.flowDecoyChoose,
        PinFlow.vault => l10n.flowVaultChoose,
      },
    };
    final line = switch (_step) {
      _Step.check =>
        _changing ? l10n.flowEnterHiddenPinLine : l10n.flowEnterYourPinLine,
      _Step.confirm => l10n.panicSetupTheSameFourDigits,
      _ => switch (widget.flow) {
        PinFlow.wipe => l10n.pinsWipeLine,
        PinFlow.decoy => l10n.flowDecoyDigits,
        PinFlow.vault => l10n.flowVaultChooseLine,
      },
    };
    // making a decoy takes a few seconds: the line says so. hidden chats are
    // made on a page of their own
    final making = _busy && _step == _Step.confirm && !_vault;
    return FitColumn(
      children: [
        const Spacer(flex: 2),
        Text(
          title,
          textAlign: TextAlign.center,
          style: HaloType.serif(size: 30, color: HaloColors.text),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AnimatedSwitcher(
            duration: _still
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Text(
              making ? l10n.newGroupCreating : _error ?? line,
              key: ValueKey(making),
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13,
                color: _error != null ? HaloColors.rose : HaloColors.text2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        PinDots(
          filled: _pin.length,
          color: _step == _Step.check ? HaloColors.amber : _tint,
          wrong: _error != null,
          shake: _shake,
          min: _min,
        ),
        const Spacer(flex: 3),
        PinPad(
          onDigit: _onDigit,
          onBack: _back,
          onEnter: _submit,
          canEnter: _pin.length >= _min,
          enabled: !_busy,
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  // what forgetting the hidden chats pin means, large, with one way on
  Widget _forget() => FitColumn(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
    children: [
      const Spacer(flex: 2),
      _Badge(icon: Icons.key_outlined, tint: HaloColors.rose),
      const SizedBox(height: 22),
      Text(
        l10n.flowVaultForgetTitle,
        textAlign: TextAlign.center,
        style: HaloType.serif(size: 30, color: HaloColors.text),
      ),
      const SizedBox(height: 16),
      Text(
        l10n.flowVaultForget,
        textAlign: TextAlign.center,
        style: HaloType.serif(size: 21, color: HaloColors.text, height: 1.4),
      ),
      const Spacer(flex: 3),
      _button(l10n.flowVaultForgetOk, () {
        if (_busy) return;
        _understood = true;
        unawaited(_make());
      }),
    ],
  );

  Widget _making() => FitColumn(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    children: [
      const Spacer(flex: 2),
      _Working(tint: _tint),
      const SizedBox(height: 22),
      Text(
        l10n.newGroupCreating,
        textAlign: TextAlign.center,
        style: HaloType.serif(size: 24, color: HaloColors.text),
      ),
      const Spacer(flex: 3),
    ],
  );

  // the backup comes after the picking, so it holds the chats just hidden
  Widget _backupOffer() => FitColumn(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    children: [
      const Spacer(flex: 2),
      _Badge(icon: Icons.save_alt_rounded, tint: HaloColors.amber),
      const SizedBox(height: 22),
      Text(
        l10n.flowVaultBackupTitle,
        textAlign: TextAlign.center,
        style: HaloType.serif(size: 28, color: HaloColors.text),
      ),
      const SizedBox(height: 10),
      Text(
        l10n.flowVaultBackupLine,
        textAlign: TextAlign.center,
        style: HaloType.sans(size: 14, color: HaloColors.text2, height: 1.45),
      ),
      const Spacer(flex: 3),
      _button(l10n.flowVaultBackupNow, () async {
        if (_busy) return;
        _busy = true;
        try {
          await widget.host.backup(context);
        } finally {
          _busy = false;
        }
        if (mounted) _go(_Step.done);
      }),
      const SizedBox(height: 6),
      _quiet(l10n.flowVaultNotNow, () => _go(_Step.done)),
    ],
  );

  Widget _done() {
    final still = _still;
    final (title, line) = switch (widget.flow) {
      PinFlow.wipe => (l10n.flowWipeDone, l10n.flowWipeDoneLine),
      PinFlow.decoy => (l10n.flowDecoyDone, l10n.flowDecoyDoneLine),
      PinFlow.vault when _changing => (
        l10n.flowVaultChanged,
        l10n.flowVaultChangedLine,
      ),
      PinFlow.vault => (l10n.flowVaultDone, l10n.flowVaultDoneLine),
    };
    return FitColumn(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      children: [
        const Spacer(flex: 2),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: still ? 1 : 0.6, end: 1),
          duration: still ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: _tint, size: 36),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: HaloType.serif(size: 28, color: HaloColors.text),
        ),
        const SizedBox(height: 10),
        Text(
          line,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 14, color: HaloColors.text2, height: 1.45),
        ),
        const Spacer(flex: 3),
        _button(l10n.commonDone, () => Navigator.of(context).pop(true)),
      ],
    );
  }

  Widget _button(String label, VoidCallback onTap) => Semantics(
    button: true,
    child: PressScale(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HaloColors.amber,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: HaloType.sans(
            size: 15,
            weight: FontWeight.w600,
            color: HaloColors.onAmber,
          ),
        ),
      ),
    ),
  );

  Widget _quiet(String label, VoidCallback onTap) => Semantics(
    button: true,
    child: PressScale(
      onTap: onTap,
      child: Container(
        height: 46,
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          label,
          style: HaloType.sans(size: 14, color: HaloColors.text2),
        ),
      ),
    ),
  );
}

// an icon in a soft round of its colour, heading a page
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.tint});
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      color: tint.withValues(alpha: 0.14),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: tint, size: 34),
  );
}

// an arc going round the hidden chats glyph while the vault is made. still
// with reduced motion: the words say it is working
class _Working extends StatefulWidget {
  const _Working({required this.tint});
  final Color tint;

  @override
  State<_Working> createState() => _WorkingState();
}

class _WorkingState extends State<_Working>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    height: 88,
    child: Stack(
      alignment: Alignment.center,
      children: [
        _Badge(icon: Icons.visibility_off_outlined, tint: widget.tint),
        RotationTransition(
          turns: _turn,
          child: CustomPaint(
            size: const Size.square(88),
            painter: _Arc(widget.tint, HaloColors.line),
          ),
        ),
      ],
    ),
  );
}

class _Arc extends CustomPainter {
  _Arc(this.tint, this.track);
  final Color tint;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 0.55, false, p..color = tint);
  }

  @override
  bool shouldRepaint(_Arc old) => old.tint != tint || old.track != track;
}
