// SPDX-License-Identifier: GPL-3.0-or-later
// setting up an extra pin step by step: what it does, the current pin, the
// new pin twice. the words change above the pad; the pad stays where it is.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../lock_state.dart';
import '../main.dart' show appState;
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/pin_pad.dart';
import '../widgets/press_scale.dart';
import '../wipe.dart';

enum PinFlow { wipe, decoy }

enum _Step { intro, check, choose, confirm, done }

class PinFlowScreen extends StatefulWidget {
  const PinFlowScreen({super.key, required this.flow, this.skipIntro = false});
  final PinFlow flow;
  // a change of an existing pin: they have read it all once already
  final bool skipIntro;
  @override
  State<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends State<PinFlowScreen>
    with SingleTickerProviderStateMixin {
  late _Step _step = widget.skipIntro ? _Step.check : _Step.intro;
  String _pin = '';
  String _first = '';
  String? _error;
  bool _busy = false;
  // forward or back, for the direction the next page comes in from
  bool _forward = true;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  bool get _wipe => widget.flow == PinFlow.wipe;
  Color get _tint => _wipe ? HaloColors.rose : HaloColors.amber;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _go(_Step s, {bool forward = true}) {
    setState(() {
      _forward = forward;
      _step = s;
      _pin = '';
      _error = null;
    });
  }

  Future<void> _fail(String why) async {
    HapticFeedback.heavyImpact();
    setState(() => _error = why);
    await _shake.forward(from: 0);
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
    if (_busy || _pin.length < kPinMin) return;
    setState(() => _busy = true);
    try {
      switch (_step) {
        case _Step.check:
          final r = await lockState.confirmPin(_pin);
          if (r == PinResult.panic) {
            await wipeHalo();
            return;
          }
          if (r != PinResult.normal) {
            await _fail(
              r == PinResult.throttled
                  ? l10n.lockTooManyTriesS(
                      whole(lockState.throttleLeft.inSeconds + 1),
                    )
                  : l10n.lockNotIt,
            );
            return;
          }
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
          final ok = _wipe
              ? await lockState.setupPanicPin(_pin)
              : lockState.inDecoy
              ? await lockState.setupDecoyPin(_pin)
              : await appState.setDecoyPin(_pin);
          if (!ok) {
            await _again(l10n.pinPickDifferent);
            return;
          }
          HapticFeedback.mediumImpact();
          _go(_Step.done);
        case _Step.intro:
        case _Step.done:
          break;
      }
    } catch (e) {
      await _again(l10n.flowNotSet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
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
    _Step.done => _done(),
    _ => _pad(),
  };

  Widget _intro() {
    final lines = _wipe
        ? [
            (Icons.delete_sweep_outlined, l10n.flowWipe1),
            (Icons.layers_clear_outlined, l10n.flowWipe2),
            (Icons.gavel_outlined, l10n.flowLaw),
          ]
        : [
            (Icons.inbox_outlined, l10n.flowDecoy1),
            (Icons.fingerprint, l10n.flowDecoyFinger),
            (Icons.dialpad_outlined, l10n.flowDecoyDigits),
            (Icons.notifications_off_outlined, l10n.flowDecoyShade),
            (Icons.gavel_outlined, l10n.flowLaw),
          ];
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
            _wipe
                ? Icons.local_fire_department_outlined
                : Icons.theater_comedy_outlined,
            color: _tint,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _wipe ? l10n.flowWipeTitle : l10n.flowDecoyTitle,
          style: HaloType.serif(size: 30, color: HaloColors.text),
        ),
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
      _ => _wipe ? l10n.flowWipeChoose : l10n.flowDecoyChoose,
    };
    final line = switch (_step) {
      _Step.check => l10n.flowEnterYourPinLine,
      _Step.confirm => l10n.panicSetupTheSameFourDigits,
      _ => _wipe ? l10n.pinsWipeLine : l10n.flowDecoyDigits,
    };
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
          // making a decoy takes a few seconds: the line says so
          child: AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Text(
              _busy && _step == _Step.confirm
                  ? l10n.newGroupCreating
                  : _error ?? line,
              key: ValueKey(_busy && _step == _Step.confirm),
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
        ),
        const Spacer(flex: 3),
        PinPad(
          onDigit: _onDigit,
          onBack: _back,
          onEnter: _submit,
          canEnter: _pin.length >= kPinMin,
          enabled: !_busy,
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _done() {
    final still = MediaQuery.of(context).disableAnimations;
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
          _wipe ? l10n.flowWipeDone : l10n.flowDecoyDone,
          textAlign: TextAlign.center,
          style: HaloType.serif(size: 28, color: HaloColors.text),
        ),
        const SizedBox(height: 10),
        Text(
          _wipe ? l10n.flowWipeDoneLine : l10n.flowDecoyDoneLine,
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
}
