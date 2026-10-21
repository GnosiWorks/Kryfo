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
import '../back_on_top.dart';
import '../forward.dart';
import 'forward_sheet.dart';
import '../picked.dart';
import '../album.dart';
import '../widgets/album_grid.dart';
import '../widgets/album_viewer.dart';
import 'media_send_screen.dart';
import '../sent_name.dart';
import '../widgets/press_scale.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/pins.dart';
import '../widgets/owned_text.dart';
import '../widgets/remembered_height.dart';
import '../widgets/video_bubble.dart';
import '../widgets/kryfo_link_text.dart';
import '../open_file.dart';
import '../file_kind.dart'
    show
        FileShape,
        bytesSayIsoVideo,
        fileFactsRead,
        fileFits,
        fileShapeNow,
        knownInstaller,
        readFileFactsFresh;
import '../file_save.dart' show saveReceivedFile;
import '../widgets/media_bubbles.dart';
import '../widgets/decode_px.dart';
import '../atmosphere.dart';
import '../notifications.dart' show clearNotificationsFor;
import 'dev_about_sheet.dart' show devForwardTarget;
import 'chat_screen.dart' show SearchHead, firstUrl;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../drafts.dart';
import '../wallpaper.dart';
import '../widgets/chat_backdrop.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../stickers/sticker_bubble.dart';
import '../stickers/sticker_flight.dart';
import '../stickers/sticker_pack.dart' show Sticker, StickerLibrary;
import '../stickers/sticker_sheet.dart'
    show GifPick, PhoneGifPick, StickerButton, StickerPick, showStickerSheet;
import '../gifs/gif_engine.dart' show appGifTabs;
import '../gifs/gif_picture.dart';
import '../stickers/sticker_view.dart' show StickerBudget;
import '../stickers/sticker_wire.dart' show StickerWire;
import '../main.dart'
    show
        appState,
        session,
        sessionQuiet,
        claimChat,
        releaseChat,
        newMsgUid,
        torStrictGetOnIsolate,
        torValve,
        shredFile,
        kAdminGone,
        themeRevision;
import '../widgets/reconnect_valve.dart';
import '../theme.dart';
import '../media_progress.dart';
import '../msg_order.dart';
import '../widgets/earlier_chip.dart';
import '../group_send_watch.dart';
import '../media_send.dart' show cancelMediaSend, mediaInflight;
import '../image_strip.dart';
import '../mp4_strip.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/burn_fade.dart';
import '../seen_timers.dart';
import '../read_burn.dart';
import '../widgets/row_anchor.dart'
    show HoldScrollController, RowAnchor, RowAnchors, holdRowsInView;
import 'group_info_screen.dart';
import '../group_end.dart' show GroupEnd, groupEndOf;
import '../widgets/motion.dart'
    show
        haloRoute,
        SendPill,
        PrivacyMode,
        TorStatus,
        motionStill,
        kHouseCurve,
        kHouseTime;
import '../widgets/chat_parts.dart';
import '../widgets/file_reach.dart';
import '../group_media_send.dart' show groupOwedTick;
import '../widgets/message_menu.dart';
import '../rooms.dart';
import '../widgets/notice_banner.dart';
import '../widgets/room_countdown.dart';
import '../widgets/room_join.dart';
import '../widgets/swipe_to_reply.dart';
import 'room_link_sheet.dart';
import '../dlog.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/shift_tap_guard.dart';
import '../widgets/held_menu.dart';
import '../widgets/menu_backdrop.dart';
import '../mentions.dart';
import '../widgets/link_stub.dart';
import '../widgets/place_stub.dart';
import 'camera_screen.dart';
import '../link_preview.dart' show titleFromHtml, senderPreview, WordLinks;
import '../widgets/preview_strip.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/moved_strip.dart';
import '../widgets/empty_chat.dart';
import '../widgets/swap.dart' show FadeSwap, RiseSwap;
import '../widgets/ease_size.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/marked.dart';
import '../l10n/numbers.dart';
import '../widgets/video_viewer.dart';
import '../chat_shots.dart' show shotsKeeps;
import '../widgets/photo_viewer.dart' show photoHeroTag;
import '../widgets/voice_mic.dart';
import '../polls.dart';
import '../widgets/attach_grid.dart';
import '../widgets/halo_hero.dart';
import '../widgets/new_poll_sheet.dart';
import '../widgets/poll_card.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/written_field.dart';
import '../bidi_safe.dart';
import '../lock_guard.dart' show LockDropped, lockGuard, onScreen;

// our nickname for a member, or nothing so the id shows. a room member is a
// key, not a person we know, so it gets the short tag instead.
String? _senderLabel(Map<String, String> nickById, String peer) =>
    nickById[peer] ?? (looksLikeRoomKey(peer) ? roomTag(peer) : null);

/// the row of a file of this phone's, kept by [save] only with its group
/// still here. a group that ended under the picker, the camera or the
/// recorder, or a row that could not be kept, takes the file at [path]
/// with it: nothing of it stays on the phone. false then
@visibleForTesting
Future<bool> keepOwnGroupFile(String path, Future<bool> Function() save) async {
  var kept = false;
  try {
    kept = await save();
  } catch (e) {
    dlog('group file: row not kept (${e.runtimeType})');
  }
  if (!kept) await shredFile(path);
  return kept;
}

// a group gone from here closes its screen. in front it goes at once; under
// other screens only when this phone was taken out, since a leave from the
// info screen pops both itself and one more pop would close the app.
// [above] is what stands over it, nearest first: what it opened goes with
// it, a chat opened over that from elsewhere stays with all above it
@visibleForTesting
bool closeGoneGroup(
  NavigatorState nav,
  Route<dynamic> route, {
  required bool removed,
  List<Route<dynamic>> above = const [],
}) {
  if (route.isCurrent) {
    nav.pop();
    return true;
  }
  if (!removed || !route.isActive) return false;
  final stop = above.indexWhere(isChatPage);
  if (stop < 0) {
    nav.popUntil((r) => r == route);
    nav.pop();
    return true;
  }
  for (final r in above.take(stop).toList().reversed) {
    if (r.isActive) nav.removeRoute(r);
  }
  nav.removeRoute(route);
  return true;
}

/// an incoming bubble names its sender at the start of their run: after
/// someone else, after one of ours, under a new day's chip
@visibleForTesting
bool startsSenderRun({
  required String sender,
  required DateTime when,
  required ({String sender, bool inbound, DateTime when})? prev,
}) {
  if (prev == null) return true;
  if (prev.sender != sender || !prev.inbound) return true;
  return prev.when.year != when.year ||
      prev.when.month != when.month ||
      prev.when.day != when.day;
}

// the groups open in the stack, by id: a tap for one goes back to it
// rather than stacking a second copy whose draft would win
final Map<String, List<_GroupChatScreenState>> _openGroups = {};

/// a group's unsent words go with it, from an open composer too: its screen
/// closing would write them back
void dropGroupDraft(String id) {
  for (final s in _openGroups[id] ?? const <_GroupChatScreenState>[]) {
    if (s.mounted) s._msgCtrl.clear();
  }
  draftPerGroup.remove(session.chatKey(id));
}

/// pops [nav] back to [groupId]'s open screen. false when it is not open
/// there
bool backToOpenGroup(NavigatorState nav, String groupId) =>
    backToPage(nav, [...?_openGroups[groupId]]);

