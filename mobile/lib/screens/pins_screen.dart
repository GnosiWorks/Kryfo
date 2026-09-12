// SPDX-License-Identifier: GPL-3.0-or-later
// the pins, on one page, each with its outcome spelled out. nothing new
// behind it: the app lock and the wipe pin were already here, buried in two
// settings rows nobody could read the meaning of.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lock_state.dart';
import '../theme.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/stagger_in.dart';
import 'lock_setup_screen.dart';
import 'panic_setup_screen.dart';
import '../widgets/confirm_sheet.dart';

class PinsScreen extends StatelessWidget {
  const PinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'App lock',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: AnimatedBuilder(
        animation: lockState,
        builder: (context, _) {
          final on = lockState.enabled;
          final wipe = lockState.panicEnabled;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: staggerAll([
              Text(
                'Two pins',
                style: HaloType.serif(size: 26, color: HaloColors.text),
              ),
              const SizedBox(height: 6),
              const SizedBox(height: 20),
              _PinCard(
                name: 'Your pin',
                state: on ? 'On' : 'Off',
                stateColor: on ? HaloColors.green : HaloColors.text3,
                outcome:
                    'Opens kryfo. Four digits, asked for when it comes '
                    'to the front.',
                primary: on ? 'Change pin' : 'Set a pin',
                onPrimary: () async {
                  HapticFeedback.selectionClick();
                  await Navigator.of(
                    context,
                  ).push(haloRoute(const LockSetupScreen()));
                },
                secondary: on ? 'Turn off' : null,
                onSecondary: on
                    ? () async {
                        final ok = await showConfirmSheet(
                          context,
                          title: 'Turn off the app lock?',
                          line:
                              'The pin goes, and the wipe pin with it. Anyone '
                              'holding your phone opens kryfo as you.',
                          yes: 'Turn off',
                        );
                        if (!ok) return;
                        await lockState.disablePanicPin();
                        await lockState.disable();
                      }
                    : null,
                extra: on && lockState.bioSupported
                    ? _Toggle(
                        label: 'Unlock with fingerprint',
                        on: lockState.biometric,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          lockState.setBiometric(!lockState.biometric);
                        },
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _PinCard(
                name: 'Wipe pin',
                state: !on
                    ? 'Needs a pin first'
                    : wipe
                    ? 'Set'
                    : 'Off',
                stateColor: wipe ? HaloColors.rose : HaloColors.text3,
                outcome: 'The second pin wipes everything.',
                primary: wipe ? 'Change wipe pin' : 'Set a wipe pin',
                onPrimary: on
                    ? () async {
                        HapticFeedback.selectionClick();
                        await Navigator.of(
                          context,
                        ).push(haloRoute(PanicSetupScreen()));
                      }
                    : null,
                secondary: wipe ? 'remove' : null,
                onSecondary: wipe
                    ? () async {
                        final ok = await showConfirmSheet(
                          context,
                          title: 'Remove the wipe pin?',
                          line:
                              'The lock screen keeps your pin. The wipe pin '
                              'stops doing anything.',
                          yes: 'Remove',
                        );
                        if (ok) await lockState.disablePanicPin();
                      }
                    : null,
              ),
            ]),
          );
        },
      ),
    );
  }
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
          on ? 'On' : 'Off',
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
