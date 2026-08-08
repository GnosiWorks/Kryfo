// SPDX-License-Identifier: GPL-3.0-or-later
// bridges. a direct tor connection is recognisable, and in the places where
// kryfo matters most that is enough to get it blocked. a bridge is an entry
// point that is not published anywhere, reached through obfs4, which makes
// the traffic look like nothing in particular.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/motion.dart';

class BridgesScreen extends StatefulWidget {
  const BridgesScreen({super.key});

  @override
  State<BridgesScreen> createState() => _BridgesScreenState();
}

class _BridgesScreenState extends State<BridgesScreen> {
  late final TextEditingController _ctrl;
  late bool _on;
  bool _busy = false;
  String? _result;
  bool _asking = false;
  bool _reconnecting = false;
  int _elapsed = 0;
  Timer? _tick;
  String? _captcha;
  String? _challenge;
  String? _askError;
  final _answer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: appState.bridgeLines);
    _on = appState.bridgesOn;
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ctrl.dispose();
    _answer.dispose();
    super.dispose();
  }

  int get _lineCount =>
      _ctrl.text.split('\n').where((l) => l.trim().isNotEmpty).length;

  // ask bridges.torproject.org for a fresh set. this is plain https, not tor -
  // tor being unreachable is the whole reason someone is on this screen.
  Future<void> _request() async {
    setState(() {
      _asking = true;
      _captcha = null;
      _challenge = null;
      _askError = null;
    });
    final r = await engine.moatFetch();
    if (!mounted) return;
    if (!r.startsWith('ok|')) {
      setState(() {
        _asking = false;
        _askError = r.replaceFirst('error: ', '');
      });
      return;
    }
    final parts = r.substring(3).split('|');
    setState(() {
      _asking = false;
      _captcha = parts[0];
      _challenge = parts.length > 1 ? parts[1] : null;
      _answer.clear();
    });
  }

  Future<void> _sendAnswer() async {
    final ch = _challenge;
    if (ch == null || _answer.text.trim().isEmpty) return;
    setState(() {
      _asking = true;
      _askError = null;
    });
    final r = await engine.moatSolve(ch, _answer.text.trim());
    if (!mounted) return;
    if (r == 'wrong') {
      // a wrong or stale captcha is a normal outcome, not a failure. fetch a
      // new one rather than making them tap again.
      setState(() => _askError = 'that was not it. here is another.');
      await _request();
      return;
    }
    if (!r.startsWith('ok|')) {
      setState(() {
        _asking = false;
        _askError = r.replaceFirst('error: ', '');
      });
      return;
    }
    final lines = r.substring(3);
    setState(() {
      _asking = false;
      _captcha = null;
      _challenge = null;
      _on = true;
      _ctrl.text = _ctrl.text.trim().isEmpty
          ? lines
          : '${_ctrl.text.trim()}\n$lines';
    });
    HapticFeedback.mediumImpact();
    if (mounted) {
      showHaloToast(context, 'got bridges · save to use them');
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final lines = _ctrl.text.trim();
    final r = await appState.applyBridges(lines, _on && lines.isNotEmpty);
    // tor reads its config once, so a change means a restart. that costs a
    // fresh bootstrap, worth saying rather than leaving someone on a spinner.
    engine.restartTor();
    if (!mounted) return;
    setState(() {
      _result = r;
      _reconnecting = true;
      _elapsed = 0;
    });
    // a dead button for ninety seconds looks broken. count, and stop when
    // tor can actually carry traffic again.
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsed++);
      if (appState.torReady || _elapsed > 240) {
        t.cancel();
        setState(() {
          _reconnecting = false;
          _busy = false;
        });
        if (appState.torReady) {
          HapticFeedback.mediumImpact();
          showHaloToast(context, 'connected');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _lineCount;
    final live = _on && n > 0;

    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'bridges',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          // the state of things, said once, at the top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: live
                    ? [
                        HaloColors.violet.withValues(alpha: 0.18),
                        HaloColors.amber.withValues(alpha: 0.06),
                      ]
                    : [
                        HaloColors.surface2,
                        HaloColors.surface2.withValues(alpha: 0.4),
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: live
                    ? HaloColors.violet.withValues(alpha: 0.45)
                    : HaloColors.line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BreathDot(
                      color: live ? HaloColors.violet : HaloColors.amber,
                      size: 7,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      live ? 'going the quiet way' : 'straight to tor',
                      style: HaloType.mono(
                        size: 11,
                        color: live ? HaloColors.violet : HaloColors.text2,
                        weight: FontWeight.w600,
                        letter: 0.12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  live
                      ? 'your connection enters tor through a relay nobody has '
                            'published, wrapped so it does not look like tor.'
                      : 'fastest, and fine on almost every network. if tor is '
                            'blocked where you are, it will not connect at all.',
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // the switch
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _on = !_on);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _on
                      ? HaloColors.violet.withValues(alpha: 0.4)
                      : HaloColors.line,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'use bridges',
                      style: HaloType.sans(size: 14.5, color: HaloColors.text),
                    ),
                  ),
                  Switch(
                    value: _on,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _on = v);
                    },
                    activeThumbColor: HaloColors.onAmber,
                    activeTrackColor: HaloColors.violet,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 26),
          _RequestBlock(
            asking: _asking,
            captcha: _captcha,
            error: _askError,
            answer: _answer,
            onRequest: _request,
            onSend: _sendAnswer,
          ),

          const SizedBox(height: 26),
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: HaloColors.violet,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'your bridges',
                style: HaloType.mono(
                  size: 11,
                  color: HaloColors.text2,
                  weight: FontWeight.w600,
                  letter: 0.14,
                ),
              ),
              const Spacer(),
              if (n > 0)
                Text(
                  n == 1 ? '1 line' : '$n lines',
                  style: HaloType.mono(size: 11, color: HaloColors.violet),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: n > 0
                    ? HaloColors.violet.withValues(alpha: 0.3)
                    : HaloColors.line,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: TextField(
              controller: _ctrl,
              maxLines: 6,
              minLines: 4,
              style: HaloType.mono(size: 11.5, color: HaloColors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0',
                hintStyle: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
            ),
          ),

          const SizedBox(height: 12),
          _Ghost(
            icon: Icons.content_paste_rounded,
            label: 'paste from clipboard',
            onTap: () async {
              final d = await Clipboard.getData('text/plain');
              final t = d?.text?.trim();
              if (t == null || t.isEmpty) return;
              HapticFeedback.selectionClick();
              setState(() {
                _ctrl.text = _ctrl.text.trim().isEmpty
                    ? t
                    : '${_ctrl.text.trim()}\n$t';
              });
            },
          ),

          const SizedBox(height: 20),
          _Note(
            'where to get them',
            'bridges.torproject.org, or email bridges@torproject.org from a '
                'gmail or riseup address. ask for obfs4 — kryfo does not speak '
                'the others yet.',
          ),

          const SizedBox(height: 24),
          GestureDetector(
            onTap: _busy ? null : _save,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: (_busy || _reconnecting)
                    ? null
                    : LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: _on && _lineCount > 0
                            ? [HaloColors.violet, HaloColors.amber]
                            : [HaloColors.amber, HaloColors.amber],
                      ),
                color: _busy ? HaloColors.surface2 : null,
                border: _reconnecting
                    ? Border.all(
                        color: HaloColors.violet.withValues(alpha: 0.5),
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _busy
                    ? null
                    : [
                        BoxShadow(
                          color:
                              (_on && _lineCount > 0
                                      ? HaloColors.violet
                                      : HaloColors.amber)
                                  .withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: _reconnecting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HaloColors.violet,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Text(
                          _elapsed < 20
                              ? 'restarting tor…'
                              : _elapsed < 60
                              ? 'finding a bridge… ${_elapsed}s'
                              : 'still trying… ${_elapsed}s',
                          style: HaloType.mono(
                            size: 12.5,
                            color: HaloColors.text2,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _busy ? 'applying…' : 'save and reconnect',
                      style: HaloType.mono(
                        size: 13,
                        color: _busy ? HaloColors.text2 : HaloColors.onAmber,
                        weight: FontWeight.w700,
                        letter: 0.04,
                      ),
                    ),
            ),
          ),

          if (_result != null) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                _result!,
                style: HaloType.mono(size: 11.5, color: HaloColors.text2),
              ),
            ),
          ],

          const SizedBox(height: 22),
          _Note(
            'what changes',
            'saving restarts tor, so the next connection takes longer than '
                'usual. bridges are slower in general. if your network does not '
                'block tor, leave this off.',
          ),
        ],
      ),
    );
  }
}

