// chat screen. message bubbles, composer, live receive over tor.
// matches 08_complete_spec.html "the everyday" chat tile.

import 'dart:async';
import 'package:flutter/material.dart';
import '../signal_session.dart';
import '../message_envelope.dart';
import '../theme.dart';
import '../main.dart' show engine, db, signalEncrypt, signalDecrypt, appState;
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
  bool sending;
  bool failed;
  _Msg(this.direction, this.text, this.when, {this.sending = false, this.failed = false});
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

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  String _status = '';
  String _lastCipher = '';
  Timer? _pollTimer;
  bool _sending = false;
  String? _peerXPub;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
    signalSession.peerXPubHex(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _peerXPub = v);
    });
    _lastCipher = _seenCipherPerPeer[widget.peerHaloId] ?? '';
    _loadMessages();
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
    final rows = await db.messagesFor(widget.peerHaloId);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (final r in rows) {
        _messages.add(_Msg(
          r['direction'] as String,
          r['plaintext'] as String,
          DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
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
        _messages.add(_Msg('in', plain, DateTime.now()));
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
      final wrapped = await wrapMessage(msg.text);
      cipher = await signalEncrypt(widget.peerHaloId, wrapped);
    } catch (e) {
      if (!mounted) return;
      setState(() { msg.sending = false; msg.failed = true; });
      return;
    }
    // sprint 7.5: fire-and-forget. optimistic ✓ now; failure marks tap-to-retry
    setState(() { msg.sending = false; });
    final sendFuture = _peerXPub == null
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

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final msg = _Msg('out', text, DateTime.now(), sending: true);
    setState(() {
      _messages.add(msg);
      _sending = true;
      _status = '';
    });
    _msgCtrl.clear();
    _scrollToEnd();
    final String cipher;
    try {
      final wrapped = await wrapMessage(text);
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
    final sendFuture = _peerXPub == null
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
        await db.saveMessage(widget.peerHaloId, 'out', text);
      } else {
        setState(() { msg.failed = true; _status = result; });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
          _Avatar(seed: avatarSeed, size: 36),
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

class _Avatar extends StatelessWidget {
  final String seed;
  final double size;
  const _Avatar({required this.seed, required this.size});
  @override
  Widget build(BuildContext context) {
    final h = seed.hashCode.abs();
    final colors = [HaloColors.rose, HaloColors.violet, HaloColors.amber, HaloColors.green];
    final bg = colors[h % colors.length];
    final letter = seed.isEmpty ? '?' : seed[0].toUpperCase();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg.withOpacity(0.85)),
      alignment: Alignment.center,
      child: Text(letter,
          style: HaloType.serif(
            size: size * 0.42, weight: FontWeight.w400,
            italic: true, color: HaloColors.text,
          )),
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
    return GestureDetector(
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
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: HaloColors.surface3,
            ),
            alignment: Alignment.center,
            child: Text('+',
                style: HaloType.sans(size: 18, color: HaloColors.text2)),
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
    );
  }
}
