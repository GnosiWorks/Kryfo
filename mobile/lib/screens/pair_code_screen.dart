// six digits, read out loud. for a table, a phone call, a room where holding
// two handsets together is awkward.
//
// one side shows a number, the other types it. both derive the same address
// from the digits alone and the invite passes through it sealed. the code
// burns after a few minutes because an address nobody is listening to is not
// worth leaving behind.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/motion.dart';

class PairCodeScreen extends StatefulWidget {
  const PairCodeScreen({super.key});
  @override
  State<PairCodeScreen> createState() => _PairCodeScreenState();
}

class _PairCodeScreenState extends State<PairCodeScreen> {
  bool _sharing = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'back',
                    icon: Icon(Icons.arrow_back, color: HaloColors.text2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'pairing code',
                    style: HaloType.serif(size: 22, italic: true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  _Tab(
                    label: 'show a code',
                    on: _sharing,
                    onTap: () => setState(() => _sharing = true),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'enter one',
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

class _ShareSide extends StatefulWidget {
  const _ShareSide();
  @override
  State<_ShareSide> createState() => _ShareSideState();
}

class _ShareSideState extends State<_ShareSide> {
  String? _code;
  String _status = '';
  int _left = 0;
  Timer? _tick;
  bool _busy = false;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _make() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'putting your invite in place…';
    });

    // Random.secure, because a guessable code is a code someone else can
    // stand in front of.
    final r = Random.secure();
    final code = List.generate(6, (_) => r.nextInt(10)).join();

    if (appState.myOnion.isEmpty) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'your invite is not ready yet';
        });
      }
      return;
    }
    final uri = await buildHaloUriV3(
      appState.myId,
      appState.myOnion,
      appState.fcCounter,
    );

    final res = await engine.pairCodePublish(code, uri);
    if (!mounted) return;
    if (res.startsWith('error')) {
      setState(() {
        _busy = false;
        _status = res.replaceFirst('error: ', '');
      });
      return;
    }

    setState(() {
      _busy = false;
      _code = code;
      _left = 300;
      _status = '';
    });
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        setState(() => _code = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_code == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          Text(
            'read six digits out loud and they can add you. nothing else '
            'needs to change hands.',
            style: HaloType.sans(size: 13.5, color: HaloColors.text2),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _make,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _busy ? HaloColors.surface2 : HaloColors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _busy ? 'working…' : 'make a code',
                style: HaloType.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: _busy ? HaloColors.text3 : HaloColors.onAmber,
                ),
              ),
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _status,
              style: HaloType.mono(size: 11, color: HaloColors.text3),
            ),
          ],
        ],
      );
    }

    final mm = (_left ~/ 60).toString();
    final ss = (_left % 60).toString().padLeft(2, '0');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
      children: [
        Center(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Clipboard.setData(ClipboardData(text: _code!));
              showHaloToast(context, 'code copied');
            },
            child: Text(
              '${_code!.substring(0, 3)} ${_code!.substring(3)}',
              style: HaloType.mono(
                size: 40,
                weight: FontWeight.w600,
                color: HaloColors.amber,
                letter: 0.16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BreathDot(color: HaloColors.amber, size: 6),
              const SizedBox(width: 8),
              Text(
                'burns in $mm:$ss',
                style: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'they open kryfo, tap add, choose pairing code and type these six '
          'digits. it works once and then the address is gone.',
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 12.5, color: HaloColors.text3),
        ),
      ],
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
      setState(() => _status = 'six digits');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'looking…';
    });

    // the other side may not have pressed share yet, so give it a few goes
    // rather than failing on the first empty answer.
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
        setState(() => _status = 'nothing there yet · trying again');
        await Future<void>.delayed(const Duration(seconds: 4));
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status =
          'nothing at that code. it may have burned, or they have not '
          'shared it yet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        Text(
          'type the six digits they read out.',
          style: HaloType.sans(size: 13.5, color: HaloColors.text2),
        ),
        const SizedBox(height: 20),
        TextField(
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
              _busy ? 'looking…' : 'add them',
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