class _RequestBlock extends StatelessWidget {
  const _RequestBlock({
    required this.asking,
    required this.captcha,
    required this.error,
    required this.answer,
    required this.onRequest,
    required this.onSend,
  });
  final bool asking;
  final String? captcha;
  final String? error;
  final TextEditingController answer;
  final VoidCallback onRequest;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.violet.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded, size: 16, color: HaloColors.violet),
              const SizedBox(width: 8),
              Text(
                'get bridges',
                style: HaloType.sans(
                  size: 14.5,
                  color: HaloColors.text,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            captcha == null
                ? 'ask the tor project directly. you solve a puzzle so bots '
                      'cannot drain the supply.'
                : 'type what you see. lowercase is fine.',
            style: HaloType.sans(size: 12.5, color: HaloColors.text2),
          ),
          if (captcha == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              decoration: BoxDecoration(
                color: HaloColors.rose.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: HaloColors.rose.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 15,
                    color: HaloColors.rose,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'this one request does not go through tor — it cannot, '
                      'since tor is what is not working. whoever runs your '
                      'network will see you contacting the tor project. if '
                      'that alone is a problem where you are, get bridges '
                      'somewhere else and paste them below.',
                      style: HaloType.sans(size: 12, color: HaloColors.text2),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (captcha != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(captcha!),
                fit: BoxFit.contain,
                height: 90,
                errorBuilder: (_, __, ___) => Text(
                  'could not draw the puzzle',
                  style: HaloType.mono(size: 11, color: HaloColors.rose),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: HaloColors.ink,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: HaloColors.line),
                    ),
                    child: TextField(
                      controller: answer,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      style: HaloType.mono(size: 13, color: HaloColors.text),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'answer',
                        hintStyle: HaloType.mono(
                          size: 12,
                          color: HaloColors.text3,
                        ),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: asking ? null : onSend,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: asking ? HaloColors.surface3 : HaloColors.violet,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      asking ? '…' : 'send',
                      style: HaloType.mono(
                        size: 12,
                        color: HaloColors.text,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: HaloType.mono(size: 11.5, color: HaloColors.rose),
            ),
          ],
          const SizedBox(height: 13),
          _Ghost(
            icon: Icons.refresh_rounded,
            label: asking
                ? 'asking…'
                : captcha == null
                ? 'request bridges'
                : 'different puzzle',
            onTap: asking ? () {} : onRequest,
          ),
        ],
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      children: [
        Icon(icon, size: 15, color: HaloColors.amber),
        const SizedBox(width: 8),
        Text(
          label,
          style: HaloType.mono(
            size: 12,
            color: HaloColors.amber,
            weight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.head, this.body);
  final String head;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
    decoration: BoxDecoration(
      color: HaloColors.surface2.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      border: Border(
        left: BorderSide(
          color: HaloColors.amber.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          head,
          style: HaloType.mono(
            size: 10.5,
            color: HaloColors.amber,
            weight: FontWeight.w600,
            letter: 0.14,
          ),
        ),
        const SizedBox(height: 6),
        Text(body, style: HaloType.sans(size: 13, color: HaloColors.text)),
      ],
    ),
  );
}
