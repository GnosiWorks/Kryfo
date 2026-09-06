// SPDX-License-Identifier: GPL-3.0-or-later
// group chat. supports text + reply + reactions + ghost mode. mirrors the
// 1:1 chat ux as closely as possible so the user never has to relearn
// gestures.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/press_scale.dart';
import '../widgets/media_bubbles.dart';
import 'chat_screen.dart'
    show
        disguiseWav,
        ChatScreen,
        LinkPreviewCard,
        SearchHead,
        Atmo,
        AtmosphereWash,
        atmoFromName,
        firstUrl,
        unescapeHtml;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../main.dart'
    show
        appState,
        db,
        currentChatPeer,
        newMsgUid,
        torGetOnIsolate,
        torGetB64OnIsolate;
import '../theme.dart';
import '../media_progress.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/burn_fade.dart';
import 'group_info_screen.dart';
import '../widgets/motion.dart'
    show haloRoute, SendPill, PrivacyMode, TorStatus;
import '../rooms.dart';
import '../widgets/notice_banner.dart';
import '../widgets/room_countdown.dart';
import 'room_link_sheet.dart';

final Map<String, String> _draftPerGroup = {};

// our nickname for a member, or nothing so the id shows. a room member is a
// key, not a person we know, so it gets the short tag instead.
String? _senderLabel(Map<String, String> nickById, String peer) =>
    nickById[peer] ?? (looksLikeRoomKey(peer) ? roomTag(peer) : null);

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_GMsg> _messages = [];
  bool _showScrollDown = false;
  int _seenCount = 0;
  String _groupName = '';
  int _memberCount = 0;
  // burner room state: when it ends, and whether this is the first open
  int? _roomExpiresAt;
  bool _roomBanner = false;
  bool get _isRoom => _roomExpiresAt != null;
  bool _isAdmin = false;
  bool _sending = false;
  _GMsg? _replyTo;
  OverlayEntry? _menuEntry;
  final GlobalKey _jumpKey = GlobalKey();
  String? _jumpUid;
  String? _rippleUid;
  // keyed by the uid of the row each divider precedes. index keys reparent
  // when rows shift (burns), and dayMs keys duplicate when a late-arriving
  // older message splits a day into two runs - two dividers, one GlobalKey,
  // framework red screen. the anchor uid is unique per divider and stable.
  final Map<String, GlobalKey> _dayKeys = {};
  final Map<String, int> _dayMsOf = {};
  final GlobalKey _listKey = GlobalKey();

  // the day dividers key off "is this a different day from the message
  // before it", so an out-of-order list emits two dividers for one day and
  // both grab the same GlobalKey.
  void _normaliseMessages() {
    _messages.sort((a, b) => a.when.compareTo(b.when));
    final seen = <String>{};
    _messages.retainWhere((m) {
      final id = m.msgUid;
      if (id == null) return true;
      return seen.add(id);
    });
  }

  final ValueNotifier<String?> _stickyLabel = ValueNotifier(null);
  final ValueNotifier<bool> _stickyShown = ValueNotifier(false);
  int? _stickyDayMs;
  Timer? _stickyHideTimer;
  bool _suppressSticky = true;
  DateTime _lastSticky = DateTime.fromMillisecondsSinceEpoch(0);
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  List<int> _matches = [];
  int _matchPos = 0;
  Atmo _atmosphere = Atmo.none;
  static const _pageSize = 60;
  bool _hasMore = true;
  bool _loadingOlder = false;
  bool _pagedOut = false;
  // ghost mode - per-session, not persisted. when on, new messages carry a
  // burn timer; receivers compute the burn deadline locally.
  bool _ghost = false;
  bool _disguise = false;
  int _burnSeconds = 300; // 5 min default, same as 1:1
  Timer? _burnTick;
  int _lastBurnSec = 0;
  bool _loading = false;
  bool _reloadQueued = false;
  bool _loaded = false; // first full load done - gates the append-fast-path
  int _seenRev = -1; // last group rev we reloaded for

  @override
  void initState() {
    super.initState();

    if (appState.secureChats) appState.forceSecure(true);
    currentChatPeer = 'group:${widget.groupId}';
    WidgetsBinding.instance.addObserver(this);
    // a room is never in the app switcher and never screenshotted. the flag
    // is set the moment we know it is a room and cleared on the way out.
    db.getGroup(widget.groupId).then((g) async {
      if (!mounted || g == null || g['room_pub'] == null) return;
      setState(() {
        _roomExpiresAt = g['expires_at'] as int?;
        _roomBanner = (g['room_seen'] as int? ?? 0) == 0;
      });
      appState.forceSecure(true);
      // the creator's first open: hand them the invite right away, that is
      // the only thing an empty room is for
      if (_roomBanner && (g['is_admin'] as int? ?? 0) == 1) {
        await Future.delayed(const Duration(milliseconds: 450));
        final link = await appState.roomLinkFor(widget.groupId);
        if (link != null && mounted) await showRoomLinkSheet(context, link);
      }
    });
    db.clearGroupUnread(widget.groupId).then((_) => appState.refreshGroups());
    // restore a draft left behind last time this group was open.
    _msgCtrl.text = _draftPerGroup[widget.groupId] ?? '';
    // save it live on every keystroke so it survives leaving regardless of
    // when dispose runs.
    _msgCtrl.addListener(() {
      final t = _msgCtrl.text;
      if (t.trim().isEmpty) {
        _draftPerGroup.remove(widget.groupId);
      } else {
        _draftPerGroup[widget.groupId] = t;
      }
    });
    _scrollCtrl.addListener(_updateSticky);
    _scrollCtrl.addListener(_onGroupScroll);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _suppressSticky = false;
    });
    _load();
    appState.loadDisguisePref().then((d) {
      if (mounted) setState(() => _disguise = d);
    });
    appState.addListener(_onAppStateChanged);
    _burnTick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      // one pass, and no list unless something actually burnt. most groups
      // carry no ghosts at all, and this runs ten times a second for as long
      // as the chat is open.
      List<_GMsg>? expired;
      var anyGhost = false;
      for (final m in _messages) {
        if (m.burnAt == null) continue;
        anyGhost = true;
        if (m.burnAt! <= now && !m.removing && !m.sending && !m.failed) {
          (expired ??= []).add(m);
        }
      }
      if (!anyGhost) return;
      if (expired != null) {
        for (final m in expired) {
          m.removing = true;
          // wait for the BurnFade dissolve (520ms) before pulling the row,
          // else the animation cuts off and the message pops away.
          Future.delayed(const Duration(milliseconds: 560), () {
            if (mounted) setState(() => _messages.remove(m));
            if (m.msgUid != null) db.deleteMessage(m.msgUid!);
          });
        }
        HapticFeedback.lightImpact();
      }
      // repaint when something expired or the countdown changes second, not
      // every 100ms (that was the jank)
      final sec = now ~/ 1000;
      if (expired != null || sec != _lastBurnSec) {
        _lastBurnSec = sec;
        setState(() {});
      }
    });
  }

  // jump to newest, same control as 1:1
  Widget _scrollDownButton() {
    final unread = _messages.length - _seenCount;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: IgnorePointer(
        ignoring: !_showScrollDown,
        child: AnimatedScale(
          scale: _showScrollDown ? 1.0 : 0.6,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _showScrollDown ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _seenCount = _messages.length);
                      _scrollToEnd();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HaloColors.surface2,
                        border: Border.all(
                          color: HaloColors.amber.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: HaloColors.amber.withValues(alpha: 0.18),
                            blurRadius: 14,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: HaloColors.amber,
                        size: 22,
                      ),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 17),
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
                          '$unread',
                          style: HaloType.mono(
                            size: 9,
                            color: HaloColors.onAmber,
                          ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onGroupScroll() {
    if (!_scrollReady) return;
    // not reversed here, unlike 1:1 - the newest message lives at
    // maxScrollExtent, so distance from the bottom is the gap to it.
    final fromBottom = _maxScroll - _pixels;
    final show = fromBottom > 240;
    if (!show) _seenCount = _messages.length;
    if (show != _showScrollDown && mounted) {
      setState(() => _showScrollDown = show);
    }
    // the settle window also stops a stray pre-jump scroll event on open
    // from loading older and anchoring the view at the top.
    if (_suppressSticky) return;
    if (_pixels < 400) _loadOlder();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _searching) return;
    _loadingOlder = true;
    try {
      final oldestRowid = _messages.isEmpty ? null : _messages.first.rowid;
      final rows = await db.groupMessagesPage(
        widget.groupId,
        beforeRowid: oldestRowid,
        limit: _pageSize + 1,
      );
      if (!mounted) return;
      _hasMore = rows.length > _pageSize;
      if (_hasMore) rows.removeAt(0);
      if (!_hasMore) _pagedOut = true;
      if (rows.isEmpty) return;
      final uids = rows
          .map((r) => r['msg_uid'] as String?)
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toList();
      final reactions = await db.loadReactionsFor(uids);
      if (!mounted) return;
      final nickById = <String, String>{};
      for (final c in appState.contacts) {
        final n = c.nickname;
        if (n != null && n.isNotEmpty) nickById[c.haloId] = n;
      }
      final older = <_GMsg>[];
      for (final r in rows) {
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
          senderName: _senderLabel(nickById, r['peer_id'] as String),
          direction: dir,
          text: r['plaintext'] as String,
          when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
          burnAt: r['burn_at'] as int?,
          msgUid: uid,
          replyTo: r['reply_to'] as String?,
          mediaPath: r['media_path'] as String?,
          filePath: r['file_path'] as String?,
          fileName: r['file_name'] as String?,
          voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
          pinned: ((r['pinned'] as int?) ?? 0) == 1,
          saved: ((r['saved'] as int?) ?? 0) == 1,
          edited: ((r['edited'] as int?) ?? 0) == 1,
          reactions: rxMap,
        );
        m.preview = _decodePv(r['preview'] as String?);
        m.rowid = (r['rowid'] as int?) ?? 0;
        older.add(m);
      }
      // divider anchors change after the prepend (day boundaries move), so
      // drop the maps - they repopulate on build.
      _dayKeys.clear();
      _dayMsOf.clear();
      setState(() {
        _messages.insertAll(0, older);
        _normaliseMessages();
      });
      // anchor: pull the previous top message back to the top of the view so
      // the prepend doesn't yank the scroll.
      final anchorUid = _messages[older.length].msgUid;
      setState(() => _jumpUid = anchorUid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _jumpKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: Duration.zero,
            alignment: 0.0,
          );
        }
        if (mounted && _jumpUid == anchorUid) {
          setState(() => _jumpUid = null);
        }
      });
    } finally {
      _loadingOlder = false;
    }
  }

  Map<String, String>? _decodePv(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      return d.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    _loading = true;
    try {
      _dayKeys.clear();
      _dayMsOf.clear();
      db.getGroupAtmosphere(widget.groupId).then((a) {
        if (mounted) setState(() => _atmosphere = atmoFromName(a));
      });
      final g = await db.getGroup(widget.groupId);
      // a room that ended while this was open is gone, so is the screen.
      // only when it is the one in front: leaving from the info screen
      // already pops both, and a third pop would close the app.
      if (g == null && _isRoom) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
        return;
      }
      final members = await db.getGroupMembers(widget.groupId);
      // keep whatever window the user has expanded to - a mid-scroll reaction
      // used to collapse the list back to one page and yank the view.
      final wantAll = _searching || _pagedOut || _messages.length > _pageSize;
      final rows = wantAll
          ? await db.loadGroupMessages(widget.groupId)
          : await db.groupMessagesPage(widget.groupId, limit: _pageSize + 1);
      if (!wantAll) {
        _hasMore = rows.length > _pageSize;
        if (_hasMore) rows.removeAt(0);
        if (!_hasMore) _pagedOut = true;
      }
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
        _roomExpiresAt = g?['expires_at'] as int?;
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
                senderName: _senderLabel(nickById, r['peer_id'] as String),
                direction: dir,
                text: r['plaintext'] as String,
                when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
                burnAt: r['burn_at'] as int?,
                msgUid: uid,
                replyTo: r['reply_to'] as String?,
                mediaPath: r['media_path'] as String?,
                filePath: r['file_path'] as String?,
                fileName: r['file_name'] as String?,
                voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
                pinned: ((r['pinned'] as int?) ?? 0) == 1,
                saved: ((r['saved'] as int?) ?? 0) == 1,
                edited: ((r['edited'] as int?) ?? 0) == 1,
                sending: dir == 'out' && (r['sent'] as int? ?? 1) == 0,
                reactions: rxMap,
              );
              m.preview = _decodePv(r['preview'] as String?);
              m.rowid = (r['rowid'] as int?) ?? 0;
              // only a STALE sending out-message is dead. a live send (<60s old,
              // future still running) must keep its pill or a working media send
              // flips to failed mid-flight - the "had to retry 2-3 times" bug.
              // also hold off while tor is warming: the send is queued, not dead.
              // outside onion there is no warmup to wait out, so a stale
              // send is simply stale.
              final torUp =
                  appState.sendMode != 'private' ||
                  appState.torStatus == TorStatus.reachable;
              final stale = m.when.isBefore(
                DateTime.now().subtract(const Duration(seconds: 60)),
              );
              if (torUp && m.direction == 'out' && m.sending && stale) {
                m.sending = false;
                m.failed = true;
              }
              return m;
            }),
          );
      });
      // only snap to the tail on first load or when the user is already
      // reading it. a background reload (reaction, preview, burn) yanking
      // the view to the bottom is what kept throwing pin jumps and
      // scrollback to the end of the chat.
      final nearEnd = !_scrollReady || _maxScroll - _pixels < 240;
      if (!_loaded || (nearEnd && _jumpUid == null)) {
        _scrollToEnd(instant: true);
      }
      _loaded = true;
    } finally {
      // a crash mid-load used to leave _loading stuck true, silently
      // freezing every later refresh: previews only appeared after
      // re-entering, pins went stale. reset no matter what.
      _loading = false;
      // if changes landed while we were loading, run exactly one catch-up.
      if (_reloadQueued) {
        _reloadQueued = false;
        _load();
      }
    }
  }

  void _onAppStateChanged() {
    // only react to our own group's traffic. a 1:1 message landing used
    // to full-reload this screen and churn every photo bubble.
    final rev = appState.chatRevOf('group:${widget.groupId}');
    if (rev == _seenRev) return;
    _seenRev = rev;
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
  bool _appending = false;
  Future<void> _tryAppendNew() async {
    if (!_loaded) {
      _load();
      return;
    }
    if (_appending) {
      _reloadQueued = true;
      return;
    }
    _appending = true;
    try {
      await _appendNewInner();
    } finally {
      _appending = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        _tryAppendNew();
      }
    }
  }

  Future<void> _appendNewInner() async {
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
      // no new message rows. this fires for reactions/edits/unsends/burns,
      // which need a full reload to show - EXCEPT while one of our own sends
      // is still in flight: a reload there rebuilds _messages with new objects
      // and orphans the optimistic one, freezing its send pill forever. so
      // defer the reload until the send settles; the completion handler
      // re-finds the live object and a later change will reload cleanly.
      final sendInFlight = _messages.any((m) => m.sending);
      if (!sendInFlight) _load();
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
        senderName: _senderLabel(nickById, r['peer_id'] as String),
        direction: dir,
        text: r['plaintext'] as String,
        when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
        burnAt: r['burn_at'] as int?,
        msgUid: uid,
        replyTo: r['reply_to'] as String?,
        mediaPath: r['media_path'] as String?,
        filePath: r['file_path'] as String?,
        fileName: r['file_name'] as String?,
        voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
        pinned: ((r['pinned'] as int?) ?? 0) == 1,
        saved: ((r['saved'] as int?) ?? 0) == 1,
        edited: ((r['edited'] as int?) ?? 0) == 1,
        sending: dir == 'out' && (r['sent'] as int? ?? 1) == 0,
        reactions: rxMap,
      );
      m.preview = _decodePv(r['preview'] as String?);
      m.rowid = (r['rowid'] as int?) ?? 0;
      if (dir == 'in') m.fresh = true;
      fresh.add(m);
    }
    final nowHave = _messages.map((m) => m.msgUid).toSet();
    fresh.removeWhere((m) => m.msgUid != null && nowHave.contains(m.msgUid));
    if (fresh.isEmpty) return;
    setState(() {
      _messages.addAll(fresh);
      _normaliseMessages();
    });
    _scrollToEnd();
  }

  // .position asserts exactly one attached scroll view, and during a route
  // transition two can be. hasClients is not enough on its own - the
  // controller attaches before the list has dimensions to read.
  bool get _scrollReady =>
      _scrollCtrl.positions.length == 1 &&
      _scrollCtrl.positions.first.hasContentDimensions;

  double get _maxScroll =>
      _scrollReady ? _scrollCtrl.positions.first.maxScrollExtent : 0.0;

  double get _pixels => _scrollReady ? _scrollCtrl.positions.first.pixels : 0.0;

  Widget _buildGroupRow(int i) {
    final m = _messages[i];
    final prev = i > 0 ? _messages[i - 1] : null;
    final showSender =
        m.direction == 'in' &&
        (prev == null || prev.sender != m.sender || prev.direction != 'in');
    String? quoted;
    String? quotedAuthor;
    if (m.replyTo != null) {
      final orig = _messages.firstWhere(
        (x) => x.msgUid == m.replyTo,
        orElse: () =>
            _GMsg(sender: '', direction: '', text: '', when: DateTime.now()),
      );
      if (orig.direction.isNotEmpty) {
        quotedAuthor = orig.direction == 'out' ? 'you' : orig.senderName;
      }
      if (orig.text.isNotEmpty) {
        quoted = orig.text;
      } else if (orig.mediaPath != null) {
        quoted = 'photo';
      } else if (orig.fileName == 'voice.wav') {
        quoted = 'voice message';
      } else if (orig.fileName != null) {
        quoted = orig.fileName;
      } else {
        quoted = 'message unavailable';
        quotedAuthor = null;
      }
    }
    final animateIn = m.fresh;
    m.fresh = false;
    final showDate = i == 0 || (prev != null && !_sameDay(prev.when, m.when));
    return Column(
      key: ValueKey(m.msgUid ?? 'r${m.rowid}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDate) _dateDivider(m.when, m.msgUid ?? 'r${m.rowid}'),
        RepaintBoundary(
          key: (m.msgUid != null && m.msgUid == _jumpUid) ? _jumpKey : null,
          child: _groupBubbleEntrance(
            isOut: m.direction == 'out',
            active: animateIn,
            child: _GroupSwipeToReply(
              onReply: () => setState(() => _replyTo = m),
              child: _GroupBubble(
                m: m,
                showSender: showSender,
                senderBadge: _badgeFor(m.sender),
                quotedText: quoted,
                quotedAuthor: quotedAuthor,
                onLongPress: (ctx) => _showEmojiPickerAt(ctx, m),
                onRetry: m.failed ? () => _retryGroup(m) : null,
                ripple: m.msgUid != null && m.msgUid == _rippleUid,
                onReplyTap: m.replyTo == null
                    ? null
                    : () {
                        for (final x in _messages) {
                          if (x.msgUid != null && x.msgUid == m.replyTo) {
                            _scrollToGroupMessage(x);
                            break;
                          }
                        }
                      },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _scrollToEnd({bool instant = false}) {
    // on first open the list isn't laid out yet, so maxScrollExtent is 0 and a
    // plain animateTo leaves us pinned at the top. jump after the frame, and if
    // extent is still growing (images sizing in), snap once more.
    void go() {
      if (!_scrollReady) return;
      final max = _maxScroll;
      if (instant) {
        _scrollCtrl.jumpTo(max);
      } else {
        _scrollCtrl.animateTo(
          max,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      go();
      // a second pass after media/layout settles catches the real bottom.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollReady) {
          _scrollCtrl.jumpTo(_maxScroll);
        }
      });
    });
  }

  Future<void> _enrichGroupPreview(
    _GMsg msg,
    String url,
    String msgUid, [
    Future<bool>? sendOk,
  ]) async {
    try {
      final html = await torGetOnIsolate(url);
      if (html.startsWith('error:') || html.isEmpty) {
        debugPrint(
          'preview: fetch failed for $url -> '
          '${html.isEmpty ? 'empty' : html.substring(0, html.length > 80 ? 80 : html.length)}',
        );
        return;
      }
      String? grab(String prop) {
        final re = RegExp(
          '<meta[^>]+(?:property|name)=["\']${RegExp.escape(prop)}["\'][^>]+content=["\']([^"\']+)',
          caseSensitive: false,
        );
        return re.firstMatch(html)?.group(1);
      }

      var title = grab('og:title') ?? grab('twitter:title');
      if (title == null) {
        final t = RegExp(
          r'<title[^>]*>([^<]+)',
          caseSensitive: false,
        ).firstMatch(html);
        title = t?.group(1)?.trim();
      }
      final image = grab('og:image') ?? grab('twitter:image');
      final site = grab('og:site_name');
      if (title == null && image == null) {
        debugPrint('preview: no og tags at $url');
        return;
      }
      String? imageData;
      if (image != null) {
        try {
          final raw = await torGetB64OnIsolate(image);
          if (raw.startsWith('ok:')) imageData = raw.substring(3);
        } catch (_) {}
      }
      // small thumb rides whole, big one drops. no chunked lane here, the
      // card still shows title/site.
      if (imageData != null && imageData.length > 80 * 1024) imageData = null;
      final pv = <String, String>{
        'url': url,
        if (title != null) 'title': unescapeHtml(title),
        'img': ?imageData,
        if (site != null) 'site': unescapeHtml(site),
      };
      // wait for the send verdict before showing/announcing - a preview for
      // a message nobody got would confuse receivers.
      if (sendOk != null && !(await sendOk)) return;
      // paint locally FIRST - the announce is a full tor multicast and made
      // the sender's own card trail the receiver's by seconds. then persist
      // and announce, neither depending on the screen still being alive.
      if (mounted) {
        // re-find by uid: a reload during the tor fetch replaces the list
        // objects; painting the orphan showed nothing until a restart.
        final live = _liveMsg(msgUid) ?? msg;
        setState(() => live.preview = pv);
      }
      await db.setMsgPreview(msgUid, jsonEncode(pv));
      await appState.sendGroupPreview(widget.groupId, msgUid, pv);
    } catch (e) {
      debugPrint('preview enrich failed: $e');
    }
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
    )..fresh = true;
    setState(() {
      _messages.add(optimistic);
      _normaliseMessages();
      _replyTo = null;
    });
    _scrollToEnd();
    var ok = false;
    final sendFut = appState.sendToGroup(
      widget.groupId,
      text,
      msgUid: uid,
      replyTo: replyToUid,
      burnSeconds: burnSeconds,
    );
    // fetch the preview while the send is in flight - the tor page fetch
    // dominates the wait, so stacking it after the send doubled the delay.
    // the card is only shown/announced once the send confirms ok.
    final url = firstUrl(text);
    if (url != null) {
      unawaited(_enrichGroupPreview(optimistic, url, uid, sendFut));
    }
    try {
      ok = await sendFut;
    } catch (e) {
      debugPrint('group send failed: $e');
    } finally {
      // always release the composer - a throw here used to leave _sending
      // stuck true, which silently killed every later send.
      if (mounted) {
        // re-find the live object; the notifyListeners at the end of
        // sendToGroup can trigger a reload that replaces `optimistic`,
        // and mutating the orphan left the send pill stuck forever.
        final live = _liveMsg(uid) ?? optimistic;
        setState(() {
          _sending = false;
          live.sending = false;
          live.failed = !ok; // no member acknowledged -> tap-to-retry
        });
        // catch up any change deferred while this send was in flight.
        if (!_messages.any((x) => x.sending)) _tryAppendNew();
      }
    }
  }

  // re-send a failed group message, reusing its uid/reply/burn so it stays
  // the same logical message. media rows re-read their saved file and go
  // back through the chunked multicast.
  Future<void> _retryGroup(_GMsg m) async {
    if (m.msgUid == null) return;
    setState(() {
      m.failed = false;
      m.sending = true;
    });
    final mediaSrc = m.mediaPath ?? m.filePath;
    if (mediaSrc != null) {
      final f = File(mediaSrc);
      if (!await f.exists()) {
        if (mounted) {
          setState(() {
            m.sending = false;
            m.failed = true;
          });
        }
        return;
      }
      final b64 = base64Encode(await f.readAsBytes());
      String r;
      try {
        r = await appState.sendMediaToGroup(
          widget.groupId,
          b64,
          msgUid: m.msgUid!,
          caption: m.text,
          fileName: m.mediaPath != null ? null : m.fileName,
          voice: m.fileName == 'voice.wav',
          voiceDisguised: m.voiceDisguised,
          burnSeconds: m.burnSecs,
        );
      } catch (e) {
        r = 'error: $e';
      }
      await _finishGroupMediaSend(m, r);
      return;
    }
    final uid = m.msgUid;
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
        final live = _liveMsg(uid) ?? m;
        setState(() {
          live.sending = false;
          live.failed = !ok;
        });
        if (!_messages.any((x) => x.sending)) _tryAppendNew();
      }
    }
  }

  void _toggleDisguise() {
    setState(() => _disguise = !_disguise);
    appState.saveDisguisePref(_disguise);
    HapticFeedback.selectionClick();
  }

  void _onVoiceComplete(String path, int ms, bool cancelled) {
    if (cancelled || path.isEmpty) return;
    _sendGroupVoice(path, ms);
  }

  void _showAttachSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        Widget tile(IconData icon, String label, VoidCallback go) {
          return ListTile(
            leading: Icon(icon, color: HaloColors.amber, size: 22),
            title: Text(
              label,
              style: HaloType.sans(size: 15, color: HaloColors.text),
            ),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              go();
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
              tile(
                Icons.photo_camera_outlined,
                'camera',
                () => _pickGroupImage(ImageSource.camera),
              ),
              tile(Icons.photo_library_outlined, 'gallery', _pickGroupMultiple),
              tile(Icons.gif_box_outlined, 'gif from phone', _pickGroupGif),
              tile(Icons.attach_file, 'file', _pickGroupFile),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickGroupImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final caption = await Navigator.of(
      context,
    ).push<String?>(haloRoute<String?>(ImageCaptionScreen(bytes: bytes)));
    if (caption == null) return;
    await _sendGroupImage(bytes, caption);
  }

  Future<void> _pickGroupMultiple() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (picked.isEmpty) return;
    if (picked.length == 1) {
      final bytes = await picked.first.readAsBytes();
      if (!mounted) return;
      final caption = await Navigator.of(
        context,
      ).push<String?>(haloRoute<String?>(ImageCaptionScreen(bytes: bytes)));
      if (caption == null) return;
      await _sendGroupImage(bytes, caption);
      return;
    }
    for (final x in picked) {
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      await _sendGroupImage(bytes, '');
    }
  }

  Future<void> _pickGroupGif() async {
    final res = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['gif'],
    );
    if (res == null || res.files.isEmpty) return;
    final data = res.files.first.bytes;
    if (data == null) return;
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, 'gif too big · 8 mb max');
      return;
    }
    // raw bytes through the image lane - re-encoding kills the animation.
    await _sendGroupImage(data, '');
  }

  Future<void> _sendGroupImage(Uint8List bytes, String caption) async {
    final uid = newMsgUid();
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final f = File('${mediaDir.path}/$uid.jpg');
    await f.writeAsBytes(bytes);
    final b64 = base64Encode(bytes);
    final burn = _ghost ? _burnSeconds : null;
    final m = _GMsg(
      sender: appState.myId,
      direction: 'out',
      text: caption,
      when: DateTime.now(),
      msgUid: uid,
      sending: true,
      mediaPath: f.path,
      burnSecs: burn,
    );
    m.fresh = true;
    setState(() {
      _messages.add(m);
      _normaliseMessages();
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await db.saveMessage(
      appState.myId,
      'out',
      caption,
      groupId: widget.groupId,
      msgUid: uid,
      mediaPath: f.path,
      sent: 0,
    );
    appState
        .sendMediaToGroup(
          widget.groupId,
          b64,
          msgUid: uid,
          caption: caption,
          burnSeconds: burn,
        )
        .then((r) => _finishGroupMediaSend(m, r));
  }

  Future<void> _sendGroupVoice(String srcPath, int ms) async {
    final src = File(srcPath);
    if (!await src.exists()) return;
    var bytes = await src.readAsBytes();
    if (_disguise) bytes = disguiseWav(bytes);
    final uid = newMsgUid();
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final dest = File('${mediaDir.path}/vn_$uid.wav');
    await dest.writeAsBytes(bytes);
    final b64 = base64Encode(bytes);
    final burn = _ghost ? _burnSeconds : null;
    final m = _GMsg(
      sender: appState.myId,
      direction: 'out',
      text: '',
      when: DateTime.now(),
      msgUid: uid,
      sending: true,
      filePath: dest.path,
      fileName: 'voice.wav',
      voiceDisguised: _disguise,
      burnSecs: burn,
    );
    m.fresh = true;
    setState(() {
      _messages.add(m);
      _normaliseMessages();
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await db.saveMessage(
      appState.myId,
      'out',
      '',
      groupId: widget.groupId,
      msgUid: uid,
      filePath: dest.path,
      fileName: 'voice.wav',
      voiceDisguised: _disguise,
      sent: 0,
    );
    appState
        .sendMediaToGroup(
          widget.groupId,
          b64,
          msgUid: uid,
          fileName: 'voice.wav',
          voice: true,
          voiceDisguised: _disguise,
          burnSeconds: burn,
        )
        .then((r) => _finishGroupMediaSend(m, r));
  }

  Future<void> _pickGroupFile() async {
    final res = await FilePicker.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final data = res.files.first.bytes;
    final name = res.files.first.name;
    if (data == null) return;
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, 'file too big · 8 mb max');
      return;
    }
    final uid = newMsgUid();
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${mediaDir.path}/f_${uid}_$safe');
    await dest.writeAsBytes(data);
    final b64 = base64Encode(data);
    final burn = _ghost ? _burnSeconds : null;
    final m = _GMsg(
      sender: appState.myId,
      direction: 'out',
      text: '',
      when: DateTime.now(),
      msgUid: uid,
      sending: true,
      filePath: dest.path,
      fileName: name,
      burnSecs: burn,
    );
    m.fresh = true;
    setState(() {
      _messages.add(m);
      _normaliseMessages();
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await db.saveMessage(
      appState.myId,
      'out',
      '',
      groupId: widget.groupId,
      msgUid: uid,
      filePath: dest.path,
      fileName: name,
      sent: 0,
    );
    appState
        .sendMediaToGroup(
          widget.groupId,
          b64,
          msgUid: uid,
          fileName: name,
          burnSeconds: burn,
        )
        .then((r) => _finishGroupMediaSend(m, r));
  }

  // after a send completes, the optimistic object may have been replaced by
  // a reload (notifyListeners -> _tryAppendNew). always re-find the live one
  // by uid so we mutate what's actually on screen, never an orphan.
  String? _badgeFor(String id) {
    for (final c in appState.contacts) {
      if (c.haloId == id) return c.supporterBadge;
    }
    return null;
  }

  _GMsg? _liveMsg(String? uid) {
    if (uid == null) return null;
    for (final m in _messages) {
      if (m.msgUid == uid) return m;
    }
    return null;
  }

  Future<void> _finishGroupMediaSend(_GMsg m, String result) async {
    if (m.msgUid != null) mediaProgressEnd(m.msgUid!);
    final ok = result == 'ok';
    final uid = m.msgUid;
    if (ok && uid != null) await db.markSent(uid);
    int? ba;
    if (ok && m.burnSecs != null && uid != null) {
      ba = DateTime.now().millisecondsSinceEpoch + m.burnSecs! * 1000;
      await db.setMsgBurnAt(uid, ba);
    }
    if (!mounted) return;
    // re-find the on-screen object; a reload may have replaced m.
    final live = _liveMsg(uid) ?? m;
    setState(() {
      if (ba != null) live.burnAt = ba;
      live.sending = false;
      live.failed = !ok;
    });
    // a reaction/edit may have arrived while this was in flight (its reload
    // was deferred to protect the pill). catch it up now the send settled.
    if (!_messages.any((x) => x.sending)) _tryAppendNew();
  }

  Future<void> _toggleReaction(_GMsg target, String emoji) async {
    if (target.msgUid == null) return;
    final current = target.reactions[''];
    final isUnreact = current == emoji;
    final newEmoji = isUnreact ? '' : emoji;
    // land the chip on screen now - don't wait for the db write + tor multicast
    // to round-trip back through a full reload. '' is our own reaction slot.
    setState(() {
      if (newEmoji.isEmpty) {
        target.reactions.remove('');
      } else {
        target.reactions[''] = newEmoji;
      }
    });
    await appState.reactInGroup(widget.groupId, target.msgUid!, newEmoji);
  }

  void _showBurnPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
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
    // drop composer focus BEFORE anything opens: routes capture the focused
    // node at open and restore it at close, which is what kept yanking the
    // keyboard up after unsend/edit/forward. captured nothing = restores
    // nothing, for every action reached from this menu.
    FocusManager.instance.primaryFocus?.unfocus();
    if (target.msgUid == null) return;
    final renderBox = bubbleCtx.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final isOut = target.direction == 'out';
    final screenH = MediaQuery.of(context).size.height;
    // anchor the menu just below the bubble, but if that would run off the
    // bottom, put it above. never off-screen.
    final belowTop = pos.dy + size.height + 8;
    final showAbove = belowTop > screenH - 220;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    void dismiss() {
      if (entry.mounted) entry.remove();
      _menuEntry = null;
    }

    entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: dismiss,
                child: Container(color: Colors.black.withValues(alpha: 0.18)),
              ),
            ),
            Positioned(
              left: isOut ? null : 12,
              right: isOut ? 12 : null,
              top: showAbove ? null : belowTop.clamp(80.0, screenH - 240),
              bottom: showAbove ? (screenH - pos.dy + 8) : null,
              child: Material(
                color: Colors.transparent,
                child: _EmojiPickerBubble(
                  emojis: const ['❤️', '👍', '😂', '😮', '😢', '🔥'],
                  selected: target.reactions[''],
                  isOut: isOut,
                  pinned: target.pinned,
                  saved: target.saved,
                  onPick: (e) {
                    dismiss();
                    _toggleReaction(target, e);
                  },
                  onReply: () {
                    dismiss();
                    setState(() => _replyTo = target);
                  },
                  onCopy: target.text.isEmpty
                      ? null
                      : () {
                          dismiss();
                          Clipboard.setData(ClipboardData(text: target.text));
                          showHaloToast(context, 'copied');
                        },
                  onPin: () {
                    dismiss();
                    _togglePinGroup(target);
                  },
                  onSave: () {
                    dismiss();
                    _toggleSavedGroup(target);
                  },
                  onForward: target.text.isEmpty
                      ? null
                      : () {
                          dismiss();
                          _forwardGroupMessage(target);
                        },
                  onEdit: (isOut && target.text.isNotEmpty)
                      ? () {
                          dismiss();
                          _editGroupMessage(target);
                        }
                      : null,
                  onUnsend: isOut
                      ? () {
                          dismiss();
                          _unsendGroupMessage(target);
                        }
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(entry);
    _menuEntry = entry;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(when.year, when.month, when.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
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
    var label = '${when.day} ${months[when.month - 1]}';
    if (when.year != now.year) label = '$label ${when.year}';
    return label;
  }

  Widget _dateDivider(DateTime when, String anchor) {
    final dayMs = DateTime(
      when.year,
      when.month,
      when.day,
    ).millisecondsSinceEpoch;
    final key = _dayKeys.putIfAbsent(anchor, () => GlobalKey());
    _dayMsOf[anchor] = dayMs;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          _dayLabel(when),
          style: HaloType.serif(
            size: 12.5,
            italic: true,
            color: HaloColors.text,
            weight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _updateSticky() {
    if (_suppressSticky || !_scrollReady) return;
    if (_maxScroll <= 0) return;
    // throttle, the raw scroll stream fires many times a frame.
    final now = DateTime.now();
    if (now.difference(_lastSticky).inMilliseconds < 100) return;
    _lastSticky = now;
    final listObj = _listKey.currentContext?.findRenderObject();
    if (listObj is! RenderBox) return;
    final top = listObj.localToGlobal(Offset.zero).dy;
    int? best;
    double bestDy = -1e9;
    _dayKeys.forEach((anchor, key) {
      final obj = key.currentContext?.findRenderObject();
      if (obj is! RenderBox) return;
      final dy = obj.localToGlobal(Offset.zero).dy;
      if (dy <= top + 6 && dy > bestDy) {
        bestDy = dy;
        best = _dayMsOf[anchor];
      }
    });
    if (best != null) _stickyDayMs = best;
    if (_stickyDayMs != null) {
      _stickyLabel.value = _dayLabel(
        DateTime.fromMillisecondsSinceEpoch(_stickyDayMs!),
      );
    }
    _stickyShown.value = true;
    _stickyHideTimer?.cancel();
    _stickyHideTimer = Timer(
      const Duration(milliseconds: 900),
      () => _stickyShown.value = false,
    );
  }

  void _openSearch() {
    setState(() => _searching = true);
    // matches should cover the whole chat, not just the loaded window.
    if (_hasMore) _load();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _searchCtrl.clear();
      _matches = [];
      _matchPos = 0;
    });
  }

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
      _matches = matches;
      _matchPos = matches.isEmpty ? 0 : matches.length - 1;
    });
    if (matches.isNotEmpty) _scrollToIndex(matches[_matchPos]);
  }

  void _gotoMatch(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _matchPos = (_matchPos + delta) % _matches.length;
      if (_matchPos < 0) _matchPos += _matches.length;
    });
    _scrollToIndex(_matches[_matchPos]);
  }

  // after the rough jump, rows above the target keep resizing as images and
  // previews build in, so one ensureVisible often left us shy or past the
  // pin. re-align over a few frames until the target stops moving.
  void _settleJump(int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollCtrl.hasClients) return;
      final ctx = _jumpKey.currentContext;
      final ro = ctx == null || !ctx.mounted ? null : ctx.findRenderObject();
      if (ro != null && ro.attached) {
        try {
          // ensureVisible asserts if the viewport is mid-update (the
          // viewport.dart red screen). computing the reveal offset and
          // jumping is the safe equivalent.
          final vp = RenderAbstractViewport.of(ro);
          final want = vp
              .getOffsetToReveal(ro, 0.3)
              .offset
              .clamp(0.0, _maxScroll)
              .toDouble();
          if (!_scrollReady) return;
          if ((want - _pixels).abs() > 4) {
            _scrollCtrl.jumpTo(want);
          }
        } catch (_) {
          // element swapped by a reload mid-settle - next pass re-finds it.
        }
        if (attempt < 4) _settleJump(attempt + 1);
      } else if (attempt < 10) {
        _settleJump(attempt + 1);
      }
    });
  }

  // rough-jump so the target gets built, then ensureVisible lands it. this
  // list is NOT reversed (unlike 1:1), older sits near offset 0.
  void _scrollToIndex(int idx) {
    if (idx < 0 || idx >= _messages.length || !_scrollReady) return;
    final m = _messages[idx];
    setState(() => _jumpUid = m.msgUid);
    final max = _maxScroll;
    final frac = idx / _messages.length;
    final vpDim = _scrollCtrl.positions.first.viewportDimension;
    final approx = (frac * max - vpDim * 0.3).clamp(0.0, max);
    _scrollCtrl.jumpTo(approx.clamp(0.0, max));
    _settleJump(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (m.msgUid != null) {
        setState(() => _rippleUid = m.msgUid);
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted && _rippleUid == m.msgUid) {
            setState(() => _rippleUid = null);
          }
        });
      }
      // clear the jump target once the ripple settles so the key frees up.
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted && _jumpUid == m.msgUid) {
          setState(() => _jumpUid = null);
        }
      });
    });
  }

  void _scrollToGroupMessage(_GMsg m) {
    var idx = _messages.indexOf(m);
    if (idx < 0 && m.msgUid != null) {
      // a reload swapped the list objects since this reference was taken -
      // the identity lookup fails and the tap used to just do nothing.
      idx = _messages.indexWhere((x) => x.msgUid == m.msgUid);
    }
    _scrollToIndex(idx);
  }

  Future<void> _showGroupPinnedSheet() async {
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
                  size: 11,
                  color: HaloColors.text3,
                  letter: 0.14,
                ),
              ),
            ),
            for (final m in pinned)
              InkWell(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(ctx);
                  _scrollToGroupMessage(m);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.push_pin_outlined,
                        size: 14,
                        color: HaloColors.amber,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.text.isEmpty ? 'photo' : m.text,
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
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx);
                          _togglePinGroup(m);
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
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
    // the sheet restores focus to the composer when it pops (that's what
    // kept yanking the keyboard up) - drop focus after it has closed.
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _togglePinGroup(_GMsg m) async {
    if (m.msgUid == null) return;
    if (!m.pinned) {
      final count = _messages.where((x) => x.pinned).length;
      if (count >= 3) {
        if (mounted) showHaloToast(context, 'max 3 pinned');
        return;
      }
    }
    final next = !m.pinned;
    if (mounted) setState(() => m.pinned = next);
    await appState.pinInGroup(widget.groupId, m.msgUid!, next);
  }

  Future<void> _toggleSavedGroup(_GMsg m) async {
    if (m.msgUid == null) return;
    final next = !m.saved;
    setState(() => m.saved = next);
    await db.setSaved(m.msgUid!, next);
    if (mounted) showHaloToast(context, next ? 'saved' : 'removed from saved');
  }

  Future<void> _forwardGroupMessage(_GMsg m) async {
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
                              KryfoAvatar(seed: c.avatarSeed, size: 32),
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
      haloRoute(
        ChatScreen(
          peerHaloId: haloId,
          peerOnion: (row['onion'] as String?) ?? '',
          peerXPub: (row['xpub'] as String?) ?? '',
          avatarSeed: haloId,
          initialText: m.text,
        ),
      ),
    );
  }

  Future<void> _editGroupMessage(_GMsg m) async {
    if (m.msgUid == null) return;
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
              decoration: InputDecoration(
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
    await appState.editInGroup(widget.groupId, m.msgUid!, newText);
  }

  Future<void> _unsendGroupMessage(_GMsg m) async {
    if (m.msgUid == null) return;
    // the confirm sheet hands focus back to the composer, popping the
    // keyboard for no reason. drop it.
    FocusManager.instance.primaryFocus?.unfocus();
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
                    Icon(
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
    await Future.delayed(const Duration(milliseconds: 560));
    if (mounted) setState(() => _messages.remove(m));
    await appState.unsendInGroup(widget.groupId, m.msgUid!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // backgrounded with the group open: drop the "open" marker so incoming
    // messages bump the unread badge instead of being treated as read.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      if (currentChatPeer == 'group:${widget.groupId}') currentChatPeer = null;
    } else if (state == AppLifecycleState.resumed) {
      // only re-claim the marker while we're the visible route, else backing
      // out and resuming later leaves the group marked open and its badge dead.
      final visible = ModalRoute.of(context)?.isCurrent ?? false;
      if (!visible) {
        if (currentChatPeer == 'group:${widget.groupId}') {
          currentChatPeer = null;
        }
        return;
      }
      currentChatPeer = 'group:${widget.groupId}';
      db.clearGroupUnread(widget.groupId).then((_) => appState.refreshGroups());
    }
  }

  @override
  void deactivate() {
    // popped or covered: stop claiming this group is being read.
    if (currentChatPeer == 'group:${widget.groupId}') currentChatPeer = null;
    _leaveRoomScreen();
    super.deactivate();
  }

  // the shield comes off here and not only in dispose: on some phones the
  // popped screen is deactivated but never disposed, and a shield nobody
  // lifts makes the whole app unscreenshottable until a restart.
  bool _left = false;
  void _leaveRoomScreen() {
    if (_left) return;
    _left = true;
    if (appState.secureChats || _isRoom) appState.forceSecure(false);
    if (_isRoom && _roomBanner) db.markRoomSeen(widget.groupId);
  }

  @override
  void activate() {
    super.activate();
    // came back after a deactivate that was only a reparent
    _left = false;
    if (_isRoom) appState.forceSecure(true);
  }

  @override
  void dispose() {
    _leaveRoomScreen();
    // persist the draft one more time on the way out.
    final draft = _msgCtrl.text;
    if (draft.trim().isEmpty) {
      _draftPerGroup.remove(widget.groupId);
    } else {
      _draftPerGroup[widget.groupId] = draft;
    }
    if (_menuEntry?.mounted ?? false) _menuEntry!.remove();
    _menuEntry = null;
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onGroupScroll);
    _scrollCtrl.removeListener(_updateSticky);
    _stickyHideTimer?.cancel();
    _stickyLabel.dispose();
    _stickyShown.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
            _searching
                ? SearchHead(
                    controller: _searchCtrl,
                    matchCount: _matches.length,
                    matchPos: _matches.isEmpty ? 0 : _matchPos + 1,
                    onChanged: _onQueryChanged,
                    onPrev: () => _gotoMatch(-1),
                    onNext: () => _gotoMatch(1),
                    onClose: _closeSearch,
                  )
                : _Header(
                    name: _groupName,
                    memberCount: _memberCount,
                    expiresAt: _roomExpiresAt,
                    onBack: () => Navigator.of(context).pop(),
                    onSearch: _openSearch,
                    pinnedCount: _messages.where((m) => m.pinned).length,
                    onPinned: _showGroupPinnedSheet,
                    onTapInfo: () async {
                      await Navigator.of(context).push(
                        haloRoute(GroupInfoScreen(groupId: widget.groupId)),
                      );
                      _load();
                    },
                  ),
            if (_isRoom && _roomBanner)
              NoticeBanner(
                glyph: NoticeGlyph.clock,
                text:
                    'this room and everything in it disappears in '
                    '${expiryWords(DateTime.fromMillisecondsSinceEpoch(_roomExpiresAt!).difference(DateTime.now()))}',
                color: HaloColors.violet,
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                delay: const Duration(milliseconds: 160),
              ),
            if (_messages.any((m) => m.pinned))
              _GroupPinnedBar(
                message: _messages.lastWhere((m) => m.pinned),
                onTap: () =>
                    _scrollToGroupMessage(_messages.lastWhere((m) => m.pinned)),
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
                  : Stack(
                      children: [
                        if (_atmosphere != Atmo.none)
                          Positioned.fill(child: AtmosphereWash(_atmosphere)),
                        _scrollDownButton(),
                        ListView.builder(
                          key: _listKey,
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            // one unbuildable message must not cost the
                            // whole conversation.
                            try {
                              return _buildGroupRow(i);
                            } catch (e) {
                              debugPrint('group bubble failed: \$e');
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  "this message can't be shown",
                                  style: HaloType.sans(
                                    size: 12,
                                    color: HaloColors.text3,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _stickyShown,
                                builder: (_, shown, _) => AnimatedOpacity(
                                  duration: const Duration(milliseconds: 220),
                                  opacity: shown ? 1.0 : 0.0,
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: _stickyLabel,
                                    builder: (_, label, _) => label == null
                                        ? const SizedBox.shrink()
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: HaloColors.surface2
                                                  .withValues(alpha: 0.92),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: HaloColors.line,
                                              ),
                                            ),
                                            child: Text(
                                              label,
                                              style: HaloType.serif(
                                                size: 12,
                                                italic: true,
                                                color: HaloColors.text,
                                                weight: FontWeight.w400,
                                              ),
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
            if (_replyTo != null)
              _ReplyQuoteBar(
                target: _replyTo!,
                onCancel: () => setState(() => _replyTo = null),
              ),
            IncomingMediaBanner(chatKey: widget.groupId),
            _Composer(
              controller: _msgCtrl,
              sending: _sending,
              ghost: _ghost,
              disguise: _disguise,
              onToggleGhost: () => setState(() => _ghost = !_ghost),
              onLongPressGhost: _showBurnPicker,
              onSend: _send,
              onAttach: _showAttachSheet,
              onToggleDisguise: _toggleDisguise,
              onVoiceComplete: _onVoiceComplete,
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
  bool removing;
  bool fresh = false; // one-shot: animate entrance, then cleared on first build
  String? mediaPath;
  String? filePath;
  String? fileName;
  bool voiceDisguised;
  bool pinned;
  bool saved;
  bool edited;
  Map<String, String>? preview;
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
    this.removing = false,
    this.mediaPath,
    this.filePath,
    this.fileName,
    this.voiceDisguised = false,
    this.pinned = false,
    this.saved = false,
    this.edited = false,
    this.preview,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? {},
       senderName = senderName ?? sender;
}

// ───────── header ─────────

class _GroupPinnedBar extends StatelessWidget {
  final _GMsg message;
  final VoidCallback onTap;
  const _GroupPinnedBar({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = message.text.isEmpty ? 'photo' : message.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            border: Border(
              bottom: BorderSide(color: HaloColors.line, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 2.5,
                height: 30,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'pinned',
                      style: HaloType.mono(
                        size: 9.5,
                        color: HaloColors.amber,
                        letter: 0.6,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 13, color: HaloColors.text),
                    ),
                  ],
                ),
              ),
              Icon(Icons.push_pin, size: 14, color: HaloColors.amber),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final int memberCount;
  final int? expiresAt; // a room: the subtitle is the clock, not the count
  final VoidCallback onBack;
  final VoidCallback onTapInfo;
  final VoidCallback? onSearch;
  final int pinnedCount;
  final VoidCallback? onPinned;
  const _Header({
    required this.name,
    required this.memberCount,
    this.expiresAt,
    required this.onBack,
    required this.onTapInfo,
    this.onSearch,
    this.pinnedCount = 0,
    this.onPinned,
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
                          color: HaloColors.amber.withValues(alpha: 0.35),
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
                          if (expiresAt != null)
                            Row(
                              children: [
                                RoomCountdown(expiresAt: expiresAt!, size: 10),
                                Text(
                                  ' · $memberCount here',
                                  style: HaloType.mono(
                                    size: 10,
                                    color: HaloColors.text3,
                                  ),
                                ),
                              ],
                            )
                          else
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
          if (pinnedCount > 0)
            InkWell(
              onTap: onPinned,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Icon(Icons.push_pin, size: 14, color: HaloColors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '$pinnedCount',
                      style: HaloType.mono(size: 10.5, color: HaloColors.amber),
                    ),
                  ],
                ),
              ),
            ),
          if (onSearch != null)
            IconButton(
              icon: Icon(Icons.search, color: HaloColors.text2, size: 21),
              onPressed: onSearch,
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
  final bool disguise;
  final VoidCallback onToggleGhost;
  final VoidCallback onLongPressGhost;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onToggleDisguise;
  final void Function(String path, int ms, bool cancelled) onVoiceComplete;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.ghost,
    required this.disguise,
    required this.onToggleGhost,
    required this.onLongPressGhost,
    required this.onSend,
    required this.onAttach,
    required this.onToggleDisguise,
    required this.onVoiceComplete,
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
          GestureDetector(
            onTap: onAttach,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 22,
                color: HaloColors.text2,
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
                  color: HaloColors.amber.withValues(alpha: 0.4),
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              // empty field: voice lane. text: the send pill.
              if (!hasText && !sending) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onToggleDisguise,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          disguise
                              ? Icons.record_voice_over
                              : Icons.voice_over_off,
                          size: 20,
                          color: disguise ? HaloColors.amber : HaloColors.text3,
                        ),
                      ),
                    ),
                    HoldToTalkMic(
                      disguise: disguise,
                      onToggleDisguise: onToggleDisguise,
                      onComplete: onVoiceComplete,
                    ),
                  ],
                );
              }
              final canSend = !sending && hasText;
              return PressScale(
                onTap: canSend ? onSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: canSend ? HaloColors.amber : HaloColors.surface3,
                    shape: BoxShape.circle,
                    boxShadow: canSend
                        ? [
                            BoxShadow(
                              color: HaloColors.amber.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: -1,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: canSend ? HaloColors.onAmber : HaloColors.text3,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────── bubble ─────────

// stable accent per sender so each person reads as their own colour in a group.
Color _authorColor(String id) {
  final palette = [
    HaloColors.green,
    HaloColors.rose,
    HaloColors.violet,
    HaloColors.amber,
  ];
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

// swipe right on any bubble to reply, mirroring the 1:1 gesture. the reply
// icon peeks from the left and haptics fire when you cross the trigger.
class _GroupSwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _GroupSwipeToReply({required this.child, required this.onReply});
  @override
  State<_GroupSwipeToReply> createState() => _GroupSwipeToReplyState();
}

class _GroupSwipeToReplyState extends State<_GroupSwipeToReply>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _armed = false;
  static const double _trigger = 56;
  static const double _max = 80;
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Animation<double> _back = const AlwaysStoppedAnimation(0);

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _settle() {
    _back = Tween(begin: _dx, end: 0.0).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    )..addListener(() => setState(() => _dx = _back.value));
    _spring
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        if (_spring.isAnimating) return;
        var nx = _dx + d.delta.dx;
        if (nx < 0) nx = 0;
        if (nx > _trigger) nx = _trigger + (nx - _trigger) * 0.35;
        if (nx > _max) nx = _max;
        final wasArmed = _armed;
        _armed = nx >= _trigger;
        if (_armed && !wasArmed) HapticFeedback.selectionClick();
        setState(() => _dx = nx);
      },
      onHorizontalDragEnd: (_) {
        if (_armed) widget.onReply();
        _armed = false;
        _settle();
      },
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Icon(
                    Icons.reply_rounded,
                    size: 20,
                    color: HaloColors.amber,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

// entrance motion matching the 1:1 chat: an outgoing bubble lifts + fades up
// with an amber glow, an incoming one slides in from the left. one-shot.
Widget _groupBubbleEntrance({
  required bool isOut,
  required bool active,
  required Widget child,
}) {
  if (!active) return child;
  if (isOut) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((1 - t) * 14, (1 - t) * 30),
          child: Transform.scale(
            scale: 0.82 + 0.18 * t,
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: HaloColors.amber.withValues(alpha: 0.45 * (1 - t)),
                    blurRadius: 18 * (1 - t) + 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: c,
            ),
          ),
        ),
      ),
    );
  }
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (_, t, c) => Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset((1 - t) * -14, (1 - t) * 6),
        child: Transform.scale(
          scale: 0.96 + 0.04 * t,
          alignment: Alignment.centerLeft,
          child: c,
        ),
      ),
    ),
  );
}

