// chat screen. message bubbles, composer, live receive over tor.
// matches 08_complete_spec.html "the everyday" chat tile.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'key_verification_screen.dart';
import '../signal_session.dart';
import '../message_envelope.dart'
    show
        wrapMessage,
        unwrapMessage,
        SenderInfo,
        ReactionFrame,
        EditFrame,
        savePeerEndpoint,
        loadPeerEndpoint;
import '../theme.dart';
import '../widgets/halo_avatar.dart';
import '../main.dart'
    show engine, db, signalEncrypt, signalDecrypt, appState, currentChatPeer;
import '../widgets/motion.dart';

// persists last-seen cipher per peer across ChatScreen instances
final Map<String, String> _seenCipherPerPeer = {};
// unsent drafts kept per peer so text survives leaving a chat.
final Map<String, String> _draftPerPeer = {};
// newest message ms seen when the chat was last left, per peer.
final Map<String, int> _lastReadPerPeer = {};

class ChatScreen extends StatefulWidget {
  final String peerHaloId;
  final String peerOnion;
  final String peerXPub;
  final String avatarSeed;
  final String? initialText;

  const ChatScreen({
    super.key,
    required this.peerHaloId,
    required this.peerOnion,
    required this.peerXPub,
    required this.avatarSeed,
    this.initialText,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Msg {
  final String direction;
  String text;
  final DateTime when;
  int? burnAt;
  int? burnSecs; // intended burn window; lit into burnAt on delivery.
  String? msgUid;
  // msg_uid of the message this one replies to, or null.
  final String? replyTo;
  bool sending;
  bool failed;
  bool edited;
  bool pinned;
  bool removing;
  String? mediaPath;
  Map<String, String> reactions;
  _Msg(
    this.direction,
    this.text,
    this.when, {
    this.burnAt,
    this.burnSecs,
    this.msgUid,
    this.replyTo,
    this.sending = false,
    this.failed = false,
    this.edited = false,
    this.pinned = false,
    this.removing = false,
    this.mediaPath,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? <String, String>{};
}

void _openFullImage(BuildContext context, String path) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.file(File(path)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
  final h = s ~/ 3600;
  s -= h * 3600;
  final m = s ~/ 60;
  s -= m * 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  int _unreadAfterMs = 0;
  int _firstUnreadIndex = -1;
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
  bool _blocked = false;
  bool _muted = false;
  bool _verified = false;
  bool _showScrollDown = false;
  int _seenCount = 0;
  String? _rippleUid;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
    appState.loadSendMode();
    currentChatPeer = widget.peerHaloId;
    _unreadAfterMs =
        _lastReadPerPeer[widget.peerHaloId] ??
        DateTime.now().millisecondsSinceEpoch;
    if (widget.initialText != null) {
      _msgCtrl.text = widget.initialText!;
    } else {
      _msgCtrl.text = _draftPerPeer[widget.peerHaloId] ?? '';
    }
    db.getContact(widget.peerHaloId).then((c) {
      if (mounted) setState(() => _nickname = c?['nickname'] as String?);
    });
    signalSession.peerXPubHex(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _peerXPub = v);
    });
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    db.isBlocked(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _blocked = v);
    });
    db.isMuted(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _muted = v);
    });
    db.isVerified(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _verified = v);
    });
    _scrollCtrl.addListener(_onScroll);
    _lastCipher = _seenCipherPerPeer[widget.peerHaloId] ?? '';
    _loadMessages();
    _burnTick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final before = _messages.length;
      _messages.removeWhere((m) => m.burnAt != null && m.burnAt! + 500 <= now);
      final removed = before - _messages.length;
      final stillBurning = _messages.where((m) => m.burnAt != null).toList();
      if (stillBurning.isNotEmpty || removed > 0) {
        debugPrint('burnTick: removed=$removed burning=${stillBurning.length}');
      }
      if (removed > 0) HapticFeedback.lightImpact();
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

  Widget _newMessagesDivider() {
    final line = Container(
      height: 0.5,
      color: HaloColors.amber.withValues(alpha: 0.35),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'new messages',
              style: HaloType.mono(
                size: 9.5,
                color: HaloColors.amber,
                letter: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: HaloColors.amber.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
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
      final approx =
          (idx / _messages.length) * _scrollCtrl.position.maxScrollExtent;
      _scrollCtrl.jumpTo(
        approx.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      );
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
    BuildContext bubbleContext,
    _Msg target,
  ) async {
    HapticFeedback.selectionClick();
    // legacy messages (predating v5 migration) get a local uid assigned
    // on first reaction. peers won't know this uid so the reaction stays
    // local-only, but the UX works.
    if (target.msgUid == null) {
      final uid = _newMsgUid();
      target.msgUid = uid;
      await db.assignUidIfMissing(
        widget.peerHaloId,
        target.when.millisecondsSinceEpoch,
        uid,
      );
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

    entry = OverlayEntry(
      builder: (_) {
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
                      final added = target.reactions[''] != e;
                      _toggleReaction(target, e);
                      if (added) _flashReaction(target);
                    },
                    onReply: () {
                      dismiss();
                      setState(() => _replyTo = target);
                    },
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        dismiss();
                        HapticFeedback.selectionClick();
                        _forwardMessage(target);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: HaloColors.surface3,
                          border: Border.all(
                            color: HaloColors.line,
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'forward',
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        dismiss();
                        HapticFeedback.selectionClick();
                        _togglePin(target);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: HaloColors.surface3,
                          border: Border.all(
                            color: HaloColors.line,
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          target.pinned ? 'unpin' : 'pin',
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (target.direction == 'out') ...[
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          dismiss();
                          HapticFeedback.selectionClick();
                          _unsendMessage(target);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: HaloColors.surface3,
                            border: Border.all(
                              color: HaloColors.line,
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                size: 14,
                                color: HaloColors.rose,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'unsend',
                                style: HaloType.sans(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: HaloColors.rose,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: HaloColors.surface3,
                            border: Border.all(
                              color: HaloColors.line,
                              width: 0.5,
                            ),
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
                              const Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: HaloColors.amber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'edit',
                                style: HaloType.sans(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: HaloColors.amber,
                                ),
                              ),
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
      },
    );
    Overlay.of(context).insert(entry);
  }

  Future<void> _showPinnedSheet() async {
    final pinned = _messages.where((m) => m.pinned).toList();
    if (pinned.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'pinned messages',
                style: HaloType.mono(
                  size: 10,
                  color: HaloColors.text3,
                  letter: 0.14,
                ),
              ),
            ),
            for (final m in pinned)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToMessage(m);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.push_pin_outlined,
                        size: 14,
                        color: HaloColors.amber,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.sans(
                            size: 14,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _togglePin(m);
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: HaloColors.text3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _unsendMessage(_Msg m) async {
    if (m.msgUid == null) return;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'unsend message',
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                "it disappears with no trace. this can't be undone.",
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(ctx, true),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: HaloColors.rose,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'unsend',
                      style: HaloType.sans(size: 14, color: HaloColors.rose),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    if (mounted) setState(() => m.removing = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await db.deleteMessage(m.msgUid!);
    if (mounted) setState(() => _messages.remove(m));
  }

  Future<void> _togglePin(_Msg m) async {
    if (m.msgUid == null) return;
    if (!m.pinned) {
      final count = _messages.where((x) => x.pinned).length;
      if (count >= 3) {
        if (mounted) {
          showHaloToast(context, 'max 3 pinned');
        }
        return;
      }
    }
    await db.setPinned(m.msgUid!, !m.pinned);
    if (mounted) setState(() => m.pinned = !m.pinned);
  }

  void _scrollToMessage(_Msg m) {
    final idx = _messages.indexOf(m);
    if (idx < 0 || !_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final approx = (idx / _messages.length) * max;
    _scrollCtrl.animateTo(
      approx.clamp(0.0, max),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // 12-char base36 id from a high-precision timestamp + random salt.
  // collision-resistant enough for our scale.
  String _newMsgUid() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r =
        (DateTime.now().microsecondsSinceEpoch ^
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
        widget.peerHaloId,
        m.when.millisecondsSinceEpoch,
        uid,
      );
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
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'edit message',
              style: HaloType.serif(
                size: 20,
                italic: true,
                color: HaloColors.amber,
              ),
            ),
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
                  child: Text(
                    'cancel',
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: Text(
                    'save',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: HaloColors.amber,
                    ),
                  ),
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
        widget.peerHaloId,
        m.when.millisecondsSinceEpoch,
        uid,
      );
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
    db.isBlocked(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _blocked = v);
    });
    db.isMuted(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _muted = v);
    });
    final rows = await db.messagesFor(widget.peerHaloId);
    if (!mounted) return;
    // collect msg_uids first, batch-load reactions, then setState.
    final loaded = <_Msg>[];
    final uids = <String>[];
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      loaded.add(
        _Msg(
          r['direction'] as String,
          r['plaintext'] as String,
          DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
          burnAt: r['burn_at'] as int?,
          msgUid: uid,
          replyTo: r['reply_to'] as String?,
          edited: (r['edited'] as int? ?? 0) == 1,
          pinned: (r['pinned'] as int? ?? 0) == 1,
          mediaPath: r['media_path'] as String?,
        ),
      );
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
    _firstUnreadIndex = -1;
    for (var i = 0; i < loaded.length; i++) {
      if (loaded[i].direction != 'out' &&
          loaded[i].when.millisecondsSinceEpoch > _unreadAfterMs) {
        _firstUnreadIndex = i;
        break;
      }
    }
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
        _messages.add(
          _Msg(
            'in',
            plain,
            DateTime.now(),
            burnAt: env.burnSeconds != null && env.burnSeconds! > 0
                ? DateTime.now().millisecondsSinceEpoch +
                      env.burnSeconds! * 1000
                : null,
          ),
        );
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
      final wrapped = await wrapMessage(
        msg.text,
        sender: SenderInfo(
          haloId: appState.myId,
          edPub: engine.myEdPubkey(),
          onion: appState.myOnion,
          xPub: engine.myXPubkey(),
        ),
      );
      cipher = await signalEncrypt(widget.peerHaloId, wrapped);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.sending = false;
        msg.failed = true;
      });
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
        setState(() {
          msg.sending = false;
          if (msg.burnSecs != null) {
            msg.burnAt =
                DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
          }
        });
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
        });
        await db.saveMessage(widget.peerHaloId, 'out', msg.text);
      } else {
        setState(() {
          msg.sending = false;
          msg.failed = true;
          _status = result;
        });
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
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_outlined,
                    size: 14,
                    color: HaloColors.amber,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ghost timer',
                    style: HaloType.serif(
                      size: 16,
                      color: HaloColors.text,
                      italic: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'how long before sent messages burn?',
                style: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.value,
                            style: HaloType.sans(
                              size: 14,
                              color: isSelected
                                  ? HaloColors.amber
                                  : HaloColors.text,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: HaloColors.amber,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // resend a failed image: re-read the saved file, re-encrypt, and push it
  // back through the same tor-first-then-nostr path the first send used.
  // flash a one-shot amber ring on a bubble when a reaction lands on it.
  // _rippleUid clears after the animation so it only fires once.
  void _flashReaction(_Msg msg) {
    HapticFeedback.selectionClick();
    if (msg.msgUid == null) return;
    setState(() => _rippleUid = msg.msgUid);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_rippleUid == msg.msgUid) setState(() => _rippleUid = null);
    });
  }

  Future<void> _retryImage(_Msg msg) async {
    final path = msg.mediaPath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      setState(() => msg.failed = true);
      return;
    }
    setState(() {
      msg.failed = false;
      msg.sending = true;
    });
    final b64 = base64Encode(await file.readAsBytes());
    final msgUid = msg.msgUid ?? _newMsgUid();
    msg.msgUid = msgUid;
    final String cipher;
    try {
      final wrapped = await wrapMessage(
        '',
        msgUid: msgUid,
        imageB64: b64,
        sender: SenderInfo(
          haloId: appState.myId,
          edPub: engine.myEdPubkey(),
          onion: appState.myOnion,
          xPub: engine.myXPubkey(),
        ),
      );
      cipher = await signalEncrypt(widget.peerHaloId, wrapped);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.sending = false;
        msg.failed = true;
      });
      return;
    }
    final sendFuture = Future<String>(() async {
      String? tor;
      if (!_backPaired && widget.peerOnion.isNotEmpty) {
        tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
        if (tor == 'ok') return 'ok';
      }
      if (_peerXPub != null) {
        return await Future(() => engine.nostrSend(_peerXPub!, cipher));
      }
      return tor ?? 'error: no transport';
    });
    sendFuture.then((result) async {
      if (!mounted) return;
      if (result == 'ok') {
        setState(() {
          msg.sending = false;
          if (msg.burnSecs != null) {
            msg.burnAt =
                DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
          }
        });
        await db.saveMessage(
          widget.peerHaloId,
          'out',
          '',
          msgUid: msgUid,
          mediaPath: path,
        );
      } else {
        setState(() {
          msg.sending = false;
          msg.failed = true;
        });
      }
    });
  }

  // bottom sheet: camera or gallery, instead of jumping straight to gallery.
  void _showAttachSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        Widget tile(IconData icon, String label, ImageSource source) {
          return ListTile(
            leading: Icon(icon, color: HaloColors.amber, size: 22),
            title: Text(
              label,
              style: HaloType.sans(size: 15, color: HaloColors.text),
            ),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickAndSendImage(source);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HaloColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              tile(Icons.photo_camera_outlined, 'camera', ImageSource.camera),
              tile(
                Icons.photo_library_outlined,
                'gallery',
                ImageSource.gallery,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    // preview the photo and let the user add a caption before it sends.
    // back = cancel; the send button returns the caption (may be empty).
    final caption = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => _ImageCaptionScreen(bytes: bytes)),
    );
    if (caption == null) return;
    final msgUid = _newMsgUid();
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final mediaFile = File('${mediaDir.path}/$msgUid.jpg');
    await mediaFile.writeAsBytes(bytes);
    final mediaPath = mediaFile.path;
    final b64 = base64Encode(bytes);
    final msg = _Msg(
      'out',
      caption,
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      mediaPath: mediaPath,
      burnSecs: _ghost ? _burnSeconds : null,
    );
    setState(() {
      _messages.add(msg);
      _status = '';
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    final String cipher;
    try {
      final wrapped = await wrapMessage(
        caption,
        msgUid: msgUid,
        imageB64: b64,
        sender: SenderInfo(
          haloId: appState.myId,
          edPub: engine.myEdPubkey(),
          onion: appState.myOnion,
          xPub: engine.myXPubkey(),
        ),
      );
      cipher = await signalEncrypt(widget.peerHaloId, wrapped);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.sending = false;
        msg.failed = true;
      });
      return;
    }
    final sendFuture = Future<String>(() async {
      String? tor;
      if (!_backPaired && widget.peerOnion.isNotEmpty) {
        tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
        if (tor == 'ok') return 'ok';
      }
      if (_peerXPub != null) {
        return await Future(() => engine.nostrSend(_peerXPub!, cipher));
      }
      return tor ?? 'error: no transport';
    });
    sendFuture.then((result) async {
      if (!mounted) return;
      if (result == 'ok') {
        setState(() {
          msg.sending = false;
          if (msg.burnSecs != null) {
            msg.burnAt =
                DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
          }
        });
        await db.saveMessage(
          widget.peerHaloId,
          'out',
          caption,
          msgUid: msgUid,
          mediaPath: mediaPath,
          burnAt: msg.burnAt,
        );
      } else {
        setState(() {
          msg.sending = false;
          msg.failed = true;
          _status = result;
        });
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final msgUid = _newMsgUid();
    final replyToUid = _replyTo?.msgUid;
    final msg = _Msg(
      'out',
      text,
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      replyTo: replyToUid,
      burnSecs: _ghost ? _burnSeconds : null,
    );
    setState(() {
      _messages.add(msg);
      _sending = true;
      _status = '';
      _replyTo = null;
    });
    _msgCtrl.clear();
    _scrollToEnd();
    HapticFeedback.lightImpact();
    final String cipher;
    try {
      final wrapped = await wrapMessage(
        text,
        burnSeconds: _ghost ? _burnSeconds : null,
        msgUid: msgUid,
        replyTo: replyToUid,
        sender: SenderInfo(
          haloId: appState.myId,
          edPub: engine.myEdPubkey(),
          onion: appState.myOnion,
          xPub: engine.myXPubkey(),
        ),
      );
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
    setState(() {
      _sending = false;
      _status = '';
    });
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
        setState(() {
          msg.sending = false;
          if (msg.burnSecs != null) {
            msg.burnAt =
                DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
          }
        });
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
        });
        await db.saveMessage(
          widget.peerHaloId,
          'out',
          text,
          burnAt: msg.burnAt,
          msgUid: msgUid,
          replyTo: replyToUid,
        );
      } else {
        setState(() {
          msg.sending = false;
          msg.failed = true;
          _status = result;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _burnTick?.cancel();
    if (currentChatPeer == widget.peerHaloId) currentChatPeer = null;
    appState.removeListener(_onAppStateChanged);
    _lastReadPerPeer[widget.peerHaloId] = _messages.isNotEmpty
        ? _messages.last.when.millisecondsSinceEpoch
        : 0;
    final draft = _msgCtrl.text;
    if (draft.trim().isEmpty) {
      _draftPerPeer.remove(widget.peerHaloId);
    } else {
      _draftPerPeer[widget.peerHaloId] = draft;
    }
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _chatActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => Navigator.pop(ctx, 'verify'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: HaloColors.amber,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'verify safety number',
                      style: HaloType.sans(size: 14, color: HaloColors.text),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(ctx, 'mute'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Icon(
                      _muted
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      size: 18,
                      color: HaloColors.text2,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _muted ? 'unmute notifications' : 'mute notifications',
                      style: HaloType.sans(size: 14, color: HaloColors.text),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(ctx, 'archive'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.archive_outlined,
                      size: 18,
                      color: HaloColors.text2,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'archive chat',
                      style: HaloType.sans(size: 14, color: HaloColors.text),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(ctx, 'block'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block, size: 18, color: HaloColors.rose),
                    const SizedBox(width: 14),
                    Text(
                      'block contact',
                      style: HaloType.sans(size: 14, color: HaloColors.rose),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'verify') {
      _openKeyVerification();
    } else if (action == 'mute') {
      await _toggleMute();
    } else if (action == 'archive') {
      await appState.archive(widget.peerHaloId);
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'block') {
      await _blockContact();
    }
  }

  void _openKeyVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KeyVerificationScreen(
          peerHaloId: widget.peerHaloId,
          peerName: _nickname ?? widget.peerHaloId,
          myXpub: engine.myXPubkey(),
          peerXpub: widget.peerXPub,
        ),
      ),
    );
  }

  Future<void> _toggleMute() async {
    if (_muted) {
      await appState.unmute(widget.peerHaloId);
    } else {
      await appState.mute(widget.peerHaloId);
    }
    if (mounted) setState(() => _muted = !_muted);
  }

  Future<void> _blockContact() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.block, size: 15, color: HaloColors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'block this contact?',
                    style: HaloType.serif(
                      size: 18,
                      italic: true,
                      color: HaloColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'their messages stop arriving and they disappear from your chats. '
                "they're never told. you can unblock anytime from settings.",
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'cancel',
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'block',
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: HaloColors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    await appState.block(widget.peerHaloId);
    if (mounted) setState(() => _blocked = true);
  }

  Future<void> _unblockContact() async {
    await appState.unblock(widget.peerHaloId);
    if (mounted) setState(() => _blocked = false);
  }

  Future<void> _forwardMessage(_Msg m) async {
    final targets = appState.contacts.where((c) => !c.blocked).toList();
    final haloId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'forward to',
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
            ),
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  'no contacts to forward to',
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final c in targets)
                      InkWell(
                        onTap: () => Navigator.pop(ctx, c.haloId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              HaloAvatar(seed: c.avatarSeed, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  c.nickname ?? c.haloId,
                                  style: HaloType.sans(
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (haloId == null || !mounted) return;
    final row = await db.getContact(haloId);
    if (row == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerHaloId: haloId,
          peerOnion: (row['onion'] as String?) ?? '',
          peerXPub: (row['xpub'] as String?) ?? '',
          avatarSeed: haloId,
          initialText: m.text,
        ),
      ),
    );
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
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'name this contact',
              style: HaloType.serif(
                size: 20,
                italic: true,
                color: HaloColors.amber,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.peerHaloId,
              style: HaloType.mono(size: 11, color: HaloColors.text3),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              cursorColor: HaloColors.amber,
              style: HaloType.sans(size: 15),
              decoration: InputDecoration(
                hintText: 'what should i call them?',
                hintStyle: HaloType.serif(
                  size: 15,
                  italic: true,
                  color: HaloColors.text3,
                ),
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
                    child: Text(
                      'remove',
                      style: HaloType.sans(size: 13, color: HaloColors.text2),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: Text(
                    'save',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: HaloColors.amber,
                    ),
                  ),
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

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final show = (pos.maxScrollExtent - pos.pixels) > 240;
    if (!show) _seenCount = _messages.length;
    if (show != _showScrollDown && mounted) {
      setState(() => _showScrollDown = show);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    setState(() => _seenCount = _messages.length);
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateDivider(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(when.year, when.month, when.day);
    final diff = today.difference(d).inDays;
    String label;
    if (diff == 0) {
      label = 'today';
    } else if (diff == 1) {
      label = 'yesterday';
    } else {
      const months = [
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec',
      ];
      label = '${when.day} ${months[when.month - 1]}';
      if (when.year != now.year) label = '$label ${when.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          label,
          style: HaloType.serif(
            size: 12.5,
            italic: true,
            color: HaloColors.text3,
            weight: FontWeight.w300,
          ),
        ),
      ),
    );
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
                    verified: _verified,
                    onBlock: _chatActions,
                    avatarSeed: widget.avatarSeed,
                    onBack: () => Navigator.pop(context),
                    onSearch: _openSearch,
                    onRename: _renameContact,
                    pinnedCount: _messages.where((m) => m.pinned).length,
                    onPinned: _showPinnedSheet,
                  ),
            Expanded(
              child: Stack(
                children: [
                  _messages.isEmpty
                      ? const _EmptyConversation()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                                quotedAuthor = original.direction == 'out'
                                    ? 'you'
                                    : 'them';
                              } else {
                                quoted = 'message unavailable';
                              }
                            }
                            final isMatch =
                                searchActive && _matches.contains(i);
                            final isCurrent =
                                searchActive &&
                                _matches.isNotEmpty &&
                                _matches[_matchPos] == i;
                            final dimmed = searchActive && !isMatch;
                            final showDate =
                                i == 0 ||
                                !_sameDay(_messages[i - 1].when, m.when);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDate) _dateDivider(m.when),
                                if (i == _firstUnreadIndex)
                                  _newMessagesDivider(),
                                Dismissible(
                                  key: ObjectKey(m),
                                  direction: DismissDirection.startToEnd,
                                  dismissThresholds: const {
                                    DismissDirection.startToEnd: 0.28,
                                  },
                                  confirmDismiss: (_) async {
                                    HapticFeedback.selectionClick();
                                    setState(() => _replyTo = m);
                                    return false;
                                  },
                                  background: const Padding(
                                    padding: EdgeInsets.only(left: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Icon(
                                        Icons.reply_rounded,
                                        size: 20,
                                        color: HaloColors.amber,
                                      ),
                                    ),
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: AnimatedScale(
                                      scale: m.removing ? 0.92 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeIn,
                                      child: AnimatedOpacity(
                                        opacity: m.removing ? 0.0 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: _Bubble(
                                          key: isMatch ? _matchKeys[i] : null,
                                          msg: m,
                                          onRetry: (m) => m.mediaPath != null
                                              ? _retryImage(m)
                                              : _retry(m),
                                          onLongPress: (ctx) =>
                                              _showEmojiPickerAt(ctx, m),
                                          quotedText: quoted,
                                          quotedAuthor: quotedAuthor,
                                          query: searchActive ? _query : '',
                                          isCurrentMatch: isCurrent,
                                          dimmed: dimmed,
                                          ripple:
                                              m.msgUid != null &&
                                              m.msgUid == _rippleUid,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  if (_showScrollDown)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: _scrollToBottom,
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HaloColors.surface2,
                                  border: Border.all(
                                    color: HaloColors.amber.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: HaloColors.amber.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 14,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: HaloColors.amber,
                                  size: 22,
                                ),
                              ),
                            ),
                            if (_messages.length - _seenCount > 0)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 17,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HaloColors.amber,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: HaloColors.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${_messages.length - _seenCount}',
                                    style:
                                        HaloType.mono(
                                          size: 9,
                                          color: HaloColors.onAmber,
                                        ).copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _friendlyStatus(_status),
                  style: HaloType.mono(size: 10, color: HaloColors.text3),
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: _replyTo != null
                  ? _ReplyQuoteBar(
                      target: _replyTo!,
                      onCancel: () => setState(() => _replyTo = null),
                    )
                  : const SizedBox.shrink(),
            ),
            _blocked
                ? _BlockedBar(onUnblock: _unblockContact)
                : _Composer(
                    onAttach: _showAttachSheet,
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

class _BlockedBar extends StatelessWidget {
  final VoidCallback onUnblock;
  const _BlockedBar({required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, size: 15, color: HaloColors.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'you blocked this contact',
              style: HaloType.serif(
                size: 14,
                italic: true,
                color: HaloColors.text2,
              ),
            ),
          ),
          TextButton(
            onPressed: onUnblock,
            child: Text(
              'unblock',
              style: HaloType.sans(
                size: 14,
                weight: FontWeight.w500,
                color: HaloColors.amber,
              ),
            ),
          ),
        ],
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
  final VoidCallback onBlock;
  final int pinnedCount;
  final VoidCallback onPinned;
  final bool verified;
  const _ChatHead({
    required this.haloId,
    this.nickname,
    required this.avatarSeed,
    required this.onBack,
    required this.onSearch,
    required this.onRename,
    required this.onBlock,
    this.pinnedCount = 0,
    required this.onPinned,
    this.verified = false,
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
            icon: const Icon(
              Icons.chevron_left,
              color: HaloColors.text2,
              size: 26,
            ),
            onPressed: onBack,
          ),
          GestureDetector(
            onTap: onBlock, // avatar -> contact actions + verify
            behavior: HitTestBehavior.opaque,
            child: HaloAvatar(seed: avatarSeed, size: 36),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: GestureDetector(
              onTap: onRename,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.98,
                                end: 1.0,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Text(
                            nickname ?? haloId,
                            key: ValueKey<String>(nickname ?? haloId),
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 14,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_user,
                          size: 13,
                          color: HaloColors.amber,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    nickname != null ? haloId : 'onion',
                    style: HaloType.mono(size: 10, color: HaloColors.text2),
                  ),
                ],
              ),
            ),
          ),
          if (pinnedCount > 0)
            IconButton(
              icon: const Icon(
                Icons.push_pin_outlined,
                color: HaloColors.amber,
                size: 19,
              ),
              onPressed: onPinned,
            ),
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: HaloColors.text2,
              size: 21,
            ),
            onPressed: onSearch,
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: HaloColors.text2,
              size: 21,
            ),
            onPressed: onBlock,
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
            bottom: BorderSide(color: HaloColors.line, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: HaloColors.text2,
                    size: 20,
                  ),
                  onPressed: widget.onClose,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: HaloColors.line2, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 15,
                          color: HaloColors.amber,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            onChanged: widget.onChanged,
                            cursorColor: HaloColors.amber,
                            cursorWidth: 1.5,
                            style: HaloType.sans(
                              size: 13,
                              color: HaloColors.text,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'find in conversation',
                              hintStyle: HaloType.serif(
                                size: 13,
                                italic: true,
                                color: HaloColors.text3,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
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
                                size: 10,
                                color: HaloColors.text2,
                              ),
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
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                if (widget.matchCount > 0)
                                  TextSpan(
                                    text:
                                        ' of ${widget.matchCount} ${widget.matchCount == 1 ? 'match' : 'matches'}',
                                  ),
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
        child: Icon(
          icon,
          size: 16,
          color: enabled ? HaloColors.amber : HaloColors.text3,
        ),
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
  final bool ripple;
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
    this.ripple = false,
  });

  // builds the message body, underlining query matches in amber. plain
  // Text when there's no active query.
  Widget _body(bool isOut, {bool image = false}) {
    final base = HaloType.sans(
      size: 14,
      color: (isOut && !image) ? HaloColors.onAmber : HaloColors.text,
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
      spans.add(
        TextSpan(
          text: text.substring(hit, hit + q.length),
          style: TextStyle(
            color: (isOut && !image) ? HaloColors.onAmber : HaloColors.amber,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: (isOut && !image)
                ? HaloColors.onAmber
                : HaloColors.amber,
            decorationThickness: 1.5,
          ),
        ),
      );
      start = hit + q.length;
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final isOut = msg.direction == 'out';
    final isImage = msg.mediaPath != null;
    final showMeta = isOut && !msg.sending && !msg.failed;
    final showPill = isOut && msg.sending;
    final metaColor = (isOut && !isImage)
        ? HaloColors.onAmber.withValues(alpha: 0.55)
        : HaloColors.text3;
    final remainingMs = msg.burnAt != null
        ? msg.burnAt! - DateTime.now().millisecondsSinceEpoch
        : 9999999;
    final isExpiring = msg.burnAt != null && remainingMs < 600;
    // freshly-sent outgoing bubble: play a one-shot lift-in. the time window
    // keeps it from re-firing on old bubbles when opening or scrolling a chat.
    final justSent =
        isOut &&
        !msg.failed &&
        DateTime.now().difference(msg.when).inMilliseconds < 900;
    return AnimatedOpacity(
      duration: Duration(milliseconds: isExpiring ? 440 : 250),
      curve: Curves.easeOut,
      opacity: dimmed ? 0.28 : 1.0,
      child: AnimatedScale(
        duration: Duration(milliseconds: isExpiring ? 560 : 500),
        curve: isExpiring ? Curves.easeInCubic : Curves.easeOut,
        scale: isExpiring ? 1.07 : 1.0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: msg.failed && onRetry != null ? () => onRetry!(msg) : null,
          onLongPress: onLongPress == null ? null : () => onLongPress!(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: isOut
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _sendOffEntrance(
                  active: justSent,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedOpacity(
                        duration: Duration(
                          milliseconds: isExpiring ? 650 : 180,
                        ),
                        curve: Curves.easeOut,
                        opacity: isExpiring ? 0.0 : 1.0,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: msg.mediaPath != null
                              ? EdgeInsets.zero
                              : const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          decoration: BoxDecoration(
                            color: (isImage && msg.text.isNotEmpty)
                                ? HaloColors.surface2
                                : (isOut || isImage)
                                ? null
                                : HaloColors.surface3,
                            gradient: (isOut && !isImage)
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      HaloColors.amber,
                                      HaloColors.amberDeep,
                                    ],
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
                          clipBehavior: msg.mediaPath != null
                              ? Clip.antiAlias
                              : Clip.none,
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
                                        : HaloColors.surface2,
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
                                                ? HaloColors.onAmber.withValues(
                                                    alpha: 0.7,
                                                  )
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
                              if (msg.mediaPath != null)
                                GestureDetector(
                                  onTap: () =>
                                      _openFullImage(context, msg.mediaPath!),
                                  child: ClipRRect(
                                    borderRadius: msg.text.isNotEmpty
                                        ? const BorderRadius.vertical(
                                            top: Radius.circular(14),
                                          )
                                        : BorderRadius.circular(14),
                                    child: Stack(
                                      children: [
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 280,
                                          ),
                                          child: Image.file(
                                            File(msg.mediaPath!),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                        if (showMeta)
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.45,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _fmtTime(msg.when),
                                                    style: const TextStyle(
                                                      fontFamily:
                                                          'JetBrains Mono',
                                                      fontSize: 9,
                                                      color: Colors.white,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  const Text(
                                                    '✓',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: msg.mediaPath != null
                                    ? (msg.text.isNotEmpty
                                          ? const EdgeInsets.fromLTRB(
                                              12,
                                              8,
                                              12,
                                              10,
                                            )
                                          : const EdgeInsets.fromLTRB(
                                              2,
                                              6,
                                              2,
                                              0,
                                            ))
                                    : EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.text.isNotEmpty)
                                      _body(
                                        isOut,
                                        image: msg.mediaPath != null,
                                      ),
                                    if (showMeta && msg.mediaPath == null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _fmtTime(msg.when),
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 9,
                                              color: metaColor,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          if (msg.edited) ...[
                                            const SizedBox(width: 5),
                                            Text(
                                              'edited',
                                              style: TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 9,
                                                color: metaColor,
                                                fontStyle: FontStyle.italic,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 3),
                                          Text(
                                            '✓',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: metaColor,
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (msg.reactions.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons
                                                  .local_fire_department_outlined,
                                              size: 11,
                                              color: (isOut && !isImage)
                                                  ? HaloColors.onAmber
                                                  : HaloColors.amber
                                                        .withOpacity(0.75),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'burns in ${_fmtBurn(msg.burnAt!)}',
                                              style: HaloType.mono(
                                                size: 9.5,
                                                color: (isOut && !isImage)
                                                    ? HaloColors.onAmber
                                                    : HaloColors.amber
                                                          .withOpacity(0.75),
                                                weight: FontWeight.w600,
                                              ).copyWith(letterSpacing: 0.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (msg.failed) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'failed · tap to retry',
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          color: HaloColors.onAmber.withValues(
                                            alpha: 0.75,
                                          ),
                                          letterSpacing: 0.4,
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
                      if (isExpiring) const _BurnEmbers(),
                      if (ripple)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOut,
                              builder: (context, t, child) => Opacity(
                                opacity: (1 - t) * 0.7,
                                child: Transform.scale(
                                  scale: 1 + t * 0.12,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(14),
                                        topRight: const Radius.circular(14),
                                        bottomLeft: Radius.circular(
                                          isOut ? 14 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isOut ? 4 : 14,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: HaloColors.amber,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
              Text(
                '$count',
                style: HaloType.mono(size: 10, color: HaloColors.text2),
              ),
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
            color: widget.selected ? HaloColors.amberSoft : HaloColors.surface3,
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
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
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
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text2,
                    height: 1.3,
                  ),
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
                _ActionTap(icon: Icons.reply_rounded, onTap: widget.onReply),
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
        child: Text(
          'say hi.',
          textAlign: TextAlign.center,
          style: HaloType.serif(
            size: 22,
            weight: FontWeight.w300,
            italic: true,
            color: HaloColors.text3,
          ),
        ),
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
  final VoidCallback onAttach;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.ghost,
    required this.onToggleGhost,
    required this.onPickBurn,
    required this.burnSeconds,
    required this.onAttach,
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
                    padding: const EdgeInsets.only(
                      left: 4,
                      right: 4,
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_outlined,
                          size: 13,
                          color: HaloColors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ghost mode',
                          style: HaloType.serif(
                            size: 12,
                            color: HaloColors.amber,
                            italic: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'messages burn after ${_humanBurn(burnSeconds)}',
                          style: HaloType.mono(
                            size: 10.5,
                            color: HaloColors.text3,
                          ),
                        ),
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ghost ? HaloColors.amber : HaloColors.surface3,
                    boxShadow: ghost
                        ? [
                            BoxShadow(
                              color: HaloColors.amber.withOpacity(0.45),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
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
              GestureDetector(
                onTap: onAttach,
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 22,
                  color: HaloColors.text2,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                      borderSide: const BorderSide(
                        color: HaloColors.amber,
                        width: 0.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend = !sending && value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: canSend ? onSend : null,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      scale: canSend ? 1.0 : 0.88,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: canSend
                              ? HaloColors.amber
                              : HaloColors.surface3,
                          boxShadow: canSend
                              ? [
                                  BoxShadow(
                                    color: HaloColors.amber.withOpacity(0.35),
                                    blurRadius: 12,
                                    spreadRadius: -1,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_upward,
                          size: 18,
                          color: canSend
                              ? HaloColors.onAmber
                              : HaloColors.text3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// full-screen preview shown after picking a photo: the image plus a caption
// field. pops the caption on send, or null on back (cancel).
class _ImageCaptionScreen extends StatefulWidget {
  final Uint8List bytes;
  const _ImageCaptionScreen({required this.bytes});
  @override
  State<_ImageCaptionScreen> createState() => _ImageCaptionScreenState();
}

class _ImageCaptionScreenState extends State<_ImageCaptionScreen> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: HaloColors.text2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'send photo',
                    style: HaloType.serif(
                      size: 16,
                      italic: true,
                      color: HaloColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(widget.bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: HaloType.sans(size: 14),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'add a caption…',
                        hintStyle: HaloType.sans(
                          size: 14,
                          color: HaloColors.text3,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: HaloColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(_ctrl.text.trim());
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: HaloColors.amber,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: HaloColors.onAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// one-shot lift + fade for a freshly-sent bubble. inactive -> returns the
// child untouched, so old/scrolled bubbles never re-animate.
Widget _sendOffEntrance({required bool active, required Widget child}) {
  if (!active) return child;
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 340),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (_, t, c) => Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 16),
        child: Transform.scale(
          scale: 0.94 + 0.06 * t,
          alignment: Alignment.bottomCenter,
          child: c,
        ),
      ),
    ),
  );
}

// a quick burst of rising embers + a warm glow, painted over a ghost message
// as it burns away. one-shot 0->1 tween; fixed phases stagger the embers so it
// looks alive without a particle engine.
class _BurnEmbers extends StatelessWidget {
  const _BurnEmbers();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOut,
          builder: (_, t, __) => CustomPaint(painter: _EmberPainter(t)),
        ),
      ),
    );
  }
}

class _EmberPainter extends CustomPainter {
  final double t;
  _EmberPainter(this.t);

  // x-fraction + start phase per ember
  static const _seeds = [
    [0.12, 0.0],
    [0.30, 0.35],
    [0.46, 0.12],
    [0.58, 0.55],
    [0.71, 0.05],
    [0.84, 0.4],
    [0.22, 0.7],
    [0.66, 0.85],
    [0.40, 0.9],
    [0.92, 0.25],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          HaloColors.amber.withValues(alpha: 0.22 * (1 - t)),
          HaloColors.amber.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    for (final seed in _seeds) {
      final tt = (t + seed[1]) % 1.0;
      final op = (1 - tt) * (1 - t * 0.4);
      if (op <= 0.02) continue;
      final x = seed[0] * size.width;
      final y = size.height - size.height * 0.7 * tt - 4;
      final r = 1.4 + 1.6 * (1 - tt);
      final paint = Paint()
        ..color = Color.lerp(
          HaloColors.amberSoft,
          HaloColors.amber,
          tt,
        )!.withValues(alpha: op.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) => old.t != t;
}

// map the saved mode string to the pill's enum. private = full tor (3 hops),
// the real route for every message today.
PrivacyMode _pmFrom(String m) => m == 'fast'
    ? PrivacyMode.fast
    : m == 'normal'
    ? PrivacyMode.normal
    : PrivacyMode.private;
