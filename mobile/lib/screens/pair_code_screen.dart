// six digits read out loud, for when holding two phones together is awkward.
// both sides derive the same address from the digits alone and the invite
// passes through it sealed. the code burns after a few minutes.
import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/pair_code_panel.dart';
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
                    icon: Icon(Icons.arrow_back, color: HaloColors.text2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    l10n.pairCodePairingCode,
                    style: HaloType.serif(size: 22, italic: true),
                  ),
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
            Expanded(child: _sharing ? const _ShareSide() : const _JoinSide()),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? HaloColors.amber.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on
                ? HaloColors.amber.withValues(alpha: 0.4)
                : HaloColors.line,
          ),
        ),
        child: Text(
          label,
          style: HaloType.mono(
            size: 11,
            color: on ? HaloColors.amber : HaloColors.text3,
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

class _JoinSide extends StatefulWidget {
  const _JoinSide();
  @override
  State<_JoinSide> createState() => _JoinSideState();
}

class _JoinSideState extends State<_JoinSide> {
  final _ctrl = TextEditingController();
  String _status = '';
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _ctrl.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _status = l10n.pairCodeSixDigits);
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.pairCodeLooking;
    });

    // the other side may not have pressed share yet, so give it a few goes
    for (var attempt = 0; attempt < 3; attempt++) {
      final res = await engine.pairCodeFetch(code);
      if (!mounted) return;
      if (res.startsWith('kryfo://')) {
        final status = await handleHaloUri(res);
        await appState.refreshContacts();
        if (!mounted) return;
        setState(() => _busy = false);
        showHaloToast(context, status);
        Navigator.of(context).pop();
        return;
      }
      if (res.startsWith('error')) {
        setState(() {
          _busy = false;
          _status = res.replaceFirst('error: ', '');
        });
        return;
      }
      if (attempt < 2) {
        setState(() => _status = l10n.pairCodeNothingThereYetTrying);
        await Future<void>.delayed(const Duration(seconds: 4));
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = l10n.pairCodeNothingAtThatCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        Text(
          l10n.pairCodeTypeTheSixDigits,
          style: HaloType.sans(size: 13.5, color: HaloColors.text2),
        ),
        const SizedBox(height: 20),
        TextField(
          textDirection: TextDirection.ltr,
          controller: _ctrl,
          keyboardType: TextInputType.number,
          maxLength: 7,
          textAlign: TextAlign.center,
          style: HaloType.mono(
            size: 28,
            weight: FontWeight.w600,
            color: HaloColors.text,
            letter: 0.14,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: HaloType.mono(size: 28, color: HaloColors.text3),
            filled: true,
            fillColor: HaloColors.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HaloColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HaloColors.line),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _busy ? null : _join,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _busy ? HaloColors.surface2 : HaloColors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _busy ? l10n.pairCodeLooking : l10n.pairCodeAddThem,
              style: HaloType.mono(
                size: 12,
                weight: FontWeight.w600,
                color: _busy ? HaloColors.text3 : HaloColors.onAmber,
              ),
            ),
          ),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _status,
            style: HaloType.mono(size: 11, color: HaloColors.text3),
          ),
        ],
      ],
    );
  }
}
