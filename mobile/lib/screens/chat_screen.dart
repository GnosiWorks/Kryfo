// chat screen. message bubbles, composer, live receive over tor.
// matches 08_complete_spec.html "the everyday" chat tile.

import 'dart:async';
import 'package:flutter/material.dart';
import '../signal_session.dart';
import '../message_envelope.dart' show wrapMessage, unwrapMessage, SenderInfo, ReactionFrame, savePeerEndpoint, loadPeerEndpoint;
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
  String? msgUid;    // stable cross-device id, used as the reaction key
  bool sending;
  bool failed;
  // reactor halo id -> emoji. '' for self.
  Map<String, String> reactions;
  _Msg(this.direction, this.text, this.when,
      {this.burnAt,
      this.msgUid,
      this.sending = false,
      this.failed = false,
      Map<String, String>? reactions})
      : reactions = reactions ?? <String, String>{};
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

  // floating reaction picker — WhatsApp-style pill above the long-pressed
  // bubble. uses an OverlayEntry so it can sit outside the chat list and
  // avoid clipping. tap outside to dismiss.
  Future<void> _showEmojiPickerAt(
      BuildContext bubbleContext, _Msg target) async {
    // legacy messages (predating v5 migration) get a local uid assigned
    // on first reaction. peers won't know this uid so the reaction stays
    // local-only, but the UX works.
    if (target.msgUid == null) {
      final uid = _newMsgUid();
      target.msgUid = uid;
      await db.assignUidIfMissing(
          widget.peerHaloId, target.when.millisecondsSinceEpoch, uid);
    }
    if (!mounted) return;
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final bubbleSize = box.size;
    final screen = MediaQuery.of(context).size;

    const pickerW = 296.0;
    const pickerH = 54.0;
    // prefer above the bubble. fall back to below if too close to the top.
    double top = offset.dy - pickerH - 10;
    if (top < MediaQuery.of(context).padding.top + 8) {
      top = offset.dy + bubbleSize.height + 10;
    }
    double left = offset.dx + bubbleSize.width / 2 - pickerW / 2;
    left = left.clamp(12.0, screen.width - pickerW - 12);

    late OverlayEntry entry;
    void dismiss() {
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(builder: (_) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismiss,
              child: Container(color: Colors.black.withOpacity(0.32)),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _EmojiPickerBubble(
              emojis: const ['❤️', '👍', '😂', '😮', '😢', '🔥'],
              selected: target.reactions[''],
              onPick: (e) {
                dismiss();
                _toggleReaction(target, e);
              },
            ),
          ),
        ],
      );
    });
    Overlay.of(context).insert(entry);
  }

  // 12-char base36 id from a high-precision timestamp + random salt.
  // collision-resistant enough for our scale.
  String _newMsgUid() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = (DateTime.now().microsecondsSinceEpoch ^
            identityHashCode(this) ^
            _msgUidCounter++)
        .abs()
        .toRadixString(36);
    return '${t.padLeft(8, '0').substring(0, 8)}${r.substring(0, 4).padLeft(4, '0')}';
  }

  int _msgUidCounter = 0;

  // toggle a reaction on a message. tap same emoji again to remove.
  // tap a different emoji to replace.
  Future<void> _toggleReaction(_Msg m, String emoji) async {
    if (m.msgUid == null) {
      final uid = _newMsgUid();
      m.msgUid = uid;
      await db.assignUidIfMissing(
          widget.peerHaloId, m.when.millisecondsSinceEpoch, uid);
    }
    final current = m.reactions[''];
    final remove = current == emoji; // tapping same emoji = unreact
    final newEmoji = remove ? '' : emoji;
    setState(() {
      if (remove) {
        m.reactions.remove('');
      } else {
        m.reactions[''] = emoji;
      }
    });
    // persist locally
    if (remove) {
      await db.removeReaction(m.msgUid!, '');
    } else {
      await db.addReaction(m.msgUid!, '', emoji);
    }
    // send to peer as a reaction control envelope (empty body).
    try {
      final wrapped = await wrapMessage(
        '',
        reaction: ReactionFrame(targetUid: m.msgUid!, emoji: newEmoji),
      );
      final cipher = await signalEncrypt(widget.peerHaloId, wrapped);
      final useDirectOnion = !_backPaired || _peerXPub == null;
      final f = useDirectOnion
          ? Future(() => engine.sendTo(widget.peerOnion, cipher))
          : Future(() => engine.nostrSend(_peerXPub!, cipher));
      await f;
    } catch (e) {
      debugPrint('reaction send failed: $e');
    }
  }

  Future<void> _loadMessages() async {
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    final rows = await db.messagesFor(widget.peerHaloId);
    if (!mounted) return;
    // collect msg_uids first, batch-load reactions, then setState.
    final loaded = <_Msg>[];
    final uids = <String>[];
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      loaded.add(_Msg(
        r['direction'] as String,
        r['plaintext'] as String,
        DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
        burnAt: r['burn_at'] as int?,
        msgUid: uid,
      ));
      if (uid != null) uids.add(uid);
    }
    final reactionMap = await db.loadReactionsFor(uids);
    for (final m in loaded) {
      if (m.msgUid == null) continue;
      final entries = reactionMap[m.msgUid!];
      if (entries == null) continue;
      for (final e in entries) {
        m.reactions[e.key] = e.value;
      }
    }
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);
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
    final msgUid = _newMsgUid();
    final msg = _Msg('out', text, DateTime.now(), sending: true,
        msgUid: msgUid,
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
      final wrapped = await wrapMessage(text, burnSeconds: _ghost ? _burnSeconds : null, msgUid: msgUid, sender: SenderInfo(
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
                : null,
            msgUid: msgUid);
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
                      itemBuilder: (c, i) => _Bubble(
                        msg: _messages[i],
                        onRetry: _retry,
                        onLongPress: (ctx) => _showEmojiPickerAt(ctx, _messages[i]),
                      ),
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
  final void Function(BuildContext)? onLongPress;
  const _Bubble({required this.msg, this.onRetry, this.onLongPress});
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
      behavior: HitTestBehavior.opaque,
      onTap: msg.failed && onRetry != null ? () => onRetry!(msg) : null,
      onLongPress: onLongPress == null ? null : () => onLongPress!(context),
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
                  if (msg.reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _buildReactionChips(msg),
                      ),
                    ),
                  ],
                  if (msg.reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _buildReactionChips(msg),
                      ),
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

  // group reactions by emoji: each chip shows the emoji + count if >1.
  // emoji used by the local user gets the amberSoft fill.
  List<Widget> _buildReactionChips(_Msg m) {
    final counts = <String, int>{};
    for (final emoji in m.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final mine = m.reactions[''];
    return counts.entries.map<Widget>((e) {
      final emoji = e.key;
      final count = e.value;
      final isMine = emoji == mine;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isMine ? HaloColors.amberSoft : HaloColors.surface3,
          border: Border.all(
            color: isMine ? HaloColors.amber : HaloColors.line,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (count > 1) ...[
              const SizedBox(width: 4),
              Text('$count',
                  style: HaloType.mono(
                      size: 10, color: HaloColors.text2)),
            ],
          ],
        ),
      );
    }).toList();
  }
}

