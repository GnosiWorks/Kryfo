// SPDX-License-Identifier: GPL-3.0-or-later
// bridges. a direct tor connection is recognisable, and in the places where
// kryfo matters most that is enough to get it blocked. a bridge is an entry
// point that is not published anywhere, reached through obfs4, which makes
// the traffic look like nothing in particular.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/stagger_in.dart';
import '../widgets/halo_switch.dart';

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
    _loadSource();
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
      setState(() => _askError = 'That was not it. Here is another.');
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
      showHaloToast(context, 'Got bridges · save to use them');
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

  // which card the saved lines came from. the connected state sits on that
  // one. remembered so it survives reopening the screen.
  String _source = 'moat';

  Future<void> _loadSource() async {
    final v = await const FlutterSecureStorage().read(key: 'bridge_source');
    if (mounted && v != null) setState(() => _source = v);
  }

  Future<void> _setSource(String v) async {
    setState(() => _source = v);
    await const FlutterSecureStorage().write(key: 'bridge_source', value: v);
  }

  @override
  Widget build(BuildContext context) {
    final n = _lineCount;
    final live = _on && n > 0;
    // connected: bridges are saved, on, and tor is carrying traffic
    final connected = live && appState.bridgesOn && appState.torReady;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'Bridges',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: staggerAll([
          Text(
            'Tor is blocked where you are?',
            style: HaloType.serif(size: 26, color: HaloColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Bridges disguise your connection so it can get out. Pick one '
            'way in, save, and tor reconnects through it.',
            style: HaloType.sans(
              size: 13,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
          if (appState.sendMode != 'private') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HaloColors.line),
              ),
              child: Text(
                'Bridges only change how tor connects, and you are not on '
                'onion mode right now. What you set here is saved, it just '
                'does nothing until you switch back.',
                style: HaloType.sans(size: 12.5, color: HaloColors.text2),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // card one: obfs4 from the tor project, through the moat
          _BridgeCard(
            name: 'obfs4',
            from: 'From the tor project',
            looksLike: 'noise',
            speed: 'good',
            body:
                'Makes tor traffic look like nothing in particular. The best '
                'default for most blocked networks. Answers a captcha, then '
                'hands you a few lines.',
            active: _source == 'moat' && n > 0,
            connected: connected && _source == 'moat',
            reconnecting: _reconnecting && _source == 'moat',
            child: _RequestBlock(
              asking: _asking,
              captcha: _captcha,
              error: _askError,
              answer: _answer,
              onRequest: () {
                _setSource('moat');
                _request();
              },
              onSend: _sendAnswer,
            ),
          ),
          const SizedBox(height: 12),

          // card two: a line someone gave you
          _BridgeCard(
            name: 'Private bridge',
            from: 'A line from a friend',
            looksLike: 'Whatever the line says',
            speed: 'depends',
            body:
                'Got a bridge line from someone you trust, or from '
                'bridges.torproject.org? Paste it here. Obfs4 lines only, '
                'kryfo does not speak the others yet.',
            active: _source == 'paste' && n > 0,
            connected: connected && _source == 'paste',
            reconnecting: _reconnecting && _source == 'paste',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: n > 0 && _source == 'paste'
                          ? HaloColors.violet.withValues(alpha: 0.3)
                          : HaloColors.line,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: 5,
                    minLines: 3,
                    onChanged: (_) {
                      if (_source != 'paste') _setSource('paste');
                    },
                    style: HaloType.mono(size: 11, color: HaloColors.text),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          'obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0',
                      hintStyle: HaloType.mono(
                        size: 10.5,
                        color: HaloColors.text3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _Ghost(
                  icon: Icons.content_paste_rounded,
                  label: 'Paste from clipboard',
                  onTap: () async {
                    final d = await Clipboard.getData('text/plain');
                    final t = d?.text?.trim();
                    if (t == null || t.isEmpty || !mounted) return;
                    HapticFeedback.selectionClick();
                    setState(() {
                      _ctrl.text = _ctrl.text.trim().isEmpty
                          ? t
                          : '${_ctrl.text.trim()}\n$t';
                    });
                    _setSource('paste');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // the switch, and the lines it applies to
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use bridges',
                          style: HaloType.sans(
                            size: 14.5,
                            color: HaloColors.text,
                          ),
                        ),
                        Text(
                          n == 0
                              ? 'No lines yet'
                              : n == 1
                              ? '1 line saved'
                              : '$n lines saved',
                          style: HaloType.mono(
                            size: 10.5,
                            color: n > 0 ? HaloColors.violet : HaloColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  HaloSwitch(
                    value: _on,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _on = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                        colors: live
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
                              ? 'Restarting tor…'
                              : _elapsed < 60
                              ? 'Finding a bridge… ${_elapsed}s'
                              : 'Still trying… ${_elapsed}s',
                          style: HaloType.mono(
                            size: 12.5,
                            color: HaloColors.text2,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _busy ? 'applying…' : 'Save and reconnect',
                      style: HaloType.mono(
                        size: 12.5,
                        color: HaloColors.onAmber,
                        weight: FontWeight.w600,
                        letter: 0.06,
                      ),
                    ),
            ),
          ),
          // the engine answers "ok: 3 bridges", never a bare ok, so the
          // old check for exactly 'ok' never matched and a save that
          // worked printed in the error colour
          if (_result != null) ...[
            const SizedBox(height: 10),
            Text(
              _result!.startsWith('ok')
                  ? _result!.replaceFirst('ok: ', '')
                  : _result!.replaceFirst('error: ', ''),
              style: HaloType.mono(
                size: 11,
                color: _result!.startsWith('ok')
                    ? HaloColors.text2
                    : HaloColors.rose,
              ),
            ),
          ],
          const SizedBox(height: 22),
          const _Note(
            'What a bridge is',
            'A tor entry point nobody has published, reached through a '
                'wrapper so the connection does not look like tor. The rest '
                'of the route is the usual three hops.',
          ),
        ]),
      ),
    );
  }
}

// one way in. what it looks like on the wire, how fast it tends to be, and
// the state of things when it is the one in use.
class _BridgeCard extends StatelessWidget {
  final String name;
  final String from;
  final String looksLike;
  final String speed;
  final String body;
  final bool active;
  final bool connected;
  final bool reconnecting;
  final Widget child;
  const _BridgeCard({
    required this.name,
    required this.from,
    required this.looksLike,
    required this.speed,
    required this.body,
    required this.active,
    required this.connected,
    required this.reconnecting,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tint = connected ? HaloColors.green : HaloColors.violet;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? tint.withValues(alpha: 0.5) : HaloColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                name,
                style: HaloType.serif(size: 20, color: HaloColors.text),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  from,
                  style: HaloType.sans(size: 12, color: HaloColors.text2),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: connected
                    ? Row(
                        key: const ValueKey('on'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BreathDot(color: HaloColors.green, size: 6),
                          const SizedBox(width: 6),
                          Text(
                            'Connected',
                            style: HaloType.mono(
                              size: 10,
                              color: HaloColors.green,
                              weight: FontWeight.w600,
                              letter: 0.1,
                            ),
                          ),
                        ],
                      )
                    : reconnecting
                    ? Text(
                        key: const ValueKey('re'),
                        'connecting',
                        style: HaloType.mono(
                          size: 10,
                          color: HaloColors.violet,
                          letter: 0.1,
                        ),
                      )
                    : active
                    ? Text(
                        key: const ValueKey('saved'),
                        'saved',
                        style: HaloType.mono(
                          size: 10,
                          color: HaloColors.violet,
                          letter: 0.1,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('off')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Meta(k: 'Looks like', v: looksLike),
              const SizedBox(width: 18),
              _Meta(k: 'speed', v: speed),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String k;
  final String v;
  const _Meta({required this.k, required this.v});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        k,
        style: HaloType.mono(size: 9.5, color: HaloColors.text3, letter: 0.1),
      ),
      const SizedBox(height: 2),
      Text(
        v,
        style: HaloType.mono(
          size: 11,
          color: HaloColors.text,
          weight: FontWeight.w600,
        ),
      ),
    ],
  );
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
                'Get bridges',
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
                ? 'Ask the tor project directly. You solve a puzzle so bots '
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
                      'This one request does not go through tor - it cannot, '
                      'since tor is what is not working. Whoever runs your '
                      'network will see you contacting the tor project. If '
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
                errorBuilder: (_, _, _) => Text(
                  'Could not draw the puzzle',
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
                        hintText: 'Answer',
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
                ? 'Request bridges'
                : 'Different puzzle',
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
