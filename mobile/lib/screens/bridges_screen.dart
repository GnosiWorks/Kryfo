// SPDX-License-Identifier: GPL-3.0-or-later
// bridges. a direct tor connection is recognisable, and in the places where
// kryfo matters most that is enough to get it blocked. a bridge is an entry
// point that is not published anywhere, reached through obfs4, which makes
// the traffic look like nothing in particular.
import 'dart:convert';
import '../secure_store.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' hide live;
import '../seen_timers.dart';
import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/motion.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/halo_switch.dart';
import '../widgets/swap.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

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
  // when the reconnect began, and the route before it
  int _since = 0;
  int _genBefore = 0;
  // the reconnect is watched once a second while the page is seen. away or
  // under the lock nothing ticks; back, it looks at once
  final _timers = SeenTimers();
  late final SeenJob _tick = _timers.until(
    () => _reconnecting ? const Duration(seconds: 1) : null,
    (_) => _watch(),
  );
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  @override
  void dispose() {
    _timers.dispose();
    _ctrl.dispose();
    _answer.dispose();
    super.dispose();
  }

  int get _lineCount =>
      _ctrl.text.split('\n').where((l) => l.trim().isNotEmpty).length;

  // ask bridges.torproject.org for a fresh set. this is plain https, not tor:
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
      setState(() => _askError = l10n.bridgesThatWasNotIt);
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
      showHaloToast(context, l10n.bridgesGotBridgesSaveTo);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final lines = _ctrl.text.trim();
    final r = await appState.applyBridges(lines, _on && lines.isNotEmpty);
    // the route generation before the reconnect. the reconnect happens after
    // restartTor returns, so a "ready" in the next second or two is the old
    // tor. connected means a newer route that a relay has connected through.
    _genBefore = appState.routeGen;
    engine.restartTor();
    if (!mounted) return;
    setState(() {
      _result = r;
      _reconnecting = true;
      _elapsed = 0;
      _since = DateTime.now().millisecondsSinceEpoch;
    });
    // a dead button for minutes looks broken. count, and stop when tor can
    // carry traffic again.
    _tick.poke();
  }

  void _watch() {
    if (!mounted || !_reconnecting) return;
    final through = appState.routeGen > _genBefore && appState.torReady;
    setState(
      () => _elapsed = (DateTime.now().millisecondsSinceEpoch - _since) ~/ 1000,
    );
    if (!through && _elapsed <= 240) return;
    setState(() {
      _reconnecting = false;
      _busy = false;
    });
    if (through) {
      HapticFeedback.mediumImpact();
      showHaloToast(context, l10n.bridgesConnected);
    } else {
      showHaloToast(context, l10n.bridgesNotThroughYetTor);
    }
  }

  // which card the saved lines came from. the connected state sits on that
  // one. remembered so it survives reopening the screen.
  String _source = 'moat';

  Future<void> _loadSource() async {
    final v = await secureStore.read(key: 'bridge_source');
    if (mounted && v != null) setState(() => _source = v);
  }

  Future<void> _setSource(String v) async {
    setState(() => _source = v);
    await secureStore.write(key: 'bridge_source', value: v);
  }

  @override
  Widget build(BuildContext context) {
    final n = _lineCount;
    final live = _on && n > 0;
    // connected: bridges are saved, on, and a relay has connected through
    // them. never while a reconnect this screen started is still settling.
    final connected =
        live && appState.bridgesOn && appState.torReady && !_reconnecting;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.bridgesBridges,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: staggerAll([
          Text(
            l10n.bridgesTorIsBlockedWhere,
            style: HaloType.serif(size: 26, color: HaloColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.bridgesBridgesDisguiseYourConnection,
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
                l10n.bridgesBridgesOnlyChangeHow,
                style: HaloType.sans(size: 12.5, color: HaloColors.text2),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // card one: obfs4 from the tor project, through the moat
          _BridgeCard(
            name: 'obfs4',
            from: l10n.bridgesFromTheTorProject,
            looksLike: l10n.bridgesNoise,
            speed: l10n.bridgesGood,
            body: l10n.bridgesMakesTorTrafficLook,
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
            name: l10n.bridgesPrivateBridge,
            from: l10n.bridgesALineFromA,
            looksLike: l10n.bridgesWhateverTheLineSays,
            speed: l10n.bridgesDepends,
            body: l10n.bridgesGotABridgeLine,
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
                    textDirection: TextDirection.ltr,
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
                  label: l10n.bridgesPasteFromClipboard,
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
                          l10n.bridgesUseBridges,
                          style: HaloType.sans(
                            size: 14.5,
                            color: HaloColors.text,
                          ),
                        ),
                        Text(
                          n == 0
                              ? l10n.bridgesNoLinesYet
                              : l10n.bridges1LineSaved(n),
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
          PressScale(
            scale: 0.97,
            haptic: false,
            onTap: _busy ? null : _save,
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
                        // an arc that turns while tor comes back, held
                        // still with less movement
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            value: motionStill(context) ? 0.3 : null,
                            strokeWidth: 2,
                            color: HaloColors.violet,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Text(
                          _elapsed < 20
                              ? l10n.bridgesRestartingTor
                              : _elapsed < 60
                              ? l10n.bridgesFindingABridgeS(whole(_elapsed))
                              : l10n.bridgesStillTryingS(whole(_elapsed)),
                          style: HaloType.mono(
                            size: 12.5,
                            color: HaloColors.text2,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _busy
                          ? l10n.bridgesApplying
                          : l10n.bridgesSaveAndReconnect,
                      style: HaloType.mono(
                        size: 12.5,
                        color: HaloColors.onAmber,
                        weight: FontWeight.w600,
                        letter: 0.06,
                      ),
                    ),
            ),
          ),
          // the engine answers "ok: 3 bridges", never a bare ok
          EaseSize(
            child: _result == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: RiseSwap(
                      child: Text(
                        _resultLine(_result!),
                        key: ValueKey(_result),
                        style: HaloType.mono(
                          size: 11,
                          color: _result!.startsWith('ok')
                              ? HaloColors.text2
                              : HaloColors.rose,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          _Note(l10n.bridgesWhatABridgeIs, l10n.bridgesATorEntryPoint),
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
              RiseSwap(
                alignment: AlignmentDirectional.centerEnd,
                child: connected
                    ? Row(
                        key: const ValueKey('on'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BreathDot(
                            color: HaloColors.green,
                            size: 6,
                            breaths: 3,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.bridgesConnected,
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
                        l10n.bridgesConnecting,
                        style: HaloType.mono(
                          size: 10,
                          color: HaloColors.violet,
                          letter: 0.1,
                        ),
                      )
                    : active
                    ? Text(
                        key: const ValueKey('saved'),
                        l10n.bridgesSavedTag,
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
              _Meta(k: l10n.bridgesLooksLike, v: looksLike),
              const SizedBox(width: 18),
              _Meta(k: l10n.bridgesSpeed, v: speed),
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
                l10n.bridgesGetBridges,
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
                ? l10n.bridgesAskTheTorProject
                : l10n.bridgesTypeWhatYouSee,
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
                      l10n.bridgesThisOneRequestDoes,
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
                  l10n.bridgesCouldNotDrawThe,
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
                      textDirection: TextDirection.ltr,
                      controller: answer,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      style: HaloType.mono(size: 13, color: HaloColors.text),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: l10n.bridgesAnswer,
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
                PressScale(
                  scale: 0.95,
                  onTap: asking ? null : onSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: asking ? HaloColors.surface3 : HaloColors.violet,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      asking ? '…' : l10n.commonSend,
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
                ? l10n.bridgesAsking
                : captcha == null
                ? l10n.bridgesRequestBridges
                : l10n.bridgesDifferentPuzzle,
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
  Widget build(BuildContext context) => PressScale(
    scale: 0.97,
    haptic: false,
    onTap: onTap,
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
      border: BorderDirectional(
        start: BorderSide(
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

String _resultLine(String r) {
  final some = RegExp(
    r'^ok: (\d+) accepted, (\d+) not understood',
  ).firstMatch(r);
  if (some != null) {
    return l10n.bridgesSavedSomeBad(
      int.parse(some.group(1)!),
      int.parse(some.group(2)!),
    );
  }
  final all = RegExp(r'^ok: (\d+) bridges').firstMatch(r);
  if (all != null) return l10n.bridgesSaved(int.parse(all.group(1)!));
  return r.replaceFirst('error: ', '');
}
