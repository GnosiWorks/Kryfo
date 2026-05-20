// chat screen. message bubbles, composer, live receive over tor.
// matches 08_complete_spec.html "the everyday" chat tile.

import 'dart:async';
import 'package:flutter/material.dart';
import '../signal_session.dart';
import '../message_envelope.dart';
import '../theme.dart';
import '../widgets/halo_avatar.dart';
import '../main.dart' show engine, db, signalEncrypt, signalDecrypt, appState, currentChatPeer;
import '../widgets/motion.dart';

// persists last-seen cipher per peer across ChatScreen instances
final Map<String, String> _seenCipherPerPeer = {};

class ChatScreen extends StatefulWidget {
  final String peerHaloId;
  final String peerOnion;
  final String peerXPub;
  final String avatarSeed;

  const ChatScreen({
    super.key,
    required this.peerHaloId,
    required this.peerOnion,
    required this.peerXPub,
    required this.avatarSeed,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Msg {
  final String direction;
  final String text;
  final DateTime when;
  final int? burnAt; // ms-since-epoch when this message expires, or null
  bool sending;
  bool failed;
  _Msg(this.direction, this.text, this.when,
      {this.burnAt, this.sending = false, this.failed = false});
}

String _friendlyStatus(String raw) {
  if (raw.isEmpty) return '';
  if (raw.startsWith('error: dial:') || raw.contains('host unreachable')) {
    return "couldn't reach peer · they may be offline";
  }
  if (raw.startsWith('error:')) return 'something went wrong';
  return raw;
}

String _fmtTime(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// remaining time on a burning message, formatted compactly:
// 4m 23s / 38s / 1h 02m. clamps at 0.
// human-friendly label for a burn duration in seconds.
String _humanBurn(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m';
  if (seconds < 86400) return '${seconds ~/ 3600}h';
  return '${seconds ~/ 86400}d';
}

String _fmtBurn(int burnAtMs) {
  final now = DateTime.now().millisecondsSinceEpoch;
  var s = ((burnAtMs - now) / 1000).round();
  if (s <= 0) return '0s';
  final h = s ~/ 3600; s -= h * 3600;
  final m = s ~/ 60; s -= m * 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  bool _ghost = false; // per-chat session toggle.
  int _burnSeconds = 300; // default 5m. long-press the fire button to change.
  Timer? _burnTick;
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  String _status = '';
  String _lastCipher = '';
  Timer? _pollTimer;
  bool _sending = false;
  String? _peerXPub;
  bool _backPaired = false;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
    currentChatPeer = widget.peerHaloId;
    signalSession.peerXPubHex(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _peerXPub = v);
    });
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    _lastCipher = _seenCipherPerPeer[widget.peerHaloId] ?? '';
    _loadMessages();
    _burnTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final before = _messages.length;
      _messages.removeWhere((m) => m.burnAt != null && m.burnAt! + 500 <= now);
      final removed = before - _messages.length;
      final stillBurning =
          _messages.where((m) => m.burnAt != null).toList();
      if (stillBurning.isNotEmpty || removed > 0) {
        debugPrint('burnTick: removed=$removed burning=${stillBurning.length}');
      }
      if (removed > 0 || stillBurning.isNotEmpty) {
        setState(() {});
      }
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkInbox();
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    final rows = await db.messagesFor(widget.peerHaloId);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (final r in rows) {
        _messages.add(_Msg(
          r['direction'] as String,
          r['plaintext'] as String,
          DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
          burnAt: r['burn_at'] as int?,
        ));
      }
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _checkInbox() async {
    final msgs = engine.drainInbox();
    if (msgs.isEmpty) return;
    for (final r in msgs) {
      final wrapped = await signalDecrypt(widget.peerHaloId, r);
      if (wrapped == null) continue;
      final env = unwrapMessage(wrapped);
      if (env.endpoint != null) {
        await savePeerEndpoint(widget.peerHaloId, env.endpoint!);
      }
      final plain = env.message;
      _lastCipher = r;
      if (!mounted) return;
      await db.saveMessage(widget.peerHaloId, 'in', plain);
      setState(() {
        _messages.add(_Msg('in', plain, DateTime.now(),
            burnAt: env.burnSeconds != null && env.burnSeconds! > 0
                ? DateTime.now().millisecondsSinceEpoch + env.burnSeconds! * 1000
                : null));
      });
      _scrollToEnd();
    }
  }

  Future<void> _retry(_Msg msg) async {
    if (_sending) return;
    setState(() {
      msg.failed = false;
      msg.sending = true;
      _status = '';
    });
    final String cipher;
    try {
      final wrapped = await wrapMessage(msg.text, sender: SenderInfo(
        haloId: appState.myId,
        edPub: engine.myEdPubkey(),
        onion: appState.myOnion,
        xPub: engine.myXPubkey(),
      ));
      cipher = await signalEncrypt(widget.peerHaloId, wrapped);
    } catch (e) {
      if (!mounted) return;
      setState(() { msg.sending = false; msg.failed = true; });
      return;
    }
    // sprint 7.5: fire-and-forget. optimistic ✓ now; failure marks tap-to-retry
    setState(() { msg.sending = false; });
    // before the peer back-pairs with us, force direct-onion so their
    // drain triggers the back-pair flow. nostr would dead-end because
    // they aren't subscribed to our xpub yet. once we receive anything
    // from them, _backPaired flips and we can use nostr.
    final useDirectOnion = !_backPaired || _peerXPub == null;
    final sendFuture = useDirectOnion
        ? Future(() => engine.sendTo(widget.peerOnion, cipher))
        : Future(() => engine.nostrSend(_peerXPub!, cipher));
    sendFuture.then((result) async {
      if (!mounted) return;
      if (result == 'ok') {
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
        });
        await db.saveMessage(widget.peerHaloId, 'out', msg.text);
      } else {
        setState(() { msg.failed = true; _status = result; });
      }
    });
  }