class _GroupBubble extends StatelessWidget {
  final _GMsg m;
  final bool showSender;
  final String? senderBadge;
  final String? quotedText;
  final String? quotedAuthor;
  final void Function(BuildContext)? onLongPress;
  final VoidCallback? onRetry;
  final bool ripple;
  final VoidCallback? onReplyTap;
  const _GroupBubble({
    required this.m,
    required this.showSender,
    this.senderBadge,
    this.quotedText,
    this.quotedAuthor,
    this.onLongPress,
    this.onRetry,
    this.ripple = false,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = m.direction == 'out';
    return BurnFade(
      active: m.removing,
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
                child: KryfoAvatar(seed: m.sender, size: 26),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.senderName,
                            style: HaloType.mono(
                              size: 9.5,
                              color: _authorColor(m.sender),
                              letter: 0.4,
                            ),
                          ),
                          if (senderBadge != null) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: HaloColors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: HaloColors.amber.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Text(
                                'supporter',
                                style: HaloType.mono(
                                  size: 7.5,
                                  color: HaloColors.amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Builder(
                        builder: (ctx) {
                          return GestureDetector(
                            onTap: m.failed ? onRetry : null,
                            onLongPress: onLongPress == null
                                ? null
                                : () => onLongPress!(ctx),
                            child: Container(
                              padding: m.mediaPath != null
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.fromLTRB(12, 8, 12, 9),
                              decoration: BoxDecoration(
                                // any photo goes edge-to-edge, no bubble fill,
                                // so there's no amber/grey frame (1:1 look).
                                color: m.mediaPath != null
                                    ? Colors.transparent
                                    : (isOut
                                          ? HaloColors.amber
                                          : HaloColors.surface2),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isOut ? 14 : 4),
                                  bottomRight: Radius.circular(isOut ? 4 : 14),
                                ),
                              ),
                              clipBehavior: m.mediaPath != null
                                  ? Clip.antiAlias
                                  : Clip.none,
                              child: IntrinsicWidth(
                                child: Column(
                                  crossAxisAlignment: isOut
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (quotedText != null) ...[
                                      GestureDetector(
                                        onTap: onReplyTap,
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            10,
                                            6,
                                            10,
                                            7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isOut
                                                ? Colors.black.withValues(
                                                    alpha: 0.12,
                                                  )
                                                : HaloColors.surface3,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border(
                                              left: BorderSide(
                                                color: isOut
                                                    ? HaloColors.onAmber
                                                          .withValues(
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
                                                              .withValues(
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
                                                      ? HaloColors.onAmber
                                                            .withValues(
                                                              alpha: 0.8,
                                                            )
                                                      : HaloColors.text2,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (m.fileName == 'voice.wav' &&
                                        m.filePath != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: VoiceBubble(
                                          key: ValueKey('gvb_${m.filePath}'),
                                          path: m.filePath!,
                                          isOut: isOut,
                                          disguised: m.voiceDisguised,
                                        ),
                                      )
                                    else if (m.fileName != null)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          if (m.filePath != null) {
                                            SharePlus.instance.share(
                                              ShareParams(
                                                files: [XFile(m.filePath!)],
                                              ),
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: fileCard(
                                            m.filePath,
                                            m.fileName,
                                            isOut,
                                          ),
                                        ),
                                      ),
                                    if (m.mediaPath != null)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: m.text.isNotEmpty ? 6 : 0,
                                        ),
                                        child: GestureDetector(
                                          onTap: m.failed
                                              ? onRetry
                                              : () => openFullImage(
                                                  context,
                                                  m.mediaPath!,
                                                ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Stack(
                                              children: [
                                                ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxHeight: 280,
                                                        maxWidth: 240,
                                                      ),
                                                  child: Image.file(
                                                    File(m.mediaPath!),
                                                    cacheWidth: 1080,
                                                    gaplessPlayback: true,
                                                    filterQuality:
                                                        FilterQuality.medium,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        const SizedBox.shrink(),
                                                  ),
                                                ),
                                                // caption-less photo: float the
                                                // time in a pill on the corner,
                                                // same as 1:1. captioned photos
                                                // keep the time in the row below.
                                                if (m.text.isEmpty && !m.failed)
                                                  Positioned(
                                                    // chip hangs right on out,
                                                    // left on in - time takes
                                                    // the free corner.
                                                    right: isOut ? null : 8,
                                                    left: isOut ? 8 : null,
                                                    bottom: 8,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 7,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _fmtTime(m.when),
                                                        style: const TextStyle(
                                                          fontFamily:
                                                              'JetBrains Mono',
                                                          fontSize: 9,
                                                          color: Colors.white,
                                                          letterSpacing: 0.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (m.text.isNotEmpty)
                                      Padding(
                                        padding: m.mediaPath != null
                                            ? const EdgeInsets.fromLTRB(
                                                4,
                                                6,
                                                4,
                                                0,
                                              )
                                            : EdgeInsets.zero,
                                        child: Text(
                                          m.text,
                                          style: HaloType.sans(
                                            size: 14,
                                            // captions get a touch more weight
                                            // so they read over busy images.
                                            weight: m.mediaPath != null
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            // a photo caption sits on a transparent
                                            // bubble (no amber), so onAmber would be
                                            // invisible - use the readable color.
                                            // text-only out messages keep onAmber.
                                            color:
                                                (isOut && m.mediaPath == null)
                                                ? HaloColors.onAmber
                                                : HaloColors.text,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    if (m.preview != null) ...[
                                      const SizedBox(height: 6),
                                      LinkPreviewCard(
                                        preview: m.preview!,
                                        isOut: isOut,
                                        fill: true,
                                      ),
                                    ],
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
                                              // an outgoing photo sits on a
                                              // transparent bubble, so onAmber
                                              // (dark) was invisible there -
                                              // media rows take the amber look.
                                              color:
                                                  (isOut && m.mediaPath == null)
                                                  ? HaloColors.onAmber
                                                        .withValues(alpha: 0.15)
                                                  : HaloColors.amberSoft,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '🔥 ${_remaining(m.burnAt!)}',
                                              style: HaloType.mono(
                                                size: 9,
                                                color:
                                                    (isOut &&
                                                        m.mediaPath == null)
                                                    ? HaloColors.onAmber
                                                    : HaloColors.amber,
                                                letter: 0.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (m.edited) ...[
                                          Text(
                                            'edited ',
                                            style: HaloType.mono(
                                              size: 9,
                                              color:
                                                  (isOut && m.mediaPath == null)
                                                  ? HaloColors.onAmber
                                                        .withValues(alpha: 0.6)
                                                  : isOut
                                                  ? HaloColors.text2
                                                  : HaloColors.text3,
                                            ),
                                          ),
                                        ],
                                        // caption-less photo shows its time on the
                                        // image overlay, so skip it here to avoid
                                        // a doubled timestamp.
                                        if (!(m.mediaPath != null &&
                                            m.text.isEmpty &&
                                            !m.failed))
                                          Text(
                                            _fmtTime(m.when),
                                            style: HaloType.mono(
                                              size: 9.5,
                                              // out photo bubble is transparent:
                                              // onAmber (dark) vanished there.
                                              color:
                                                  (isOut && m.mediaPath == null)
                                                  ? HaloColors.onAmber
                                                        .withValues(alpha: 0.7)
                                                  : isOut
                                                  ? HaloColors.text2
                                                  : HaloColors.text3,
                                            ),
                                          ),
                                        // sent tick, matching 1:1: outgoing +
                                        // delivered, only where the row-time shows
                                        // (skip caption-less photos, time's on the
                                        // image there). photo bubble is
                                        // transparent so use a readable color.
                                        if (isOut &&
                                            !m.sending &&
                                            !m.failed &&
                                            !(m.mediaPath != null &&
                                                m.text.isEmpty)) ...[
                                          const SizedBox(width: 3),
                                          Text(
                                            '✓',
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 11,
                                              color: m.mediaPath != null
                                                  ? HaloColors.text2
                                                  : HaloColors.onAmber
                                                        .withValues(alpha: 0.7),
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                          ),
                                        ],
                                        if (m.failed) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '! tap to retry',
                                            style: HaloType.mono(
                                              size: 9,
                                              color: isOut
                                                  ? HaloColors.onAmber
                                                  : HaloColors.rose,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (m.reactions.isNotEmpty)
                        Positioned(
                          // ig-style: hangs at the bubble's bottom edge on the
                          // sender's side, same as 1:1. keys off direction.
                          bottom: -13,
                          right: isOut ? 10 : null,
                          left: isOut ? null : 10,
                          child: Wrap(
                            spacing: 3,
                            children: _buildReactionChips(m),
                          ),
                        ),
                      if (ripple)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 820),
                              curve: Curves.easeOut,
                              builder: (context, t, child) => Opacity(
                                opacity: (1 - t) * 0.92,
                                child: Transform.scale(
                                  scale: 1 + t * 0.16,
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
                  if (m.reactions.isNotEmpty) const SizedBox(height: 10),
                  if (isOut && m.sending) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.msgUid != null &&
                              (m.mediaPath != null || m.filePath != null)) ...[
                            SendProgressLabel(msgUid: m.msgUid!),
                            const SizedBox(width: 6),
                          ],
                          SendPill(mode: _groupSendMode()),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PrivacyMode _groupSendMode() => appState.sendMode == 'fast'
      ? PrivacyMode.fast
      : appState.sendMode == 'private'
      ? PrivacyMode.private
      : PrivacyMode.normal;

  List<Widget> _buildReactionChips(_GMsg m) {
    final counts = <String, int>{};
    for (final emoji in m.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final selfEmoji = m.reactions[''];
    return counts.entries.map<Widget>((e) {
      final isSelf = e.key == selfEmoji;
      // solid ink pill, no border - same as 1:1, reads as a tab under the bubble.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: HaloColors.ink,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.key, style: const TextStyle(fontSize: 13, height: 1.2)),
            if (e.value > 1) ...[
              const SizedBox(width: 3),
              Text(
                '${e.value}',
                style: HaloType.mono(
                  size: 9.5,
                  color: isSelf ? HaloColors.amber : HaloColors.text2,
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
    this.isOut = false,
    this.pinned = false,
    this.saved = false,
    this.onCopy,
    this.onPin,
    this.onSave,
    this.onForward,
    this.onEdit,
    this.onUnsend,
  });
  final bool isOut;
  final bool pinned;
  final bool saved;
  final VoidCallback? onCopy;
  final VoidCallback? onPin;
  final VoidCallback? onSave;
  final VoidCallback? onForward;
  final VoidCallback? onEdit;
  final VoidCallback? onUnsend;
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
      builder: (_, _) => Opacity(
        opacity: fade.value,
        child: Transform.scale(
          scale: scale.value,
          alignment: widget.isOut
              ? Alignment.bottomRight
              : Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: widget.isOut
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: HaloColors.line, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
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
              _menuRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow() {
    final items = <Widget>[];
    void add(IconData icon, String label, VoidCallback? tap, {Color? tint}) {
      if (tap == null) return;
      items.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: tint ?? HaloColors.text2),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: HaloType.sans(
                      size: 13,
                      color: tint ?? HaloColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    add(Icons.push_pin_outlined, widget.pinned ? 'unpin' : 'pin', widget.onPin);
    add(
      widget.saved ? Icons.bookmark : Icons.bookmark_outline,
      widget.saved ? 'unsave' : 'save',
      widget.onSave,
    );
    add(Icons.copy_rounded, 'copy', widget.onCopy);
    add(Icons.forward_rounded, 'forward', widget.onForward);
    if (widget.isOut) {
      add(Icons.edit_outlined, 'edit', widget.onEdit, tint: HaloColors.amber);
      add(
        Icons.delete_outline,
        'unsend',
        widget.onUnsend,
        tint: HaloColors.rose,
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
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