// big tappable emoji button used in the bottom-sheet reaction picker.
class _EmojiTap extends StatefulWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _EmojiTap({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_EmojiTap> createState() => _EmojiTapState();
}

class _EmojiTapState extends State<_EmojiTap> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.85),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: widget.selected
                ? HaloColors.amberSoft
                : HaloColors.surface3,
            border: Border.all(
              color: widget.selected ? HaloColors.amber : HaloColors.line,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(widget.emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

// floating reaction bar shown above the long-pressed bubble. soft shadow,
// rounded pill, scale + fade entrance. matches halo's surface3 + line
// design language.
class _EmojiPickerBubble extends StatefulWidget {
  final List<String> emojis;
  final String? selected;
  final void Function(String) onPick;
  const _EmojiPickerBubble({
    required this.emojis,
    required this.selected,
    required this.onPick,
  });

  @override
  State<_EmojiPickerBubble> createState() => _EmojiPickerBubbleState();
}

class _EmojiPickerBubbleState extends State<_EmojiPickerBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    return Material(
      color: Colors.transparent,
      child: ScaleTransition(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: _ctrl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: HaloColors.surface3,
              border: Border.all(color: HaloColors.line, width: 0.5),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.emojis.map((e) {
                final isSelected = e == widget.selected;
                return _EmojiTap(
                  emoji: e,
                  selected: isSelected,
                  onTap: () => widget.onPick(e),
                );
              }).toList(),
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
