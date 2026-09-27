// SPDX-License-Identifier: GPL-3.0-or-later
// the pins on one page, each with its outcome spelled out. in a decoy
// session the page works on the decoy's own pins and shows what a fresh
// install would. hidden chats read "Set up" everywhere but inside them, so
// the page never says whether there are any.
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../lock_state.dart';
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import 'hide_picker.dart';
import 'lock_setup_screen.dart';
import 'pin_flow_screen.dart';
import '../widgets/confirm_sheet.dart';
import '../l10n/l10n.dart';

class PinsScreen extends StatefulWidget {
  const PinsScreen({super.key, this.lock, this.host = const PinsHost()});
  // the app's own lock when null
  final LockState? lock;
  final PinsHost host;
  @override
  State<PinsScreen> createState() => _PinsScreenState();
}

class _PinsScreenState extends State<PinsScreen> {
  // closed until asked for: most people only ever need the first card
  bool _open = false;

  LockState get _lock => widget.lock ?? lockState;
  PinsHost get _host => widget.host;

  // the decoy row, as this session should show it
  bool get _decoyOn => _lock.inDecoy ? _lock.decoyPinOn : _host.hasDecoy;

  Future<void> _turnOff() async {
    // hidden chats need the lock: they come back to the chat list first
    if (_lock.inVault) {
      final remove = await showConfirmSheet(
        context,
        title: l10n.pinsTurnOffTheApp,
        line: l10n.pinsTurnOffHiddenFirst,
        yes: l10n.pinsRemoveHiddenChats,
        rose: false,
      );
      if (remove) await _removeHidden();
      return;
    }
    final decoy = !_lock.inDecoy && _host.hasDecoy;
    final ok = await showConfirmSheet(
      context,
      title: l10n.pinsTurnOffTheApp,
      line: decoy ? l10n.pinsTurnOffWithDecoy : l10n.pinsThePinGoesAnd,
      yes: l10n.pinsTurnOff,
    );
    if (!ok) return;
    if (decoy) await _host.removeDecoy();
    // any hidden chats go with the lock, and the line above reads the same
    // whether there are any. a turn off in the decoy deletes nothing
    if (!_lock.inDecoy) {
      try {
        await _host.destroyVault();
      } catch (e) {
        // its entry went first: no pin opens what is left, and the next
        // setup clears it
        dlog('lock: hidden chats not all gone (${e.runtimeType})');
      }
    }
    await _lock.disablePanicPin();
    await _lock.disable();
  }

