// chat screen. message bubbles, composer, live receive over tor.
// matches 08_complete_spec.html "the everyday" chat tile.

import 'dart:async';
import 'package:flutter/material.dart';
import '../signal_session.dart';
import '../message_envelope.dart' show wrapMessage, unwrapMessage, SenderInfo, ReactionFrame, EditFrame, savePeerEndpoint, loadPeerEndpoint;
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
  String text;
  final DateTime when;
  final int? burnAt;
  String? msgUid;
  // msg_uid of the message this one replies to, or null.
  final String? replyTo;
  bool sending;
  bool failed;
  bool edited;
  Map<String, String> reactions;
  _Msg(this.direction, this.text, this.when,
      {this.burnAt,
      this.msgUid,
      this.replyTo,
      this.sending = false,
      this.failed = false,
      this.edited = false,
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
  // the message we're currently replying to, or null. set by tapping
  // 'reply' on the long-press picker, cleared after send or by the X
  // in the composer's quote bar.
  _Msg? _replyTo;

  // search-in-chat. _searching swaps the header for the search bar.
  // _query is the live trimmed term; _matches holds indices into
  // _messages that contain it; _matchPos is which hit is "current".
  // _matchKeys gives each matched bubble a GlobalKey so we can scroll
  // it into view.
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<int> _matches = [];
  int _matchPos = 0;
  final Map<int, GlobalKey> _matchKeys = {};
  String? _nickname;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
    appState.loadSendMode();
    currentChatPeer = widget.peerHaloId;
    db.getContact(widget.peerHaloId).then((c) {
      if (mounted) setState(() => _nickname = c?['nickname'] as String?);
    });
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

  // ---- search ----------------------------------------------------------

  void _openSearch() {
    setState(() => _searching = true);
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchCtrl.clear();
      _matches = [];
      _matchPos = 0;
      _matchKeys.clear();
    });
  }

  // recompute matches whenever the query changes. jumps to the most
  // recent hit (bottom of the list) by default, then scrolls it in.
  void _onQueryChanged(String q) {
    final query = q.trim();
    final matches = <int>[];
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      for (var i = 0; i < _messages.length; i++) {
        if (_messages[i].text.toLowerCase().contains(lower)) {
          matches.add(i);
        }
      }
    }
    setState(() {
      _query = query;
      _matches = matches;
      _matchPos = matches.isEmpty ? 0 : matches.length - 1;
      _matchKeys
        ..clear()
        ..addEntries(matches.map((i) => MapEntry(i, GlobalKey())));
    });
    _scrollToCurrentMatch();
  }

  // chevrons: delta -1 = previous (older) hit, +1 = next (newer). wraps.
  void _gotoMatch(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _matchPos = (_matchPos + delta) % _matches.length;
      if (_matchPos < 0) _matchPos += _matches.length;
    });
    _scrollToCurrentMatch();
  }

  // rough-jump to the match's approximate position (so it gets built),
  // then ensureVisible to center it precisely. avoids a scroll-to-index
  // package dependency while still landing reliably for normal chats.
  void _scrollToCurrentMatch() {
    if (_matches.isEmpty || !_scrollCtrl.hasClients) return;
    final idx = _matches[_matchPos];
    if (_messages.isNotEmpty) {
      final approx = (idx / _messages.length) *
          _scrollCtrl.position.maxScrollExtent;
      _scrollCtrl.jumpTo(
          approx.clamp(0.0, _scrollCtrl.position.maxScrollExtent));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _matchKeys[idx]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          alignment: 0.4,
        );
      }
    });
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
    const pickerH = 54.0;
    // prefer above the bubble. fall back to below if too close to the top.
    double top = offset.dy - pickerH - 10;
    if (top < MediaQuery.of(context).padding.top + 8) {
      top = offset.dy + bubbleSize.height + 10;
    }
    // pin the bar to the message's side so reply + edit never
    // run off the right edge. 12px margin from screen edge.
    final alignRight = target.direction == 'out';

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
            top: top,
            left: alignRight ? null : 12,
            right: alignRight ? 12 : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: target.direction == 'out'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _EmojiPickerBubble(
                  emojis: const ['❤️', '👍', '😂', '😮', '😢', '🔥'],
                  selected: target.reactions[''],
                  onPick: (e) {
                    dismiss();
                    _toggleReaction(target, e);
                  },
                  onReply: () {
                    dismiss();
                    setState(() => _replyTo = target);
                  },
                ),
                if (target.direction == 'out') ...[
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        dismiss();
                        _editMessage(target);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: HaloColors.surface3,
                          border: Border.all(
                              color: HaloColors.line, width: 0.5),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined,
                                size: 14, color: HaloColors.amber),
                            const SizedBox(width: 6),
                            Text('edit',
                                style: HaloType.sans(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: HaloColors.amber)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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

  // open an edit sheet for own message m. saves locally + tells the peer.
  Future<void> _editMessage(_Msg m) async {
    if (m.msgUid == null) {
      final uid = _newMsgUid();
      m.msgUid = uid;
      await db.assignUidIfMissing(
          widget.peerHaloId, m.when.millisecondsSinceEpoch, uid);
    }
    final ctrl = TextEditingController(text: m.text);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HaloColors.surface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('edit message',
                style: HaloType.serif(size: 20, italic: true, color: HaloColors.amber)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: null,
              cursorColor: HaloColors.amber,
              style: HaloType.sans(size: 15),
              decoration: const InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.line2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.amber),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('cancel',
                      style: HaloType.sans(size: 13, color: HaloColors.text2)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: Text('save',
                      style: HaloType.sans(size: 14, weight: FontWeight.w500, color: HaloColors.amber)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final newText = result.trim();
    if (newText.isEmpty || newText == m.text) return;
    setState(() {
      m.text = newText;
      m.edited = true;
    });
    await db.editMessage(m.msgUid!, newText);
    try {
      final wrapped = await wrapMessage(
        '',
        edit: EditFrame(targetUid: m.msgUid!, newText: newText),
      );
      final cipher = await signalEncrypt(widget.peerHaloId, wrapped);
      final useDirectOnion = !_backPaired || _peerXPub == null;
      final f = useDirectOnion
          ? Future(() => engine.sendTo(widget.peerOnion, cipher))
          : Future(() => engine.nostrSend(_peerXPub!, cipher));
      await f;
    } catch (e) {
      debugPrint('edit send failed: $e');
    }
  }

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
        replyTo: r['reply_to'] as String?,
        edited: (r['edited'] as int? ?? 0) == 1,
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
    // if a search is active, recompute matches against the fresh list.
    if (_searching && _query.isNotEmpty) {
      _onQueryChanged(_query);
    } else {
      _scrollToEnd();
    }
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
    // stays in 'sending' until the transport replies below.
    // before the peer back-pairs with us, force direct-onion so their
    // drain triggers the back-pair flow. nostr would dead-end because
    // they aren't subscribed to our xpub yet. once we receive anything
    // from them, _backPaired flips and we can use nostr.
    // try direct tor first if peer hasn't back-paired and we have their onion.
    // on tor failure / timeout, fall back to nostr store-and-forward.
    final sendFuture = Future<String>(() async {
      String? tor;
      if (!_backPaired && widget.peerOnion.isNotEmpty) {
        tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
        if (tor == 'ok') return 'ok';
        debugPrint('chat send: tor direct failed (\$tor), trying nostr');
      }
      if (_peerXPub != null) {
        return await Future(() => engine.nostrSend(_peerXPub!, cipher));
      }
      return tor ?? 'error: no transport';
    });
    sendFuture.then((result) async {
      if (!mounted) return;
      if (result == 'ok') {
        setState(() => msg.sending = false);
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
        });
        await db.saveMessage(widget.peerHaloId, 'out', msg.text);
      } else {
        setState(() { msg.sending = false; msg.failed = true; _status = result; });
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
    final replyToUid = _replyTo?.msgUid;
    final msg = _Msg('out', text, DateTime.now(), sending: true,
        msgUid: msgUid,
        replyTo: replyToUid,
        burnAt: _ghost
            ? DateTime.now().millisecondsSinceEpoch + _burnSeconds * 1000
            : null);
    setState(() {
      _messages.add(msg);
      _sending = true;
      _status = '';
      _replyTo = null;
    });
    _msgCtrl.clear();
    _scrollToEnd();
    final String cipher;
    try {
      final wrapped = await wrapMessage(text, burnSeconds: _ghost ? _burnSeconds : null, msgUid: msgUid, replyTo: replyToUid, sender: SenderInfo(
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
    setState(() { _sending = false; _status = ''; });
    // before the peer back-pairs with us, force direct-onion so their
    // drain triggers the back-pair flow. nostr would dead-end because
    // they aren't subscribed to our xpub yet. once we receive anything
    // from them, _backPaired flips and we can use nostr.
    // try direct tor first if peer hasn't back-paired and we have their onion.
    // on tor failure / timeout, fall back to nostr store-and-forward.
    final sendFuture = Future<String>(() async {
      String? tor;
      if (!_backPaired && widget.peerOnion.isNotEmpty) {
        tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
        if (tor == 'ok') return 'ok';
        debugPrint('chat send: tor direct failed (\$tor), trying nostr');
      }
      if (_peerXPub != null) {
        return await Future(() => engine.nostrSend(_peerXPub!, cipher));
      }
      return tor ?? 'error: no transport';
    });
    sendFuture.then((result) async {
      if (!mounted) return;
      if (result == 'ok') {
        setState(() => msg.sending = false);
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
        });
        await db.saveMessage(widget.peerHaloId, 'out', text,
            burnAt: _ghost
                ? DateTime.now().millisecondsSinceEpoch + _burnSeconds * 1000
                : null,
            msgUid: msgUid,
            replyTo: replyToUid);
      } else {
        setState(() { msg.sending = false; msg.failed = true; _status = result; });
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
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _renameContact() async {
    final ctrl = TextEditingController(text: _nickname ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HaloColors.surface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('name this contact',
                style: HaloType.serif(size: 20, italic: true, color: HaloColors.amber)),
            const SizedBox(height: 4),
            Text(widget.peerHaloId,
                style: HaloType.mono(size: 11, color: HaloColors.text3)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              cursorColor: HaloColors.amber,
              style: HaloType.sans(size: 15),
              decoration: InputDecoration(
                hintText: 'what should i call them?',
                hintStyle: HaloType.serif(size: 15, italic: true, color: HaloColors.text3),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.line2),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.amber),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if ((_nickname ?? '').isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, ''),
                    child: Text('remove',
                        style: HaloType.sans(size: 13, color: HaloColors.text2)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: Text('save',
                      style: HaloType.sans(size: 14, weight: FontWeight.w500, color: HaloColors.amber)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final t = result.trim();
    await db.setNickname(widget.peerHaloId, t.isEmpty ? null : t);
    if (mounted) setState(() => _nickname = t.isEmpty ? null : t);
  }

  @override
  Widget build(BuildContext context) {
    final searchActive = _searching && _query.isNotEmpty;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _searching
                ? _SearchHead(
                    controller: _searchCtrl,
                    matchCount: _matches.length,
                    matchPos: _matches.isEmpty ? 0 : _matchPos + 1,
                    onChanged: _onQueryChanged,
                    onPrev: () => _gotoMatch(-1),
                    onNext: () => _gotoMatch(1),
                    onClose: _closeSearch,
                  )
                : _ChatHead(
                    haloId: widget.peerHaloId,
                    nickname: _nickname,
                    avatarSeed: widget.avatarSeed,
                    onBack: () => Navigator.pop(context),
                    onSearch: _openSearch,
                    onRename: _renameContact,
                  ),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyConversation()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (c, i) {
                        final m = _messages[i];
                        String? quoted;
                        String? quotedAuthor;
                        if (m.replyTo != null) {
                          final original = _messages.firstWhere(
                            (x) => x.msgUid == m.replyTo,
                            orElse: () => _Msg('', '', DateTime.now()),
                          );
                          if (original.text.isNotEmpty) {
                            quoted = original.text;
                            quotedAuthor =
                                original.direction == 'out' ? 'you' : 'them';
                          } else {
                            quoted = 'message unavailable';
                          }
                        }
                        final isMatch = searchActive && _matches.contains(i);
                        final isCurrent = searchActive &&
                            _matches.isNotEmpty &&
                            _matches[_matchPos] == i;
                        final dimmed = searchActive && !isMatch;
                        return _Bubble(
                          key: isMatch ? _matchKeys[i] : null,
                          msg: m,
                          onRetry: _retry,
                          onLongPress: (ctx) =>
                              _showEmojiPickerAt(ctx, m),
                          quotedText: quoted,
                          quotedAuthor: quotedAuthor,
                          query: searchActive ? _query : '',
                          isCurrentMatch: isCurrent,
                          dimmed: dimmed,
                        );
                      },
                    ),
            ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(_friendlyStatus(_status),
                    style: HaloType.mono(size: 10, color: HaloColors.text3)),
              ),
            if (_replyTo != null) _ReplyQuoteBar(
              target: _replyTo!,
              onCancel: () => setState(() => _replyTo = null),
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
  final String? nickname;
  final String avatarSeed;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onRename;
  const _ChatHead({
    required this.haloId,
    this.nickname,
    required this.avatarSeed,
    required this.onBack,
    required this.onSearch,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
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
            child: GestureDetector(
              onTap: onRename,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(nickname ?? haloId,
                        key: ValueKey<String>(nickname ?? haloId),
                        style: HaloType.sans(size: 14, weight: FontWeight.w500)),
                  ),
                  Text(nickname != null ? haloId : 'onion',
                      style: HaloType.mono(size: 10, color: HaloColors.text2)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded,
                color: HaloColors.text2, size: 21),
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

// search bar that replaces the chat header when search is active. slides
// + fades in. magnifier glyph, italic-serif hint, mono match counter, and
// up/down chevrons to jump between hits. matches the search_mockup spec.
class _SearchHead extends StatefulWidget {
  final TextEditingController controller;
  final int matchCount;
  final int matchPos; // 1-based; 0 when no matches
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;
  const _SearchHead({
    required this.controller,
    required this.matchCount,
    required this.matchPos,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  @override
  State<_SearchHead> createState() => _SearchHeadState();
}

class _SearchHeadState extends State<_SearchHead> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = widget.controller.text.trim().isNotEmpty;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -10 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 11),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: HaloColors.line, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: HaloColors.text2, size: 20),
                  onPressed: widget.onClose,
                ),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: HaloColors.line2, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            size: 15, color: HaloColors.amber),
                        const SizedBox(width: 9),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            onChanged: widget.onChanged,
                            cursorColor: HaloColors.amber,
                            cursorWidth: 1.5,
                            style: HaloType.sans(
                                size: 13, color: HaloColors.text),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'find in conversation',
                              hintStyle: HaloType.serif(
                                  size: 13,
                                  italic: true,
                                  color: HaloColors.text3),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: hasQuery
                  ? Padding(
                      key: const ValueKey('search-meta'),
                      padding: const EdgeInsets.fromLTRB(6, 9, 6, 0),
                      child: Row(
                        children: [
                          Text.rich(
                            TextSpan(
                              style: HaloType.mono(
                                  size: 10, color: HaloColors.text2),
                              children: [
                                TextSpan(
                                  text: widget.matchCount == 0
                                      ? 'no matches'
                                      : '${widget.matchPos}',
                                  style: HaloType.mono(
                                      size: 10,
                                      color: widget.matchCount == 0
                                          ? HaloColors.text3
                                          : HaloColors.amber,
                                      weight: FontWeight.w500),
                                ),
                                if (widget.matchCount > 0)
                                  TextSpan(
                                      text:
                                          ' of ${widget.matchCount} ${widget.matchCount == 1 ? 'match' : 'matches'}'),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _NavBtn(
                            icon: Icons.keyboard_arrow_up_rounded,
                            enabled: widget.matchCount > 0,
                            onTap: widget.onPrev,
                          ),
                          const SizedBox(width: 5),
                          _NavBtn(
                            icon: Icons.keyboard_arrow_down_rounded,
                            enabled: widget.matchCount > 0,
                            onTap: widget.onNext,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// small up/down chevron button for the search match navigator.
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: enabled ? HaloColors.amberSoft : HaloColors.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: enabled
                ? HaloColors.amber.withOpacity(0.45)
                : HaloColors.line2,
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 16,
            color: enabled ? HaloColors.amber : HaloColors.text3),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final void Function(_Msg)? onRetry;
  final void Function(BuildContext)? onLongPress;
  final String? quotedText;
  final String? quotedAuthor;
  // search context: the live query (empty when not searching), whether
  // this bubble is the current hit (gets a soft amber halo), and whether
  // it should dim (search active but this isn't a match).
  final String query;
  final bool isCurrentMatch;
  final bool dimmed;
  const _Bubble({
    super.key,
    required this.msg,
    this.onRetry,
    this.onLongPress,
    this.quotedText,
    this.quotedAuthor,
    this.query = '',
    this.isCurrentMatch = false,
    this.dimmed = false,
  });

  // builds the message body, underlining query matches in amber. plain
  // Text when there's no active query.
  Widget _body(bool isOut) {
    final base = HaloType.sans(
      size: 14,
      color: isOut ? HaloColors.onAmber : HaloColors.text,
      height: 1.4,
    );
    if (query.isEmpty) {
      return Text(msg.text, style: base);
    }
    final text = msg.text;
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final hit = lower.indexOf(q, start);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (hit > start) {
        spans.add(TextSpan(text: text.substring(start, hit)));
      }
      spans.add(TextSpan(
        text: text.substring(hit, hit + q.length),
        style: TextStyle(
          color: isOut ? HaloColors.onAmber : HaloColors.amber,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: isOut ? HaloColors.onAmber : HaloColors.amber,
          decorationThickness: 1.5,
        ),
      ));
      start = hit + q.length;
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }

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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      opacity: isExpiring ? 0.0 : (dimmed ? 0.28 : 1.0),
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
                border: isCurrentMatch
                    ? Border.all(color: HaloColors.amber, width: 1)
                    : null,
                boxShadow: isCurrentMatch
                    ? [
                        BoxShadow(
                          color: HaloColors.amber.withOpacity(0.28),
                          blurRadius: 22,
                          spreadRadius: -4,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (quotedText != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
                      decoration: BoxDecoration(
                        color: isOut
                            ? Colors.black.withOpacity(0.12)
                            : HaloColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isOut
                                ? HaloColors.onAmber.withValues(alpha: 0.55)
                                : HaloColors.amber,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (quotedAuthor != null)
                            Text(
                              quotedAuthor!,
                              style: HaloType.mono(
                                size: 9.5,
                                color: isOut
                                    ? HaloColors.onAmber.withValues(alpha: 0.7)
                                    : HaloColors.amber,
                                letter: 0.6,
                              ),
                            ),
                          if (quotedAuthor != null) const SizedBox(height: 2),
                          Text(
                            quotedText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 12.5,
                              color: isOut
                                  ? HaloColors.onAmber.withValues(alpha: 0.8)
                                  : HaloColors.text2,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _body(isOut),
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
                        if (msg.edited) ...[
                          const SizedBox(width: 5),
                          Text('edited',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                color: metaColor,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.4,
                              )),
                        ],
                        const SizedBox(width: 3),
                        Text('✓', style: TextStyle(fontSize: 11, color: metaColor, fontWeight: FontWeight.w700, height: 1)),
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
              Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SendPill(mode: _pmFrom(appState.sendMode)),
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

// thin bar shown above the composer when the user is in the middle of
// composing a reply. shows a snippet of the target message + an X to
// cancel. tap the bar itself to keep editing.
class _ReplyQuoteBar extends StatelessWidget {
  final _Msg target;
  final VoidCallback onCancel;
  const _ReplyQuoteBar({required this.target, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: const BoxDecoration(
        color: HaloColors.surface2,
        border: Border(
          top: BorderSide(color: HaloColors.line, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // amber accent stripe to mark this as a quote
          Container(
            width: 2.5,
            height: 32,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: HaloColors.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'replying to ${target.direction == 'out' ? 'yourself' : 'them'}',
                  style: HaloType.mono(
                      size: 9.5, color: HaloColors.amber, letter: 0.6),
                ),
                const SizedBox(height: 2),
                Text(
                  target.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                      size: 13, color: HaloColors.text2, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: HaloColors.text3,
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          ),
        ],
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
  final VoidCallback onReply;
  const _EmojiPickerBubble({
    required this.emojis,
    required this.selected,
    required this.onPick,
    required this.onReply,
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
              children: [
                ...widget.emojis.map((e) {
                  final isSelected = e == widget.selected;
                  return _EmojiTap(
                    emoji: e,
                    selected: isSelected,
                    onTap: () => widget.onPick(e),
                  );
                }),
                Container(
                  width: 0.5,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: HaloColors.line2,
                ),
                _ActionTap(
                  icon: Icons.reply_rounded,
                  onTap: widget.onReply,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// icon-based tappable button used in the reaction picker for "reply" etc.
// shares the visual language of _EmojiTap but renders an icon.
class _ActionTap extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionTap({required this.icon, required this.onTap});
  @override
  State<_ActionTap> createState() => _ActionTapState();
}

class _ActionTapState extends State<_ActionTap> {
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
            color: HaloColors.surface3,
            border: Border.all(color: HaloColors.line, width: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 20, color: HaloColors.amber),
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

// map the saved mode string to the pill's enum. private = full tor (3 hops),
// the real route for every message today.
PrivacyMode _pmFrom(String m) => m == 'fast'
    ? PrivacyMode.fast
    : m == 'normal'
        ? PrivacyMode.normal
        : PrivacyMode.private;
