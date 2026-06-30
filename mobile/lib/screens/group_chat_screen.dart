// SPDX-License-Identifier: GPL-3.0-or-later
// group chat. supports text + reply + reactions + ghost mode. mirrors the
// 1:1 chat ux as closely as possible so the user never has to relearn
// gestures.

import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show appState, db, currentChatPeer, newMsgUid;
import '../theme.dart';
import '../widgets/halo_avatar.dart';
import 'group_info_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_GMsg> _messages = [];
  String _groupName = '';
  int _memberCount = 0;
  bool _isAdmin = false;
  bool _sending = false;
  _GMsg? _replyTo;
  // ghost mode - per-session, not persisted. when on, new messages carry a
  // burn timer; receivers compute the burn deadline locally.
  bool _ghost = false;
  int _burnSeconds = 300; // 5 min default, same as 1:1
  Timer? _burnTick;
  bool _loading = false;
  bool _reloadQueued = false;
  bool _loaded = false; // first full load done - gates the append-fast-path

  @override
  void initState() {
    super.initState();
    currentChatPeer = 'group:${widget.groupId}';
    _load();
    appState.addListener(_onAppStateChanged);
    _burnTick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      bool any = false;
      for (final m in _messages) {
        if (m.burnAt != null) any = true;
      }
      if (any && mounted) {
        // grace period of 500ms so the fade-out animation finishes. also
        // delete the db row, else the message reappears on the next reload.
        final dead = _messages
            .where((m) => m.burnAt != null && m.burnAt! + 500 <= now)
            .toList();
        for (final m in dead) {
          if (m.msgUid != null) db.deleteMessage(m.msgUid!);
        }
        setState(() {
          _messages.removeWhere(
            (m) => m.burnAt != null && m.burnAt! + 500 <= now,
          );
        });
      }
    });
  }

  Future<void> _load() async {
    _loading = true;
    final g = await db.getGroup(widget.groupId);
    final members = await db.getGroupMembers(widget.groupId);
    final rows = await db.loadGroupMessages(widget.groupId);
    // gather reactions for every uid we have
    final uids = rows
        .map((r) => r['msg_uid'] as String?)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .toList();
    final reactions = await db.loadReactionsFor(uids);
    // local nickname is the display source of truth. fall back to the 3-word
    // id when we have no nickname for that member.
    final nickById = <String, String>{};
    for (final c in appState.contacts) {
      final n = c.nickname;
      if (n != null && n.isNotEmpty) nickById[c.haloId] = n;
    }
    if (!mounted) return;
    setState(() {
      _groupName = (g?['name'] as String?) ?? 'group';
      _memberCount = members.length;
      _isAdmin = ((g?['is_admin'] as int?) ?? 0) == 1;
      _messages
        ..clear()
        ..addAll(
          rows.map((r) {
            final uid = r['msg_uid'] as String?;
            final rxMap = <String, String>{};
            if (uid != null && reactions[uid] != null) {
              for (final e in reactions[uid]!) {
                rxMap[e.key] = e.value;
              }
            }
            final dir = r['direction'] as String;
            final m = _GMsg(
              sender: r['peer_id'] as String,
              senderName: nickById[r['peer_id'] as String],
              direction: dir,
              text: r['plaintext'] as String,
              when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
              burnAt: r['burn_at'] as int?,
              msgUid: uid,
              replyTo: r['reply_to'] as String?,
              sending: dir == 'out' && (r['sent'] as int? ?? 1) == 0,
              reactions: rxMap,
            );
            m.rowid = (r['rowid'] as int?) ?? 0;
            // a reloaded sending out-message is dead - its send future didn't
            // survive the reload. flip to failed for tap-to-retry, not a
            // stuck sending zombie.
            if (m.direction == 'out' && m.sending) {
              m.sending = false;
              m.failed = true;
            }
            return m;
          }),
        );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    _loading = false;
    _loaded = true;
    // if changes landed while we were loading, run exactly one catch-up pass.
    if (_reloadQueued) {
      _reloadQueued = false;
      _load();
    }
  }

  void _onAppStateChanged() {
    // a group control or new message landed. guard against the reload storm:
    // a single multicast fires notifyListeners() once per recipient, and a full
    // _load() per fire froze the ui. if a load is already running, queue at most
    // one follow-up instead of stacking N of them.
    if (_loading) {
      _reloadQueued = true;
      return;
    }
    _tryAppendNew();
  }

  // append-fast-path: pull only rows newer than our max rowid and add the
  // brand-new ones, instead of rebuilding the whole list on every multicast
  // fire. falls back to a full _load when nothing is brand-new, which covers
  // reactions/edits/burns/deletes and clock-skew.
  Future<void> _tryAppendNew() async {
    if (!_loaded) {
      _load();
      return;
    }
    final lastRowid = _messages.isEmpty
        ? 0
        : _messages.map((m) => m.rowid).reduce((a, b) => a > b ? a : b);
    final rows = await db.groupMessagesAfter(widget.groupId, lastRowid);
    if (!mounted) return;
    final have = _messages.map((m) => m.msgUid).toSet();
    final brandNew = rows
        .where(
          (r) =>
              (r['msg_uid'] as String?) != null &&
              !have.contains(r['msg_uid'] as String?),
        )
        .toList();
    if (brandNew.isEmpty) {
      _load();
      return;
    }
    final nickById = <String, String>{};
    for (final c in appState.contacts) {
      final n = c.nickname;
      if (n != null && n.isNotEmpty) nickById[c.haloId] = n;
    }
    final uids = brandNew
        .map((r) => r['msg_uid'] as String?)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .toList();
    final reactions = await db.loadReactionsFor(uids);
    if (!mounted) return;
    final fresh = <_GMsg>[];
    for (final r in brandNew) {
      final uid = r['msg_uid'] as String?;
      final rxMap = <String, String>{};
      if (uid != null && reactions[uid] != null) {
        for (final e in reactions[uid]!) {
          rxMap[e.key] = e.value;
        }
      }
      final dir = r['direction'] as String;
      final m = _GMsg(
        sender: r['peer_id'] as String,
        senderName: nickById[r['peer_id'] as String],
        direction: dir,
        text: r['plaintext'] as String,
        when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
        burnAt: r['burn_at'] as int?,
        msgUid: uid,
        replyTo: r['reply_to'] as String?,
        sending: dir == 'out' && (r['sent'] as int? ?? 1) == 0,
        reactions: rxMap,
      );
      m.rowid = (r['rowid'] as int?) ?? 0;
      fresh.add(m);
    }
    setState(() => _messages.addAll(fresh));
    _scrollToEnd();
  }

  void _scrollToEnd() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    final uid = newMsgUid();
    final replyToUid = _replyTo?.msgUid;
    final burnSeconds = _ghost ? _burnSeconds : null;
    final optimistic = _GMsg(
      sender: appState.myId,
      direction: 'out',
      text: text,
      when: DateTime.now(),
      msgUid: uid,
      replyTo: replyToUid,
      sending: true,
      burnSecs: burnSeconds,
      burnAt: _ghost
          ? DateTime.now().millisecondsSinceEpoch + _burnSeconds * 1000
          : null,
    );
    setState(() {
      _messages.add(optimistic);
      _replyTo = null;
    });
    _scrollToEnd();
    var ok = false;
    try {
      ok = await appState.sendToGroup(
        widget.groupId,
        text,
        msgUid: uid,
        replyTo: replyToUid,
        burnSeconds: burnSeconds,
      );
    } catch (e) {
      debugPrint('group send failed: $e');
    } finally {
      // always release the composer - a throw here used to leave _sending
      // stuck true, which silently killed every later send.
      if (mounted) {
        setState(() {
          _sending = false;
          optimistic.sending = false;
          // no member acknowledged - mark failed for tap-to-retry.
          optimistic.failed = !ok;
        });
      }
    }
  }

  // re-send a failed group message, reusing its uid/reply/burn so it stays
  // the same logical message.
  Future<void> _retryGroup(_GMsg m) async {
    if (m.msgUid == null) return;
    setState(() {
      m.failed = false;
      m.sending = true;
    });
    var ok = false;
    try {
      ok = await appState.sendToGroup(
        widget.groupId,
        m.text,
        msgUid: m.msgUid,
        replyTo: m.replyTo,
        burnSeconds: m.burnSecs,
      );
    } catch (e) {
      debugPrint('group retry failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          m.sending = false;
          m.failed = !ok;
        });
      }
    }
  }

  Future<void> _toggleReaction(_GMsg target, String emoji) async {
    if (target.msgUid == null) return;
    final current = target.reactions[''];
    final isUnreact = current == emoji;
    final newEmoji = isUnreact ? '' : emoji;
    await appState.reactInGroup(widget.groupId, target.msgUid!, newEmoji);
    // local state update happens via appState listener reload.
  }

  void _showBurnPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) {
        const options = [
          (30, '30 seconds'),
          (60, '1 minute'),
          (300, '5 minutes'),
          (3600, '1 hour'),
          (86400, '24 hours'),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HaloColors.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'burn timer',
                style: HaloType.serif(
                  size: 16,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'new messages disappear after this',
                style: HaloType.sans(size: 11, color: HaloColors.text3),
              ),
              const SizedBox(height: 12),
              for (final opt in options)
                InkWell(
                  onTap: () {
                    setState(() => _burnSeconds = opt.$1);
                    Navigator.pop(c);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt.$2,
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        if (opt.$1 == _burnSeconds)
                          Icon(
                            Icons.check_rounded,
                            color: HaloColors.amber,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEmojiPickerAt(BuildContext bubbleCtx, _GMsg target) async {
    if (target.msgUid == null) return;
    final renderBox = bubbleCtx.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final showAbove = pos.dy > 120;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    void dismiss() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: dismiss,
                child: Container(color: Colors.black.withOpacity(0.18)),
              ),
            ),
            Positioned(
              left: pos.dx,
              top: showAbove ? pos.dy - 64 : pos.dy + size.height + 8,
              child: Material(
                color: Colors.transparent,
                child: _EmojiPickerBubble(
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
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(entry);
  }

  @override
  void dispose() {
    if (currentChatPeer == 'group:${widget.groupId}') currentChatPeer = null;
    appState.removeListener(_onAppStateChanged);
    _burnTick?.cancel();
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
            _Header(
              name: _groupName,
              memberCount: _memberCount,
              onBack: () => Navigator.of(context).pop(),
              onTapInfo: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupInfoScreen(groupId: widget.groupId),
                  ),
                );
                _load();
              },
            ),
            if (_ghost)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: HaloColors.amberSoft,
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: HaloColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ghost mode on · burns in ${_fmtBurn(_burnSeconds)}',
                      style: HaloType.mono(
                        size: 10,
                        color: HaloColors.amber,
                        letter: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            Divider(height: 0.5, color: HaloColors.line, thickness: 0.5),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        _isAdmin
                            ? 'group created. say hi.'
                            : 'no messages yet.',
                        style: HaloType.serif(
                          size: 14,
                          italic: true,
                          color: HaloColors.text3,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final prev = i > 0 ? _messages[i - 1] : null;
                        final showSender =
                            m.direction == 'in' &&
                            (prev == null ||
                                prev.sender != m.sender ||
                                prev.direction != 'in');
                        String? quoted;
                        String? quotedAuthor;
                        if (m.replyTo != null) {
                          final orig = _messages.firstWhere(
                            (x) => x.msgUid == m.replyTo,
                            orElse: () => _GMsg(
                              sender: '',
                              direction: '',
                              text: '',
                              when: DateTime.now(),
                            ),
                          );
                          if (orig.text.isNotEmpty) {
                            quoted = orig.text;
                            quotedAuthor = orig.direction == 'out'
                                ? 'you'
                                : orig.sender;
                          } else {
                            quoted = 'message unavailable';
                          }
                        }
                        return _GroupBubble(
                          m: m,
                          showSender: showSender,
                          quotedText: quoted,
                          quotedAuthor: quotedAuthor,
                          onLongPress: (ctx) => _showEmojiPickerAt(ctx, m),
                        );
                      },
                    ),
            ),
            if (_replyTo != null)
              _ReplyQuoteBar(
                target: _replyTo!,
                onCancel: () => setState(() => _replyTo = null),
              ),
            _Composer(
              controller: _msgCtrl,
              sending: _sending,
              ghost: _ghost,
              onToggleGhost: () => setState(() => _ghost = !_ghost),
              onLongPressGhost: _showBurnPicker,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtBurn(int s) {
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m';
  if (s < 86400) return '${s ~/ 3600}h';
  return '${s ~/ 86400}d';
}

class _GMsg {
  final String sender;
  final String senderName;
  final String direction;
  String text;
  final DateTime when;
  int? burnAt;
  int? burnSecs; // intended burn window; lit into burnAt on delivery
  final String? msgUid;
  final String? replyTo;
  bool sending;
  bool failed;
  int rowid = 0; // db insertion order, for append-fast-path
  final Map<String, String> reactions;
  _GMsg({
    required this.sender,
    String? senderName,
    required this.direction,
    required this.text,
    required this.when,
    this.burnAt,
    this.burnSecs,
    this.msgUid,
    this.replyTo,
    this.sending = false,
    this.failed = false,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? {},
       senderName = senderName ?? sender;
}

// ───────── header ─────────

class _Header extends StatelessWidget {
  final String name;
  final int memberCount;
  final VoidCallback onBack;
  final VoidCallback onTapInfo;
  const _Header({
    required this.name,
    required this.memberCount,
    required this.onBack,
    required this.onTapInfo,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: HaloColors.text, size: 26),
            onPressed: onBack,
          ),
          Expanded(
            child: InkWell(
              onTap: onTapInfo,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: HaloColors.amberSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: HaloColors.amber.withOpacity(0.35),
                          width: 0.6,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isEmpty
                            ? '·'
                            : name.characters.first.toUpperCase(),
                        style: HaloType.serif(
                          size: 18,
                          italic: true,
                          color: HaloColors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: HaloType.sans(
                              size: 15,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            ),
                          ),
                          Text(
                            '$memberCount members',
                            style: HaloType.mono(
                              size: 10,
                              color: HaloColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── composer + reply bar ─────────

class _ReplyQuoteBar extends StatelessWidget {
  final _GMsg target;
  final VoidCallback onCancel;
  const _ReplyQuoteBar({required this.target, required this.onCancel});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(width: 2.5, height: 32, color: HaloColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'replying to ${target.direction == "out" ? "you" : target.senderName}',
                  style: HaloType.mono(
                    size: 9.5,
                    color: HaloColors.amber,
                    letter: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  target.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(size: 12.5, color: HaloColors.text2),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: HaloColors.text2),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool ghost;
  final VoidCallback onToggleGhost;
  final VoidCallback onLongPressGhost;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.ghost,
    required this.onToggleGhost,
    required this.onLongPressGhost,
    required this.onSend,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleGhost,
            onLongPress: onLongPressGhost,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              child: Icon(
                Icons.local_fire_department_rounded,
                color: ghost ? HaloColors.amber : HaloColors.text3,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: HaloColors.amber.withOpacity(0.4),
                  width: 0.6,
                ),
              ),
              child: TextField(
                controller: controller,
                style: HaloType.sans(size: 14, color: HaloColors.text),
                cursorColor: HaloColors.amber,
                decoration: InputDecoration(
                  hintText: 'message',
                  hintStyle: HaloType.sans(size: 14, color: HaloColors.text3),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: HaloColors.amber,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_upward_rounded,
                color: HaloColors.onAmber,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── bubble ─────────

class _GroupBubble extends StatelessWidget {
  final _GMsg m;
  final bool showSender;
  final String? quotedText;
  final String? quotedAuthor;
  final void Function(BuildContext)? onLongPress;
  const _GroupBubble({
    required this.m,
    required this.showSender,
    this.quotedText,
    this.quotedAuthor,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = m.direction == 'out';
    // burn fade-out: dim + scale toward end of life
    final now = DateTime.now().millisecondsSinceEpoch;
    final fadeOut = m.burnAt != null && now > m.burnAt! - 500;
    return AnimatedOpacity(
      opacity: fadeOut ? 0 : 1,
      curve: Curves.easeInCubic,
      duration: const Duration(milliseconds: 500),
      child: AnimatedScale(
        scale: fadeOut ? 0.88 : 1,
        duration: const Duration(milliseconds: 500),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isOut
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isOut && showSender)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                  child: HaloAvatar(seed: m.sender, size: 26),
                ),
              if (!isOut && !showSender) const SizedBox(width: 32),
              Flexible(
                child: Column(
                  crossAxisAlignment: isOut
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isOut && showSender)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 3),
                        child: Text(
                          m.senderName,
                          style: HaloType.mono(
                            size: 9.5,
                            color: HaloColors.amber,
                            letter: 0.4,
                          ),
                        ),
                      ),
                    Builder(
                      builder: (ctx) {
                        return GestureDetector(
                          onLongPress: onLongPress == null
                              ? null
                              : () => onLongPress!(ctx),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                            decoration: BoxDecoration(
                              color: isOut
                                  ? HaloColors.amber
                                  : HaloColors.surface2,
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
                                if (quotedText != null) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      6,
                                      10,
                                      7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? Colors.black.withOpacity(0.12)
                                          : HaloColors.surface3,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border(
                                        left: BorderSide(
                                          color: isOut
                                              ? HaloColors.onAmber.withValues(
                                                  alpha: 0.55,
                                                )
                                              : HaloColors.amber,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (quotedAuthor != null)
                                          Text(
                                            quotedAuthor!,
                                            style: HaloType.mono(
                                              size: 9.5,
                                              color: isOut
                                                  ? HaloColors.onAmber
                                                        .withValues(alpha: 0.7)
                                                  : HaloColors.amber,
                                              letter: 0.6,
                                            ),
                                          ),
                                        if (quotedAuthor != null)
                                          const SizedBox(height: 2),
                                        Text(
                                          quotedText!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: HaloType.sans(
                                            size: 12.5,
                                            color: isOut
                                                ? HaloColors.onAmber.withValues(
                                                    alpha: 0.8,
                                                  )
                                                : HaloColors.text2,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Text(
                                  m.text,
                                  style: HaloType.sans(
                                    size: 14,
                                    color: isOut
                                        ? HaloColors.onAmber
                                        : HaloColors.text,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (m.burnAt != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOut
                                              ? HaloColors.onAmber.withOpacity(
                                                  0.15,
                                                )
                                              : HaloColors.amberSoft,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '🔥 ${_remaining(m.burnAt!)}',
                                          style: HaloType.mono(
                                            size: 9,
                                            color: isOut
                                                ? HaloColors.onAmber
                                                : HaloColors.amber,
                                            letter: 0.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      _fmtTime(m.when),
                                      style: HaloType.mono(
                                        size: 9.5,
                                        color: isOut
                                            ? HaloColors.onAmber.withOpacity(
                                                0.7,
                                              )
                                            : HaloColors.text3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (m.reactions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _buildReactionChips(m),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReactionChips(_GMsg m) {
    final counts = <String, int>{};
    for (final emoji in m.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final selfEmoji = m.reactions[''];
    return counts.entries.map<Widget>((e) {
      final isSelf = e.key == selfEmoji;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelf ? HaloColors.amberSoft : HaloColors.surface3,
          border: Border.all(
            color: isSelf ? HaloColors.amber : HaloColors.line2,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.key, style: const TextStyle(fontSize: 12)),
            if (e.value > 1) ...[
              const SizedBox(width: 3),
              Text(
                '${e.value}',
                style: HaloType.mono(
                  size: 9.5,
                  color: isSelf ? HaloColors.amber : HaloColors.text3,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _remaining(int burnAt) {
    final ms = burnAt - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return '0s';
    final s = ms ~/ 1000;
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m';
    if (s < 86400) return '${s ~/ 3600}h';
    return '${s ~/ 86400}d';
  }
}

// ───────── reaction picker ─────────

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
      duration: const Duration(milliseconds: 180),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_ctrl);
    final fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: fade.value,
        child: Transform.scale(
          scale: scale.value,
          alignment: Alignment.bottomLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: HaloColors.line, width: 0.5),
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
                _ActionTap(icon: Icons.reply_rounded, onTap: widget.onReply),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
            color: widget.selected ? HaloColors.amberSoft : Colors.transparent,
            border: widget.selected
                ? Border.all(color: HaloColors.amber, width: 1.2)
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(widget.emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

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