  void _pickBurnDuration() {
    final options = <int, String>{
      30: '30 seconds',
      60: '1 minute',
      300: '5 minutes',
      3600: '1 hour',
      86400: '24 hours',
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.local_fire_department_outlined,
                    size: 14, color: HaloColors.amber),
                const SizedBox(width: 8),
                Text('ghost timer',
                    style: HaloType.serif(
                        size: 16, color: HaloColors.text, italic: true)),
              ]),
              const SizedBox(height: 4),
              Text('how long before sent messages burn?',
                  style: HaloType.mono(size: 11, color: HaloColors.text3)),
              const SizedBox(height: 12),
              ...options.entries.map((e) {
                final isSelected = _burnSeconds == e.key;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _burnSeconds = e.key;
                      _ghost = true;
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Expanded(child: Text(e.value,
                          style: HaloType.sans(
                              size: 14,
                              color: isSelected
                                  ? HaloColors.amber
                                  : HaloColors.text))),
                      if (isSelected)
                        const Icon(Icons.check_rounded,
                            size: 16, color: HaloColors.amber),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final msg = _Msg('out', text, DateTime.now(), sending: true,
        burnAt: _ghost
            ? DateTime.now().millisecondsSinceEpoch + _burnSeconds * 1000
            : null);
    setState(() {
      _messages.add(msg);
      _sending = true;
      _status = '';
    });
    _msgCtrl.clear();
    _scrollToEnd();
    final String cipher;
    try {
      final wrapped = await wrapMessage(text, burnSeconds: _ghost ? _burnSeconds : null, sender: SenderInfo(
        haloId: appState.myId,
        edPub: engine.myEdPubkey(),
        onion: appState.myOnion,
        xPub: engine.myXPubkey(),
      ));
      cipher = await signalEncrypt(widget.peerHaloId, wrapped);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.sending = false;
        msg.failed = true;
        _sending = false;
        _status = 'no signal session — re-pair';
      });
      return;
    }
    // sprint 7.5: fire-and-forget. optimistic ✓ now; failure marks tap-to-retry
    setState(() { msg.sending = false; _sending = false; _status = ''; });
    // before the peer back-pairs with us, force direct-onion so their
    // drain triggers the back-pair flow. nostr would dead-end because
    // they aren't subscribed to our xpub yet. once we receive anything
    // from them, _backPaired flips and we can use nostr.
    final useDirectOnion = !_backPaired || _peerXPub == null;
    final sendFuture = useDirectOnion
        ? Future(() => engine.sendTo(widget.peerOnion, cipher))
        : Future(() => engine.nostrSend(_peerXPub!, cipher));
    sendFuture.then((result) async {
      if (!mounted) return;
      if (result == 'ok') {
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
        });
        await db.saveMessage(widget.peerHaloId, 'out', text,
            burnAt: _ghost
                ? DateTime.now().millisecondsSinceEpoch + _burnSeconds * 1000
                : null);
      } else {
        setState(() { msg.failed = true; _status = result; });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _burnTick?.cancel();
    if (currentChatPeer == widget.peerHaloId) currentChatPeer = null;
    appState.removeListener(_onAppStateChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHead(
              haloId: widget.peerHaloId,
              avatarSeed: widget.avatarSeed,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyConversation()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (c, i) => _Bubble(msg: _messages[i], onRetry: _retry),
                    ),
            ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(_friendlyStatus(_status),
                    style: HaloType.mono(size: 10, color: HaloColors.text3)),
              ),
            _Composer(
              ghost: _ghost,
              onToggleGhost: () => setState(() => _ghost = !_ghost),
              onPickBurn: _pickBurnDuration,
              burnSeconds: _burnSeconds,
              controller: _msgCtrl,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHead extends StatelessWidget {
  final String haloId;
  final String avatarSeed;
  final VoidCallback onBack;
  const _ChatHead({required this.haloId, required this.avatarSeed, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
            onPressed: onBack,
          ),
          HaloAvatar(seed: avatarSeed, size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(haloId,
                    style: HaloType.sans(size: 14, weight: FontWeight.w500)),
                Text('onion',
                    style: HaloType.mono(size: 10, color: HaloColors.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final void Function(_Msg)? onRetry;
  const _Bubble({required this.msg, this.onRetry});
  @override
  Widget build(BuildContext context) {
    final isOut = msg.direction == 'out';
    final showMeta = isOut && !msg.sending && !msg.failed;
    final showPill = isOut && msg.sending;
    final metaColor = isOut
        ? HaloColors.onAmber.withValues(alpha: 0.55)
        : HaloColors.text3;
    final remainingMs = msg.burnAt != null
        ? msg.burnAt! - DateTime.now().millisecondsSinceEpoch
        : 9999999;
    final isExpiring = msg.burnAt != null && remainingMs < 600;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      opacity: isExpiring ? 0.0 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        scale: isExpiring ? 0.88 : 1.0,
        child: GestureDetector(
      onTap: msg.failed && onRetry != null ? () => onRetry!(msg) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: isOut ? null : HaloColors.surface3,
                gradient: isOut
                    ? const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [HaloColors.amber, HaloColors.amberDeep],
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isOut ? 14 : 4),
                  bottomRight: Radius.circular(isOut ? 4 : 14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(msg.text,
                      style: HaloType.sans(
                        size: 14,
                        color: isOut ? HaloColors.onAmber : HaloColors.text,
                        height: 1.4,
                      )),
                  if (showMeta) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_fmtTime(msg.when),
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: metaColor,
                              letterSpacing: 0.4,
                            )),
                        const SizedBox(width: 3),
                        Text('✓',
                            style: TextStyle(
                              fontSize: 11,
                              color: metaColor,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            )),
                      ],
                    ),
                  ],
                  if (msg.burnAt != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_outlined,
                          size: 11,
                          color: isOut
                              ? HaloColors.onAmber
                              : HaloColors.amber.withOpacity(0.75)),
                      const SizedBox(width: 4),
                      Text('burns in ${_fmtBurn(msg.burnAt!)}',
                          style: HaloType.mono(
                              size: 9.5,
                              color: isOut
                                  ? HaloColors.onAmber
                                  : HaloColors.amber.withOpacity(0.75),
                              weight: FontWeight.w600)
                              .copyWith(letterSpacing: 0.3)),
                    ],
                  ),
                ),
              ],
              if (msg.failed) ...[
                    const SizedBox(height: 4),
                    Text('failed · tap to retry',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          color: HaloColors.onAmber.withValues(alpha: 0.75),
                          letterSpacing: 0.4,
                        )),
                  ],
                ],
              ),
            ),
            if (showPill) ...[
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: SendPill(mode: PrivacyMode.normal),
              ),
            ],
          ],
        ),
      ),
    ),
    ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text('say hi.',
            textAlign: TextAlign.center,
            style: HaloType.serif(
              size: 22, weight: FontWeight.w300,
              italic: true, color: HaloColors.text3,
            )),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool ghost;
  final VoidCallback onToggleGhost;
  final VoidCallback onPickBurn;
  final int burnSeconds;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.ghost,
    required this.onToggleGhost,
    required this.onPickBurn,
    required this.burnSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ghost ? HaloColors.amber.withOpacity(0.6) : HaloColors.line,
            width: ghost ? 0.8 : 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axisAlignment: -1,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: ghost
                ? Padding(
                    key: const ValueKey('ghost-banner'),
                    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_outlined,
                            size: 13, color: HaloColors.amber),
                        const SizedBox(width: 6),
                        Text('ghost mode',
                            style: HaloType.serif(
                                size: 12,
                                color: HaloColors.amber,
                                italic: true)),
                        const SizedBox(width: 8),
                        Text('messages burn after ${_humanBurn(burnSeconds)}',
                            style: HaloType.mono(
                                size: 10.5, color: HaloColors.text3)),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Row(
        children: [
          GestureDetector(
            onTap: onToggleGhost,
            onLongPress: onPickBurn,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ghost ? HaloColors.amber : HaloColors.surface3,
                boxShadow: ghost
                    ? [BoxShadow(
                        color: HaloColors.amber.withOpacity(0.45),
                        blurRadius: 12, spreadRadius: 1)]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.local_fire_department_outlined,
                size: 18,
                color: ghost ? HaloColors.onAmber : HaloColors.text2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: HaloType.sans(size: 14),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'message',
                hintStyle: HaloType.sans(size: 14, color: HaloColors.text3),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: HaloColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: HaloColors.amber, width: 0.5),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sending ? HaloColors.surface3 : HaloColors.amber,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_upward,
                size: 18,
                color: sending ? HaloColors.text3 : HaloColors.onAmber,
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}
