// six digits read out loud, for when holding two phones together is awkward.
// both sides derive the same address from the digits alone and the invite
// passes through it sealed. the code burns after a few minutes.
import 'package:flutter/material.dart';

import '../main.dart' hide live;
import '../theme.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/pair_code_panel.dart';
import '../widgets/pair_join.dart';
import '../widgets/swap.dart';
import '../l10n/l10n.dart';

class PairCodeScreen extends StatefulWidget {
  // open on the entering side: the other person read their code out
  final bool entering;
  const PairCodeScreen({super.key, this.entering = false});
  @override
  State<PairCodeScreen> createState() => _PairCodeScreenState();
}

class _PairCodeScreenState extends State<PairCodeScreen> {
  late bool _sharing = !widget.entering;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 0),
              child: Row(
                children: staggerAll([
                  IconButton(
                    tooltip: l10n.commonBack,
                    icon: Icon(
                      Icons.chevron_left,
                      color: HaloColors.text,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(l10n.pairCodePairingCode, style: HaloType.pageTitle()),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  _Tab(
                    label: l10n.pairCodeShowACode,
                    on: _sharing,
                    onTap: () => setState(() => _sharing = true),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: l10n.pairCodeEnterOne,
                    on: !_sharing,
                    onTap: () => setState(() => _sharing = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FadeSwap(
                child: KeyedSubtree(
                  key: ValueKey(_sharing),
                  child: _sharing ? const _ShareSide() : const _JoinSide(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = motionStill(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    // one node: the name, a button, chosen or not
    return Semantics(
      container: true,
      button: true,
      selected: on,
      label: label,
      child: PressScale(
        onTap: onTap,
        scale: 0.96,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: d,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: HaloColors.amber.withValues(alpha: on ? 0.14 : 0),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: on
                    ? HaloColors.amber.withValues(alpha: 0.4)
                    : HaloColors.line,
              ),
            ),
            child: AnimatedDefaultTextStyle(
              duration: d,
              curve: Curves.easeOutCubic,
              style: HaloType.mono(
                size: 11,
                color: on ? HaloColors.amber : HaloColors.text2,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── show a code ─────────

class _ShareSide extends StatelessWidget {
  const _ShareSide();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: const [PairCodePanel()],
    );
  }
}

// ───────── enter one ─────────

class _JoinSide extends StatelessWidget {
  const _JoinSide();

  @override
  Widget build(BuildContext context) {
    return PairJoin(
      // a quiet session never reaches the relays: it answers as unreachable
      // ones would
      fetch: (code) async =>
          sessionQuiet ? pairUnreached : await engine.pairCodeFetch(code),
      add: (invite) async {
        final status = await handleHaloUri(invite);
        await appState.refreshContacts();
        return status;
      },
      onAdded: (status) {
        showHaloToast(context, status);
        Navigator.of(context).pop();
      },
    );
  }
}
