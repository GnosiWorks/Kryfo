// SPDX-License-Identifier: GPL-3.0-or-later
// group chat: text, media, replies, reactions and ghost mode, with the same
// gestures as the 1:1 chat.

import 'dart:async';
import 'dart:math' as math;
import '../lock_state.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../picked.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/press_scale.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/pins.dart';
import '../widgets/remembered_height.dart';
import '../widgets/video_bubble.dart';
import '../widgets/kryfo_link_text.dart';
import '../open_file.dart';
import '../widgets/media_bubbles.dart';
import '../widgets/decode_px.dart';
import '../atmosphere.dart';
import 'shield_sheet.dart';
import '../notifications.dart' show clearNotificationsFor;
import '../devchat/dev_key.dart' show isDevChat;
import 'dev_about_sheet.dart'
    show DevForwardTile, devChatRoute, devForwardTarget, devSlot;
import 'chat_screen.dart'
    show
        disguiseWav,
        ChatScreen,
        SearchHead,
        Atmo,
        AtmosphereWash,
        atmoFromName,
        firstUrl;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../stickers/sticker_bubble.dart';
import '../stickers/sticker_flight.dart';
import '../stickers/sticker_pack.dart' show Sticker, StickerLibrary;
import '../stickers/sticker_sheet.dart'
    show StickerButton, StickerPick, showStickerSheet;
import '../stickers/sticker_view.dart' show StickerBudget;
import '../stickers/sticker_wire.dart' show StickerWire;
import '../main.dart'
    show
        appState,
        session,
        claimChat,
        releaseChat,
        newMsgUid,
        torStrictGetOnIsolate,
        shredFile;
import '../theme.dart';
import '../media_progress.dart';
import '../media_send.dart' show cancelMediaSend;
import '../image_strip.dart';
import '../mp4_strip.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/burn_fade.dart';
import '../seen_timers.dart';
import 'group_info_screen.dart';
import '../widgets/motion.dart'
    show haloRoute, SendPill, PrivacyMode, TorStatus, motionStill;
import '../widgets/chat_parts.dart';
import '../widgets/message_menu.dart';
import '../rooms.dart';
import '../widgets/notice_banner.dart';
import '../widgets/room_countdown.dart';
import '../widgets/swipe_to_reply.dart';
import 'room_link_sheet.dart';
import '../dlog.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/menu_backdrop.dart';
import '../mentions.dart';
import '../widgets/link_stub.dart';
import 'camera_screen.dart';
import '../link_preview.dart' show titleFromHtml, senderPreview;
import '../widgets/preview_strip.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/moved_strip.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/marked.dart';
import '../l10n/numbers.dart';
import '../widgets/video_viewer.dart';
import '../widgets/photo_viewer.dart' show photoHeroTag;
import '../widgets/voice_parts.dart' show DisguiseToggle;
import '../polls.dart';
import '../widgets/attach_grid.dart';
import '../widgets/new_poll_sheet.dart';
import '../widgets/poll_card.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/written_field.dart';
import '../bidi_safe.dart';
import '../lock_guard.dart' show lockGuard, onScreen;

final Map<String, String> _draftPerGroup = {};