/// a group message's words to edit. null when cancelled or dismissed
@visibleForTesting
Future<String?> showGroupEditSheet(BuildContext context, String text) =>
    showHaloSheet<String>(
      context,
      scroll: true,
      builder: (_) => OwnedText(
        initial: text,
        builder: (ctx, ctrl) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            // the keyboard, or the navigation bar when it is down
            bottom:
                math.max(
                  MediaQuery.paddingOf(ctx).bottom,
                  MediaQuery.viewInsetsOf(ctx).bottom,
                ) +
                20,
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
                  color: HaloColors.amberText,
                ),
              ),
              const SizedBox(height: 14),
              ShiftTapGuard(
                controller: ctrl,
                child: TextField(
                  controller: ctrl,
                  enableIMEPersonalizedLearning: false,
                  autofocus: true,
                  // a long message scrolls in the field, so save stays in view
                  minLines: 1,
                  maxLines: 6,
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
                        color: HaloColors.amberText,
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

// the newest row id held when a group was last left, keyed by
// session.chatKey like the drafts
final Map<String, int> _lastRowPerGroup = {};

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  // open at this message, lit for a moment (from search)
  final String? jumpToUid;
  const GroupChatScreen({super.key, required this.groupId, this.jumpToUid});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with
        WidgetsBindingObserver,
        BackOnTop<GroupChatScreen>,
        HeldMenu<GroupChatScreen> {
  final _msgCtrl = TextEditingController();
  // the people @ can offer, refreshed with the roster
  List<MentionCandidate> _mentionable = const [];
  final _scrollCtrl = HoldScrollController();
  final List<_GMsg> _messages = [];

  // when the oldest of ours still going was written. a file that is
  // plainly moving is not waiting, and neither is a row that already reads
  // as failed
  DateTime? _waitingSince() {
    DateTime? oldest;
    for (final m in _messages) {
      if (m.direction != 'out' || !m.pending) continue;
      if (appState.linkUp &&
          m.msgUid != null &&
          mediaInflight.contains(m.msgUid)) {
        continue;
      }
      if (oldest == null || m.when.isBefore(oldest)) oldest = m.when;
    }
    return oldest;
  }

  bool _showScrollDown = false;
  // others' messages that came in while reading back, for the jump button.
  // counted as they arrive: older pages and reloads add none
  int _unseenNew = 0;
  // came in written well before the bottom, up the thread (EarlierChip)
  final _earlier = EarlierArrivals();
  String _groupName = '';
  int _memberCount = 0;
  // who this phone is in this chat: its kryfo id, or its key in a room
  String _me = '';
  // nobody else is in it: a room before anyone joins, or a group everyone
  // else left. a send would reach nobody and only turn failed
  bool _alone = false;

  // true, and says so, when there is nobody to send to. a room not let in
  // yet has nobody either: no member reads its key
  bool _nobodyToRead() {
    if (_waiting) {
      HapticFeedback.lightImpact();
      return true;
    }
    if (!_alone) return false;
    HapticFeedback.lightImpact();
    showHaloToast(context, l10n.groupChatNobodyToReadIt);
    return true;
  }

  // the room did not answer: the join goes again and the wait starts over.
  // the panel turns back to waiting at once, the relays take their time
  void _knockAgain() {
    HapticFeedback.selectionClick();
    setState(() => _joiningAt = DateTime.now().millisecondsSinceEpoch);
    final id = widget.groupId;
    unawaited(() async {
      try {
        await appState.retryRoomJoin(id);
      } catch (e) {
        dlog('room join again: ${e.runtimeType}');
      }
    }());
  }

  // a group whose admin "this isn't them" took off this phone: left as
  // the group info page leaves one
  Future<void> _leaveAdminGone() async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.groupInfoLeaveGroup,
      line: leaveLine(room: false, admin: false),
      yes: l10n.groupInfoLeave,
    );
    if (!ok || !mounted) return;
    await appState.leaveGroupAndAnnounce(widget.groupId);
    if (mounted) Navigator.of(context).pop();
  }

  // nothing in it to lose: the room goes from this phone, and the screen
  // with it
  void _leaveWaiting() {
    HapticFeedback.mediumImpact();
    final id = widget.groupId;
    Navigator.of(context).pop();
    unawaited(appState.leaveRoom(id));
  }

  String _nameOf(String id) {
    for (final c in appState.contacts) {
      final n = c.nickname;
      if (c.haloId == id && n != null && n.isNotEmpty) return n;
    }
    return _senderLabel(const {}, id) ?? id;
  }

  int? _faceOf(String id) {
    for (final c in appState.contacts) {
      if (c.haloId == id) return c.avatar;
    }
    return null;
  }

  // burner room state: when it ends, and whether this is the first open
  int? _roomExpiresAt;
  bool _roomBanner = false;
  bool get _isRoom => _roomExpiresAt != null;
  // joined off a link and not let in yet: when the join went
  int? _joiningAt;
  bool get _waiting => _isRoom && _joiningAt != null;
  bool _isAdmin = false;
  // its admin was taken off this phone ("this isn't them"): no change to
  // the group reaches it any more
  bool _adminGone = false;
  // its admin ended it: what it held is gone, and nothing is written here
  GroupEnd? _end;
  bool _sending = false;
  // at most six stickers play at once in the whole chat
  final _stickers = StickerBudget(6);
  // stickers flying in from the sheet, by message uid. a bubble stays
  // hidden until its flight is down
  final Map<String, StickerLanding> _landings = {};
  final List<VoidCallback> _flights = [];
  _GMsg? _replyTo;
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
    _messages.sort(
      (a, b) => byWritten(
        a.when.millisecondsSinceEpoch,
        a.rowid,
        b.when.millisecondsSinceEpoch,
        b.rowid,
      ),
    );
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
  // what this group shows behind it (wallpaper.dart)
  ChatWall _wall = ChatWall.none;
  static const _pageSize = 60;
  bool _hasMore = true;
  bool _loadingOlder = false;
  bool _pagedOut = false;
  // ghost mode, kept as the 1:1 chats keep it. when on, new messages carry
  // a burn timer; receivers compute the burn deadline locally.
  bool _ghost = false;
  // this group's voice notes go out disguised
  bool _disguise = false;
  int _burnSeconds = 300; // 5 min default, same as 1:1
  // the burn and the auto retry run only while the group is in view, and
  // catch up the moment it is back
  final _timers = SeenTimers();
  late final SeenJob _burn;
  int _lastBurnSec = 0;
  bool _loading = false;
  // a message of ours some members still lack, by uid
  Map<String, ({int have, int of, int gaveUp})> _reach = const {};
  bool _reloadQueued = false;
  bool _loaded = false; // first full load done, gates the fast append
  int _seenRev = -1; // last group rev we reloaded for
  // this group in the session that opened it, for what is kept between
  // visits
  late final String _memo;

  @override
  void initState() {
    super.initState();
    _memo = session.chatKey(widget.groupId);
    _loadWall();
    // set from its info page or under appearance: shown at once
    wallpaperRevision.addListener(_loadWall);
    // the chat list already knows the header: the tile flies in with its
    // letter and the count is right from the first frame
    for (final g in appState.groups) {
      if (g.groupId != widget.groupId) continue;
      _groupName = g.name;
      _memberCount = g.memberCount;
      _isAdmin = g.isAdmin;
      _roomExpiresAt = g.expiresAt;
      _joiningAt = g.joiningAt;
      if (g.endedBy != null) _end = (at: 0, by: g.endedBy!);
      break;
    }

    claimChat('group:${widget.groupId}');
    (_openGroups[widget.groupId] ??= []).add(this);
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
      // gone already: nothing is held for a screen that let go
      if (!_left) _holdSecure(true);
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
    _msgCtrl.text = draftPerGroup[_memo] ?? '';
    // save it live on every keystroke so it survives leaving regardless of
    // when dispose runs.
    _msgCtrl.addListener(() {
      final t = _msgCtrl.text;
      if (t.trim().isEmpty) {
        draftPerGroup.remove(_memo);
      } else {
        draftPerGroup[_memo] = t;
      }
    });
    _scrollCtrl.addListener(_updateSticky);
    _scrollCtrl.addListener(_onGroupScroll);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _suppressSticky = false;
    });
    _load();
    _loadDisguise();
    appState.loadGhostPref().then((p) {
      if (mounted) {
        setState(() {
          _ghost = p.$1;
          _burnSeconds = p.$2;
        });
      }
    });
    appState.addListener(_onAppStateChanged);
    groupOwedTick.addListener(_reachMoved);
    _timers.every(const Duration(seconds: 30), _autoRetryTick);
    _burn = _timers.until(_burnWait, _burnTick);
    // back in view: what shows now has been read
    _reads.keepTime(_timers);
    _scrollCtrl.addListener(_reads.look);
    _scrollCtrl.addListener(_lookEarlier);
  }

  final RowAnchors _anchors = RowAnchors();

  // the route this chat is on: a sheet, a dialog or a see-through page over
  // it leaves it drawn but not read
  ModalRoute<Object?>? _route;

  // others' timed messages start counting once read here
  late final _reads = ReadBurns(
    anchors: _anchors,
    allowed: () => !lockGuard.isLocked() && !sessionQuiet,
    reading: () =>
        _timers.seen &&
        (_route?.isCurrent ?? true) &&
        !lockGuard.isLocked() &&
        !sessionQuiet,
    waiting: () => [
      for (final m in _messages)
        if (m.burnUnread && !m.removing && m.msgUid != null) m.msgUid!,
    ],
    light: _lightRead,
  );

  // what is acted on is read: opened, played, voted on, held or answered
  void _touched(_GMsg m) {
    if (m.burnUnread) _reads.touched(m.msgUid);
  }

  Future<Map<String, int>> _lightRead(List<String> uids) async {
    final at = await session.lightReadBurns(widget.groupId, uids);
    if (!mounted || at.isEmpty) return at;
    setState(() {
      // older rows lit along with them come back too
      for (final m in _messages) {
        final t = at[m.msgUid];
        if (t != null && m.burnUnread) {
          m.burnAt = t;
          m.burnUnseen = false;
        }
      }
    });
    // a pin that waited shows now
    unawaited(_refreshPinCount());
    return at;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
    _route = ModalRoute.of(context);
    // what covered the chat has gone: what shows now is read
    _reads.look();
  }

  // when the burn looks again: the next deadline, or the countdown's next
  // second. nothing while no message here counts down
  Duration? _burnWait() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // what waited its day counts from then, in the frame that asks
    _startWaited(now);
    var ghosts = false;
    int? soonest;
    // a row still waiting starts counting a day after it came
    final starts = <int>[];
    for (final m in _messages) {
      if (m.burnWaits) {
        starts.add(burnStartBy(m.came, now));
      }
      final at = m.burnAt;
      if (at == null) continue;
      ghosts = true;
      if (m.removing || m.sending || m.failed) continue;
      if (soonest == null || at < soonest) soonest = at;
    }
    return burnWaitStarts(
      now,
      ghosts: ghosts,
      soonest: soonest,
      starts: starts,
    );
  }

  // what waited a day unread counts from then, as the sweep writes it
  void _startWaited(int now) {
    for (final m in _messages) {
      if (!m.burnWaits) continue;
      final s = burnStartBy(m.came, now);
      if (s > now) continue;
      m.burnAt = s + m.burnSecs! * 1000;
      m.burnUnseen = true;
    }
  }

  void _burnTick(bool back) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _startWaited(now);
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
        if (m.msgUid != null) _earlier.drop(m.msgUid!);
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

  // the line for what came up the thread, above the jump button
  Widget _earlierLine() => Positioned(
    left: 16,
    right: 16,
    bottom: 0,
    child: Center(
      child: EarlierChip(
        count: _earlier.count,
        lifted: _showScrollDown,
        onTap: _toEarlier,
      ),
    ),
  );

  // jump to newest, same control as 1:1
  Widget _scrollDownButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: Center(
        child: JumpDownButton(
          shown: _showScrollDown,
          count: _unseenNew,
          label: l10n.groupChatJumpToTheNewest,
          onTap: () {
            setState(() => _unseenNew = 0);
            _scrollToEnd();
          },
        ),
      ),
    );
  }

  void _onGroupScroll() {
    if (!_scrollReady) return;
    final show = !_nearNewest;
    if (!show) _unseenNew = 0;
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
      final oldest = _oldestHeld();
      _blocked = await session.blockedIds();
      final rows0 = await session.groupMessagesPage(
        widget.groupId,
        beforeRowid: oldest?.rowid,
        beforeAt: oldest?.when.millisecondsSinceEpoch,
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
          when: DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
          sticker: StickerWire.parse(r['sticker']),
          burnAt: r['burn_at'] as int?,
          burnSecs: (r['burn_secs'] as num?)?.toInt(),
          burnUnseen: r['burn_unseen'] == 1,
          msgUid: uid,
          replyTo: r['reply_to'] as String?,
          mediaPath: r['media_path'] as String?,
          filePath: r['file_path'] as String?,
          fileName: r['file_name'] as String?,
          voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
          pinned: ((r['pinned'] as int?) ?? 0) == 1,
          saved: ((r['saved'] as int?) ?? 0) == 1,
          edited: ((r['edited'] as int?) ?? 0) == 1,
          album: AlbumTag.ofRow(r),
          reactions: rxMap,
        );
        m.preview = _decodePv(r['preview'] as String?);
        m.poll = PollSpec.parse(r['poll']);
        m.votes = votes[uid] ?? const {};
        m.reach = _reach[uid];
        m.rowid = (r['rowid'] as int?) ?? 0;
        m.cameAt = (r['sent_at'] as num?)?.toInt();
        older.add(m);
      }
      // divider anchors change after the prepend (day boundaries move), so
      // drop the maps, build fills them again.
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

  void _loadWall() {
    chatWall(widget.groupId, group: true).then((w) {
      if (mounted && !w.sameAs(_wall)) setState(() => _wall = w);
    });
  }

  Future<void> _load() async {
    _loading = true;
    try {
      _dayKeys.clear();
      _dayMsOf.clear();
      final g = await session.getGroup(widget.groupId);
      // a room that ended, or a group this phone was taken out of, is gone,
      // so is the screen
      if (g == null) {
        final removed = appState.takeRemovedFrom(widget.groupId);
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route == null) return;
        final nav = Navigator.of(context);
        final closed = closeGoneGroup(
          nav,
          route,
          removed: removed != null,
          above: routeStack.above(route),
        );
        if (closed && removed != null) {
          showHaloToast(nav.context, l10n.groupChatYouWereRemovedFrom(removed));
        }
        return;
      }
      final members = await session.getGroupMembers(widget.groupId);
      _me = await appState.meIn(widget.groupId);
      // keep whatever window the user has expanded to, so a mid-scroll
      // reaction does not collapse the list back to one page
      final wantAll = _searching || _pagedOut || _messages.length > _pageSize;
      // opened on a message: the newest page, and the whole thread only
      // when it is further up than that
      final jumpTo = _didJump ? null : widget.jumpToUid;
      _blocked = await session.blockedIds();
      var rows0 = wantAll
          ? await session.loadGroupMessages(widget.groupId)
          : await session.groupMessagesPage(
              widget.groupId,
              limit: _pageSize + 1,
            );
      if (!wantAll) {
        _hasMore = rows0.length > _pageSize;
        if (_hasMore) rows0.removeAt(0);
        if (!_hasMore) _pagedOut = true;
        if (jumpTo != null && !rows0.any((r) => r['msg_uid'] == jumpTo)) {
          rows0 = await session.loadGroupMessages(widget.groupId);
          _hasMore = false;
          _pagedOut = true;
        }
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
      final reach = await session.groupFileReach(widget.groupId);
      // local nickname is the display source of truth. fall back to the 3-word
      // id when we have no nickname for that member.
      final nickById = <String, String>{};
      final faceById = <String, int?>{};
      for (final c in appState.contacts) {
        final n = c.nickname;
        if (n != null && n.isNotEmpty) nickById[c.haloId] = n;
        faceById[c.haloId] = c.avatar;
      }
      _mentionable = mentionable(
        members,
        me: _me,
        room: g['room_pub'] != null,
        names: nickById,
        faces: faceById,
      );
      if (!mounted) return;
      final joining = g['room_pub'] != null ? g['joining_at'] as int? : null;
      // let in while the room is open: a light tap as it comes alive
      if (_waiting && joining == null && _loaded) {
        HapticFeedback.lightImpact();
      }
      _holdSeen();
      setState(() {
        _groupName = (g['name'] as String?) ?? l10n.groupInfoGroup;
        // an ended group counts no one
        _memberCount = groupEndOf(g) != null ? 0 : members.length;
        _alone = !members.any((m) => m != _me && m != appState.sessionId);
        _roomExpiresAt = g['expires_at'] as int?;
        _joiningAt = joining;
        _isAdmin = ((g['is_admin'] as int?) ?? 0) == 1;
        _adminGone = g['admin_id'] == kAdminGone && g['room_pub'] == null;
        _end = groupEndOf(g);
        _reach = reach;
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
                when: DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
                sticker: StickerWire.parse(r['sticker']),
                burnAt: r['burn_at'] as int?,
                burnSecs: (r['burn_secs'] as num?)?.toInt(),
                burnUnseen: r['burn_unseen'] == 1,
                msgUid: uid,
                replyTo: r['reply_to'] as String?,
                mediaPath: r['media_path'] as String?,
                filePath: r['file_path'] as String?,
                fileName: r['file_name'] as String?,
                voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
                pinned: ((r['pinned'] as int?) ?? 0) == 1,
                saved: ((r['saved'] as int?) ?? 0) == 1,
                edited: ((r['edited'] as int?) ?? 0) == 1,
                album: AlbumTag.ofRow(r),
                sending: dir == 'out' && (r['sent'] as int? ?? 1) == 0,
                reactions: rxMap,
              );
              m.preview = _decodePv(r['preview'] as String?);
              m.poll = PollSpec.parse(r['poll']);
              m.votes = votes[uid] ?? const {};
              m.reach = reach[uid];
              m.rowid = (r['rowid'] as int?) ?? 0;
              m.cameAt = (r['sent_at'] as num?)?.toInt();
              _placeLoadedSend(m);
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
      final after = _lastRowPerGroup[_memo];
      if (!_loaded && after != null) {
        try {
          await _earlierSince(after);
        } catch (e) {
          // the line is a help: a read that fails leaves the chat as it is
          dlog('earlier: not read (${e.runtimeType})');
        }
      }
      if (_earlier.count > 0) {
        await _pruneEarlier();
        _lookEarlierSoon();
      }
      _loaded = true;
      unawaited(_refreshPinCount());
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

  // a message some members still lacked moved on: its line follows,
  // without a reload of the whole list
  void _reachMoved() => unawaited(_loadReach());

  Future<void> _loadReach() async {
    final reach = await session.groupFileReach(widget.groupId);
    if (!mounted) return;
    setState(() {
      _reach = reach;
      for (final m in _messages) {
        final uid = m.msgUid;
        m.reach = uid == null ? null : reach[uid];
      }
    });
  }

  // whether the route was up at the last change, so a send left 'sending'
  // while it was down is looked at again once it comes up. a look that a
  // send in flight held back stays due until that send ends
  bool _wasReady = appState.torReady;
  bool _deadLookDue = false;

  // the creator found no seat for this phone's join
  late bool _full = appState.roomFull(widget.groupId);

  void _onAppStateChanged() {
    final full = appState.roomFull(widget.groupId);
    if (full != _full && mounted) setState(() => _full = full);
    final ready = appState.torReady;
    if (ready && !_wasReady) _deadLookDue = true;
    _wasReady = ready;
    if (_lookAtDeadSends()) return;
    // only react to our own group's traffic, or every 1:1 message reloads
    // this screen and churns every photo bubble
    final rev = appState.chatRevOf('group:${widget.groupId}');
    if (rev == _seenRev) return;
    _seenRev = rev;
    // ended while open: all of it went, read it whole again
    if (_end == null &&
        appState.groups.any((g) => g.groupId == widget.groupId && g.ended)) {
      _replyTo = null;
      if (_loading) {
        _reloadQueued = true;
      } else {
        unawaited(_load());
      }
      return;
    }
    unawaited(_settleOthersSends());
    // a single multicast fires notifyListeners() once per recipient, and a
    // full _load() per fire freezes the ui. if a load is already running,
    // queue at most one follow-up.
    if (_loading) {
      _reloadQueued = true;
      return;
    }
    _tryAppendNew();
  }

  // reloads when the route came up over a dead 'sending' row, so the
  // reload marks it failed and retryable. true when it reloaded
  bool _lookAtDeadSends() {
    if (!_deadLookDue || _sending) return false;
    _deadLookDue = false;
    if (!appState.torReady || !_messages.any(_deadSend)) return false;
    _seenRev = appState.chatRevOf('group:${widget.groupId}');
    if (_loading) {
      _reloadQueued = true;
    } else {
      _load();
    }
    return true;
  }

  // only a stale sending out-message is dead: a live send (<60s old) keeps
  // its pill, or a working media send flips to failed mid-flight. the same
  // rule as a 1:1 chat
  bool _deadSend(_GMsg m) =>
      m.direction == 'out' &&
      m.sending &&
      appState.sendLooksDead(m.when, msgUid: m.msgUid);

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

  // the oldest row on screen that the database has, in the chat's order
  _GMsg? _oldestHeld() {
    for (final m in _messages) {
      if (m.rowid > 0) return m;
    }
    return null;
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
    // one written before the pages held comes with the page it is in
    final oldest = _hasMore ? _oldestHeld() : null;
    final brandNew = rows
        .where(
          (r) =>
              (r['msg_uid'] as String?) != null &&
              !have.contains(r['msg_uid'] as String?) &&
              (oldest == null ||
                  byWritten(
                        rowWrittenAt(r),
                        (r['rowid'] as int?) ?? 0,
                        oldest.when.millisecondsSinceEpoch,
                        oldest.rowid,
                      ) >
                      0),
        )
        .toList();
    if (brandNew.isEmpty) {
      // no new rows: reactions, edits, unsends and burns need a full reload,
      // except while one of our own sends is in flight. a reload then
      // orphans the optimistic row and freezes its send pill, so it waits.
      // a group that ended or was left meanwhile closes the screen anyway
      final sendInFlight = _messages.any((m) => m.sending);
      if (!sendInFlight || !await session.groupExists(widget.groupId)) {
        if (mounted) _load();
      }
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
        when: DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
        sticker: StickerWire.parse(r['sticker']),
        burnAt: r['burn_at'] as int?,
        burnSecs: (r['burn_secs'] as num?)?.toInt(),
        burnUnseen: r['burn_unseen'] == 1,
        msgUid: uid,
        replyTo: r['reply_to'] as String?,
        mediaPath: r['media_path'] as String?,
        filePath: r['file_path'] as String?,
        fileName: r['file_name'] as String?,
        voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
        pinned: ((r['pinned'] as int?) ?? 0) == 1,
        saved: ((r['saved'] as int?) ?? 0) == 1,
        edited: ((r['edited'] as int?) ?? 0) == 1,
        album: AlbumTag.ofRow(r),
        sending: dir == 'out' && (r['sent'] as int? ?? 1) == 0,
        reactions: rxMap,
      );
      m.preview = _decodePv(r['preview'] as String?);
      m.poll = PollSpec.parse(r['poll']);
      m.votes = votes[uid] ?? const {};
      m.reach = _reach[uid];
      m.rowid = (r['rowid'] as int?) ?? 0;
      m.cameAt = (r['sent_at'] as num?)?.toInt();
      if (dir == 'in') m.fresh = true;
      _placeLoadedSend(m);
      fresh.add(m);
    }
    final nowHave = _messages.map((m) => m.msgUid).toSet();
    fresh.removeWhere((m) => m.msgUid != null && nowHave.contains(m.msgUid));
    if (fresh.isEmpty) return;
    // someone reading back stays where they are, a late one put in above
    // them too. near the newest they are taken down to what lands at the
    // end; one that came late goes where it was written and is not counted
    final last = _messages.lastOrNull;
    bool below(_GMsg m) =>
        last == null ||
        byWritten(
              m.when.millisecondsSinceEpoch,
              m.rowid,
              last.when.millisecondsSinceEpoch,
              last.rowid,
            ) >
            0;
    final theirs = fresh.where((m) => m.direction != 'out' && below(m)).length;
    final ours = fresh.any((m) => m.direction == 'out');
    final follow = (_nearNewest && fresh.any(below)) || ours;
    for (final m in fresh) {
      if (m.direction != 'out' &&
          m.msgUid != null &&
          last != null &&
          cameEarlier(
            m.when.millisecondsSinceEpoch,
            last.when.millisecondsSinceEpoch,
          )) {
        _earlier.add(m.msgUid!);
      }
    }
    if (!follow) {
      holdRowsInView(
        ctrl: _scrollCtrl,
        anchors: _anchors,
        alive: () => mounted,
      );
    }
    setState(() {
      _messages.addAll(fresh);
      _normaliseMessages();
      if (!follow) _unseenNew += theirs;
    });
    _lookEarlierSoon();
    if (follow) _scrollToEnd();
  }

  // what came in after row [after] and went up the thread, well above the
  // newest row read then: in the rows held or above them
  Future<void> _earlierSince(int after) async {
    _GMsg? read;
    for (final m in _messages) {
      if (m.rowid > 0 && m.rowid <= after) read = m;
    }
    if (read == null) return;
    final bottom = read.when.millisecondsSinceEpoch;
    final first = _oldestHeld();
    final rows = _withoutBlocked(
      await session.groupMessagesAfter(widget.groupId, after),
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid == null || r['direction'] == 'out') continue;
      final at = rowWrittenAt(r);
      final id = (r['rowid'] as int?) ?? 0;
      final held = _messages.any((m) => m.msgUid == uid);
      final up = held
          ? byWritten(at, id, bottom, read.rowid) < 0
          : first != null &&
                byWritten(
                      at,
                      id,
                      first.when.millisecondsSinceEpoch,
                      first.rowid,
                    ) <
                    0;
      if (up && cameEarlier(at, bottom)) _earlier.add(uid);
    }
  }

  // each one up the thread that is on screen now has been seen. one
  // leaving, taken back or burned, is no longer there to see
  void _lookEarlier() {
    if (!mounted || _earlier.count == 0) return;
    var went = false;
    for (final m in _messages) {
      if (m.removing && m.msgUid != null && _earlier.drop(m.msgUid!)) {
        went = true;
      }
    }
    if ((!_reloading && _earlier.seenIn(_anchors)) || went) setState(() {});
  }

  // a reload's first frame can lay rows out where they do not stay: none
  // counts as seen until the frame after
  bool _reloading = false;
  void _holdSeen() {
    _reloading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reloading = false;
        _lookEarlier();
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  // a row that comes in, grows or folds moves the others without a scroll
  bool _threadResized(ScrollMetricsNotification n) {
    if (n.depth == 0) _lookEarlier();
    return false;
  }

  // after a reload: only what is still in the database stays counted
  Future<void> _pruneEarlier() async {
    if (_earlier.count == 0) return;
    final held = {
      for (final m in _messages)
        if (m.msgUid != null && !m.removing) m.msgUid!,
    };
    final gone = <String>[];
    for (final id in _earlier.ids) {
      if (held.contains(id)) continue;
      final leaving = _messages.any((m) => m.msgUid == id);
      var there = !leaving;
      if (there) {
        try {
          there = await session.messageExists(id);
        } catch (e) {
          dlog('earlier: not read (${e.runtimeType})');
        }
      }
      if (!there) gone.add(id);
    }
    if (gone.isEmpty || !mounted) return;
    setState(() {
      for (final id in gone) {
        _earlier.drop(id);
      }
    });
  }

  void _lookEarlierSoon() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookEarlier());

  // the line's tap: to the first one up the thread, the thread brought in
  // whole when it is above the pages held
  Future<void> _toEarlier() async {
    final uid = _earlier.first;
    if (uid == null) return;
    setState(() => _earlier.drop(uid));
    if (!_messages.any((m) => m.msgUid == uid)) {
      _pagedOut = true;
      await _load();
      if (!mounted) return;
    }
    final at = _messages.indexWhere((m) => m.msgUid == uid);
    if (at >= 0) _scrollToIndex(at);
  }

  // .position asserts exactly one attached scroll view, and during a route
  // transition two can be. hasClients is not enough on its own: the
  // controller attaches before the list has dimensions to read.
  bool get _scrollReady =>
      _scrollCtrl.positions.length == 1 &&
      _scrollCtrl.positions.first.hasContentDimensions;

  double get _maxScroll =>
      _scrollReady ? _scrollCtrl.positions.first.maxScrollExtent : 0.0;

  double get _pixels => _scrollReady ? _scrollCtrl.positions.first.pixels : 0.0;

  // not reversed here, unlike 1:1: the newest message lives at
  // maxScrollExtent. the jump button shows above this
  bool get _nearNewest => !_scrollReady || _maxScroll - _pixels <= 240;

  // the thread's albums, read again each time the thread is drawn
  AlbumIndex<_GMsg> _albums = _indexAlbums(const []);

  static AlbumIndex<_GMsg> _indexAlbums(Iterable<_GMsg> rows) =>
      AlbumIndex<_GMsg>(
        rows,
        tag: (m) => m.album,
        written: (m) => m.when.millisecondsSinceEpoch,
        // each member's own, and ours apart from theirs
        owner: (m) => m.direction == 'out' ? '' : m.sender,
        // a photo or a video; one of theirs whose file could not be kept
        // still holds its place
        media: (m) =>
            m.sticker == null &&
            m.poll == null &&
            (m.preparing ||
                m.mediaPath != null ||
                (m.filePath != null &&
                    m.fileName != 'voice.wav' &&
                    fileShapeNow(m.filePath, m.fileName) == FileShape.video) ||
                (m.direction == 'in' && m.filePath == null)),
      );

  // one row standing for a whole album: the caption of its first item, the
  // send state of all of it, its reactions, and the earliest clock
  static _GMsg _albumFace(AlbumRun<_GMsg> run) {
    final ms = run.present;
    final a = run.anchor;
    String? replyTo;
    for (final x in ms) {
      replyTo ??= x.replyTo;
    }
    final face = _GMsg(
      sender: a.sender,
      senderName: a.senderName,
      direction: a.direction,
      text: run.caption((x) => x.text),
      when: a.when,
      burnSecs: a.burnSecs,
      burnUnseen: ms.any((x) => x.burnUnseen),
      burnAt: albumBurnAt([for (final x in ms) x.burnAt]),
      msgUid: a.msgUid,
      replyTo: replyTo,
      sending: ms.any((x) => x.sending),
      mediaPath: a.mediaPath ?? a.filePath ?? '',
      pinned: ms.any((x) => x.pinned),
      saved: ms.any((x) => x.saved),
      album: a.album,
      reactions: albumReactions([for (final x in ms) x.reactions]),
    );
    face
      ..cameAt = a.cameAt
      ..rowid = a.rowid
      ..failed = ms.any((x) => x.failed)
      ..gaveUp = ms.any((x) => x.gaveUp)
      ..removing = ms.any((x) => x.removing);
    return face;
  }

  // the member a reaction from this phone goes on: the one already holding
  // it, or the album's first
  static _GMsg _reactOn(AlbumRun<_GMsg> run) {
    for (final x in run.present) {
      if (x.reactions.containsKey('')) return x;
    }
    return run.anchor;
  }

  // the row above as drawn: an album's other rows are not
  _GMsg? _drawnBefore(int i) {
    for (var j = i - 1; j >= 0; j--) {
      final o = _messages[j];
      if (!_albums.hidden(o)) return o;
    }
    return null;
  }

  Widget _buildGroupRow(int i) {
    final row = _messages[i];
    // one alone still made ready shows as a waiting tile of its own
    final run =
        _albums.runOf(row) ??
        (row.preparing
            ? (AlbumRun<_GMsg>('', const AlbumTag('', 1, 0), row, 0)
                ..slots[0] = row)
            : null);
    // drawn by its album's first row
    if (run != null && !identical(run.lead, row)) {
      return SizedBox.shrink(key: ValueKey(row.msgUid ?? 'r${row.rowid}'));
    }
    final m = run == null ? row : _albumFace(run);
    final members = run?.present ?? [row];
    final making = members.any((x) => x.preparing);
    final prev = _drawnBefore(i);
    final showSender =
        m.direction == 'in' &&
        startsSenderRun(
          sender: m.sender,
          when: m.when,
          prev: prev == null
              ? null
              : (
                  sender: prev.sender,
                  inbound: prev.direction == 'in',
                  when: prev.when,
                ),
        );
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
      // a timed message not read yet says only that it is one: its words
      // show on its own bubble, where reading them starts its clock
      if (orig.burnUnread) {
        quoted = l10n.timedMessageLabel;
      } else if (orig.sticker != null) {
        quoted = l10n.stickerLabel;
        quotedSticker = orig.sticker;
      } else if (orig.poll != null) {
        quoted = l10n.pollPreview(orig.text);
      } else if (orig.text.isNotEmpty) {
        quoted = orig.text;
      } else if (_albums.runOf(orig) != null) {
        quoted = l10n.albumQuoted;
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
    // an in-chat search marks its hits and dims the rest, as the 1:1 does.
    // an album is a hit when its caption is
    final searchActive = _searching && _query.isNotEmpty;
    final rowsAt = run == null
        ? [i]
        : [for (final x in members) _messages.indexOf(x)];
    final isMatch = searchActive && rowsAt.any(_matchSet.contains);
    final isCurrent =
        searchActive &&
        _matches.isNotEmpty &&
        rowsAt.contains(_matches[_matchPos]);
    final animateIn = members.any((x) => x.fresh);
    for (final x in members) {
      x.fresh = false;
    }
    final landing = m.msgUid == null ? null : _landings[m.msgUid];
    final showDate = i == 0 || (prev != null && !_sameDay(prev.when, m.when));
    final react = run == null ? row : _reactOn(run);
    final answer = run == null ? row : run.anchor;
    final lifted = members.any(
      (x) => x.msgUid != null && x.msgUid == _liftedUid,
    );
    // its other rows are read, and landed on, where the album is
    Widget anchored(Widget child) {
      var w = child;
      for (final x in members) {
        if (!identical(x, row)) {
          w = RowAnchor(
            anchors: _anchors,
            id: x.msgUid ?? 'r${x.rowid}',
            child: w,
          );
        }
      }
      return w;
    }

    return Column(
      key: ValueKey(row.msgUid ?? 'r${row.rowid}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDate) _dateDivider(m.when, row.msgUid ?? 'r${row.rowid}'),
        // the bubble alone: what says it has been read
        RowAnchor(
          anchors: _anchors,
          id: row.msgUid ?? 'r${row.rowid}',
          child: anchored(
            RepaintBoundary(
              key: members.any((x) => x.msgUid != null && x.msgUid == _jumpUid)
                  ? _jumpKey
                  : null,
              child: BubbleEntrance(
                isOut: m.direction == 'out',
                // a sticker pops or flies in on its own
                active: animateIn && m.sticker == null,
                // the row is the width of the list: a glow would light all
                // of it
                glow: false,
                child: SwipeToReply(
                  onReply: () {
                    for (final x in members) {
                      _touched(x);
                    }
                    setState(() => _replyTo = answer);
                  },
                  // the lifted copy in the overlay is the one that animates;
                  // the row underneath just steps aside
                  child: Opacity(
                    opacity: lifted ? 0.0 : 1.0,
                    child: _GroupBubble(
                      m: m,
                      album: run,
                      showSender: showSender,
                      kept: _keeps(m),
                      stickers: _stickers,
                      stickerOrder: _messages.length - 1 - i,
                      landing: landing,
                      arriving: animateIn && landing == null,
                      quotedSticker: quotedSticker,
                      me: _me,
                      nameOf: _nameOf,
                      faceOf: _faceOf,
                      onVote: m.poll == null || m.msgUid == null
                          ? null
                          : (c) {
                              _touched(m);
                              appState.votePoll(widget.groupId, m.msgUid!, c);
                            },
                      onAct: () {
                        for (final x in members) {
                          _touched(x);
                        }
                      },
                      onClosePoll: m.poll == null || m.msgUid == null
                          ? null
                          : () => appState.closePoll(widget.groupId, m.msgUid!),
                      senderBadge: _badgeFor(m.sender),
                      linkTitle: _linkPreview(m)?['title'],
                      linkBySender: _linkPreview(m)?['by'] == 'sender',
                      quotedText: quoted,
                      quotedAuthor: quotedAuthor,
                      // nothing to act on while it is still made ready
                      onLongPress: making
                          ? null
                          : (ctx) => _showEmojiPickerAt(
                              ctx,
                              m,
                              album: run,
                              showSender: showSender,
                              quotedText: quoted,
                              quotedAuthor: quotedAuthor,
                              quotedSticker: quotedSticker,
                            ),
                      onLongPressTile: run == null || making
                          ? null
                          : (ctx, tile) => _showEmojiPickerAt(
                              ctx,
                              m,
                              album: run,
                              tile: tile,
                              showSender: showSender,
                              quotedText: quoted,
                              quotedAuthor: quotedAuthor,
                              quotedSticker: quotedSticker,
                            ),
                      onRetry: m.looksFailed
                          ? () {
                              for (final x in members) {
                                if (!x.failed) continue;
                                x.autoRetries = 0;
                                x.gaveUp = false;
                                _retryGroup(x);
                              }
                            }
                          : null,
                      onReact: m.msgUid == null
                          ? null
                          : (e) {
                              final added = react.reactions[''] != e;
                              _toggleReaction(react, e);
                              if (added) _flashReaction(react);
                            },
                      ripple: members.any(
                        (x) => x.msgUid != null && x.msgUid == _rippleUid,
                      ),
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
    // a quiet session fetches nothing: what is typed there stays here
    if (url == null || _previewBusy || sessionQuiet || appState.everydayHeld) {
      return;
    }
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
    // the words stay in the field until someone is here
    if (_nobodyToRead()) return;
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
    int? burnAt;
    final sendFut = _watch.owning(
      uid,
      () => appState.sendToGroup(
        widget.groupId,
        text,
        msgUid: uid,
        replyTo: replyToUid,
        burnSeconds: burnSeconds,
        preview: preview,
      ),
    );
    try {
      ok = await sendFut;
      burnAt = await _burnFrom(uid, ok);
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
          if (burnAt != null) live.burnAt = burnAt;
        });
        // catch up any change deferred while this send was in flight.
        if (!_lookAtDeadSends() && !_messages.any((x) => x.sending)) {
          _tryAppendNew();
        }
      }
    }
  }

  // online, a failed send goes again on its own: half a minute apart, six
  // goes, then it is shown as failed with the tap
  void _autoRetryTick() {
    if (!mounted) return;
    // a row nobody is sending turns failed here once it is old enough
    unawaited(_settleOthersSends());
    if (_sending || _cannotSend()) return;
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
    // the group is gone: nothing goes, and the screen closes
    if (!await session.groupExists(widget.groupId)) {
      if (mounted) _load();
      return;
    }
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
      await _sendGroupMedia(
        m,
        () => appState.sendMediaToGroup(
          widget.groupId,
          f.path,
          msgUid: m.msgUid!,
          caption: m.text,
          fileName: m.mediaPath != null ? null : m.fileName,
          voice: m.fileName == 'voice.wav',
          voiceDisguised: m.voiceDisguised,
          replyTo: m.replyTo,
          burnSeconds: m.burnSecs,
          // when it was written, not now
          writtenAt: m.when.millisecondsSinceEpoch,
          album: m.album,
        ),
      );
      return;
    }
    final uid = m.msgUid!;
    var ok = false;
    int? burnAt;
    try {
      ok = await _watch.owning(
        uid,
        () => appState.sendToGroup(
          widget.groupId,
          m.text,
          msgUid: m.msgUid,
          replyTo: m.replyTo,
          burnSeconds: m.burnSecs,
          preview: m.preview,
          writtenAt: m.when.millisecondsSinceEpoch,
        ),
      );
      burnAt = await _burnFrom(uid, ok);
    } catch (e) {
      dlog('group retry failed: $e');
    } finally {
      if (mounted) {
        final live = _liveMsg(uid) ?? m;
        setState(() {
          live.sending = false;
          live.failed = !ok;
          if (burnAt != null) live.burnAt = burnAt;
        });
        if (!_messages.any((x) => x.sending)) _tryAppendNew();
      }
    }
  }

  // its own choice, else on in a burner room, else the default. read again
  // when the group's page closes, where it is switched
  Future<void> _loadDisguise() async {
    final g = await session.getGroup(widget.groupId);
    final d = await appState.loadChatDisguise(
      widget.groupId,
      group: true,
      burner: g?['room_pub'] != null,
    );
    if (mounted) setState(() => _disguise = d);
  }

  void _onVoice(VoiceTake take) {
    // the chat went while the note was made: the raw voice goes, unsent
    if (!mounted) {
      take.making?.cancel();
      unawaited(dropTake(take.path, take.masked));
      return;
    }
    // the last one left while it recorded: the raw voice goes, unsent
    if (_nobodyToRead()) {
      take.making?.cancel();
      unawaited(dropTake(take.path, take.masked));
      return;
    }
    _sendGroupVoice(take);
  }

  Future<void> _showStickers() async {
    if (_nobodyToRead()) return;
    final pick = await showStickerSheet(
      context,
      container: session.container,
      gifs: appGifTabs(),
    );
    // the sheet hands focus back to the composer; the keyboard stays down
    FocusManager.instance.primaryFocus?.unfocus();
    if (pick == null || !mounted) return;
    // a found gif goes the way a gif from the phone goes: inside the
    // message, cleaned, never fetched again by anyone
    if (pick is GifPick) return _sendGroupImage(pick.bytes, '');
    if (pick is PhoneGifPick) return _pickGroupGif();
    if (pick is! StickerPick) return;
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
      ok = await _watch.owning(
        uid,
        () => appState.sendToGroup(
          widget.groupId,
          s.emoji,
          msgUid: uid,
          replyTo: replyToUid,
          burnSeconds: burnSeconds,
          sticker: w.value,
        ),
      );
    } catch (e) {
      dlog('group sticker send failed: $e');
    }
    final burnAt = await _burnFrom(uid, ok);
    if (!mounted) return;
    final live = _liveMsg(uid) ?? optimistic;
    setState(() {
      live.sending = false;
      live.failed = !ok;
      if (burnAt != null) live.burnAt = burnAt;
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
    if (_nobodyToRead()) return;
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
      ok = await _watch.owning(
        uid,
        () => appState.sendToGroup(
          widget.groupId,
          d.question,
          msgUid: uid,
          poll: poll,
          burnSeconds: burnSeconds,
        ),
      );
    } catch (e) {
      dlog('group poll send failed: $e');
    }
    final burnAt = await _burnFrom(uid, ok);
    if (!mounted) return;
    final live = _liveMsg(uid) ?? optimistic;
    setState(() {
      live.sending = false;
      live.failed = !ok;
      if (burnAt != null) live.burnAt = burnAt;
    });
    if (!_messages.any((x) => x.sending)) _tryAppendNew();
  }

  // a video from the gallery, same reasoning as the one-to-one chat
  Future<void> _pickGroupVideo() async {
    final x = await lockState.hold(
      () => ImagePicker().pickVideo(source: ImageSource.gallery),
    );
    if (x == null) return;
    try {
      // a screen gone meanwhile sends nothing, and the copy still goes
      if (!mounted) return;
      // the send preview first, as every pick has it; named as a made
      // video on its way (madeVideoName), never as it was picked
      await sendGalleryPicks(
        [x],
        videos: true,
        pickMore: () => lockState.hold(pickGallery),
        preview: _preview,
        send: _sendPicked,
      );
    } finally {
      await shredPickedImages([x]);
    }
  }

  Future<void> _pickGroupMultiple() async {
    // whole, each in a folder of its own: see readPickedPhotos. videos come
    // too where android has its photo picker
    final picked = await lockState.hold(pickGallery);
    if (picked.isEmpty) return;
    // one or several: the preview first, and nothing goes without its send
    await sendGalleryPicks(
      picked,
      pickMore: () => lockState.hold(pickGallery),
      preview: _preview,
      send: _sendPicked,
    );
  }

  // the send preview: null when the person backed out. a group's items
  // carry no protect mark. what it was handed goes at once when it closes
  // with nothing sent, a lock or a session switch with it
  Future<MediaSendResult?> _preview(
    List<PickedMedia> items, [
    Future<List<PickedMedia>> Function()? more,
  ]) async {
    if (!mounted) return null;
    return Navigator.of(context).push<MediaSendResult?>(
      haloRoute<MediaSendResult?>(
        MediaSendScreen(
          items: items,
          addMore: more,
          onGone: (videos) => unawaited(shredPickedImages(videos)),
        ),
      ),
    );
  }

  // what the send preview gave back. its bubbles show at once, waiting,
  // as albums of up to kAlbumMax with the caption on the first; then each
  // item is made ready in its order. one that will not go is taken out and
  // the rest counted again before anything is saved or sent
  Future<void> _sendPicked(MediaSendResult r) async {
    if (r.items.isEmpty || !mounted) return;
    final plan = albumPlan(r.items, r.caption);
    final reply = _takeReply();
    final now = DateTime.now().millisecondsSinceEpoch;
    final burn = _ghost ? _burnSeconds : null;
    final waiting = [
      for (final (k, go) in plan.indexed)
        _GMsg(
            sender: appState.sessionId,
            direction: 'out',
            text: go.caption,
            // a millisecond apart, so they keep their order
            when: DateTime.fromMillisecondsSinceEpoch(now + k),
            msgUid: newMsgUid(),
            replyTo: k == 0 ? reply : null,
            sending: true,
            burnSecs: burn,
            album: go.album,
          )
          ..preparing = true
          ..fresh = true,
    ];
    setState(() {
      _messages.addAll(waiting);
      _normaliseMessages();
    });
    _scrollToEnd();
    final ready = <(_GMsg, _GReady)>[];
    for (final (k, go) in plan.indexed) {
      if (!mounted) break;
      final m = waiting[k];
      final v = go.item.video;
      final one = v != null
          ? await _readyGroupFile(v.path, madeVideoName(v.name), uid: m.msgUid)
          : await _readyGroupPhoto(go.item.photo!, uid: m.msgUid);
      if (one != null) ready.add((m, one));
    }
    if (!mounted) {
      for (final (_, x) in ready) {
        await shredFile(x.path);
      }
      return;
    }
    // the answer goes with the first that is ready
    if (ready.isNotEmpty && reply != null) ready.first.$1.replyTo = reply;
    if (ready.length < waiting.length) {
      // what would not go leaves, and the rest are counted again
      final again = albumPlan([for (final (m, _) in ready) m], r.caption);
      setState(() {
        _messages.removeWhere(
          (m) => waiting.contains(m) && !again.any((g) => identical(g.item, m)),
        );
        for (final g in again) {
          g.item
            ..album = g.album
            ..text = g.caption;
        }
      });
    }
    for (final (k, (m, x)) in ready.indexed) {
      // the chat went part way: what was made ready and not sent goes
      if (!mounted) {
        for (final (_, rest) in ready.skip(k)) {
          await shredFile(rest.path);
        }
        return;
      }
      await _sendGroupReady(x, m.text, shown: m);
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
    } on LockDropped {
      return;
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
    // raw bytes through the image lane: re-encoding kills the animation.
    await _sendGroupImage(clean, '');
  }

  Future<void> _sendGroupImage(Uint8List raw, String caption) async {
    final ready = await _readyGroupPhoto(raw);
    if (ready != null) await _sendGroupReady(ready, caption);
  }

  // a photo cleaned of what the gallery's re-encode copied across and
  // written under its own uid: nothing shows or leaves yet
  Future<_GReady?> _readyGroupPhoto(Uint8List raw, {String? uid}) async {
    final bytes = await photoToSendOffUi(raw);
    if (bytes == null) {
      if (mounted) showHaloToast(context, l10n.cameraCouldNotStripThat);
      return null;
    }
    // ended while it was picked: nothing is written
    if (!await _stillHere()) return null;
    final made = uid ?? newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.groupId);
    // a png, gif, webp or heic keeps its own kind, and its name says so
    final f = File('${mediaDir.path}/$made.${pictureExt(bytes)}');
    await f.writeAsBytes(bytes);
    return _GReady(made, f.path);
  }

  // a ready photo or file shown, kept and sent
  Future<void> _sendGroupReady(
    _GReady ready,
    String caption, {
    AlbumTag? album,
    // its bubble, shown on send while it was made ready
    _GMsg? shown,
  }) async {
    final isFile = ready.fileName != null;
    final uid = ready.uid;
    final burn = shown == null
        ? (_ghost ? _burnSeconds : null)
        : shown.burnSecs;
    // the message being answered: taken now, or by the first bubble shown
    final reply = shown == null ? _takeReply() : shown.replyTo;
    final m =
        shown ??
        (_GMsg(
          sender: appState.sessionId,
          direction: 'out',
          text: caption,
          when: DateTime.now(),
          msgUid: uid,
          replyTo: reply,
          sending: true,
          burnSecs: burn,
          album: album,
        )..fresh = true);
    album = m.album;
    caption = m.text;
    setState(() {
      m
        ..mediaPath = isFile ? null : ready.path
        ..filePath = isFile ? ready.path : null
        ..fileName = ready.fileName
        ..preparing = false;
      if (!_messages.contains(m)) _messages.add(m);
      _normaliseMessages();
    });
    if (shown == null) _scrollToEnd();
    HapticFeedback.lightImpact();
    final kept = await keepOwnGroupFile(
      ready.path,
      () => session.saveInGroup(
        appState.sessionId,
        caption,
        groupId: widget.groupId,
        msgUid: uid,
        replyTo: reply,
        mediaPath: m.mediaPath,
        filePath: m.filePath,
        fileName: m.fileName,
        burnSecs: burn,
        album: album,
        // the time its bubble shows, kept by a resend after a restart
        writtenAt: m.when.millisecondsSinceEpoch,
      ),
    );
    if (!kept) return _unkept(m);
    unawaited(
      _sendGroupMedia(
        m,
        () => appState.sendMediaToGroup(
          widget.groupId,
          ready.path,
          msgUid: uid,
          caption: caption,
          replyTo: reply,
          fileName: ready.fileName,
          burnSeconds: burn,
          album: album,
        ),
      ),
    );
  }

  // the message being answered goes with the next file, and its bar with it
  String? _takeReply() {
    final r = _replyTo?.msgUid;
    if (_replyTo != null && mounted) setState(() => _replyTo = null);
    return r;
  }

  Future<void> _sendGroupVoice(VoiceTake take) async {
    final srcPath = take.path;
    final disguise = take.disguise;
    final making = take.making;
    if (!await File(srcPath).exists()) {
      making?.cancel();
      return dropTake(srcPath, take.masked);
    }
    final group = widget.groupId;
    // where the group is as the note leaves: one hidden or brought back
    // while it is made keeps none of it
    final home = session.chatKey(group);
    // said wherever the person is once the lock is down, and only where
    // the group is still there to see
    void say(String line) => showHaloToastAnywhere(
      line,
      still: () => session.chatKey(group) == home,
    );
    final uid = newMsgUid();
    final burn = _ghost ? _burnSeconds : null;
    // sent is sent: leaving the chat does not stop it. the lock does, and
    // nothing of it outlives the lock
    var locked = false;
    final unguard = lockGuard.closeOnLock(() {
      locked = true;
      making?.cancel();
    });
    _GMsg? pending;
    String? reply;
    void unpend() {
      final m = pending;
      if (m == null || !mounted) return;
      setState(() => _messages.remove(m));
    }

    // the lock stopped it: its bubble goes, and once the lock is down the
    // person hears it did not go
    Future<void> lockedOut(String? masked, {String? placed}) async {
      unpend();
      if (placed != null) await shredFile(placed);
      await dropTake(srcPath, masked);
      say(l10n.voiceLockedNotSent);
    }

    _GMsg bubble() => _GMsg(
      sender: appState.sessionId,
      direction: 'out',
      text: '',
      when: DateTime.now(),
      msgUid: uid,
      replyTo: reply,
      sending: true,
      fileName: 'voice.wav',
      voiceDisguised: disguise,
      burnSecs: burn,
    )..fresh = true;

    try {
      var masked = take.masked;
      if (making != null) {
        // its bubble shows at once, waiting for its disguise
        reply = _takeReply();
        final m = pending = bubble()..making = making.progress;
        if (mounted) {
          setState(() {
            _messages.add(m);
            _normaliseMessages();
          });
          _scrollToEnd();
        }
        masked = await making.file;
        if (locked) return lockedOut(masked);
      }
      // not made yet: made now, if the disk has room for it
      if (disguise && masked == null && !await roomForVoice(take.ms)) {
        unpend();
        await dropTake(srcPath, null);
        say(l10n.voiceNoRoomNotSent);
        return;
      }
      final File dest;
      try {
        if (session.chatKey(group) != home) throw StateError('moved');
        final mediaDir = await session.mediaDirOf(group);
        dest = File('${mediaDir.path}/vn_$uid.wav');
      } catch (e) {
        dlog('group voice: no media folder (${e.runtimeType})');
        unpend();
        await dropTake(srcPath, masked);
        return;
      }
      // the recorder's file is the voice before any disguise: it is the copy
      // kept with the message, or it goes once the disguise is there
      final placed = await placeVoice(
        srcPath,
        dest.path,
        disguise: disguise,
        masked: masked,
      );
      // never sent as recorded when it was to go disguised
      if (!placed) {
        unpend();
        if (locked) {
          say(l10n.voiceLockedNotSent);
        } else if (disguise) {
          final room = await roomForVoice(take.ms);
          say(room ? l10n.voiceNotDisguised : l10n.voiceNoRoomNotSent);
        }
        return;
      }
      if (locked) return lockedOut(null, placed: dest.path);
      // ended while it was recorded: nothing is kept
      if (!await _stillHere()) {
        unpend();
        return shredFile(dest.path);
      }
      if (pending == null) reply = _takeReply();
      final m = pending ?? bubble();
      m
        ..filePath = dest.path
        ..making = null;
      if (mounted) {
        setState(() {
          if (!_messages.contains(m)) _messages.add(m);
          _normaliseMessages();
        });
        _scrollToEnd();
        HapticFeedback.lightImpact();
      }
      // the bubble, the row and the wire all say when it was begun
      final writtenAt = m.when.millisecondsSinceEpoch;
      // from here a lock takes it off the screen as one still being made
      pending = m;
      final kept = await keepOwnGroupFile(
        dest.path,
        () => appState.keepOwn(group, () async {
          // a lock while it waited for a move: nothing is written
          if (locked) return false;
          return session.saveInGroup(
            appState.sessionId,
            '',
            groupId: group,
            msgUid: uid,
            replyTo: reply,
            filePath: dest.path,
            fileName: 'voice.wav',
            voiceDisguised: disguise,
            burnSecs: burn,
            writtenAt: writtenAt,
            home: home,
          );
        }),
      );
      // the file is shredded already
      if (!kept && locked) return lockedOut(null);
      if (!kept) {
        say(l10n.voiceNotSent);
        return _unkept(m);
      }
      // left while it was made: the screen showing the group now hears of it
      if (!mounted) appState.chatChanged('group:$group');
      unawaited(
        _sendGroupMedia(
          m,
          () => appState.sendMediaToGroup(
            group,
            dest.path,
            msgUid: uid,
            replyTo: reply,
            fileName: 'voice.wav',
            voice: true,
            voiceDisguised: disguise,
            burnSeconds: burn,
            writtenAt: writtenAt,
          ),
        ),
      );
    } finally {
      unguard();
    }
  }

  // the picker's own copy is copied into the media folder; no byte array
  // crosses the plugin channel. see the 1:1 chat for why.
  Future<void> _pickGroupFile() async {
    final PlatformFile? res;
    try {
      // every kind of file: apps, archives, anything the phone holds
      res = await lockState.hold(() => FilePicker.pickFile(type: FileType.any));
    } on LockDropped {
      // the session it was picked in is gone: nothing to say
      return;
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

  // the in-app camera: a stripped photo or a clip goes through the send
  // preview; the clip's private copy is shredded once it is done with
  Future<void> _openGroupCamera() async {
    if (_nobodyToRead()) return;
    final r = await Navigator.of(
      context,
    ).push<CaptureResult>(haloRoute<CaptureResult>(const CameraScreen()));
    if (r == null || !mounted) return;
    if (r.photo != null) {
      final sent = await _preview([PickedMedia.photo(r.photo!)]);
      if (sent != null) await _sendPicked(sent);
      return;
    }
    final path = r.videoPath;
    if (path == null) return;
    try {
      if (!mounted) return;
      // the preview too, as every pick has it
      final sent = await _preview([
        PickedMedia.video(XFile(path, name: madeVideoName())),
      ]);
      if (sent != null) await _sendPicked(sent);
    } finally {
      await shredCapture(path);
    }
  }

  Future<void> _sendGroupFileFrom(String src, String picked) async {
    final ready = await _readyGroupFile(src, picked);
    if (ready != null) await _sendGroupReady(ready, '');
  }

  // a file checked, copied into the media folder under its own uid and
  // cleaned there: nothing shows or leaves yet. null when it will not go,
  // and the toast has said why
  Future<_GReady?> _readyGroupFile(
    String src,
    String picked, {
    // its bubble's, when it shows before it is ready
    String? uid,
  }) async {
    final name = sentFileName(picked);
    final int size;
    try {
      size = await File(src).length();
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.groupChatCouldNotReadThat);
      return null;
    }
    // an empty file would read as sent with nothing gone
    if (size == 0) {
      if (mounted) showHaloToast(context, l10n.groupChatCouldNotReadThat);
      return null;
    }
    if (!fileFits(size)) {
      if (mounted) showHaloToast(context, fileTooBigLine(size));
      return null;
    }
    // a picture the lane cannot clean goes only once the sender has read
    // that its details go with it
    final raw = (await readFileFactsFresh(src, name))?.raw ?? false;
    if (raw && mounted) {
      final ok = await showConfirmSheet(
        context,
        title: l10n.fileRawPictureTitle,
        figure: humanFileSize(size),
        line: l10n.fileRawPictureLine,
        yes: l10n.chatSendIt,
        keep: l10n.commonCancel,
        rose: false,
      );
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
      if (!ok) return null;
    }
    // ended while it was picked: nothing is copied
    if (!await _stillHere()) return null;
    final made = uid ?? newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.groupId);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${mediaDir.path}/f_${made}_$safe');
    await File(src).copy(dest.path);
    // a gallery video carries what a gallery photo does: where, on what,
    // and when. stripped in place on our own copy; a file that cannot be
    // walked is not sent, the same as a jpeg that cannot be. one renamed is
    // told by its bytes
    // a raw picture is not one, whatever it is called: the video cleaner
    // would break it without cleaning it
    if (!raw &&
        (videoNameNeedsStrip(name) || await bytesSayIsoVideo(dest.path))) {
      final ok = await stripMp4Metadata(dest.path);
      final left = ok == null ? null : await mp4MetadataCount(dest.path);
      if (ok == null || left != 0) {
        await shredFile(dest.path);
        if (mounted) {
          showHaloToast(context, l10n.groupChatCouldNotCleanThatVideo);
        }
        return null;
      }
    }
    // a picture sent as a file is cleaned like one sent as a photo. it is
    // told by its bytes, not its name: jpeg, png, webp, heic, avif. one the
    // app cannot read through is not sent; the photo button re-encodes and
    // will take it.
    else if (await stripPictureFileOffUi(dest.path) == null) {
      await shredFile(dest.path);
      if (mounted) {
        showHaloToast(context, l10n.groupChatCouldNotCleanThatPictureSend);
      }
      return null;
    }
    return _GReady(made, dest.path, fileName: name);
  }

  // the group is still here to send into. one gone closes the screen
  Future<bool> _stillHere() async {
    if (await session.groupExists(widget.groupId)) return true;
    if (mounted) _load();
    return false;
  }

  // a row of ours that was not kept: off the screen, and the screen reads
  // the group again, closing when it is gone
  void _unkept(_GMsg m) {
    if (!mounted) return;
    setState(() => _messages.remove(m));
    _load();
  }

  String? _badgeFor(String id) {
    for (final c in appState.contacts) {
      if (c.haloId == id) return c.supporterBadge;
    }
    return null;
  }

  // a timed message's clock, started by the send that went. null for one
  // that did not go or has no timer
  Future<int?> _burnFrom(String uid, bool ok) async {
    if (!ok) return null;
    try {
      return await session.lightBurn(uid);
    } catch (e) {
      dlog('group burn: $e');
      return null;
    }
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
    // no send behind the strip: the file may be across, so only the strip goes
    if (!mediaInflight.contains(uid)) {
      mediaProgressEnd(uid);
      return;
    }
    cancelMediaSend(uid);
    mediaProgressEnd(uid);
    if (mounted) setState(() => m.removing = true);
    await Future.delayed(kLeaveGone);
    await session.deleteMessage(uid);
    if (mounted) setState(() => _messages.remove(m));
    // the unsend goes to each member once the send has let go
    unawaited(appState.unsendInGroup(widget.groupId, uid));
  }

  final _watch = GroupSendWatch();

  // a photo, voice note or file of this screen's, settled by it once done
  Future<void> _sendGroupMedia(_GMsg m, Future<String> Function() send) =>
      _watch.owning(m.msgUid!, () async {
        String r;
        try {
          r = await send();
        } catch (e) {
          r = 'error: $e';
        }
        await _finishGroupMediaSend(m, r);
      });

  void _placeLoadedSend(_GMsg m) {
    final uid = m.msgUid;
    if (uid == null || m.direction != 'out') return;
    final seen = _watch.loaded(
      uid,
      sending: m.sending,
      dead: _deadSend(m),
      inflight: mediaInflight.contains(uid),
    );
    if (seen == SendSeen.failed) {
      m.sending = false;
      m.failed = true;
    }
  }

  bool _settling = false;
  bool _settleAgain = false;
  Future<void> _settleOthersSends() async {
    if (_settling) {
      _settleAgain = true;
      return;
    }
    _settling = true;
    var changed = false;
    try {
      for (final m in List<_GMsg>.of(_messages)) {
        final uid = m.msgUid;
        if (uid == null || m.direction != 'out') continue;
        final check = _watch.needsCheck(
          uid,
          sending: m.sending,
          failed: m.failed,
          inflight: mediaInflight.contains(uid),
        );
        if (!check) continue;
        final s = await session.sendState(uid);
        if (!mounted) return;
        final live = _liveMsg(uid);
        if (live == null) continue;
        final seen = _watch.verdict(
          uid,
          sending: live.sending,
          sent: s.sent,
          dead: _deadSend(live),
          inflight: mediaInflight.contains(uid),
        );
        if (seen == SendSeen.keep) continue;
        final failed = seen == SendSeen.failed;
        if (live.sending || live.failed != failed) changed = true;
        live.sending = false;
        live.failed = failed;
      }
    } finally {
      _settling = false;
    }
    if (_settleAgain && mounted) {
      _settleAgain = false;
      unawaited(_settleOthersSends());
    }
    if (!changed || !mounted) return;
    setState(() {});
    if (!_messages.any((x) => x.sending)) _tryAppendNew();
  }

  Future<void> _finishGroupMediaSend(_GMsg m, String result) async {
    // a stopped send has no row left to finish
    if (result == 'cancelled') return;
    // another sender already has this one. its verdict is read off the row
    // once that send has ended
    if (result == 'busy') {
      if (m.msgUid != null) _watch.busy(m.msgUid!);
      return;
    }
    if (m.msgUid != null) mediaProgressEnd(m.msgUid!);
    final ok = result == 'ok';
    final uid = m.msgUid;
    if (ok && uid != null) await session.markSent(uid);
    int? ba;
    if (ok && m.burnSecs != null && uid != null) {
      ba = DateTime.now().millisecondsSinceEpoch + m.burnSecs! * 1000;
      // an album's item takes the clock the album already has
      ba = await session.setMsgBurnAt(uid, ba);
    }
    if (!mounted) {
      // left and reopened while it uploaded: tell the screen showing it now
      appState.chatChanged('group:${widget.groupId}');
      return;
    }
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

  // a one-shot amber ring on a bubble when a reaction lands on it
  void _flashReaction(_GMsg msg) {
    HapticFeedback.selectionClick();
    if (msg.msgUid == null) return;
    setState(() => _rippleUid = msg.msgUid);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_rippleUid == msg.msgUid) setState(() => _rippleUid = null);
    });
  }

  Future<void> _toggleReaction(_GMsg target, String emoji) async {
    if (target.msgUid == null) return;
    final current = target.reactions[''];
    final isUnreact = current == emoji;
    final newEmoji = isUnreact ? '' : emoji;
    // land the chip now, not after the db write and the send come back
    // through a full reload. '' is our own reaction slot.
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 14,
                      color: HaloColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.groupChatBurnTimer,
                        style: HaloType.serif(
                          size: 16,
                          italic: true,
                          color: HaloColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.groupChatNewMessagesDisappearOnceRead,
                  style: HaloType.mono(size: 11, color: HaloColors.text2),
                ),
                const SizedBox(height: 12),
                for (final opt in options)
                  InkWell(
                    // picking a time is asking for timed messages
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _burnSeconds = opt.$1;
                        _ghost = true;
                      });
                      appState.saveGhostPref(true, opt.$1);
                      Navigator.pop(c);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              opt.$2,
                              style: HaloType.sans(
                                size: 14,
                                color: opt.$1 == _burnSeconds
                                    ? HaloColors.amberText
                                    : HaloColors.text,
                              ),
                            ),
                          ),
                          if (opt.$1 == _burnSeconds)
                            Icon(
                              Icons.check_rounded,
                              color: HaloColors.amber,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEmojiPickerAt(
    BuildContext bubbleCtx,
    _GMsg target, {
    // an album: [target] stands for all of it, [tile] is the one held
    AlbumRun<_GMsg>? album,
    int? tile,
    bool showSender = false,
    String? quotedText,
    String? quotedAuthor,
    StickerWire? quotedSticker,
  }) async {
    for (final x in album?.present ?? [target]) {
      _touched(x);
    }
    final anchor = album?.anchor ?? target;
    final reactOn = album == null ? target : _reactOn(album);
    final held = album != null && tile != null && tile < album.drawn.length
        ? album.drawn[tile]
        : null;
    // drop composer focus before anything opens: a route captures the
    // focused node at open and restores it at close, which would pull the
    // keyboard up after unsend, edit or forward
    await keyboardDown(context);
    if (target.msgUid == null ||
        !mounted ||
        !bubbleCtx.mounted ||
        lockGuard.isLocked() ||
        ModalRoute.isCurrentOf(context) == false) {
      return;
    }
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
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    // the card's height from how many rows it has
    final words = target.text.isNotEmpty && target.sticker == null;
    final rows =
        2 +
        (words ? 2 : 0) +
        (target.filePath != null && target.fileName != 'voice.wav' ? 1 : 0) +
        (isOut ? (words ? 2 : 1) : 0);
    final rowH = 20 + math.max(17.0, mq.textScaler.scale(13.5) * 1.3);
    final menuH = rows * rowH + 16;
    // reactions above the bubble and actions under it, as in a 1:1 chat.
    // where there is no room for that, both go on the side that has it
    const pickerH = 58.0;
    final safeTop = mq.padding.top + 8;
    // above a keyboard that would not go, too
    final safeBottom =
        screenH - math.max(mq.padding.bottom, mq.viewInsets.bottom) - 12;
    final bubbleBottom = pos.dy + size.height;
    final aboveTop = pos.dy - pickerH - 10;
    double reactTop;
    double? menuTop;
    double? menuBottom;
    if (aboveTop >= safeTop && safeBottom - bubbleBottom >= menuH + 10) {
      reactTop = aboveTop;
      menuTop = bubbleBottom + 10;
    } else if (aboveTop >= safeTop) {
      reactTop = aboveTop;
      menuBottom = screenH - (reactTop - 8);
    } else {
      reactTop = bubbleBottom + 10;
      menuTop = reactTop + pickerH + 8;
    }
    // a bubble taller than the room either side: the card keeps to the
    // bottom of the screen and the reactions sit on it, over the bubble
    final menuOffTop =
        menuBottom != null && screenH - menuBottom - menuH < safeTop;
    if (menuOffTop || (menuTop != null && menuTop + menuH > safeBottom)) {
      menuBottom = null;
      menuTop = math.max(safeTop + pickerH + 8, safeBottom - menuH);
      reactTop = math.max(safeTop, math.min(reactTop, menuTop - pickerH - 8));
    }
    final still = motionStill(context);
    final overlay = Overlay.of(context);
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _liftedUid = target.msgUid);
    late OverlayEntry entry;
    VoidCallback? unguard;
    // not entry.mounted: an entry closed before its first frame is not
    // mounted yet and has to go all the same
    var gone = false;
    // on its way out: the dim and the menu fade, the lifted copy settles
    final closing = ValueNotifier(false);
    late final void Function({bool now}) shut;
    void close() {
      if (gone) return;
      gone = true;
      unguard?.call();
      entry.remove();
      menuRemoved(shut);
    }

    void finish() {
      close();
      if (menuMayTouch) setState(() => _liftedUid = null);
    }

    void dismiss() {
      if (gone || closing.value) return;
      if (still) return finish();
      closing.value = true;
      menuFolding(shut);
      // the row comes back once the copy above it has settled on it
      Future.delayed(const Duration(milliseconds: 170), finish);
    }

    Widget fading(Widget child) => ValueListenableBuilder<bool>(
      valueListenable: closing,
      child: child,
      builder: (_, out, child) => AnimatedOpacity(
        opacity: out ? 0 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeIn,
        child: child,
      ),
    );

    entry = OverlayEntry(
      builder: (_) {
        return ValueListenableBuilder<bool>(
          valueListenable: closing,
          builder: (context, out, _) => IgnorePointer(
            ignoring: out,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: dismiss,
                    child: fading(const MenuBackdrop()),
                  ),
                ),
                // the position is from the left edge, in either direction
                Positioned(
                  left: rowPos.dx,
                  top: rowPos.dy,
                  width: rowW,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: still || out ? 0 : 1),
                      duration: out
                          ? const Duration(milliseconds: 160)
                          : kHouseTime,
                      curve: out ? Curves.easeOut : kHouseCurve,
                      child: Material(
                        type: MaterialType.transparency,
                        child: _GroupBubble(
                          m: target,
                          album: album,
                          showSender: showSender,
                          faceOf: _faceOf,
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
                  key: const ValueKey('group-menu-reactions'),
                  start: isOut ? null : 12,
                  end: isOut ? 12 : null,
                  top: reactTop,
                  child: fading(
                    MenuPop(
                      fromRight: isOut,
                      child: ReactionPicker(
                        replyLabel: l10n.groupChatReply,
                        emojis: const ['❤️', '👍', '😂', '😮', '😢', '🔥'],
                        selected: target.reactions[''],
                        onPick: (e) {
                          dismiss();
                          final added = reactOn.reactions[''] != e;
                          _toggleReaction(reactOn, e);
                          if (added) _flashReaction(reactOn);
                        },
                        onReply: () {
                          dismiss();
                          setState(() => _replyTo = anchor);
                        },
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  key: const ValueKey('group-menu-actions'),
                  start: isOut ? null : 12,
                  end: isOut ? 12 : null,
                  top: menuTop,
                  bottom: menuBottom,
                  child: fading(
                    MenuPop(
                      fromRight: isOut,
                      child: Material(
                        color: Colors.transparent,
                        child: _menuCard(
                          target,
                          isOut,
                          dismiss,
                          album: album,
                          held: held,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    shut = ({bool now = false}) => now ? finish() : dismiss();
    menuOpened(shut);
    // the lock closes it at once, with what it shows
    unguard = lockGuard.closeOnLock(finish);
  }

  // someone else's, in a room, which always blocks: not copied,
  // forwarded, shared, saved or opened elsewhere (shotsKeeps)
  bool _keeps(_GMsg m) =>
      shotsKeeps(blocking: _isRoom, mine: m.direction == 'out');

  // what can be done to one message, under it while the menu is open
  Widget _menuCard(
    _GMsg target,
    bool isOut,
    VoidCallback dismiss, {
    // an album's pin goes on its first item, a save on the one held
    AlbumRun<_GMsg>? album,
    _GMsg? held,
  }) {
    final kept = _keeps(target);
    final words = target.text.isNotEmpty && target.sticker == null && !kept;
    final anchor = album?.anchor ?? target;
    final saveOn = held ?? anchor;
    final shareOn = album == null ? target : held;
    return MessageMenuCard(
      note: kept ? l10n.roomShotsMenuNote : null,
      actions: [
        MenuAction(
          icon: anchor.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: anchor.pinned ? l10n.groupChatUnpin : l10n.groupChatPin,
          onTap: () {
            dismiss();
            _togglePinGroup(anchor);
          },
        ),
        MenuAction(
          icon: saveOn.saved ? Icons.bookmark : Icons.bookmark_outline,
          label: saveOn.saved ? l10n.groupChatUnsave : l10n.commonSave,
          tint: saveOn.saved ? HaloColors.amber : null,
          // one saved before stays, and can be let go
          onTap: kept && !saveOn.saved
              ? null
              : () {
                  dismiss();
                  _toggleSavedGroup(saveOn);
                },
        ),
        // a sticker is not copied, forwarded or edited
        MenuAction(
          icon: Icons.copy_rounded,
          label: l10n.commonCopy,
          onTap: !words
              ? null
              : () {
                  dismiss();
                  Clipboard.setData(ClipboardData(text: target.text));
                  showHaloToast(context, l10n.commonCopied);
                },
        ),
        MenuAction(
          icon: Icons.forward_rounded,
          label: l10n.groupChatForward,
          onTap:
              kept ||
                  !canForward(
                    text: target.text,
                    mediaPath: target.mediaPath,
                    filePath: target.filePath,
                    sticker: target.sticker != null,
                  )
              ? null
              : () {
                  dismiss();
                  _forwardGroupMessage(target);
                },
        ),
        // a tap opens a file, so sharing it lives here. an app installer is
        // only ever saved
        MenuAction(
          icon: Icons.ios_share_rounded,
          label: l10n.commonShare,
          onTap:
              (kept ||
                  shareOn == null ||
                  shareOn.filePath == null ||
                  shareOn.fileName == 'voice.wav' ||
                  knownInstaller(shareOn.filePath!, shareOn.fileName))
              ? null
              : () {
                  dismiss();
                  lockState.hold(
                    () =>
                        shareFileOut(shareOn.filePath!, name: shareOn.fileName),
                  );
                },
        ),
        MenuAction(
          icon: Icons.download_rounded,
          label: l10n.fileSaveToDevice,
          // in an album, the one held. nothing a room keeps leaves it
          onTap:
              (kept ||
                  shareOn == null ||
                  shareOn.filePath == null ||
                  shareOn.fileName == null ||
                  shareOn.fileName == 'voice.wav')
              ? null
              : () {
                  dismiss();
                  saveReceivedFile(
                    context,
                    shareOn.filePath!,
                    shareOn.fileName,
                  );
                },
        ),
        if (isOut) ...[
          MenuAction(
            icon: Icons.edit_outlined,
            label: l10n.commonEdit,
            tint: HaloColors.amber,
            // an album's caption stays as it went
            onTap: words && album == null
                ? () {
                    dismiss();
                    _editGroupMessage(target);
                  }
                : null,
          ),
          MenuAction(
            icon: Icons.delete_outline,
            label: l10n.groupChatUnsend,
            danger: true,
            onTap: () {
              dismiss();
              if (album != null) {
                _unsendGroupAlbum(album);
              } else {
                _unsendGroupMessage(target);
              }
            },
          ),
        ],
      ],
    );
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
          // element swapped by a reload mid-settle, the next pass finds it again.
        }
        if (attempt < 4) _settleJump(attempt + 1);
      } else if (attempt < 10) {
        _settleJump(attempt + 1);
      }
    });
  }

  // rough-jump so the target gets built, then ensureVisible lands it. this
  // list is not reversed, unlike 1:1: older sits near offset 0.
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
    final rows = await _shownPins();
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
            when: DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
            text: (r['plaintext'] as String?) ?? '',
            imagePath: r['media_path'] as String?,
            fileName: r['file_name'] as String?,
            sticker: StickerWire.parse(r['sticker']),
          );
        }(),
    ];
  }

  // a timed message not read yet stays out of the pins, as it does out of
  // the photos: it shows in the thread, where reading it starts its clock
  Future<List<Map<String, Object?>>> _shownPins() async => [
    for (final r in await session.pinnedIn(groupId: widget.groupId))
      if (!burnWaitsRow(r)) r,
  ];

  int _pinCount = 0;
  Future<void> _refreshPinCount() async {
    final n = (await _shownPins()).length;
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
    final id = await pickWordsChat(
      context,
      title: l10n.groupChatForwardTo,
      empty: l10n.groupChatNoContactsToForward,
      // the developer chat, once it has started
      dev: devForwardTarget,
    );
    if (id == null || !mounted) return;
    final route = await wordsRoute(id, m.text);
    if (route == null || !mounted) return;
    Navigator.of(context).push(route);
  }

  // a page title only while the words still lead with its link: an edit
  // to another link leaves it behind
  static Map<String, String>? _linkPreview(_GMsg m) {
    final pv = m.preview;
    return pv != null && pv['url'] == m.url ? pv : null;
  }

  Future<void> _editGroupMessage(_GMsg m) async {
    if (m.msgUid == null) return;
    final result = await showGroupEditSheet(context, m.text);
    if (result == null) return;
    final newText = result.trim();
    if (newText.isEmpty || newText == m.text) return;
    setState(() {
      m.text = newText;
      m.edited = true;
    });
    await appState.editInGroup(widget.groupId, m.msgUid!, newText);
  }

  // an album taken back whole, ours only: each item's row and file go
  // here and each is unsent there, so a phone without albums drops them all.
  // one still going stops where it is
  Future<void> _unsendGroupAlbum(AlbumRun<_GMsg> run) async {
    final ms = [
      for (final x in run.present)
        if (x.direction == 'out' && x.msgUid != null) x,
    ];
    if (ms.isEmpty || !await _confirmUnsend(album: true)) return;
    for (final x in ms) {
      mediaProgressEnd(x.msgUid!);
    }
    if (mounted) {
      setState(() {
        for (final x in ms) {
          x.removing = true;
        }
      });
    }
    await Future.delayed(kLeaveGone);
    if (mounted) setState(() => _messages.removeWhere(ms.contains));
    // each stops a send still going, and goes from here and from them
    for (final x in ms) {
      await appState.unsendInGroup(widget.groupId, x.msgUid!);
    }
  }

  Future<void> _unsendGroupMessage(_GMsg m) async {
    if (m.msgUid == null) return;
    if (!await _confirmUnsend()) return;
    if (mounted) setState(() => m.removing = true);
    await Future.delayed(kLeaveGone);
    if (mounted) setState(() => _messages.remove(m));
    await appState.unsendInGroup(widget.groupId, m.msgUid!);
  }

  Future<bool> _confirmUnsend({bool album = false}) async {
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
                album ? l10n.albumUnsendTitle : l10n.groupChatUnsendMessage,
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
    return confirm == true;
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
    _catchUp();
  }

  // a screen pushed over this one closed: this is the one being read again
  @override
  void backOnTop() {
    if (lockGuard.isLocked()) {
      _underLock = true;
      return;
    }
    claimChat('group:${widget.groupId}');
    _markRead();
    _catchUp();
  }

  void _markRead() {
    _reads.look();
    session
        .clearGroupUnread(widget.groupId)
        .then((_) => appState.refreshGroups());
    unawaited(clearNotificationsFor('group:${widget.groupId}'));
  }

  // back in front: what changed while it was away is read from the
  // database, whatever the notes on the way said
  void _catchUp() {
    _seenRev = appState.chatRevOf('group:${widget.groupId}');
    if (_loading) {
      _reloadQueued = true;
    } else {
      _load();
    }
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
      // what rang while it was away has been seen now
      _markRead();
      _catchUp();
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
    _holdSecure(false);
    // a room still waiting never showed its line
    if (_isRoom && _roomBanner && !_waiting) {
      session.markRoomSeen(widget.groupId);
    }
  }

  // this screen's one hold on the shield, taken and let go once each
  bool _secureHeld = false;
  void _holdSecure(bool on) {
    if (on == _secureHeld) return;
    _secureHeld = on;
    appState.forceSecure(on);
  }

  @override
  void activate() {
    super.activate();
    // came back after a deactivate that was only a reparent
    _left = false;
    if (_isRoom) _holdSecure(true);
  }

  @override
  void dispose() {
    wallpaperRevision.removeListener(_loadWall);
    final open = _openGroups[widget.groupId]?..remove(this);
    if (open != null && open.isEmpty) _openGroups.remove(widget.groupId);
    for (final land in List.of(_flights)) {
      land();
    }
    _leaveRoomScreen();
    // persist the draft one more time on the way out.
    final draft = _msgCtrl.text;
    if (draft.trim().isEmpty) {
      draftPerGroup.remove(_memo);
    } else {
      draftPerGroup[_memo] = draft;
    }
    _lastRowPerGroup[_memo] = _messages.fold(
      0,
      (a, m) => m.rowid > a ? m.rowid : a,
    );
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
    groupOwedTick.removeListener(_reachMoved);
    _timers.dispose();
    _reads.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => menuBack(child: _page(context));

  Widget _page(BuildContext context) {
    // the albums as the thread stands now: a row of one is drawn by its lead
    _albums = _indexAlbums(_messages);
    // a message that just started counting down gets its burn on time
    _burn.poke();
    // and one that waits is read once this frame shows it
    _reads.look();
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // search and the head cross over both ways, as in a 1:1 chat
            FadeSwap(
              child: _searching
                  ? SearchHead(
                      key: const ValueKey('search'),
                      controller: _searchCtrl,
                      matchCount: _matches.length,
                      matchPos: _matches.isEmpty ? 0 : _matchPos + 1,
                      onChanged: _onQueryChanged,
                      onPrev: () => _gotoMatch(-1),
                      onNext: () => _gotoMatch(1),
                      onClose: _closeSearch,
                    )
                  : _Header(
                      key: const ValueKey('head'),
                      name: _groupName,
                      groupId: widget.groupId,
                      memberCount: _memberCount,
                      expiresAt: _roomExpiresAt,
                      joiningAt: _waiting ? _joiningAt : null,
                      ended: _end != null,
                      onBack: () => Navigator.of(context).pop(),
                      onSearch: _waiting || _end != null ? null : _openSearch,
                      pinnedCount: _end != null ? 0 : _pinCount,
                      onPinned: _waiting || _end != null
                          ? null
                          : _showGroupPinnedSheet,
                      onTapInfo: () async {
                        await Navigator.of(context).push(
                          haloRoute(GroupInfoScreen(groupId: widget.groupId)),
                        );
                        _load();
                        _loadDisguise();
                      },
                    ),
            ),
            // the room's first open: its line eases the thread down
            // instead of shoving it when the room is known
            EaseSize(
              child: _isRoom && _roomBanner && !_waiting
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        // every phone that opens a room holds the flag on
                        // it, since the first version with rooms
                        NoticeBanner(
                          glyph: NoticeGlyph.shield,
                          text: l10n.roomShotsBlocked,
                          color: HaloColors.violet,
                          margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                          delay: const Duration(milliseconds: 220),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            // its admin went with "this isn't them": the group is frozen here
            EaseSize(
              child: _adminGone && _end == null
                  ? _AdminGoneLine(onLeave: _leaveAdminGone)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            // a send that has waited on tor a minute gets a way out
            ReconnectValve(
              valve: torValve,
              waitingSince: _waitingSince(),
              private: appState.sendMode == 'private',
              quiet: sessionQuiet,
              online: appState.online,
              linkUp: appState.linkUp,
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            ),
            Divider(height: 0.5, color: HaloColors.line, thickness: 0.5),
            Expanded(
              // nothing until the first load lands, so an empty state
              // never flashes over a group that has messages. the words
              // cross over when the first person joins, when the room lets
              // this phone in, and into the first message
              child: FadeSwap(
                child: !_loaded
                    ? const SizedBox.shrink(key: ValueKey('wait'))
                    : _waiting || _messages.isEmpty || _end != null
                    ? _end != null
                          // its admin ended it: the line alone
                          ? EmptyChat(
                              key: const ValueKey('ended'),
                              icon: Icons.stop_circle_outlined,
                              tint: HaloColors.text2,
                              title: endedLine(_end!),
                            )
                          : _waiting
                          ? RoomJoinPanel(
                              key: const ValueKey('joining'),
                              name: _groupName,
                              joiningAt: _joiningAt!,
                              full: _full,
                              onTryAgain: _knockAgain,
                              onLeave: _leaveWaiting,
                            )
                          : EmptyChat(
                              key: ValueKey(_alone),
                              icon: Icons.groups_outlined,
                              tint: _isRoom ? HaloColors.violet : null,
                              // a group everyone else left is no new group
                              title: _alone
                                  ? _isRoom
                                        ? l10n.groupChatNobodyHereYet
                                        : l10n.groupChatNoMessagesYet
                                  : _isRoom
                                  ? l10n.chatSayHi
                                  : _isAdmin
                                  ? l10n.groupChatGroupCreatedSayHi
                                  : l10n.groupChatNoMessagesYet,
                              line: !_alone
                                  ? l10n.groupChatEveryoneHereReads
                                  : _isRoom
                                  ? l10n.groupChatShareTheRoomLink
                                  : l10n.groupChatNobodyToReadIt,
                            )
                    : AtmoScope(
                        key: const ValueKey('list'),
                        atmo: _wall.atmo,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ChatBackdrop(_wall, chat: _memo),
                            ),
                            NotificationListener<ScrollMetricsNotification>(
                              onNotification: _threadResized,
                              // the newest bubble's time rests above the line
                              child: EarlierRoom(
                                shown: _earlier.count > 0,
                                controller: _scrollCtrl,
                                reversed: false,
                                builder: (_, room) => ListView.builder(
                                  key: _listKey,
                                  controller: _scrollCtrl,
                                  padding: EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    12 + room,
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
                                            color: HaloColors.text2,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
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
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
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
                            // over the list, or the list takes its taps
                            _scrollDownButton(),
                            _earlierLine(),
                          ],
                        ),
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
              chatKey: _memo,
              onCancel: (uid) {
                final m = _liveMsg(uid);
                if (m != null) _stopGroupSending(m);
              },
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _msgCtrl,
              builder: (_, v, _) => PreviewStrip(
                url: !_isRoom && !sessionQuiet && _torUp
                    ? firstUrl(v.text)
                    : null,
                pending: _pendingPreview,
                busy: _previewBusy,
                onAdd: _addPreview,
                onDrop: () => setState(() => _pendingPreview = null),
              ),
            ),
            // no composer while the room has not let this phone in: it
            // grows in once the room does
            GrowSwap(
              alignment: Alignment.topCenter,
              child: _end != null
                  ? const GroupEndedBar(key: ValueKey('ended'))
                  : _waiting
                  ? const SizedBox(
                      key: ValueKey('no-composer'),
                      width: double.infinity,
                    )
                  : KeyedSubtree(
                      key: const ValueKey('composer'),
                      child: _Composer(
                        controller: _msgCtrl,
                        members: _mentionable,
                        sending: _sending,
                        ghost: _ghost,
                        burnSeconds: _burnSeconds,
                        disguise: _disguise,
                        onToggleGhost: () {
                          setState(() => _ghost = !_ghost);
                          appState.saveGhostPref(_ghost, _burnSeconds);
                        },
                        onLongPressGhost: _showBurnPicker,
                        onSend: _send,
                        onAttach: _showAttachSheet,
                        onStickers: _showStickers,
                        onCamera: _openGroupCamera,
                        onVoice: _onVoice,
                        mayRecord: () => !_nobodyToRead(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// in place of the composer once the group has ended: what it is.
/// its colours are read again on a theme switch, const as it is
class GroupEndedBar extends StatelessWidget {
  const GroupEndedBar({super.key});

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: themeRevision, builder: (c, _) => _bar());

  Widget _bar() {
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.stop_circle_outlined,
                size: 15,
                color: HaloColors.text2,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                l10n.groupEndedBar,
                textAlign: TextAlign.center,
                style: HaloType.serif(
                  size: 14,
                  italic: true,
                  color: HaloColors.text2,
                ),
              ),
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

// a photo or a file in the media folder under its uid, cleaned and ready
// to go: nothing is shown or sent yet
class _GReady {
  final String uid;
  final String path;
  final String? fileName;
  const _GReady(this.uid, this.path, {this.fileName});
}

class _GMsg with WordLinks {
  final String sender;
  final String senderName;
  final String direction;
  @override
  String text;
  // when it was written: where it shows and what it shows
  final DateTime when;
  // when it came, the row's sent_at: what its burn counts from
  int? cameAt;
  int get came => cameAt ?? when.millisecondsSinceEpoch;
  int? burnAt;
  // the burn window: ours is lit into burnAt when it goes, theirs when it
  // is first read
  int? burnSecs;
  // theirs, counting since before it was read (kBurnWaitMost)
  bool burnUnseen;
  final String? msgUid;
  // set again on a pick's first bubble that is ready when the one before
  // would not go
  String? replyTo;
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
  // a voice note sent while its disguise is made: how far it is
  ValueListenable<double?>? making;
  bool pinned;
  bool saved;
  bool edited;
  Map<String, String>? preview;
  int rowid = 0; // db insertion order, for append-fast-path
  final Map<String, String> reactions;
  // a poll: its answers on the row, the votes this phone holds for it
  PollSpec? poll;
  Map<String, PollVote> votes = const {};
  // a message of ours some members still lack: how many of them have it
  ({int have, int of, int gaveUp})? reach;
  // a sticker: drawn from our pack; text is its emoji
  final StickerWire? sticker;
  // its place in an album (album.dart). set again while it is still
  // being made ready, when one before it would not go
  AlbumTag? album;
  // shown at once on send, while its photo or video is still cleaned:
  // not saved, not sent yet
  bool preparing = false;
  _GMsg({
    required this.sender,
    String? senderName,
    required this.direction,
    required this.text,
    required this.when,
    this.sticker,
    this.burnAt,
    this.burnSecs,
    this.burnUnseen = false,
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
    this.album,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? {},
       senderName = senderName ?? sender;

  // came in timed and not read yet: its clock waits for the first read
  bool get burnWaits => direction == 'in' && burnAt == null && burnSecs != null;

  // not read yet, its clock waiting or running: reading it is still owed
  bool get burnUnread => burnWaits || (burnUnseen && burnAt != null);

  // what is left on its clock, or the whole window while it waits. null
  // for a message with no clock to show
  int? get burnLeftMs => burnAt != null
      ? burnAt! - DateTime.now().millisecondsSinceEpoch
      : burnWaits
      ? burnSecs! * 1000
      : null;
}

class _Header extends StatelessWidget {
  final String name;
  final String groupId;
  final int memberCount;
  final int? expiresAt; // a room: the subtitle is the clock, not the count
  // a room not let in yet: its subtitle says so, and there is no info page
  final int? joiningAt;
  // its admin ended it: no count under the name
  final bool ended;
  final VoidCallback onBack;
  final VoidCallback onTapInfo;
  final VoidCallback? onSearch;
  final int pinnedCount;
  final VoidCallback? onPinned;
  const _Header({
    super.key,
    required this.name,
    required this.groupId,
    required this.memberCount,
    this.expiresAt,
    this.joiningAt,
    this.ended = false,
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
              onTap: joiningAt == null ? onTapInfo : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    // a room's tile is violet, as on the chat list it
                    // flies from: known from that list before the load
                    HaloHero(
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
                            color: room
                                ? HaloColors.violet
                                : HaloColors.amberText,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 15,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            ),
                          ),
                          // let in, the waiting line rises into the clock
                          RiseSwap(
                            child: ended
                                // the page and its bar say it: no count
                                ? const SizedBox(key: ValueKey('ended'))
                                : joiningAt != null
                                ? RoomJoinLine(
                                    key: const ValueKey('joining'),
                                    joiningAt: joiningAt!,
                                    full: appState.roomFull(groupId),
                                  )
                                : expiresAt != null
                                ? SlotLine(
                                    key: const ValueKey('room'),
                                    msg: (t) =>
                                        l10n.groupChatHere(memberCount, t),
                                    slot: RoomCountdown(
                                      expiresAt: expiresAt!,
                                      size: 10,
                                    ),
                                    style: HaloType.mono(
                                      size: 10,
                                      color: HaloColors.text2,
                                    ),
                                  )
                                : Text(
                                    l10n.groupChatMembers(memberCount),
                                    key: const ValueKey('members'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HaloType.mono(
                                      size: 10,
                                      color: HaloColors.text2,
                                    ),
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
          // nothing to search or pin before the room lets you in: the
          // actions fade in with it, their places kept
          AnimatedOpacity(
            duration: motionStill(context) ? Duration.zero : kHouseTime,
            curve: Curves.easeOut,
            opacity: joiningAt == null ? 1 : 0,
            child: IgnorePointer(
              ignoring: joiningAt != null,
              child: ExcludeSemantics(
                excluding: joiningAt != null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PinHeaderButton(count: pinnedCount, onTap: onPinned),
                    IconButton(
                      tooltip: l10n.groupChatSearchThisChat,
                      icon: Icon(
                        Icons.search,
                        color: HaloColors.text2,
                        size: 21,
                      ),
                      onPressed: onSearch,
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

// ---- composer and reply bar ----

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
                    color: HaloColors.amberText,
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
  final int burnSeconds;
  final bool disguise;
  final VoidCallback onToggleGhost;
  final VoidCallback onLongPressGhost;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onStickers;
  final VoidCallback onCamera;
  final void Function(VoiceTake take) onVoice;
  final bool Function() mayRecord;
  // who @ can offer
  final List<MentionCandidate> members;
  const _Composer({
    this.members = const [],
    required this.controller,
    required this.sending,
    required this.ghost,
    this.burnSeconds = 300,
    required this.disguise,
    required this.onToggleGhost,
    required this.onLongPressGhost,
    required this.onSend,
    required this.onAttach,
    required this.onStickers,
    required this.onCamera,
    required this.onVoice,
    required this.mayRecord,
  });
  @override
  Widget build(BuildContext context) {
    // a phone whose identity has moved has no engine running: a message
    // typed here would sit in the outbox for good. nowhere to type it.
    if (appState.movedAway) return const MovedStrip();
    final still = motionStill(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ghost
                ? HaloColors.amber.withValues(alpha: 0.6)
                : HaloColors.line,
            width: ghost ? 0.8 : 0.5,
          ),
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // timed messages on: a line over the field that grows in and out
          AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axisAlignment: -1,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: ghost
                ? Padding(
                    key: const ValueKey('ghost-strip'),
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_outlined,
                          size: 13,
                          color: HaloColors.amber,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.groupChatGhostModeOnBurns(
                              _fmtBurn(burnSeconds),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.mono(
                              size: 10.5,
                              color: HaloColors.amberText,
                              letter: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-ghost-strip')),
          ),
          _MentionPicker(controller: controller, members: members),
          Row(
            children: [
              PressScale(
                label: l10n.groupChatTimedMessages,
                onTap: onToggleGhost,
                onLongPress: onLongPressGhost,
                scale: 0.88,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
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
                                  color: HaloColors.amber.withValues(
                                    alpha: 0.45,
                                  ),
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
                ),
              ),
              const SizedBox(width: 4),
              // the camera that keeps its photos inside kryfo
              PressScale(
                label: l10n.groupChatOpenTheCamera,
                onTap: onCamera,
                scale: 0.86,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 22,
                    color: HaloColors.text2,
                  ),
                ),
              ),
              PressScale(
                label: l10n.groupChatAttachAPhoto,
                onTap: onAttach,
                scale: 0.86,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 22,
                    color: HaloColors.text2,
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
                          builder: (dir) => ShiftTapGuard(
                            controller: controller,
                            child: TextField(
                              textDirection: dir,
                              inputFormatters: const [UnmarkedInput()],
                              controller: controller,
                              enableIMEPersonalizedLearning: false,
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
                  // empty field: voice lane. text: the send pill. the two
                  // trade places with a small pop instead of a cut
                  return AnimatedSwitcher(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: !hasText && !sending
                        ? KeyedSubtree(
                            key: const ValueKey('mic'),
                            child: HoldToTalkMic(
                              disguise: disguise,
                              onSend: onVoice,
                              mayRecord: mayRecord,
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('send'),
                            child: _sendPill(!sending && hasText),
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

  Widget _sendPill(bool canSend) {
    return PressScale(
      label: l10n.commonSend,
      onTap: canSend ? onSend : null,
      scale: 0.86,
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
  }
}

// ---- bubble ----

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
                                  // never more than a third of the row, so
                                  // the name keeps its room at a big font
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width / 3,
                                    ),
                                    child: Text(
                                      m.id,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HaloType.mono(
                                        size: 10,
                                        color: HaloColors.text2,
                                      ),
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
  final String? quotedText;
  final String? quotedAuthor;
  final void Function(BuildContext)? onLongPress;
  // its photo, video or file opened, or its voice note played
  final VoidCallback? onAct;
  final VoidCallback? onRetry;
  // a tap on a chip puts the same emoji on from here, or takes it off
  final void Function(String emoji)? onReact;
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
  // the face a contact picked, so they look the same here as everywhere
  final int? Function(String id)? faceOf;
  // a sticker row: the chat's budget, its place in it, its entrance
  final StickerBudget? stickers;
  final int stickerOrder;
  final StickerLanding? landing;
  final bool arriving;
  // the quoted message is a sticker
  final StickerWire? quotedSticker;
  // an album: [m] stands for all of it, and its grid is drawn
  final AlbumRun<_GMsg>? album;
  // a tile of the album held: the bubble's context and the tile
  final void Function(BuildContext, int)? onLongPressTile;
  const _GroupBubble({
    required this.m,
    this.album,
    this.onLongPressTile,
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
    this.faceOf,
    this.senderBadge,
    this.quotedText,
    this.quotedAuthor,
    this.onLongPress,
    this.onAct,
    this.onRetry,
    this.onReact,
    this.ripple = false,
    this.query = '',
    this.isCurrentMatch = false,
    this.dimmed = false,
    this.onReplyTap,
    this.linkTitle,
    this.linkBySender = false,
    this.kept = false,
  });

  // someone else's, in a room: opened in no other app
  final bool kept;

  // a search steps what is not a hit back, as in the 1:1 chat
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    opacity: dimmed ? 0.4 : 1.0,
    // a file is drawn by what its bytes are once they are read
    child: m.filePath == null || m.fileName == 'voice.wav'
        ? _bubble(context)
        : ValueListenableBuilder<int>(
            valueListenable: fileFactsRead,
            builder: (context, _, _) => _bubble(context),
          ),
  );

  Widget _bubble(BuildContext context) {
    final isOut = m.direction == 'out';
    final shape = fileShapeNow(m.filePath, m.fileName);
    // a video with no caption sits on the chat like a photo: no bubble around
    // it, its time in its corner
    final isVideo =
        m.filePath != null &&
        m.text.isEmpty &&
        m.fileName != 'voice.wav' &&
        shape == FileShape.video;
    final frameless = m.mediaPath != null || isVideo;
    final onAmberText = isOut && m.mediaPath == null;
    final reacted = m.reactions.isNotEmpty;
    final roomTime = motionStill(context) ? Duration.zero : kHouseTime;
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
                child: KryfoAvatar(
                  seed: m.sender,
                  size: 26,
                  choice: faceOf?.call(m.sender),
                ),
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
                      // the name gives way first; the tags keep their size
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              m.senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.mono(
                                size: 9.5,
                                color: _authorColor(m.sender),
                                letter: 0.4,
                              ),
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
                                maxLines: 1,
                                style: HaloType.mono(
                                  size: 9,
                                  color: HaloColors.amberText,
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
                      // the chip's room is inside the stack, so it can be
                      // tapped, and eases open
                      AnimatedPadding(
                        duration: roomTime,
                        curve: kHouseCurve,
                        padding: EdgeInsets.only(
                          bottom: reacted ? kChipRoom : 0,
                        ),
                        child: BurnFade(
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
                                      bottomEnd: Radius.circular(
                                        isOut ? 4 : 14,
                                      ),
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
                                          PressScale(
                                            scale: 0.97,
                                            haptic: false,
                                            onTap: onReplyTap,
                                            child: Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              padding:
                                                  const EdgeInsets.fromLTRB(
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
                                                            : HaloColors
                                                                  .amberText,
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
                                        if (album case final run?)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: m.text.isNotEmpty ? 6 : 0,
                                            ),
                                            child: _grid(context, run),
                                          )
                                        else if (m.making != null)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: VoiceMakingBubble(
                                              progress: m.making!,
                                              isOut: isOut,
                                            ),
                                          )
                                        else if (m.fileName == 'voice.wav' &&
                                            m.filePath != null)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: VoiceBubble(
                                              key: ValueKey(
                                                'gvb_${m.filePath}',
                                              ),
                                              path: m.filePath!,
                                              isOut: isOut,
                                              disguised: m.voiceDisguised,
                                              onPlay: onAct,
                                            ),
                                          )
                                        else if (m.filePath != null &&
                                            shape == FileShape.video)
                                          VideoBubble(
                                            key: ValueKey('vid_${m.filePath}'),
                                            path: m.filePath!,
                                            fileName: m.fileName!,
                                            width: 240,
                                            onOpen: () {
                                              onAct?.call();
                                              openVideo(
                                                context,
                                                path: m.filePath!,
                                                fileName: m.fileName,
                                                kept: kept,
                                                room: true,
                                              );
                                            },
                                            stamp: m.failed
                                                ? null
                                                : _groupStamp(m),
                                          )
                                        else if (m.fileName != null)
                                          PressScale(
                                            scale: 0.97,
                                            haptic: false,
                                            onTap: () {
                                              onAct?.call();
                                              if (m.filePath != null) {
                                                openReceivedFile(
                                                  context,
                                                  m.filePath!,
                                                  m.fileName,
                                                  kept: kept,
                                                  room: true,
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                              child: fileCard(
                                                m.filePath,
                                                m.fileName,
                                                isOut,
                                                shape: shape,
                                              ),
                                            ),
                                          ),
                                        if (album == null &&
                                            m.mediaPath != null)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: m.text.isNotEmpty ? 6 : 0,
                                            ),
                                            child: PressScale(
                                              scale: 0.97,
                                              haptic: false,
                                              onTap: m.failed
                                                  ? onRetry
                                                  : () {
                                                      onAct?.call();
                                                      openFullImage(
                                                        context,
                                                        m.mediaPath!,
                                                        tag: photoHeroTag(
                                                          m.mediaPath!,
                                                          'chat',
                                                        ),
                                                        radius: 10,
                                                      );
                                                    },
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
                                                        child: HaloHero(
                                                          tag: photoHeroTag(
                                                            m.mediaPath!,
                                                            'chat',
                                                          ),
                                                          child: ChatPicture(
                                                            path: m.mediaPath!,
                                                            child: Image.file(
                                                              File(
                                                                m.mediaPath!,
                                                              ),
                                                              semanticLabel:
                                                                  l10n.appPhoto,
                                                              cacheWidth:
                                                                  decodePx(
                                                                    context,
                                                                    240,
                                                                  ),
                                                              gaplessPlayback:
                                                                  true,
                                                              filterQuality:
                                                                  FilterQuality
                                                                      .medium,
                                                              fit: BoxFit.cover,
                                                              // the file is gone:
                                                              // say so, not a gap
                                                              errorBuilder:
                                                                  (_, _, _) =>
                                                                      const _MissingPhoto(),
                                                            ),
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
                                          writtenStart(
                                            m.text,
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
                                                        style: _bodyStyle(
                                                          isOut,
                                                        ),
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
                                                                m.mediaPath ==
                                                                    null)
                                                            ? HaloColors.onAmber
                                                            : HaloColors.text,
                                                        height: 1.35,
                                                      ),
                                                      onAmber:
                                                          isOut &&
                                                          m.mediaPath == null,
                                                      linkColor:
                                                          (isOut &&
                                                              m.mediaPath ==
                                                                  null)
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
                                                              m.mediaPath !=
                                                                  null
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
                                                              ? HaloColors
                                                                    .onAmber
                                                              : HaloColors.text,
                                                          height: 1.35,
                                                        ),
                                                        accent:
                                                            (isOut &&
                                                                m.mediaPath ==
                                                                    null)
                                                            ? HaloColors.onAmber
                                                            : null,
                                                      ),
                                                      textDirection: writtenDir(
                                                        m.text,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        if (m.url case final u?) ...[
                                          const SizedBox(height: 6),
                                          LinkStub(
                                            url: u,
                                            isOut: isOut,
                                            title: linkTitle,
                                            bySender: linkBySender,
                                          ),
                                        ],
                                        if (m.place case final p?) ...[
                                          const SizedBox(height: 6),
                                          PlaceStub(place: p, isOut: isOut),
                                        ],
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (m.burnLeftMs
                                                case final left?) ...[
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
                                                child: _burnPill(
                                                  left,
                                                  waits: m.burnWaits,
                                                  color:
                                                      (isOut &&
                                                          m.mediaPath == null)
                                                      ? HaloColors.onAmber
                                                      : HaloColors.amber,
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
                                                                ? HaloColors
                                                                      .text2
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
                                                        key: ValueKey(
                                                          'no-tick',
                                                        ),
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
                      ),
                      // hangs at the bubble's bottom edge on the sender's side
                      PositionedDirectional(
                        bottom: 0,
                        end: isOut ? 10 : null,
                        start: isOut ? null : 10,
                        child: _reactionRow(context, isOut),
                      ),
                      // the ring keeps to the bubble as the room opens
                      if (ripple)
                        AnimatedPositionedDirectional(
                          duration: roomTime,
                          curve: kHouseCurve,
                          top: 0,
                          start: 0,
                          end: 0,
                          bottom: reacted ? kChipRoom : 0,
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
                  // the sending pill folds away as the tick comes in. a
                  // message some members still lack says how many have it
                  // until they all do, or how many did not get it once
                  // only those past their tries are left
                  if (isOut)
                    GrowSwap(
                      child: !m.pending
                          ? switch (m.reach) {
                              final r? => Padding(
                                // one key while it counts: the pill rolls
                                // its words in place instead of folding
                                key: const ValueKey('reach'),
                                padding: const EdgeInsetsDirectional.only(
                                  top: 4,
                                  end: 4,
                                ),
                                child: FileReachPill(
                                  have: r.have,
                                  of: r.of,
                                  gaveUp: r.gaveUp,
                                ),
                              ),
                              null => const SizedBox.shrink(
                                key: ValueKey('no-pill'),
                              ),
                            }
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
  // the album's grid: a tile a place, each opening the viewer at itself.
  // the time sits in the corner the reaction chip leaves free
  Widget _grid(BuildContext context, AlbumRun<_GMsg> run) {
    final shown = run.drawn;
    final hold = onLongPressTile;
    final isOut = m.direction == 'out';
    return AlbumGrid(
      tiles: [
        for (final x in shown)
          x == null
              ? null
              : AlbumTile(
                  path: x.mediaPath ?? x.filePath,
                  video: x.mediaPath == null && x.filePath != null,
                  lost:
                      !x.preparing && x.mediaPath == null && x.filePath == null,
                  sendingUid: isOut && x.sending ? x.msgUid : null,
                ),
      ],
      width: 260,
      captioned: m.text.isNotEmpty,
      stamp: m.text.isEmpty && !m.failed ? _groupStamp(m) : null,
      // the reaction chip hangs at the end on ours, the start on theirs
      stampAtStart: isOut,
      onOpen: (i) {
        onAct?.call();
        final items = <AlbumItem>[
          for (final x in shown)
            if (x != null && (x.mediaPath ?? x.filePath) != null)
              AlbumItem(
                (x.mediaPath ?? x.filePath)!,
                video: x.mediaPath == null,
                fileName: x.fileName,
              ),
        ];
        final paths = [for (final x in shown) x?.mediaPath ?? x?.filePath];
        final start = albumOpenAt(paths, i);
        if (start != null) openAlbum(context, items, start: start);
      },
      onLongPress: hold == null ? null : (i) => hold(context, i),
    );
  }

  Widget _sticker(StickerWire st) {
    final isOut = m.direction == 'out';
    final quoted = quotedText;
    final burn = m.burnLeftMs;
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
        burn: burn == null ? null : burnLeft(burn),
        burnWaits: m.burnWaits,
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
      // their own chosen faces, and this phone's for its own vote
      faceOf: (id) => id == me ? appState.myAvatar : faceOf?.call(id),
      burn: m.burnLeftMs == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              // the flame low while the clock waits, as on a bubble
              child: _burnPill(
                m.burnLeftMs!,
                waits: m.burnWaits,
                color: HaloColors.amber,
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
                color: HaloColors.amberText,
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
    final react = onReact;
    return [
      for (final e in counts.entries)
        ReactionChip(
          key: ValueKey(e.key),
          emoji: e.key,
          count: e.value,
          mine: e.key == selfEmoji,
          popKey: '${m.msgUid}:${e.key}',
          onTap: react == null ? null : () => react(e.key),
        ),
    ];
  }

  // the chips under the bubble, as in a chat: the last one to go scales back
  // out, a fade alone when the phone asks for no movement
  Widget _reactionRow(BuildContext context, bool isOut) {
    final still = motionStill(context);
    final reacted = m.reactions.isNotEmpty;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 150 : 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // a new row springs its own chips in: only the way out is drawn here
      transitionBuilder: (c, a) {
        if (c.key != const ValueKey('chips') || reacted) return c;
        final fade = FadeTransition(opacity: a, child: c);
        return still ? fade : ScaleTransition(scale: a, child: fade);
      },
      layoutBuilder: (top, gone) => Stack(
        clipBehavior: Clip.none,
        alignment: isOut
            ? AlignmentDirectional.bottomEnd
            : AlignmentDirectional.bottomStart,
        children: [...gone, ?top],
      ),
      child: !reacted
          ? const SizedBox.shrink(key: ValueKey('no-chips'))
          : Wrap(
              key: const ValueKey('chips'),
              spacing: 3,
              children: _buildReactionChips(m),
            ),
    );
  }

  String _fmtTime(DateTime t) => hourMinute(t);

  // the flame and what is left, the flame low while the clock waits
  Widget _burnPill(int left, {required bool waits, required Color color}) =>
      BurnLine(burnLeft(left), waits: waits, color: color);
}

// a photo whose file is gone: a quiet tile in the bubble's place
class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 120,
      color: HaloColors.surface2,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 26,
            color: HaloColors.text3,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.chatPhotoUnavailable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ],
      ),
    );
  }
}

// the line in a group whose admin "this isn't them" took off this phone:
// nothing it changes reaches here, and the way out
class _AdminGoneLine extends StatelessWidget {
  final VoidCallback onLeave;
  const _AdminGoneLine({required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: HaloColors.rose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HaloColors.rose.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.gpp_bad_outlined, size: 15, color: HaloColors.rose),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                l10n.groupAdminGoneLine,
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.4,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            child: PressScale(
              onTap: onLeave,
              child: Container(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Text(
                  l10n.groupInfoLeave,
                  style: HaloType.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: HaloColors.rose,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