  Future<void> _flow(PinFlow f, {bool change = false}) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      haloRoute(
        PinFlowScreen(flow: f, skipIntro: change, lock: _lock, host: _host),
      ),
    );
  }

  Future<void> _wipeRow() async {
    if (!_lock.panicEnabled) return _flow(PinFlow.wipe);
    final r = await showChangeOrRemoveSheet(
      context,
      title: l10n.pinsWipePin,
      line: l10n.pinsWipeLine,
      change: l10n.pinsChangeWipePin,
      remove: l10n.pinsRemove,
    );
    if (!mounted || r == null) return;
    if (r == 'change') return _flow(PinFlow.wipe, change: true);
    final ok = await showConfirmSheet(
      context,
      title: l10n.pinsRemoveTheWipePin,
      line: l10n.pinsTheLockScreenKeeps,
      yes: l10n.commonRemove,
    );
    if (ok) await _lock.disablePanicPin();
  }

  Future<void> _decoyRow() async {
    if (!_decoyOn) return _flow(PinFlow.decoy);
    final r = await showChangeOrRemoveSheet(
      context,
      title: l10n.pinsDecoyPin,
      line: l10n.pinsDecoyLine,
      change: l10n.pinsChangeDecoyPin,
      remove: l10n.pinsRemove,
    );
    if (!mounted || r == null) return;
    if (r == 'change') return _flow(PinFlow.decoy, change: true);
    final ok = await showConfirmSheet(
      context,
      title: l10n.pinsRemoveTheDecoyPin,
      line: l10n.pinsTheDecoyGoes,
      yes: l10n.commonRemove,
    );
    if (!ok) return;
    _lock.inDecoy
        ? await _lock.clearInnerDecoyPin()
        : await _host.removeDecoy();
  }

  // outside the vault the row always leads to setup, which replaces any
  // hidden chats there are. inside it, the hidden chats' own choices
  Future<void> _hiddenRow() async {
    if (!_lock.inVault) return _flow(PinFlow.vault);
    final r = await showChangeOrRemoveSheet(
      context,
      title: l10n.pinsHiddenChats,
      line: l10n.pinsHiddenLine,
      change: l10n.pinsChangeHiddenPin,
      more: l10n.pinsHideMoreChats,
      remove: l10n.pinsRemoveHiddenChats,
    );
    if (!mounted || r == null) return;
    if (r == 'change') return _flow(PinFlow.vault, change: true);
    if (r == 'more') {
      HapticFeedback.selectionClick();
      await Navigator.of(context).push(
        haloRoute(
          HidePickerScreen(
            chats: _host.hideable(),
            onHide: (people, groups) =>
                _host.hideChats(people: people, groups: groups),
          ),
        ),
      );
      return;
    }
    final ok = await showConfirmSheet(
      context,
      title: l10n.pinsRemoveHiddenTitle,
      line: l10n.pinsRemoveHiddenLine,
      yes: l10n.pinsRemoveHiddenChats,
    );
    if (ok) await _removeHidden();
  }

  // every hidden chat back in the chat list, and the pin opens nothing
  Future<void> _removeHidden() async {
    HapticFeedback.mediumImpact();
    await _host.removeVault();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.pinsAppLock,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_lock, _host.changes]),
        builder: (context, _) {
          final on = _lock.lockOn;
          final wipe = _lock.panicEnabled;
          final decoy = _decoyOn;
          final vault = _lock.inVault;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: staggerAll([
              _PinCard(
                name: l10n.pinsYourPin,
                state: on ? l10n.commonOn : l10n.commonOff,
                stateColor: on ? HaloColors.green : HaloColors.text3,
                outcome: l10n.pinsOpensKryfoFourDigits,
                primary: on ? l10n.pinsChangePin : l10n.pinsSetAPin,
                onPrimary: () async {
                  HapticFeedback.selectionClick();
                  await Navigator.of(
                    context,
                  ).push(haloRoute(const LockSetupScreen()));
                },
                secondary: on ? l10n.pinsTurnOff : null,
                onSecondary: on ? _turnOff : null,
                extra: on && _lock.bioSupported
                    ? _Toggle(
                        label: l10n.pinsUnlockWithFingerprint,
                        on: _lock.biometric,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _lock.setBiometric(!_lock.biometric);
                        },
                      )
                    : null,
              ),
              const SizedBox(height: 22),
              _Advanced(
                open: _open,
                onToggle: () {
                  HapticFeedback.selectionClick();
                  setState(() => _open = !_open);
                },
                children: [
                  _ExtraRow(
                    icon: Icons.local_fire_department_outlined,
                    tint: HaloColors.rose,
                    name: l10n.pinsWipePin,
                    line: l10n.pinsWipeLine,
                    state: !on
                        ? l10n.pinsNeedsAPinFirst
                        : wipe
                        ? l10n.pinsSet
                        : l10n.commonOff,
                    stateColor: on && wipe ? HaloColors.rose : HaloColors.text3,
                    onTap: on ? _wipeRow : null,
                  ),
                  _ExtraRow(
                    icon: Icons.theater_comedy_outlined,
                    tint: HaloColors.amber,
                    name: l10n.pinsDecoyPin,
                    line: l10n.pinsDecoyLine,
                    state: !on
                        ? l10n.pinsNeedsAPinFirst
                        : decoy
                        ? l10n.pinsSet
                        : l10n.commonOff,
                    stateColor: on && decoy
                        ? HaloColors.amber
                        : HaloColors.text3,
                    onTap: on ? _decoyRow : null,
                  ),
                  _ExtraRow(
                    icon: Icons.visibility_off_outlined,
                    tint: HaloColors.violet,
                    name: l10n.pinsHiddenChats,
                    line: l10n.pinsHiddenLine,
                    state: !on
                        ? l10n.pinsNeedsAPinFirst
                        : vault
                        ? l10n.pinsSet
                        : l10n.pinsSetUp,
                    stateColor: on && vault
                        ? HaloColors.violet
                        : HaloColors.text3,
                    onTap: on ? _hiddenRow : null,
                  ),
                  _HowRow(onTap: () => _showHow(context)),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }
}

// a header that opens to the rows under it. the rows grow in with the
// height; with reduced motion they are simply there
class _Advanced extends StatelessWidget {
  const _Advanced({
    required this.open,
    required this.onToggle,
    required this.children,
  });
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final d = still ? Duration.zero : const Duration(milliseconds: 260);
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: HaloColors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.pinsAdvanced,
                            style: HaloType.sans(
                              size: 15,
                              weight: FontWeight.w600,
                              color: HaloColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.pinsAdvancedLine,
                            style: HaloType.sans(
                              size: 12.5,
                              color: HaloColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: d,
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: HaloColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: d,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Column(
                    children: [
                      Container(height: 0.5, color: HaloColors.line),
                      ...children,
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.icon,
    required this.tint,
    required this.name,
    required this.line,
    required this.state,
    required this.stateColor,
    required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String name;
  final String line;
  final String state;
  final Color stateColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: PressScale(
        onTap: onTap,
        scale: 0.98,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: HaloType.sans(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        Text(
                          state,
                          style: HaloType.mono(
                            size: 10,
                            color: stateColor,
                            weight: FontWeight.w600,
                            letter: 0.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      line,
                      style: HaloType.sans(
                        size: 12.5,
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
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  const _HowRow({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 17, color: HaloColors.amber),
            const SizedBox(width: 8),
            Text(
              l10n.pinsHowThisWorks,
              style: HaloType.sans(size: 13.5, color: HaloColors.amber),
            ),
          ],
        ),
      ),
    ),
  );
}

// what the extra pins do, what they do not, and the law
void _showHow(BuildContext context) {
  HapticFeedback.selectionClick();
  showHaloSheet<void>(
    context,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              l10n.pinsHowThisWorks,
              style: HaloType.serif(size: 22, color: HaloColors.text),
            ),
            const SizedBox(height: 16),
            for (final (icon, tint, line) in [
              (
                Icons.local_fire_department_outlined,
                HaloColors.rose,
                l10n.howWipe,
              ),
              (Icons.theater_comedy_outlined, HaloColors.amber, l10n.howDecoy),
              (Icons.visibility_off_outlined, HaloColors.violet, l10n.howVault),
              (Icons.fingerprint, HaloColors.amber, l10n.flowDecoyFinger),
              (Icons.dialpad_outlined, HaloColors.amber, l10n.flowDecoyDigits),
              (Icons.gavel_outlined, HaloColors.text2, l10n.flowLaw),
            ]) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(icon, size: 18, color: tint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      line,
                      style: HaloType.sans(
                        size: 13.5,
                        color: HaloColors.text,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PinCard extends StatelessWidget {
  final String name;
  final String state;
  final Color stateColor;
  final String outcome;
  final String primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final Widget? extra;
  const _PinCard({
    required this.name,
    required this.state,
    required this.stateColor,
    required this.outcome,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final can = onPrimary != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: HaloType.serif(size: 20, color: HaloColors.text),
                ),
              ),
              Text(
                state,
                style: HaloType.mono(
                  size: 10,
                  color: stateColor,
                  weight: FontWeight.w600,
                  letter: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            outcome,
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
          if (extra != null) ...[const SizedBox(height: 12), extra!],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPrimary,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: can ? HaloColors.amber : HaloColors.surface3,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      primary,
                      style: HaloType.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: can ? HaloColors.onAmber : HaloColors.text3,
                      ),
                    ),
                  ),
                ),
              ),
              if (secondary != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onSecondary,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HaloColors.line),
                    ),
                    child: Text(
                      secondary!,
                      style: HaloType.sans(size: 13, color: HaloColors.rose),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Toggle({required this.label, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      children: [
        Icon(Icons.fingerprint, size: 18, color: HaloColors.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: HaloType.sans(size: 13.5, color: HaloColors.text),
          ),
        ),
        Text(
          on ? l10n.commonOn : l10n.commonOff,
          style: HaloType.mono(
            size: 10.5,
            color: on ? HaloColors.green : HaloColors.text3,
            weight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