// our nickname for a member, or nothing so the id shows. a room member is a
// key, not a person we know, so it gets the short tag instead.
String? _senderLabel(Map<String, String> nickById, String peer) =>
    nickById[peer] ?? (looksLikeRoomKey(peer) ? roomTag(peer) : null);

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  // open at this message, lit for a moment (from search)
  final String? jumpToUid;
  const GroupChatScreen({super.key, required this.groupId, this.jumpToUid});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  // the people @ can offer, refreshed with the roster
  List<MentionCandidate> _mentionable = const [];
  final _scrollCtrl = ScrollController();
  final List<_GMsg> _messages = [];
  bool _showScrollDown = false;
  int _seenCount = 0;
  String _groupName = '';
  int _memberCount = 0;
  // who this phone is in this chat: its kryfo id, or its key in a room
  String _me = '';

  String _nameOf(String id) {
    for (final c in appState.contacts) {
      final n = c.nickname;
      if (c.haloId == id && n != null && n.isNotEmpty) return n;
    }
    return _senderLabel(const {}, id) ?? id;
  }

  // burner room state: when it ends, and whether this is the first open
  int? _roomExpiresAt;
  bool _roomBanner = false;
  bool get _isRoom => _roomExpiresAt != null;
  bool _isAdmin = false;
  bool _sending = false;
  // at most six stickers play at once in the whole chat
  final _stickers = StickerBudget(6);
  // stickers flying in from the sheet, by message uid. a bubble stays
  // hidden until its flight is down
  final Map<String, StickerLanding> _landings = {};
  final List<VoidCallback> _flights = [];
  _GMsg? _replyTo;
  // takes the open message menu away, if there is one
  VoidCallback? _menuClose;
  // the bubble under an open menu: hidden in the list, drawn lifted above
  // the blur
  String? _liftedUid;
  final GlobalKey _jumpKey = GlobalKey();
  String? _jumpUid;
  String? _rippleUid;
  // keyed by the uid of the row each divider precedes. index keys reparent
  // when rows shift (burns), and dayMs keys repeat when a late older message
  // splits a day into two runs: two dividers, one GlobalKey. the anchor uid
  // is unique per divider and stable.
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
  // what was looked for, and the same hits as _matches for a row's test
  String _query = '';
  Set<int> _matchSet = {};
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
  // the burn and the auto retry run only while the group is in view, and
  // catch up the moment it is back
  final _timers = SeenTimers();
  late final SeenJob _burn;
  int _lastBurnSec = 0;
  bool _loading = false;
  bool _reloadQueued = false;
  bool _loaded = false; // first full load done - gates the append-fast-path
  int _seenRev = -1; // last group rev we reloaded for
  // the shield's verdict on members you never added, by id. a mark on
  // their own bubbles, nothing above the thread.
  final Map<String, ShieldFlag> _shieldFlags = {};
  int _seenShieldRev = -1;

  @override
  void initState() {
    super.initState();

    claimChat('group:${widget.groupId}');
    WidgetsBinding.instance.addObserver(this);
    // read once, before the first sticker row asks for it. a failure here is
    // the row's to show when it loads again
    StickerLibrary.load().ignore();
    lockState.addListener(_lockLifted);
    // a room is never in the app switcher and never screenshotted. the flag
    // is set the moment we know it is a room and cleared on the way out.
    session.getGroup(widget.groupId).then((g) async {
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
    // opened under the lock: marked read once it lifts
    lockGuard.isLocked() ? _underLock = true : _markRead();
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
    _timers.every(const Duration(seconds: 30), _autoRetryTick);
    _burn = _timers.until(_burnWait, _burnTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  // when the burn looks again: the next deadline, or the countdown's next
  // second. nothing while no message here counts down
  Duration? _burnWait() {
    var ghosts = false;
    int? soonest;
    for (final m in _messages) {
      final at = m.burnAt;
      if (at == null) continue;
      ghosts = true;
      if (m.removing || m.sending || m.failed) continue;
      if (soonest == null || at < soonest) soonest = at;
    }
    return burnWait(
      DateTime.now().millisecondsSinceEpoch,
      ghosts: ghosts,
      soonest: soonest,
    );
  }

  void _burnTick(bool back) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // one pass, and no list unless something actually burnt. most groups
    // carry no ghosts at all
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
      }
      if (back) {
        // it burned while the group was out of view: gone, as it would be
        // by now, with no burn played for it
        _messages.removeWhere(expired.contains);
        for (final m in expired) {
          if (m.msgUid != null) session.deleteMessage(m.msgUid!);
        }
      } else {
        for (final m in expired) {
          // it burns, then its row folds (LeaveFold); pulled sooner, the
          // animation is cut off and the messages around it jump
          Future.delayed(kLeaveGone, () {
            if (mounted) setState(() => _messages.remove(m));
            if (m.msgUid != null) session.deleteMessage(m.msgUid!);
          });
        }
        HapticFeedback.lightImpact();
      }
    }
    // repaint when something expired or the countdown changes second
    final sec = now ~/ 1000;
    if (expired != null || sec != _lastBurnSec) {
      _lastBurnSec = sec;
      setState(() {});
    }
  }

  // jump to newest, same control as 1:1
  Widget _scrollDownButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: Center(
        child: JumpDownButton(
          shown: _showScrollDown,
          count: _messages.length - _seenCount,
          label: l10n.groupChatJumpToTheNewest,
          onTap: () {
            setState(() => _seenCount = _messages.length);
            _scrollToEnd();
          },
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

  // who is blocked, refreshed with every load. appState.contacts is
  // accepted-only and would miss anyone blocked while still a stranger.
  Set<String> _blocked = {};

  List<Map<String, Object?>> _withoutBlocked(List<Map<String, Object?>> rows) {
    if (_blocked.isEmpty) return rows;
    return [
      for (final r in rows)
        if (!_blocked.contains(r['peer_id'])) r,
    ];
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _searching) return;
    _loadingOlder = true;
    try {
      final oldestRowid = _messages.isEmpty ? null : _messages.first.rowid;
      _blocked = await session.blockedIds();
      final rows0 = await session.groupMessagesPage(
        widget.groupId,
        beforeRowid: oldestRowid,
        limit: _pageSize + 1,
      );
      // a blocked member is out of sight here too, not only at the door.
      // the page size is judged before the filter, or one filtered row
      // ends paging for good.
      _hasMore = rows0.length > _pageSize;
      final rows = _withoutBlocked(rows0);
      if (!mounted) return;
      if (_hasMore && rows.isNotEmpty && rows.length == rows0.length) {
        rows.removeAt(0);
      }
      if (!_hasMore) _pagedOut = true;
      if (rows.isEmpty) return;
      final uids = rows
          .map((r) => r['msg_uid'] as String?)
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toList();
      final reactions = await session.loadReactionsFor(uids);
      final votes = await session.pollVotesFor(uids);
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
          sticker: StickerWire.parse(r['sticker']),
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
        m.poll = PollSpec.parse(r['poll']);
        m.votes = votes[uid] ?? const {};
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
      session.getGroupAtmosphere(widget.groupId).then((a) {
        if (mounted) setState(() => _atmosphere = atmoFromName(a));
      });
      final g = await session.getGroup(widget.groupId);
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
      final members = await session.getGroupMembers(widget.groupId);
      _me = await appState.meIn(widget.groupId);
      // keep whatever window the user has expanded to, so a mid-scroll
      // reaction does not collapse the list back to one page
      final wantAll =
          _searching ||
          _pagedOut ||
          _messages.length > _pageSize ||
          (widget.jumpToUid != null && !_didJump);
      _blocked = await session.blockedIds();
      final rows0 = wantAll
          ? await session.loadGroupMessages(widget.groupId)
          : await session.groupMessagesPage(
              widget.groupId,
              limit: _pageSize + 1,
            );
      if (!wantAll) {
        _hasMore = rows0.length > _pageSize;
        if (_hasMore) rows0.removeAt(0);
        if (!_hasMore) _pagedOut = true;
      }
      final rows = _withoutBlocked(rows0);
      // gather reactions for every uid we have
      final uids = rows
          .map((r) => r['msg_uid'] as String?)
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toList();
      final reactions = await session.loadReactionsFor(uids);
      final votes = await session.pollVotesFor(uids);
      // local nickname is the display source of truth. fall back to the 3-word
      // id when we have no nickname for that member.
      final nickById = <String, String>{};
      final faceById = <String, int?>{};
      for (final c in appState.contacts) {
        final n = c.nickname;
        if (n != null && n.isNotEmpty) nickById[c.haloId] = n;
        faceById[c.haloId] = c.avatar;
      }
      _mentionable = [
        for (final id in members)
          if (id != appState.sessionId)
            MentionCandidate(id: id, name: nickById[id], avatar: faceById[id]),
      ];
      if (!mounted) return;
      setState(() {
        _groupName = (g?['name'] as String?) ?? 'group';
        _memberCount = members.length;
        _roomExpiresAt = g?['expires_at'] as int?;
        _isAdmin = ((g?['is_admin'] as int?) ?? 0) == 1;
        // a reload rebuilds every row; the retry count rides across, or a
        // failed send never reaches its cap and spins forever
        final carry = {
          for (final m in _messages)
            if (m.msgUid != null) m.msgUid!: (m.autoRetries, m.gaveUp),
        };
        final before = List<_GMsg>.of(_messages);
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
                sticker: StickerWire.parse(r['sticker']),
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
              m.poll = PollSpec.parse(r['poll']);
              m.votes = votes[uid] ?? const {};
              m.rowid = (r['rowid'] as int?) ?? 0;
              // only a stale sending out-message is dead: a live send (<60s
              // old) keeps its pill, or a working media send flips to failed
              // mid-flight. while tor warms up the send is queued, not dead;
              // outside onion there is no warmup to wait out.
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
              final c = carry[m.msgUid];
              if (c != null) {
                m.autoRetries = c.$1;
                m.gaveUp = c.$2;
              }
              return m;
            }),
          );
        if (_loaded) _keepLeaving(before);
      });
      // only snap to the tail on first load or when the user is already
      // reading it, so a background reload (reaction, preview, burn) never
      // throws a pin jump or scrollback to the end of the chat
      final nearEnd = !_scrollReady || _maxScroll - _pixels < 240;
      final target = !_didJump && widget.jumpToUid != null
          ? _messages.indexWhere((m) => m.msgUid == widget.jumpToUid)
          : -1;
      if (widget.jumpToUid != null) _didJump = true;
      if (target >= 0) {
        _jumpWhenReady(target, 0);
      } else if (!_loaded || (nearEnd && _jumpUid == null)) {
        _scrollToEnd(instant: true);
      }
      _loaded = true;
      unawaited(_refreshPinCount());
      await _loadShieldFlags();
    } finally {
      // a throw mid-load must not leave _loading stuck true, or every later
      // refresh freezes
      _loading = false;
      // if changes landed while we were loading, run exactly one catch-up.
      if (_reloadQueued) {
        _reloadQueued = false;
        _load();
      }
    }
  }

  // a reload rebuilds every row from the database. a message already leaving
  // keeps its row so the burn and fold carry on, and one gone from the
  // database since leaves the same way, placed by time, instead of popping out
  void _keepLeaving(List<_GMsg> before) {
    final old = {
      for (final m in before)
        if (m.msgUid != null) m.msgUid!: m,
    };
    final present = <String>{};
    for (var i = 0; i < _messages.length; i++) {
      final uid = _messages[i].msgUid;
      if (uid == null) continue;
      present.add(uid);
      final o = old[uid];
      if (o != null && o.removing) _messages[i] = o;
    }
    final oldest = _messages.isEmpty ? null : _messages.first.when;
    for (final o in before) {
      final uid = o.msgUid;
      if (uid == null || present.contains(uid) || o.sending) continue;
      if (oldest != null && o.when.isBefore(oldest)) continue;
      if (!o.removing) {
        o.removing = true;
        Future.delayed(kLeaveGone, () {
          if (mounted) setState(() => _messages.remove(o));
        });
      }
      var at = _messages.indexWhere((m) => m.when.isAfter(o.when));
      if (at < 0) at = _messages.length;
      _messages.insert(at, o);
    }
  }

  Future<void> _loadShieldFlags() async {
    _seenShieldRev = appState.shieldRev;
    final senders = {
      for (final m in _messages)
        if (m.direction == 'in') m.sender,
    };
    final next = <String, ShieldFlag>{};
    for (final id in senders) {
      if (await session.isAccepted(id)) continue;
      final f = ShieldFlag.fromRow(await session.shieldFor(id));
      if (f != null) next[id] = f;
    }
    if (!mounted) return;
    setState(() {
      _shieldFlags
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _openShield(String id) async {
    final flag = _shieldFlags[id];
    if (flag == null) return;
    final c = await showShieldSheet(context, id, flag, group: true);
    if (!mounted) return;
    if (c == ShieldChoice.block) {
      showHaloToast(context, l10n.groupChatBlockedEverywhere);
      await _load();
      return;
    }
    await _loadShieldFlags();
  }

  void _onAppStateChanged() {
    // a verdict landed after its message did: refresh the marks alone
    if (appState.shieldRev != _seenShieldRev && !_loading) {
      unawaited(_loadShieldFlags());
    }
    // only react to our own group's traffic, or every 1:1 message reloads
    // this screen and churns every photo bubble
    final rev = appState.chatRevOf('group:${widget.groupId}');
    if (rev == _seenRev) return;
    _seenRev = rev;
    // a single multicast fires notifyListeners() once per recipient, and a
    // full _load() per fire freezes the ui. if a load is already running,
    // queue at most one follow-up.
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
    final rows = _withoutBlocked(
      await session.groupMessagesAfter(widget.groupId, lastRowid),
    );
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
      // no new rows: reactions, edits, unsends and burns need a full reload,
      // except while one of our own sends is in flight. a reload then
      // orphans the optimistic row and freezes its send pill, so it waits.
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
    final reactions = await session.loadReactionsFor(uids);
    final votes = await session.pollVotesFor(uids);
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
        sticker: StickerWire.parse(r['sticker']),
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
      m.poll = PollSpec.parse(r['poll']);
      m.votes = votes[uid] ?? const {};
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
    final shieldFlag = m.direction == 'in' ? _shieldFlags[m.sender] : null;
    // a flagged member's name line shows on every one of their bubbles,
    // since the mark lives there
    final showSender =
        m.direction == 'in' &&
        (shieldFlag != null ||
            prev == null ||
            prev.sender != m.sender ||
            prev.direction != 'in');
    String? quoted;
    String? quotedAuthor;
    StickerWire? quotedSticker;
    if (m.replyTo != null) {
      final orig = _messages.firstWhere(
        (x) => x.msgUid == m.replyTo,
        orElse: () =>
            _GMsg(sender: '', direction: '', text: '', when: DateTime.now()),
      );
      if (orig.direction.isNotEmpty) {
        quotedAuthor = orig.direction == 'out'
            ? l10n.groupChatYou
            : orig.senderName;
      }
      if (orig.sticker != null) {
        quoted = l10n.stickerLabel;
        quotedSticker = orig.sticker;
      } else if (orig.poll != null) {
        quoted = l10n.pollPreview(orig.text);
      } else if (orig.text.isNotEmpty) {
        quoted = orig.text;
      } else if (orig.mediaPath != null) {
        quoted = l10n.groupChatQuotedPhoto;
      } else if (orig.fileName == 'voice.wav') {
        quoted = l10n.groupChatVoiceMessage;
      } else if (orig.fileName != null) {
        quoted = orig.fileName;
      } else {
        quoted = l10n.groupChatMessageUnavailable;
        quotedAuthor = null;
      }
    }
    // an in-chat search marks its hits and dims the rest, as the 1:1 does
    final searchActive = _searching && _query.isNotEmpty;
    final isMatch = searchActive && _matchSet.contains(i);
    final isCurrent =
        searchActive && _matches.isNotEmpty && _matches[_matchPos] == i;
    final animateIn = m.fresh;
    m.fresh = false;
    final landing = m.msgUid == null ? null : _landings[m.msgUid];
    final showDate = i == 0 || (prev != null && !_sameDay(prev.when, m.when));
    return Column(
      key: ValueKey(m.msgUid ?? 'r${m.rowid}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDate) _dateDivider(m.when, m.msgUid ?? 'r${m.rowid}'),
        RepaintBoundary(
          key: (m.msgUid != null && m.msgUid == _jumpUid) ? _jumpKey : null,
          child: BubbleEntrance(
            isOut: m.direction == 'out',
            // a sticker pops or flies in on its own
            active: animateIn && m.sticker == null,
            // the row is the width of the list: a glow would light all of it
            glow: false,
            child: SwipeToReply(
              onReply: () => setState(() => _replyTo = m),
              // the lifted copy in the overlay is the one that animates;
              // the row underneath just steps aside
              child: Opacity(
                opacity: (m.msgUid != null && m.msgUid == _liftedUid)
                    ? 0.0
                    : 1.0,
                child: _GroupBubble(
                  m: m,
                  showSender: showSender,
                  stickers: _stickers,
                  stickerOrder: _messages.length - 1 - i,
                  landing: landing,
                  arriving: animateIn && landing == null,
                  quotedSticker: quotedSticker,
                  me: _me,
                  nameOf: _nameOf,
                  onVote: m.poll == null || m.msgUid == null
                      ? null
                      : (c) => appState.votePoll(widget.groupId, m.msgUid!, c),
                  onClosePoll: m.poll == null || m.msgUid == null
                      ? null
                      : () => appState.closePoll(widget.groupId, m.msgUid!),
                  senderBadge: _badgeFor(m.sender),
                  shieldFlag: shieldFlag,
                  onShield: shieldFlag == null
                      ? null
                      : () => _openShield(m.sender),
                  linkTitle: m.preview?['title'],
                  linkBySender: m.preview?['by'] == 'sender',
                  quotedText: quoted,
                  quotedAuthor: quotedAuthor,
                  onLongPress: (ctx) => _showEmojiPickerAt(
                    ctx,
                    m,
                    showSender: showSender,
                    quotedText: quoted,
                    quotedAuthor: quotedAuthor,
                    quotedSticker: quotedSticker,
                  ),
                  onRetry: m.looksFailed
                      ? () {
                          m.autoRetries = 0;
                          m.gaveUp = false;
                          _retryGroup(m);
                        }
                      : null,
                  ripple: m.msgUid != null && m.msgUid == _rippleUid,
                  query: searchActive ? _query : '',
                  isCurrentMatch: isCurrent,
                  dimmed: searchActive && !isMatch,
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

  // the sender side, as in a chat: fetched over tor on this phone, riding
  // inside the next message. never offered in a room
  Map<String, String>? _pendingPreview;
  bool _previewBusy = false;

  bool get _torUp {
    final s = appState.torStatus;
    return s == TorStatus.bootstrapped ||
        s == TorStatus.publishing ||
        s == TorStatus.reachable;
  }

  Future<void> _addPreview() async {
    final url = firstUrl(_msgCtrl.text);
    if (url == null || _previewBusy) return;
    setState(() => _previewBusy = true);
    try {
      final html = await torStrictGetOnIsolate(url);
      final title = html.startsWith('error:') ? null : titleFromHtml(html);
      if (!mounted) return;
      if (title == null || title.trim().isEmpty) {
        // three different failures, said apart: tor itself, the site, or a
        // page that has no title to give
        showHaloToast(
          context,
          html.startsWith('error: tor')
              ? l10n.groupChatTorIsNotUp
              : html.startsWith('error:')
              ? l10n.groupChatCouldnTReachIt
              : l10n.groupChatNoTitleCameBack,
        );
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _pendingPreview = senderPreview(url, title));
    } catch (_) {
      if (mounted) {
        showHaloToast(context, l10n.groupChatCouldnTFetchIt);
      }
    } finally {
      if (mounted) setState(() => _previewBusy = false);
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
    final url = firstUrl(text);
    final preview = url != null && _pendingPreview?['url'] == url
        ? _pendingPreview
        : null;
    final optimistic = _GMsg(
      sender: appState.sessionId,
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
    optimistic.preview = preview;
    setState(() {
      _messages.add(optimistic);
      _normaliseMessages();
      _replyTo = null;
      _pendingPreview = null;
    });
    _scrollToEnd();
    var ok = false;
    final sendFut = appState.sendToGroup(
      widget.groupId,
      text,
      msgUid: uid,
      replyTo: replyToUid,
      burnSeconds: burnSeconds,
      preview: preview,
    );
    try {
      ok = await sendFut;
    } catch (e) {
      dlog('group send failed: $e');
    } finally {
      // always release the composer: a throw must not leave _sending stuck
      // true and kill every later send
      if (mounted) {
        // re-find the live object; the notifyListeners at the end of
        // sendToGroup can trigger a reload that replaces `optimistic`, and
        // the orphan's send pill would stay stuck
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

  // online, a failed send goes again on its own: half a minute apart, six
  // goes, then it is shown as failed with the tap
  void _autoRetryTick() {
    if (!mounted || _sending || _cannotSend()) return;
    for (final m in _messages) {
      if (m.direction != 'out' || !m.failed || m.gaveUp || m.msgUid == null) {
        continue;
      }
      if (m.autoRetries >= 6) {
        setState(() => m.gaveUp = true);
        continue;
      }
      m.autoRetries++;
      _retryGroup(m);
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
      String r;
      try {
        r = await appState.sendMediaToGroup(
          widget.groupId,
          f.path,
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
        preview: m.preview,
      );
    } catch (e) {
      dlog('group retry failed: $e');
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

  Future<void> _showStickers() async {
    final pick = await showStickerSheet(context, container: session.container);
    // the sheet hands focus back to the composer; the keyboard stays down
    FocusManager.instance.primaryFocus?.unfocus();
    if (pick == null || !mounted) return;
    StickerLibrary lib;
    try {
      lib = StickerLibrary.ready ?? await StickerLibrary.load();
    } catch (e) {
      dlog('sticker pack: $e');
      return;
    }
    final pack = lib.pack(pick.ref.pack);
    final s = pack?.sticker(pick.ref.id);
    if (pack == null || s == null || !mounted) return;
    await _sendSticker(s, StickerWire.of(pack, s), pick);
  }

  // a sticker goes out like a typed message, its emoji as the words: the
  // same row, reply, burn timer, ticks and retry
  Future<void> _sendSticker(Sticker s, StickerWire w, StickerPick pick) async {
    final uid = newMsgUid();
    final replyToUid = _replyTo?.msgUid;
    final burnSeconds = _ghost ? _burnSeconds : null;
    final optimistic = _GMsg(
      sender: appState.sessionId,
      direction: 'out',
      text: s.emoji,
      when: DateTime.now(),
      sticker: w,
      msgUid: uid,
      replyTo: replyToUid,
      sending: true,
      burnSecs: burnSeconds,
      burnAt: burnSeconds == null
          ? null
          : DateTime.now().millisecondsSinceEpoch + burnSeconds * 1000,
    )..fresh = true;
    _fly(uid, s, pick);
    setState(() {
      _messages.add(optimistic);
      _normaliseMessages();
      _replyTo = null;
    });
    _scrollToEnd();
    var ok = false;
    try {
      ok = await appState.sendToGroup(
        widget.groupId,
        s.emoji,
        msgUid: uid,
        replyTo: replyToUid,
        burnSeconds: burnSeconds,
        sticker: w.value,
      );
    } catch (e) {
      dlog('group sticker send failed: $e');
    }
    if (!mounted) return;
    final live = _liveMsg(uid) ?? optimistic;
    setState(() {
      live.sending = false;
      live.failed = !ok;
    });
    if (!_messages.any((x) => x.sending)) _tryAppendNew();
  }

  // the sticker flies from its cell to the new row. under reduced motion
  // there is no flight and the bubble fades in
  void _fly(String uid, Sticker s, StickerPick pick) {
    if (pick.from.isEmpty || MediaQuery.disableAnimationsOf(context)) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final landing = _landings[uid] = StickerLanding();
    VoidCallback? unguard;
    late final VoidCallback land;
    land = flySticker(
      context,
      sticker: s,
      from: pick.from,
      at: pick.at,
      landing: landing,
      fallback: () => _landingGuess(rtl) ?? pick.from,
      onGone: () {
        unguard?.call();
        _flights.remove(land);
      },
    );
    _flights.add(land);
    // the lock takes it down with everything else it covers
    unguard = lockGuard.closeOnLock(land);
  }

  // where a new sticker row lands before it has a layout: the bottom end of
  // the list
  Rect? _landingGuess(bool rtl) {
    final box = _listKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final r = box.localToGlobal(Offset.zero) & box.size;
    const side = kStickerBubble, pad = 14.0;
    return Rect.fromLTWH(
      rtl ? r.left + pad : r.right - pad - side,
      r.bottom - 12 - side,
      side,
      side,
    );
  }

  void _showAttachSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    showHaloSheet<void>(
      context,
      builder: (sheetCtx) => AttachGrid(
        note: l10n.chatNoExifNeverSaved,
        items: [
          AttachItem(
            icon: (c) => Icon(Icons.photo_camera_outlined, color: c),
            tint: HaloColors.amber,
            label: l10n.groupChatCamera,
            onTap: _openGroupCamera,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.photo_library_outlined, color: c),
            tint: HaloColors.violet,
            label: l10n.groupChatGallery,
            onTap: _pickGroupMultiple,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.videocam_outlined, color: c),
            tint: HaloColors.rose,
            label: l10n.groupChatVideo,
            onTap: _pickGroupVideo,
          ),
          AttachItem(
            icon: (c) => StrokeIcon(pollGlyph, color: c, stroke: 1.9),
            tint: HaloColors.green,
            label: l10n.pollAttach,
            onTap: _newPoll,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.gif_box_outlined, color: c),
            tint: HaloColors.violet,
            label: l10n.groupChatGifFromPhone,
            onTap: _pickGroupGif,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.attach_file, color: c),
            tint: HaloColors.amber,
            label: l10n.groupChatFile,
            onTap: _pickGroupFile,
          ),
        ],
      ),
    );
  }

  // a poll goes out like a message: timed when the chat is, into a room as
  // into a group
  Future<void> _newPoll() async {
    final d = await showNewPollSheet(context);
    if (d == null || !mounted) return;
    final uid = newMsgUid();
    final burnSeconds = _ghost ? _burnSeconds : null;
    final poll = PollSpec(options: d.options, multi: d.multi);
    // on screen at once, like a typed message, and settled by this send
    // when it is done, so a row stuck sending never blocks the reload
    final optimistic =
        _GMsg(
            sender: appState.sessionId,
            direction: 'out',
            text: d.question,
            when: DateTime.now(),
            msgUid: uid,
            sending: true,
            burnSecs: burnSeconds,
            burnAt: burnSeconds == null
                ? null
                : DateTime.now().millisecondsSinceEpoch + burnSeconds * 1000,
          )
          ..fresh = true
          ..poll = poll;
    setState(() {
      _messages.add(optimistic);
      _normaliseMessages();
    });
    _scrollToEnd();
    var ok = false;
    try {
      ok = await appState.sendToGroup(
        widget.groupId,
        d.question,
        msgUid: uid,
        poll: poll,
        burnSeconds: burnSeconds,
      );
    } catch (e) {
      dlog('group poll send failed: $e');
    }
    if (!mounted) return;
    final live = _liveMsg(uid) ?? optimistic;
    setState(() {
      live.sending = false;
      live.failed = !ok;
    });
    if (!_messages.any((x) => x.sending)) _tryAppendNew();
  }

  // a video from the gallery, same reasoning as the one-to-one chat
  Future<void> _pickGroupVideo() async {
    final x = await lockState.hold(
      () => ImagePicker().pickVideo(source: ImageSource.gallery),
    );
    if (x == null || !mounted) return;
    await _sendGroupFileFrom(x.path, x.name);
    await shredPickedImages([x]);
  }

  Future<void> _pickGroupMultiple() async {
    final picked = await lockState.hold(
      () => ImagePicker().pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      ),
    );
    if (picked.isEmpty) return;
    if (picked.length == 1) {
      final bytes = await picked.first.readAsBytes();
      await shredPickedImages(picked);
      if (!mounted) return;
      final caption = await Navigator.of(
        context,
      ).push<String?>(haloRoute<String?>(ImageCaptionScreen(bytes: bytes)));
      if (caption == null) return;
      await _sendGroupImage(bytes, caption);
      return;
    }
    final bytesOf = [for (final x in picked) await x.readAsBytes()];
    await shredPickedImages(picked);
    for (final bytes in bytesOf) {
      if (!mounted) return;
      await _sendGroupImage(bytes, '');
    }
  }

  Future<void> _pickGroupGif() async {
    final PlatformFile? res;
    try {
      res = await lockState.hold(
        () => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['gif'],
        ),
      );
    } catch (e) {
      if (mounted) showHaloToast(context, l10n.groupChatCouldNotReadThat);
      return;
    }
    if (res == null) return;
    final path = res.path;
    final data = path == null ? null : await File(path).readAsBytes();
    await shredPicked([res]);
    if (data == null) return;
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, l10n.groupChatGifTooBig8);
      return;
    }
    // raw, but not with what rode along: a gif's comment and xmp blocks
    // go, its frames and its loop count stay. whatever was picked under
    // the gif filter is cleaned as the kind of file its bytes say it is.
    final clean = stripPictureBytes(data);
    if (clean == null) {
      if (mounted) showHaloToast(context, l10n.groupChatCouldNotCleanThat);
      return;
    }
    // raw bytes through the image lane - re-encoding kills the animation.
    await _sendGroupImage(clean, '');
  }

  Future<void> _sendGroupImage(Uint8List bytes, String caption) async {
    final uid = newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.groupId);
    final f = File('${mediaDir.path}/$uid.jpg');
    await f.writeAsBytes(bytes);
    final burn = _ghost ? _burnSeconds : null;
    final m = _GMsg(
      sender: appState.sessionId,
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
    await session.saveMessage(
      appState.sessionId,
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
          f.path,
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
    final mediaDir = await session.mediaDirOf(widget.groupId);
    final dest = File('${mediaDir.path}/vn_$uid.wav');
    await dest.writeAsBytes(bytes);
    final burn = _ghost ? _burnSeconds : null;
    final m = _GMsg(
      sender: appState.sessionId,
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
    await session.saveMessage(
      appState.sessionId,
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
          dest.path,
          msgUid: uid,
          fileName: 'voice.wav',
          voice: true,
          voiceDisguised: _disguise,
          burnSeconds: burn,
        )
        .then((r) => _finishGroupMediaSend(m, r));
  }

  // the picker's own copy is copied into the media folder; no byte array
  // crosses the plugin channel. see the 1:1 chat for why.
  Future<void> _pickGroupFile() async {
    final PlatformFile? res;
    try {
      res = await lockState.hold(() => FilePicker.pickFile());
    } catch (e) {
      // the picker could not copy what was chosen: a provider that will
      // not hand the file over, a gone download. say so instead of nothing.
      if (mounted) showHaloToast(context, l10n.groupChatCouldNotReadThat);
      return;
    }
    if (res == null) return;
    final path = res.path;
    final name = res.name;
    if (path != null) await _sendGroupFileFrom(path, name);
    await shredPicked([res]);
  }

  // the in-app camera: a stripped photo goes through the caption screen; a
  // clip goes as a file and its private copy is shredded once read
  Future<void> _openGroupCamera() async {
    final r = await Navigator.of(
      context,
    ).push<CaptureResult>(haloRoute<CaptureResult>(const CameraScreen()));
    if (r == null || !mounted) return;
    if (r.photo != null) {
      final caption = await Navigator.of(
        context,
      ).push<String?>(haloRoute<String?>(ImageCaptionScreen(bytes: r.photo!)));
      if (caption == null) return;
      await _sendGroupImage(r.photo!, caption);
      return;
    }
    final path = r.videoPath;
    if (path == null) return;
    if (!mounted) return;
    await _sendGroupFileFrom(
      path,
      'clip_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    await shredFile(path);
  }

  Future<void> _sendGroupFileFrom(String src, String name) async {
    final int size;
    try {
      size = await File(src).length();
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.groupChatCouldNotReadThat);
      return;
    }
    if (size > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, l10n.groupChatFileTooBig8);
      return;
    }
    final uid = newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.groupId);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${mediaDir.path}/f_${uid}_$safe');
    await File(src).copy(dest.path);
    // a gallery video carries what a gallery photo does: where, on what,
    // and when. stripped in place on our own copy; a file that cannot be
    // walked is not sent, the same as a jpeg that cannot be.
    if (videoNameNeedsStrip(name)) {
      final ok = await stripMp4Metadata(dest.path);
      final left = ok == null ? null : await mp4MetadataCount(dest.path);
      if (ok == null || left != 0) {
        try {
          await dest.delete();
        } catch (_) {
          // not sent either way, and the original is still where it was
        }
        if (mounted) {
          showHaloToast(context, l10n.groupChatCouldNotCleanThatVideo);
        }
        return;
      }
    }
    // a picture sent as a file is cleaned like one sent as a photo. it is
    // told by its bytes, not its name: jpeg, png, webp, heic, avif. one the
    // app cannot read through is not sent; the photo button re-encodes and
    // will take it.
    else if (await stripPictureFileOffUi(dest.path) == null) {
      try {
        await dest.delete();
      } catch (_) {
        // not sent either way, and the original is still where it was
      }
      if (mounted) {
        showHaloToast(context, l10n.groupChatCouldNotCleanThatPictureSend);
      }
      return;
    }
    final burn = _ghost ? _burnSeconds : null;
    final m = _GMsg(
      sender: appState.sessionId,
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
    await session.saveMessage(
      appState.sessionId,
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
          dest.path,
          msgUid: uid,
          fileName: name,
          burnSeconds: burn,
        )
        .then((r) => _finishGroupMediaSend(m, r));
  }

  String? _badgeFor(String id) {
    for (final c in appState.contacts) {
      if (c.haloId == id) return c.supporterBadge;
    }
    return null;
  }

  // after a send completes, the optimistic object may have been replaced by
  // a reload (notifyListeners -> _tryAppendNew). always re-find the live one
  // by uid so we mutate what's actually on screen, never an orphan.
  _GMsg? _liveMsg(String? uid) {
    if (uid == null) return null;
    for (final m in _messages) {
      if (m.msgUid == uid) return m;
    }
    return null;
  }

  // stop a photo or file mid-send. the workers end between slices, the row
  // goes here, and the group is told to drop what it has.
  Future<void> _stopGroupSending(_GMsg m) async {
    final uid = m.msgUid;
    if (uid == null) return;
    cancelMediaSend(uid);
    mediaProgressEnd(uid);
    if (mounted) setState(() => m.removing = true);
    await Future.delayed(kLeaveGone);
    await session.deleteMessage(uid);
    if (mounted) setState(() => _messages.remove(m));
    unawaited(appState.unsendInGroup(widget.groupId, uid));
  }

  Future<void> _finishGroupMediaSend(_GMsg m, String result) async {
    // another sender already has this one; its verdict comes later
    if (result == 'busy') return;
    if (m.msgUid != null) mediaProgressEnd(m.msgUid!);
    final ok = result == 'ok';
    final uid = m.msgUid;
    if (ok && uid != null) await session.markSent(uid);
    int? ba;
    if (ok && m.burnSecs != null && uid != null) {
      ba = DateTime.now().millisecondsSinceEpoch + m.burnSecs! * 1000;
      await session.setMsgBurnAt(uid, ba);
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
    showHaloSheet(
      context,
      builder: (c) {
        final options = [
          (30, l10n.groupChat30Seconds),
          (60, l10n.groupChat1Minute),
          (300, l10n.groupChat5Minutes),
          (3600, l10n.groupChat1Hour),
          (86400, l10n.groupChat24Hours),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 14),
              Text(
                l10n.groupChatBurnTimer,
                style: HaloType.serif(
                  size: 16,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.groupChatNewMessagesDisappearAfter,
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

  Future<void> _showEmojiPickerAt(
    BuildContext bubbleCtx,
    _GMsg target, {
    bool showSender = false,
    String? quotedText,
    String? quotedAuthor,
    StickerWire? quotedSticker,
  }) async {
    // drop composer focus before anything opens: a route captures the
    // focused node at open and restores it at close, which would pull the
    // keyboard up after unsend, edit or forward
    FocusManager.instance.primaryFocus?.unfocus();
    if (target.msgUid == null) return;
    final renderBox = bubbleCtx.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    // the row that holds the bubble, avatar and sender line: the lifted copy
    // is drawn over it at the same width so it lines up exactly
    final rowBox = bubbleCtx
        .findAncestorRenderObjectOfType<RenderRepaintBoundary>();
    final rowPos = rowBox?.localToGlobal(Offset.zero) ?? pos;
    final rowW = rowBox?.size.width ?? size.width;
    final isOut = target.direction == 'out';
    final screenH = MediaQuery.of(context).size.height;
    // anchor the menu just below the bubble, but if that would run off the
    // bottom, put it above. never off-screen.
    final belowTop = pos.dy + size.height + 8;
    // the bar and the card under it, from how many rows the card has
    final words = target.text.isNotEmpty && target.sticker == null;
    final rows =
        2 +
        (words ? 2 : 0) +
        (target.filePath != null && target.fileName != 'voice.wav' ? 1 : 0) +
        (isOut ? (words ? 2 : 1) : 0);
    final rowH =
        20 + math.max(17.0, MediaQuery.textScalerOf(context).scale(13.5) * 1.3);
    final showAbove = belowTop > screenH - (72 + rows * rowH + 16);
    final overlay = Overlay.of(context);
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _liftedUid = target.msgUid);
    late OverlayEntry entry;
    VoidCallback? unguard;
    // not entry.mounted: an entry closed before its first frame is not
    // mounted yet and has to go all the same
    var gone = false;
    void close() {
      if (gone) return;
      gone = true;
      unguard?.call();
      entry.remove();
      if (identical(_menuClose, close)) _menuClose = null;
    }

    void dismiss() {
      close();
      if (mounted) setState(() => _liftedUid = null);
    }

    entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismiss,
                child: const MenuBackdrop(),
              ),
            ),
            // the position is from the left edge, in either direction
            Positioned(
              left: rowPos.dx,
              top: rowPos.dy,
              width: rowW,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: motionStill(context) ? 0 : 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: Material(
                    type: MaterialType.transparency,
                    child: _GroupBubble(
                      m: target,
                      showSender: showSender,
                      senderBadge: _badgeFor(target.sender),
                      quotedText: quotedText,
                      quotedAuthor: quotedAuthor,
                      quotedSticker: quotedSticker,
                    ),
                  ),
                  builder: (_, t, child) => Transform.scale(
                    scale: 1.0 + 0.04 * t,
                    alignment: isOut
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: child,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: isOut ? null : 12,
              end: isOut ? 12 : null,
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
                  // a sticker is not copied, forwarded or edited
                  onCopy: target.text.isEmpty || target.sticker != null
                      ? null
                      : () {
                          dismiss();
                          Clipboard.setData(ClipboardData(text: target.text));
                          showHaloToast(context, l10n.commonCopied);
                        },
                  onPin: () {
                    dismiss();
                    _togglePinGroup(target);
                  },
                  onSave: () {
                    dismiss();
                    _toggleSavedGroup(target);
                  },
                  onForward: target.text.isEmpty || target.sticker != null
                      ? null
                      : () {
                          dismiss();
                          _forwardGroupMessage(target);
                        },
                  // a tap opens a file, so sharing it lives here
                  onShare:
                      (target.filePath == null ||
                          target.fileName == 'voice.wav')
                      ? null
                      : () {
                          dismiss();
                          lockState.hold(
                            () => SharePlus.instance.share(
                              ShareParams(files: [XFile(target.filePath!)]),
                            ),
                          );
                        },
                  onEdit:
                      (isOut &&
                          target.text.isNotEmpty &&
                          target.sticker == null)
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
    _menuClose = close;
    // the lock closes it, with what it shows
    unguard = lockGuard.closeOnLock(dismiss);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(when.year, when.month, when.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return l10n.groupChatToday;
    if (diff == 1) return l10n.groupChatYesterday;
    return dayMonthMaybeYear(when, now: now);
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: DayChip(_dayLabel(when))),
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
      // the floating chip sits at the top of this list, so a divider only
      // counts as passed once it is off screen, or the day shows twice
      if (dy + obj.size.height <= top && dy > bestDy) {
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
      _query = '';
      _matchSet = {};
      _matchPos = 0;
    });
  }

  void _onQueryChanged(String q) {
    final query = q.trim();
    final matches = <int>[];
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      for (var i = 0; i < _messages.length; i++) {
        // a sticker has no words; its emoji is not what was said
        if (_messages[i].sticker == null &&
            _messages[i].text.toLowerCase().contains(lower)) {
          matches.add(i);
        }
      }
    }
    setState(() {
      _query = query;
      _matches = matches;
      _matchSet = matches.toSet();
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
  // previews build in, so one ensureVisible can land shy of or past the pin.
  // re-align over a few frames until the target stops moving.
  void _settleJump(int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollCtrl.hasClients) return;
      final ctx = _jumpKey.currentContext;
      final ro = ctx == null || !ctx.mounted ? null : ctx.findRenderObject();
      if (ro != null && ro.attached) {
        try {
          // ensureVisible asserts if the viewport is mid-update. computing
          // the reveal offset and jumping is the safe equivalent.
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
    // the key has just been asked for and lands with the next frame. if
    // the row is already built then, go straight to it: the rough jump is
    // a guess from whatever rows happen to be laid out, and guessing away
    // from a row that is on screen makes a second tap on a pin wander.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollReady) return;
      if (_jumpKey.currentContext == null) {
        final max = _maxScroll;
        final frac = idx / _messages.length;
        final vpDim = _scrollCtrl.positions.first.viewportDimension;
        final approx = (frac * max - vpDim * 0.3).clamp(0.0, max);
        _scrollCtrl.jumpTo(approx.clamp(0.0, max));
      }
      _settleJump(0);
    });
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

  bool _didJump = false;

  // the list has to be laid out before a jump can land: wait a few frames
  void _jumpWhenReady(int idx, int tries) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollReady) {
        _scrollToIndex(idx);
      } else if (tries < 20) {
        _jumpWhenReady(idx, tries + 1);
      }
    });
  }

  void _scrollToGroupMessage(_GMsg m) {
    var idx = _messages.indexOf(m);
    if (idx < 0 && m.msgUid != null) {
      // a reload swapped the list objects since this reference was taken,
      // so the identity lookup fails: find it by uid
      idx = _messages.indexWhere((x) => x.msgUid == m.msgUid);
    }
    _scrollToIndex(idx);
  }

  // read from the database: a pin far up the thread is still a pin when
  // only the last page is loaded
  Future<List<PinEntry>> _loadPins() async {
    final rows = await session.pinnedIn(groupId: widget.groupId);
    final nickById = <String, String>{};
    final faceById = <String, int?>{};
    for (final c in appState.contacts) {
      final n = c.nickname;
      if (n != null && n.isNotEmpty) nickById[c.haloId] = n;
      faceById[c.haloId] = c.avatar;
    }
    return [
      for (final r in rows)
        () {
          final out = r['direction'] == 'out';
          final peer = r['peer_id'] as String;
          return PinEntry(
            uid: r['msg_uid'] as String,
            author: out
                ? l10n.groupChatYou2
                : (_senderLabel(nickById, peer) ?? peer),
            authorSeed: out ? appState.sessionId : peer,
            face: out ? appState.myAvatar : faceById[peer],
            when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
            text: (r['plaintext'] as String?) ?? '',
            imagePath: r['media_path'] as String?,
            fileName: r['file_name'] as String?,
            sticker: StickerWire.parse(r['sticker']),
          );
        }(),
    ];
  }

  int _pinCount = 0;
  Future<void> _refreshPinCount() async {
    final n = (await session.pinnedIn(groupId: widget.groupId)).length;
    if (mounted && n != _pinCount) setState(() => _pinCount = n);
  }

  Future<void> _showGroupPinnedSheet() async {
    // the composer regains focus when a sheet closes, and the keyboard
    // coming up under a jump throws the landing off
    FocusManager.instance.primaryFocus?.unfocus();
    await showPinsSheet(
      context,
      load: _loadPins,
      onJump: (e) {
        final at = _messages.indexWhere((m) => m.msgUid == e.uid);
        if (at >= 0) _scrollToIndex(at);
      },
      onUnpin: (e) => _setPinnedGroup(e.uid, false),
    );
  }

  Future<void> _setPinnedGroup(String uid, bool on) async {
    if (mounted) {
      setState(() {
        for (final m in _messages) {
          if (m.msgUid == uid) m.pinned = on;
        }
      });
    }
    // ours first, so the list and the count are right at once; telling the
    // members is a send to each over tor and is not waited for
    await session.setPinned(uid, on);
    unawaited(appState.pinInGroup(widget.groupId, uid, on));
    await _refreshPinCount();
  }

  Future<void> _togglePinGroup(_GMsg m) async {
    if (m.msgUid == null) return;
    if (!m.pinned) {
      final count = (await session.pinnedIn(groupId: widget.groupId)).length;
      if (count >= kMaxPins) {
        if (mounted) {
          showHaloToast(context, l10n.groupChatThisChatHasPins(kMaxPins));
        }
        return;
      }
    }
    if (!mounted) return;
    final ok = await showConfirmSheet(
      context,
      title: m.pinned
          ? l10n.groupChatUnpinThisMessage
          : l10n.groupChatPinThisMessage,
      line: m.pinned
          ? l10n.groupChatItLeavesThePinned
          : l10n.groupChatItGoesUnderThe,
      yes: m.pinned ? l10n.groupChatUnpin : l10n.groupChatPinIt,
      keep: l10n.groupChatNotNow,
      rose: false,
    );
    if (!ok) return;
    await _setPinnedGroup(m.msgUid!, !m.pinned);
  }

  Future<void> _toggleSavedGroup(_GMsg m) async {
    if (m.msgUid == null) return;
    final next = !m.saved;
    setState(() => m.saved = next);
    await session.setSaved(m.msgUid!, next);
    if (mounted) {
      showHaloToast(
        context,
        next ? l10n.groupChatSaved : l10n.groupChatRemovedFromSaved,
      );
    }
  }

  Future<void> _forwardGroupMessage(_GMsg m) async {
    final targets = appState.contacts.where((c) => !c.blocked).toList();
    // the developer chat, once it has started
    final dev = devForwardTarget;
    final devAt = dev == null ? -1 : devSlot(dev, targets);
    final haloId = await showHaloSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                l10n.groupChatForwardTo,
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
            ),
            if (targets.isEmpty && dev == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  l10n.groupChatNoContactsToForward,
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              )
            else
              // the sheet scrolls as one, so the list is laid out in full
              // and does not scroll on its own
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final (i, c) in targets.indexed) ...[
                    if (i == devAt)
                      DevForwardTile(
                        onTap: () => Navigator.pop(ctx, dev!.chatId),
                      ),
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
                  if (devAt == targets.length)
                    DevForwardTile(
                      onTap: () => Navigator.pop(ctx, dev!.chatId),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
    if (haloId == null || !mounted) return;
    if (isDevChat(haloId)) {
      Navigator.of(context).push(devChatRoute(haloId, initialText: m.text));
      return;
    }
    final row = await session.getContact(haloId);
    if (row == null || !mounted) return;
    Navigator.of(context).push(
      haloRoute(
        ChatScreen(
          peerHaloId: haloId,
          peerOnion: (row['onion'] as String?) ?? '',
          peerXPub: (row['xpub'] as String?) ?? '',
          avatarSeed: haloId,
          avatarChoice: (row['avatar'] as num?)?.toInt(),
          initialText: m.text,
        ),
      ),
    );
  }

  Future<void> _editGroupMessage(_GMsg m) async {
    if (m.msgUid == null) return;
    final ctrl = TextEditingController(text: m.text);
    final result = await showHaloSheet<String>(
      context,
      scroll: true,
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
            const SheetHandle(),
            Text(
              l10n.groupChatEditMessage,
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
                    l10n.commonCancel,
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: Text(
                    l10n.commonSave,
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
    final confirm = await showHaloSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                l10n.groupChatUnsendMessage,
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                l10n.groupChatItDisappearsWithNo,
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
                      l10n.groupChatUnsend,
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
    await Future.delayed(kLeaveGone);
    if (mounted) setState(() => _messages.remove(m));
    await appState.unsendInGroup(widget.groupId, m.msgUid!);
  }

  // the lock lifted with this group on top: it is the one being read again
  // set while the lock is up, so its lifting is acted on once
  bool _underLock = false;

  void _lockLifted() {
    if (!mounted) return;
    if (lockGuard.isLocked()) {
      _underLock = true;
      return;
    }
    if (!_underLock) return;
    _underLock = false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    claimChat('group:${widget.groupId}');
    _markRead();
  }

  void _markRead() {
    session
        .clearGroupUnread(widget.groupId)
        .then((_) => appState.refreshGroups());
    unawaited(clearNotificationsFor('group:${widget.groupId}'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // backgrounded with the group open: drop the "open" marker so incoming
    // messages bump the unread badge instead of being treated as read.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      releaseChat('group:${widget.groupId}');
    } else if (state == AppLifecycleState.resumed) {
      // only re-claim the marker as the visible route with no lock over it,
      // else backing out and resuming later leaves the group marked open and
      // its badge dead. under the lock the claim waits for _lockLifted.
      if (!onScreen(context)) {
        releaseChat('group:${widget.groupId}');
        return;
      }
      claimChat('group:${widget.groupId}');
      session
          .clearGroupUnread(widget.groupId)
          .then((_) => appState.refreshGroups());
    }
  }

  @override
  void deactivate() {
    // popped or covered: stop claiming this group is being read.
    releaseChat('group:${widget.groupId}');
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
    if (_isRoom) appState.forceSecure(false);
    if (_isRoom && _roomBanner) session.markRoomSeen(widget.groupId);
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
    for (final land in List.of(_flights)) {
      land();
    }
    _leaveRoomScreen();
    // persist the draft one more time on the way out.
    final draft = _msgCtrl.text;
    if (draft.trim().isEmpty) {
      _draftPerGroup.remove(widget.groupId);
    } else {
      _draftPerGroup[widget.groupId] = draft;
    }
    _menuClose?.call();
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onGroupScroll);
    _scrollCtrl.removeListener(_updateSticky);
    _stickyHideTimer?.cancel();
    _stickyLabel.dispose();
    _stickyShown.dispose();
    WidgetsBinding.instance.removeObserver(this);
    lockState.removeListener(_lockLifted);
    releaseChat('group:${widget.groupId}');
    appState.removeListener(_onAppStateChanged);
    _timers.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // a message that just started counting down gets its burn on time
    _burn.poke();
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
                    groupId: widget.groupId,
                    memberCount: _memberCount,
                    expiresAt: _roomExpiresAt,
                    onBack: () => Navigator.of(context).pop(),
                    onSearch: _openSearch,
                    pinnedCount: _pinCount,
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
                text: l10n.groupChatThisRoomAndEverything(
                  expiryWords(
                    DateTime.fromMillisecondsSinceEpoch(
                      _roomExpiresAt!,
                    ).difference(DateTime.now()),
                  ),
                ),
                color: HaloColors.violet,
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                delay: const Duration(milliseconds: 160),
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
                      l10n.groupChatGhostModeOnBurns(_fmtBurn(_burnSeconds)),
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
                            ? l10n.groupChatGroupCreatedSayHi
                            : l10n.groupChatNoMessagesYet,
                        style: HaloType.serif(
                          size: 14,
                          italic: true,
                          color: HaloColors.text3,
                        ),
                      ),
                    )
                  : AtmoScope(
                      atmo: _atmosphere,
                      child: Stack(
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
                                dlog('group bubble failed: \$e');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    l10n.groupChatThisMessageCanT,
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
                                          : DayChip(label),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // grows in over the composer and folds away, as in the 1:1 chat
            GrowSwap(
              alignment: Alignment.topCenter,
              child: _replyTo != null
                  ? _ReplyQuoteBar(
                      target: _replyTo!,
                      onCancel: () => setState(() => _replyTo = null),
                    )
                  : const SizedBox.shrink(),
            ),
            IncomingMediaBanner(
              chatKey: widget.groupId,
              onCancel: (uid) {
                final m = _liveMsg(uid);
                if (m != null) _stopGroupSending(m);
              },
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _msgCtrl,
              builder: (_, v, _) => PreviewStrip(
                url: !_isRoom && _torUp ? firstUrl(v.text) : null,
                pending: _pendingPreview,
                busy: _previewBusy,
                onAdd: _addPreview,
                onDrop: () => setState(() => _pendingPreview = null),
              ),
            ),
            _Composer(
              controller: _msgCtrl,
              members: _mentionable,
              sending: _sending,
              ghost: _ghost,
              disguise: _disguise,
              onToggleGhost: () => setState(() => _ghost = !_ghost),
              onLongPressGhost: _showBurnPicker,
              onSend: _send,
              onAttach: _showAttachSheet,
              onStickers: _showStickers,
              onCamera: _openGroupCamera,
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
  if (s < 60) return l10n.groupChatS(whole(s));
  if (s < 3600) return l10n.groupChatM(whole(s ~/ 60));
  if (s < 86400) return l10n.groupChatH(whole(s ~/ 3600));
  return l10n.groupChatD(whole(s ~/ 86400));
}

// the phone cannot send at all: no network, or onion mode without a route
bool _cannotSend() => !appState.online || !appState.torReady;

// the time on a photo or a video with no caption: a small dark pill in the
// corner, since there is no bubble under it to carry it
Widget _groupStamp(_GMsg m) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
  decoration: BoxDecoration(
    color: Colors.black.withValues(alpha: 0.45),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    hourMinute(m.when),
    style: TextStyle(
      fontFamily: HaloType.monoFamily,
      fontFamilyFallback: HaloType.monoFallbackNow,
      fontSize: 9,
      color: Colors.white,
      letterSpacing: track(0.4),
    ),
  ),
);

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
  bool failed = false;
  // online, a failed row retries itself and reads as pending; the count
  // stops that after six goes
  int autoRetries = 0;
  bool gaveUp = false;
  bool get looksFailed => failed && (gaveUp || _cannotSend());
  bool get pending => sending || (failed && !looksFailed);
  bool removing = false;
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
  // a poll: its answers on the row, the votes this phone holds for it
  PollSpec? poll;
  Map<String, PollVote> votes = const {};
  // a sticker: drawn from our pack; text is its emoji
  final StickerWire? sticker;
  _GMsg({
    required this.sender,
    String? senderName,
    required this.direction,
    required this.text,
    required this.when,
    this.sticker,
    this.burnAt,
    this.burnSecs,
    this.msgUid,
    this.replyTo,
    this.sending = false,
    this.mediaPath,
    this.filePath,
    this.fileName,
    this.voiceDisguised = false,
    this.pinned = false,
    this.saved = false,
    this.edited = false,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? {},
       senderName = senderName ?? sender;
}

class _Header extends StatelessWidget {
  final String name;
  final String groupId;
  final int memberCount;
  final int? expiresAt; // a room: the subtitle is the clock, not the count
  final VoidCallback onBack;
  final VoidCallback onTapInfo;
  final VoidCallback? onSearch;
  final int pinnedCount;
  final VoidCallback? onPinned;
  const _Header({
    required this.name,
    required this.groupId,
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
    final room =
        expiresAt != null ||
        appState.groups.any((g) => g.groupId == groupId && g.expiresAt != null);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonBack,
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
                    // a room's tile is violet, as on the chat list it
                    // flies from: known from that list before the load
                    Hero(
                      tag: 'group-$groupId',
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: room
                              ? HaloColors.violet.withValues(alpha: 0.14)
                              : HaloColors.amberSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (room ? HaloColors.violet : HaloColors.amber)
                                .withValues(alpha: 0.35),
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
                            color: room ? HaloColors.violet : HaloColors.amber,
                          ),
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
                            SlotLine(
                              msg: (t) => l10n.groupChatHere(memberCount, t),
                              slot: RoomCountdown(
                                expiresAt: expiresAt!,
                                size: 10,
                              ),
                              style: HaloType.mono(
                                size: 10,
                                color: HaloColors.text3,
                              ),
                            )
                          else
                            Text(
                              l10n.groupChatMembers(memberCount),
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
          PinHeaderButton(count: pinnedCount, onTap: onPinned),
          if (onSearch != null)
            IconButton(
              tooltip: l10n.groupChatSearchThisChat,
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
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
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
                  target.direction == 'out'
                      ? l10n.groupChatReplyingToYou
                      : l10n.groupChatReplyingTo(target.senderName),
                  style: HaloType.mono(
                    size: 9.5,
                    color: HaloColors.amber,
                    letter: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                if (target.sticker case final st?)
                  StickerLine(
                    st,
                    style: HaloType.sans(size: 12.5, color: HaloColors.text2),
                  )
                else
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
            tooltip: l10n.commonClose,
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
  final VoidCallback onStickers;
  final VoidCallback onCamera;
  final VoidCallback onToggleDisguise;
  final void Function(String path, int ms, bool cancelled) onVoiceComplete;
  // who @ can offer
  final List<MentionCandidate> members;
  const _Composer({
    this.members = const [],
    required this.controller,
    required this.sending,
    required this.ghost,
    required this.disguise,
    required this.onToggleGhost,
    required this.onLongPressGhost,
    required this.onSend,
    required this.onAttach,
    required this.onStickers,
    required this.onCamera,
    required this.onToggleDisguise,
    required this.onVoiceComplete,
  });
  @override
  Widget build(BuildContext context) {
    // a phone whose identity has moved has no engine running: a message
    // typed here would sit in the outbox for good. nowhere to type it.
    if (appState.movedAway) return const MovedStrip();
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MentionPicker(controller: controller, members: members),
          Row(
            children: [
              Semantics(
                label: l10n.groupChatTimedMessages,
                button: true,
                child: GestureDetector(
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
              ),
              // the camera that keeps its photos inside kryfo
              Semantics(
                label: l10n.groupChatOpenTheCamera,
                button: true,
                child: GestureDetector(
                  onTap: onCamera,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 22,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: l10n.groupChatAttachAPhoto,
                button: true,
                child: GestureDetector(
                  onTap: onAttach,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 22,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsetsDirectional.only(
                    start: 14,
                    end: 2,
                    top: 4,
                    bottom: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: HaloColors.amber.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  // stickers sit inside the field: no width taken from the row
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: WrittenDir(
                          controller: controller,
                          builder: (dir) => TextField(
                            textDirection: dir,
                            inputFormatters: const [UnmarkedInput()],
                            controller: controller,
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                            ),
                            cursorColor: HaloColors.amber,
                            decoration: InputDecoration(
                              hintText: l10n.groupChatMessage,
                              hintStyle: HaloType.sans(
                                size: 14,
                                color: HaloColors.text3,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            minLines: 1,
                            maxLines: 5,
                            onSubmitted: (_) => onSend(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: StickerButton(onTap: onStickers),
                      ),
                    ],
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
                        DisguiseToggle(
                          on: disguise,
                          label: l10n.groupChatDisguiseVoice,
                          onTap: onToggleDisguise,
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
                    label: l10n.commonSend,
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
                                  color: HaloColors.amber.withValues(
                                    alpha: 0.35,
                                  ),
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
        ],
      ),
    );
  }
}

// ───────── bubble ─────────

// stable accent per sender so each person reads as their own colour
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

// the names that come up when you type @. sits above the field, at most
// five, ours first. a tap drops the three words in and keeps typing.
class _MentionPicker extends StatelessWidget {
  final TextEditingController controller;
  final List<MentionCandidate> members;
  const _MentionPicker({required this.controller, required this.members});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, v, _) {
        final q = members.isEmpty
            ? null
            : mentionQuery(v.text, v.selection.baseOffset);
        final hits = q == null
            ? const <MentionCandidate>[]
            : mentionMatches<MentionCandidate>(
                q,
                members,
                (m) => m.id,
                (m) => m.name,
              ).take(5).toList();
        final picker = hits.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 0, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HaloColors.line, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final m in hits)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            final r = insertMention(
                              v.text,
                              v.selection.baseOffset,
                              m.id,
                            );
                            controller.value = TextEditingValue(
                              text: r.text,
                              selection: TextSelection.collapsed(
                                offset: r.cursor,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                KryfoAvatar(
                                  seed: m.id,
                                  size: 26,
                                  choice: m.avatar,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    m.name ?? m.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HaloType.sans(
                                      size: 13.5,
                                      color: HaloColors.text,
                                    ),
                                  ),
                                ),
                                if (m.name != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    m.id,
                                    style: HaloType.mono(
                                      size: 10,
                                      color: HaloColors.text3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
        // an AnimatedSize given no time trips over its own layout: still, it
        // is left out
        if (motionStill(context)) return picker;
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: picker,
        );
      },
    );
  }
}

class _GroupBubble extends StatelessWidget {
  final _GMsg m;
  final bool showSender;
  final String? senderBadge;
  final ShieldFlag? shieldFlag;
  final VoidCallback? onShield;
  final String? quotedText;
  final String? quotedAuthor;
  final void Function(BuildContext)? onLongPress;
  final VoidCallback? onRetry;
  final bool ripple;
  // an in-chat search: the words to mark, this is the hit in view, or it is
  // not a hit at all and steps back
  final String query;
  final bool isCurrentMatch;
  final bool dimmed;
  final VoidCallback? onReplyTap;
  final String? linkTitle;
  final bool linkBySender;
  // a poll: who this phone is in the chat, voting, closing, and names
  final String me;
  final void Function(List<int>)? onVote;
  final VoidCallback? onClosePoll;
  final String Function(String id)? nameOf;
  // a sticker row: the chat's budget, its place in it, its entrance
  final StickerBudget? stickers;
  final int stickerOrder;
  final StickerLanding? landing;
  final bool arriving;
  // the quoted message is a sticker
  final StickerWire? quotedSticker;
  const _GroupBubble({
    required this.m,
    required this.showSender,
    this.stickers,
    this.stickerOrder = 0,
    this.landing,
    this.arriving = false,
    this.quotedSticker,
    this.me = '',
    this.onVote,
    this.onClosePoll,
    this.nameOf,
    this.senderBadge,
    this.shieldFlag,
    this.onShield,
    this.quotedText,
    this.quotedAuthor,
    this.onLongPress,
    this.onRetry,
    this.ripple = false,
    this.query = '',
    this.isCurrentMatch = false,
    this.dimmed = false,
    this.onReplyTap,
    this.linkTitle,
    this.linkBySender = false,
  });

  // a search steps what is not a hit back, as in the 1:1 chat
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    opacity: dimmed ? 0.4 : 1.0,
    child: _bubble(context),
  );

  Widget _bubble(BuildContext context) {
    final isOut = m.direction == 'out';
    // a video with no caption sits on the chat like a photo: no bubble around
    // it, its time in its corner
    final isVideo =
        m.filePath != null &&
        m.text.isEmpty &&
        m.fileName != 'voice.wav' &&
        nameSaysVideo(m.fileName);
    final frameless = m.mediaPath != null || isVideo;
    final onAmberText = isOut && m.mediaPath == null;
    return LeaveFold(
      leaving: m.removing,
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
                padding: const EdgeInsetsDirectional.only(end: 6, bottom: 2),
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
                      padding: const EdgeInsetsDirectional.only(
                        start: 2,
                        bottom: 3,
                      ),
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
                                l10n.groupChatSupporter,
                                style: HaloType.mono(
                                  size: 7.5,
                                  color: HaloColors.amber,
                                ),
                              ),
                            ),
                          ],
                          if (shieldFlag != null) ...[
                            const SizedBox(width: 5),
                            // the shield's mark: tap for the reasons, block
                            // or ignore. no banner, no clean line here.
                            GestureDetector(
                              onTap: onShield,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: HaloColors.rose.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: HaloColors.rose.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 9,
                                      color: HaloColors.rose,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      shieldFlag!.headline,
                                      style: HaloType.mono(
                                        size: 7.5,
                                        color: HaloColors.rose,
                                      ),
                                    ),
                                  ],
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
                      BurnFade(
                        active: m.removing,
                        child: Builder(
                          builder: (ctx) {
                            if (m.sticker case final st?) {
                              return GestureDetector(
                                onLongPress: onLongPress == null
                                    ? null
                                    : () => onLongPress!(ctx),
                                child: _sticker(st),
                              );
                            }
                            // a poll is its own card, on either side
                            if (m.poll != null) {
                              return GestureDetector(
                                onTap: m.failed ? onRetry : null,
                                onLongPress: onLongPress == null
                                    ? null
                                    : () => onLongPress!(ctx),
                                child: _pollCard(),
                              );
                            }
                            return GestureDetector(
                              onTap: m.failed ? onRetry : null,
                              onLongPress: onLongPress == null
                                  ? null
                                  : () => onLongPress!(ctx),
                              child: Container(
                                padding: frameless
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.fromLTRB(12, 8, 12, 9),
                                decoration: BoxDecoration(
                                  // a photo or video goes edge to edge with no
                                  // bubble fill, so no amber or grey frame
                                  color: frameless
                                      ? Colors.transparent
                                      : (isOut
                                            ? HaloColors.amber
                                            : atmoBubbleIn(
                                                context,
                                                HaloColors.surface2,
                                              )),
                                  borderRadius: BorderRadiusDirectional.only(
                                    topStart: const Radius.circular(14),
                                    topEnd: const Radius.circular(14),
                                    bottomStart: Radius.circular(
                                      isOut ? 14 : 4,
                                    ),
                                    bottomEnd: Radius.circular(isOut ? 4 : 14),
                                  ),
                                  border: searchRing(isCurrentMatch),
                                  boxShadow: searchGlow(isCurrentMatch),
                                ),
                                clipBehavior: frameless
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: BorderDirectional(
                                                start: BorderSide(
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
                                                if (quotedSticker
                                                    case final qs?)
                                                  StickerLine(
                                                    qs,
                                                    style: _quoteStyle(isOut),
                                                  )
                                                else
                                                  Text(
                                                    quotedText!,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: _quoteStyle(isOut),
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
                                      else if (m.filePath != null &&
                                          nameSaysVideo(m.fileName))
                                        VideoBubble(
                                          key: ValueKey('vid_${m.filePath}'),
                                          path: m.filePath!,
                                          fileName: m.fileName!,
                                          width: 240,
                                          onOpen: () => openVideo(
                                            context,
                                            path: m.filePath!,
                                            fileName: m.fileName,
                                          ),
                                          stamp: m.failed
                                              ? null
                                              : _groupStamp(m),
                                        )
                                      else if (m.fileName != null)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            if (m.filePath != null) {
                                              openReceivedFile(
                                                context,
                                                m.filePath!,
                                                m.fileName,
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
                                                    tag: photoHeroTag(
                                                      m.mediaPath!,
                                                      'chat',
                                                    ),
                                                    radius: 10,
                                                  ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Stack(
                                                children: [
                                                  ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxHeight: 280,
                                                          maxWidth: 240,
                                                        ),
                                                    child: RememberedHeight(
                                                      id: m.mediaPath!,
                                                      child: Hero(
                                                        tag: photoHeroTag(
                                                          m.mediaPath!,
                                                          'chat',
                                                        ),
                                                        child: Image.file(
                                                          File(m.mediaPath!),
                                                          cacheWidth: decodePx(
                                                            context,
                                                            240,
                                                          ),
                                                          gaplessPlayback: true,
                                                          filterQuality:
                                                              FilterQuality
                                                                  .medium,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, _, _) =>
                                                              const SizedBox.shrink(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // caption-less photo: float the
                                                  // time in a pill on the corner,
                                                  // same as 1:1. captioned photos
                                                  // keep the time in the row below.
                                                  if (m.text.isEmpty &&
                                                      !m.failed)
                                                    PositionedDirectional(
                                                      // the reaction chip hangs
                                                      // at the end on out, the
                                                      // start on in; the time
                                                      // takes the free corner
                                                      end: isOut ? null : 8,
                                                      start: isOut ? 8 : null,
                                                      bottom: 8,
                                                      child: _groupStamp(m),
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
                                          // a search marks its hits; else
                                          // a kryfo link is drawn as one,
                                          // otherwise @three-words in amber
                                          child: query.isNotEmpty
                                              ? Text.rich(
                                                  TextSpan(
                                                    style: _bodyStyle(isOut),
                                                    children: searchLit(
                                                      m.text,
                                                      query,
                                                      onAmber: onAmberText,
                                                    ),
                                                  ),
                                                  textDirection: writtenDir(
                                                    m.text,
                                                  ),
                                                )
                                              : m.text.contains('kryfo://')
                                              ? KryfoLinkText(
                                                  text: m.text,
                                                  style: HaloType.sans(
                                                    size: 14,
                                                    color:
                                                        (isOut &&
                                                            m.mediaPath == null)
                                                        ? HaloColors.onAmber
                                                        : HaloColors.text,
                                                    height: 1.35,
                                                  ),
                                                  onAmber:
                                                      isOut &&
                                                      m.mediaPath == null,
                                                  linkColor:
                                                      (isOut &&
                                                          m.mediaPath == null)
                                                      ? HaloColors.onAmber
                                                      : HaloColors.amber,
                                                )
                                              : Text.rich(
                                                  mentionRich(
                                                    m.text,
                                                    HaloType.sans(
                                                      size: 14,
                                                      // captions get more
                                                      // weight to read over
                                                      // busy images
                                                      weight:
                                                          m.mediaPath != null
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                      // a photo caption sits
                                                      // on a transparent
                                                      // bubble, where onAmber
                                                      // is invisible
                                                      color:
                                                          (isOut &&
                                                              m.mediaPath ==
                                                                  null)
                                                          ? HaloColors.onAmber
                                                          : HaloColors.text,
                                                      height: 1.35,
                                                    ),
                                                    accent:
                                                        (isOut &&
                                                            m.mediaPath == null)
                                                        ? HaloColors.onAmber
                                                        : null,
                                                  ),
                                                  textDirection: writtenDir(
                                                    m.text,
                                                  ),
                                                ),
                                        ),
                                      if (firstUrl(m.text) case final u?) ...[
                                        const SizedBox(height: 6),
                                        LinkStub(
                                          url: u,
                                          isOut: isOut,
                                          title: linkTitle,
                                          bySender: linkBySender,
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (m.burnAt != null) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                // an outgoing photo sits on a
                                                // transparent bubble where
                                                // onAmber (dark) is invisible,
                                                // so media rows take amber
                                                color:
                                                    (isOut &&
                                                        m.mediaPath == null)
                                                    ? HaloColors.onAmber
                                                          .withValues(
                                                            alpha: 0.15,
                                                          )
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
                                              '${l10n.groupChatEdited} ',
                                              style: HaloType.mono(
                                                size: 9,
                                                color:
                                                    (isOut &&
                                                        m.mediaPath == null)
                                                    ? HaloColors.onAmber
                                                          .withValues(
                                                            alpha: 0.6,
                                                          )
                                                    : isOut
                                                    ? HaloColors.text2
                                                    : HaloColors.text3,
                                              ),
                                            ),
                                          ],
                                          // caption-less photo shows its time on the
                                          // image overlay, so skip it here to avoid
                                          // a doubled timestamp.
                                          if (!(frameless &&
                                              m.text.isEmpty &&
                                              !m.looksFailed))
                                            Text(
                                              _fmtTime(m.when),
                                              style: HaloType.mono(
                                                size: 9.5,
                                                // out photo bubble is transparent:
                                                // onAmber (dark) vanishes there
                                                color: (isOut && !frameless)
                                                    ? HaloColors.onAmber
                                                          .withValues(
                                                            alpha: 0.7,
                                                          )
                                                    : isOut
                                                    ? HaloColors.text2
                                                    : HaloColors.text3,
                                              ),
                                            ),
                                          // sent tick: outgoing and delivered,
                                          // only where the row time shows. a
                                          // photo bubble is transparent, so it
                                          // takes a readable colour.
                                          // it pops in when the send ends
                                          // with the chat open
                                          if (isOut)
                                            AnimatedSwitcher(
                                              duration: motionStill(context)
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 260,
                                                    ),
                                              transitionBuilder: (c, a) =>
                                                  FadeTransition(
                                                    opacity: a,
                                                    child: ScaleTransition(
                                                      scale: Tween(
                                                        begin: 0.4,
                                                        end: 1.0,
                                                      ).animate(a),
                                                      child: c,
                                                    ),
                                                  ),
                                              child:
                                                  !m.pending &&
                                                      !m.looksFailed &&
                                                      !(frameless &&
                                                          m.text.isEmpty)
                                                  ? Padding(
                                                      key: const ValueKey(
                                                        'tick',
                                                      ),
                                                      padding:
                                                          const EdgeInsetsDirectional.only(
                                                            start: 3,
                                                          ),
                                                      child: Text(
                                                        '✓',
                                                        style: TextStyle(
                                                          fontFamily: HaloType
                                                              .monoFamily,
                                                          fontFamilyFallback:
                                                              HaloType
                                                                  .monoFallbackNow,
                                                          fontSize: 11,
                                                          color:
                                                              m.mediaPath !=
                                                                  null
                                                              ? HaloColors.text2
                                                              : HaloColors
                                                                    .onAmber
                                                                    .withValues(
                                                                      alpha:
                                                                          0.7,
                                                                    ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          height: 1,
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(
                                                      key: ValueKey('no-tick'),
                                                    ),
                                            ),
                                          if (m.looksFailed) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              l10n.groupChatTapToRetry,
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
                      ),
                      if (m.reactions.isNotEmpty)
                        PositionedDirectional(
                          // hangs at the bubble's bottom edge on the sender's
                          // side
                          bottom: -13,
                          end: isOut ? 10 : null,
                          start: isOut ? null : 10,
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
                                  scale: motionStill(context)
                                      ? 1
                                      : 1 + t * 0.16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadiusDirectional.only(
                                            topStart: const Radius.circular(14),
                                            topEnd: const Radius.circular(14),
                                            bottomStart: Radius.circular(
                                              isOut ? 14 : 4,
                                            ),
                                            bottomEnd: Radius.circular(
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
                  // the sending pill folds away as the tick comes in
                  if (isOut)
                    GrowSwap(
                      child: !m.pending
                          ? const SizedBox.shrink(key: ValueKey('no-pill'))
                          : Padding(
                              key: const ValueKey('pill'),
                              padding: const EdgeInsetsDirectional.only(
                                top: 4,
                                end: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (m.msgUid != null &&
                                      (m.mediaPath != null ||
                                          m.filePath != null)) ...[
                                    SendProgressLabel(msgUid: m.msgUid!),
                                    const SizedBox(width: 6),
                                  ],
                                  SendPill(mode: _groupSendMode()),
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
  }

  // the words of a bubble: weightier on a photo's caption, dark on ours
  TextStyle _bodyStyle(bool isOut) => HaloType.sans(
    size: 14,
    weight: m.mediaPath != null ? FontWeight.w600 : FontWeight.w400,
    color: (isOut && m.mediaPath == null)
        ? HaloColors.onAmber
        : HaloColors.text,
    height: 1.35,
  );

  TextStyle _quoteStyle(bool isOut) => HaloType.sans(
    size: 12.5,
    color: isOut ? HaloColors.onAmber.withValues(alpha: 0.8) : HaloColors.text2,
    height: 1.3,
  );

  // no bubble: the sticker alone, its time in a pill
  Widget _sticker(StickerWire st) {
    final isOut = m.direction == 'out';
    final quoted = quotedText;
    final burn = m.burnAt;
    return StickerBubble(
      wire: st,
      emoji: m.text,
      isOut: isOut,
      seed: m.msgUid ?? '',
      budget: stickers,
      order: stickerOrder,
      arriving: arriving,
      landing: landing,
      onTap: onRetry,
      quote: quoted == null
          ? null
          : StickerQuoteCard(
              author: quotedAuthor,
              text: quoted,
              sticker: quotedSticker,
              onTap: onReplyTap,
            ),
      stamp: StickerStamp(
        time: _fmtTime(m.when),
        sent: isOut && !m.pending && !m.looksFailed,
        burn: burn == null ? null : _remaining(burn),
        alert: m.looksFailed ? l10n.groupChatTapToRetry : null,
        alertColor: HaloColors.rose,
      ),
    );
  }

  Widget _pollCard() {
    final isOut = m.direction == 'out';
    return PollCard(
      key: ValueKey('poll_${m.msgUid}'),
      question: m.text,
      poll: m.poll!,
      votes: m.votes,
      me: me,
      mine: isOut,
      isOut: isOut,
      onVote: (c) => onVote?.call(c),
      onClose: isOut ? onClosePoll : null,
      nameOf: nameOf ?? (id) => id,
      burn: m.burnAt == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _remaining(m.burnAt!),
                style: HaloType.mono(size: 9, color: HaloColors.amber),
              ),
            ),
      stamp: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmtTime(m.when),
            style: HaloType.mono(size: 9.5, color: HaloColors.text2),
          ),
          if (isOut && !m.pending && !m.looksFailed) ...[
            const SizedBox(width: 3),
            Text(
              '✓',
              style: TextStyle(
                fontFamily: HaloType.monoFamily,
                fontFamilyFallback: HaloType.monoFallbackNow,
                fontSize: 11,
                color: HaloColors.amber,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
          if (m.looksFailed) ...[
            const SizedBox(width: 6),
            Text(
              l10n.groupChatTapToRetry,
              style: HaloType.mono(size: 9, color: HaloColors.rose),
            ),
          ],
        ],
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
    return [
      for (final e in counts.entries)
        ReactionChip(
          key: ValueKey(e.key),
          emoji: e.key,
          count: e.value,
          mine: e.key == selfEmoji,
          popKey: '${m.msgUid}:${e.key}',
        ),
    ];
  }

  String _fmtTime(DateTime t) => hourMinute(t);

  String _remaining(int burnAt) {
    final ms = burnAt - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return l10n.groupChat0s;
    final s = ms ~/ 1000;
    if (s < 60) return l10n.groupChatS(whole(s));
    if (s < 3600) return l10n.groupChatM(whole(s ~/ 60));
    if (s < 86400) return l10n.groupChatH(whole(s ~/ 3600));
    return l10n.groupChatD(whole(s ~/ 86400));
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
    this.onShare,
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
  final VoidCallback? onShare;
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
      duration: const Duration(milliseconds: 240),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // same growth as the chat's menu, so the two read as one thing
    final scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_ctrl);
    final fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    final still = motionStill(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Opacity(
        opacity: fade.value,
        child: Transform.scale(
          scale: still ? 1 : scale.value,
          alignment: widget.isOut
              ? AlignmentDirectional.bottomEnd
              : AlignmentDirectional.bottomStart,
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
                    Semantics(
                      label: l10n.groupChatReply,
                      button: true,
                      child: _ActionTap(
                        icon: Icons.reply_rounded,
                        onTap: widget.onReply,
                      ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MessageMenuCard(
        actions: [
          MenuAction(
            icon: widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: widget.pinned ? l10n.groupChatUnpin : l10n.groupChatPin,
            onTap: widget.onPin,
          ),
          MenuAction(
            icon: widget.saved ? Icons.bookmark : Icons.bookmark_outline,
            label: widget.saved ? l10n.groupChatUnsave : l10n.commonSave,
            tint: widget.saved ? HaloColors.amber : null,
            onTap: widget.onSave,
          ),
          MenuAction(
            icon: Icons.copy_rounded,
            label: l10n.commonCopy,
            onTap: widget.onCopy,
          ),
          MenuAction(
            icon: Icons.forward_rounded,
            label: l10n.groupChatForward,
            onTap: widget.onForward,
          ),
          MenuAction(
            icon: Icons.ios_share_rounded,
            label: l10n.commonShare,
            onTap: widget.onShare,
          ),
          if (widget.isOut) ...[
            MenuAction(
              icon: Icons.edit_outlined,
              label: l10n.commonEdit,
              tint: HaloColors.amber,
              onTap: widget.onEdit,
            ),
            MenuAction(
              icon: Icons.delete_outline,
              label: l10n.groupChatUnsend,
              danger: true,
              onTap: widget.onUnsend,
            ),
          ],
        ],
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
