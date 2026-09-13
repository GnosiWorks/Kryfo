// SPDX-License-Identifier: GPL-3.0-or-later
// chat screen. message bubbles, composer, live receive over tor.
// matches 08_complete_spec.html "the everyday" chat tile.

import '../lock_state.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../picked.dart';
import 'package:share_plus/share_plus.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:convert';
import 'key_verification_screen.dart';
import 'contact_screen.dart';
import 'wallpaper_sheet.dart';
import 'introduce_sheet.dart';
import 'vouchers_sheet.dart';
import 'shield_sheet.dart';
import '../vouch_text.dart';
import '../widgets/intro_chip.dart';
import '../widgets/notice_banner.dart';
import '../widgets/swipe_to_reply.dart';
import '../signal_session.dart';
import '../message_envelope.dart'
    show
        wrapMessage,
        SenderInfo,
        ReactionFrame,
        loadPeerEndpoint,
        grindPow,
        powBits;
import '../theme.dart';
import '../media_progress.dart';
import '../media_send.dart';
import '../notifications.dart' show clearNotificationsFor;
import '../widgets/kryfo_avatar.dart';
import '../main.dart'
    show
        engine,
        db,
        signalEncrypt,
        signalEncryptSerial,
        hasSessionWith,
        appState,
        currentChatPeer,
        shredFile,
        torStrictGetOnIsolate,
        TorHalo;
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/motion.dart';
import '../widgets/burn_fade.dart';
import '../dlog.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/link_stub.dart';
import '../widgets/preview_strip.dart';
import '../link_prefs.dart';
import 'camera_screen.dart';
import '../link_preview.dart' show titleFromHtml, firstUrl, senderPreview;
export '../link_preview.dart' show firstUrl;
export '../atmosphere.dart'
    show
        Atmo,
        atmoFromName,
        atmoAccent,
        atmoLabel,
        atmoIsPattern,
        PatternPainter,
        AtmosphereWash;
import '../atmosphere.dart';
import '../widgets/halo_sheet.dart';

// persists last-seen cipher per peer across ChatScreen instances
// chunk indices already accepted by the peer, per media msg_uid. lets a
// retry resume instead of re-uploading the whole file over tor.
// unsent drafts kept per peer so text survives leaving a chat.
final Map<String, String> _draftPerPeer = {};
// newest message ms seen when the chat was last left, per peer.
final Map<String, int> _lastReadPerPeer = {};

class ChatScreen extends StatefulWidget {
  final String peerHaloId;
  final String peerOnion;
  final String peerXPub;
  final String avatarSeed;
  // the face they picked, handed over so the hero never lands on the
  // letter fallback while the row is still loading
  final int? avatarChoice;
  final String? initialText;
  final String? jumpToUid;

  const ChatScreen({
    super.key,
    required this.peerHaloId,
    required this.peerOnion,
    required this.peerXPub,
    required this.avatarSeed,
    this.avatarChoice,
    this.initialText,
    this.jumpToUid,
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
  // sender asked that this not be screenshotted
  final bool secure;
  bool sending;
  bool failed = false;
  // online, a failed row retries itself and still reads as pending. these
  // count the goes; past the cap it is shown as failed and the tap is the
  // only way on.
  int autoRetries = 0;
  bool gaveUp = false;
  // stored at an address they do not read yet: not sent, not failed. the
  // outbox keeps trying routes that reach them until they add us back.
  bool parked = false;
  bool delivered;
  bool edited;
  bool pinned;
  bool removing = false;
  String? mediaPath;
  String? filePath;
  String? fileName;
  bool voiceDisguised;
  bool saved;
  Map<String, String> reactions;
  bool fresh = false;
  int rowid = 0; // db insertion order, for append tracking
  Map<String, String>? preview; // link preview card, decoded from stored json
  _Msg(
    this.direction,
    this.text,
    this.when, {
    this.burnAt,
    this.burnSecs,
    this.msgUid,
    this.replyTo,
    this.secure = false,
    this.sending = false,
    this.edited = false,
    this.pinned = false,
    this.mediaPath,
    this.filePath,
    this.fileName,
    this.voiceDisguised = false,
    this.saved = false,
    this.delivered = false,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? <String, String>{};
}

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes b';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} kb';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} mb';
}

IconData _fileGlyph(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (n.endsWith('.zip') || n.endsWith('.rar') || n.endsWith('.7z')) {
    return Icons.folder_zip_outlined;
  }
  if (n.endsWith('.doc') || n.endsWith('.docx') || n.endsWith('.txt')) {
    return Icons.description_outlined;
  }
  if (n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a')) {
    return Icons.audiotrack_outlined;
  }
  if (n.endsWith('.mp4') || n.endsWith('.mov') || n.endsWith('.mkv')) {
    return Icons.movie_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

Widget _fileCard(_Msg msg, bool isOut) {
  final fg = isOut ? HaloColors.onAmber : HaloColors.text;
  final sub = isOut ? HaloColors.onAmber : HaloColors.text3;
  final icon = isOut ? HaloColors.onAmber : HaloColors.amber;
  int? sz;
  try {
    if (msg.filePath != null) sz = File(msg.filePath!).lengthSync();
  } catch (_) {}
  final ext = (msg.fileName ?? '').contains('.')
      ? msg.fileName!.split('.').last.toUpperCase()
      : 'FILE';
  return Container(
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: isOut
          ? HaloColors.onAmber.withValues(alpha: 0.12)
          : HaloColors.surface3,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isOut
                ? HaloColors.onAmber.withValues(alpha: 0.16)
                : HaloColors.amberSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(_fileGlyph(msg.fileName ?? ''), size: 19, color: icon),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.fileName ?? 'file',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.sans(
                  size: 13,
                  color: fg,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sz != null ? '$ext · ${_humanSize(sz)}' : ext,
                style: HaloType.mono(size: 9, color: sub),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _openFullImage(BuildContext context, String path, {bool secure = false}) {
  // drop the composer's focus first, else popping the viewer restores it and
  // the keyboard springs up over the chat.
  FocusManager.instance.primaryFocus?.unfocus();
  // the flag is per-window, so it can only be on while this screen is up.
  // that is exactly the granularity we want: the photo is protected, the
  // conversation around it is not.
  // a screen that already forced the flag (a room, a marked chat) keeps
  // it: the flag is one bool, and dropping it here left the room open to
  // screenshots for the rest of the session
  final wasForced = appState.secureForced;
  if (secure && !wasForced) appState.forceSecure(true);
  Navigator.of(context)
      .push(
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
      )
      .then((_) {
        if (secure && !wasForced) appState.forceSecure(false);
        FocusManager.instance.primaryFocus?.unfocus();
      });
}

// the phone cannot send at all: no network, or onion mode without a route
bool _cannotSend() => !appState.online || !appState.torReady;

// a failed send only reads as failed when the phone cannot send, or when
// it has retried itself to the cap. online, the row keeps going on its own
// and shows as pending - the tap-to-retry pill was appearing on every slow
// photo and reading as a real failure.
bool _sendLooksFailed(_Msg m) => m.failed && (m.gaveUp || _cannotSend());

String _friendlyStatus(String raw) {
  if (raw.isEmpty || raw == 'parked') return '';
  if (!appState.online && raw.startsWith('error:')) {
    return "you are offline · this sends itself when you reconnect";
  }
  if (raw.startsWith('error:') && !appState.torReady) {
    return "still connecting to tor · it'll go out on its own";
  }
  // online, a transport error is not the user's problem: the row retries
  // itself and the bubble stays pending. no line.
  if (raw.startsWith('error:')) return '';
  return raw;
}

String _fmtFull(DateTime d) {
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
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final now = DateTime.now();
  final date = d.year == now.year
      ? '${d.day} ${months[d.month - 1]}'
      : '${d.day} ${months[d.month - 1]} ${d.year}';
  return '$date · $hh:$mm';
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

// last-used ghost settings, remembered for the session
// isolate entrypoint for compute() - grinds first-contact pow.
int _grindPowTask(String seed) => grindPow(seed, powBits);

int _lastBurnSeconds = 300;
bool _lastGhost = false;

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  int _unreadAfterMs = 0;
  int _firstUnreadIndex = -1;
  bool _unreadResolved = false;
  bool _ghost = _lastGhost; // restored from last use this session.
  // marks the next message so the other phone blocks screenshots of it. off
  // by default: most messages do not need it and the cost is that neither
  // side can screenshot the chat.
  bool _secureNext = false;
  bool _disguise = false;
  int _burnSeconds = _lastBurnSeconds; // restored from last use this session.
  Timer? _burnTick;
  int _lastBurnSec = 0;
  final _scrollCtrl = ScrollController();
  static const _pageSize = 60;
  bool _hasMore = false;
  bool _loadingOlder = false;
  // set once the user paged deep or jumped - reloads keep the full thread
  // so their scroll position doesn't collapse back to one page.
  bool _pagedOut = false;

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore) return;
    _loadingOlder = true;
    try {
      final oldest = _messages.isEmpty ? null : _messages.first.rowid;
      final rows = await db.messagesPage(
        widget.peerHaloId,
        beforeRowid: oldest,
        limit: _pageSize + 1,
      );
      if (!mounted) return;
      _hasMore = rows.length > _pageSize;
      if (_hasMore) rows.removeAt(0);
      if (!_hasMore) _pagedOut = true;
      final older = <_Msg>[];
      final uids = <String>[];
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        final m = _Msg(
          r['direction'] as String,
          r['plaintext'] as String,
          DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
          burnAt: r['burn_at'] as int?,
          msgUid: uid,
          replyTo: r['reply_to'] as String?,
          secure: (r['secure'] as int? ?? 0) == 1,
          edited: (r['edited'] as int? ?? 0) == 1,
          pinned: (r['pinned'] as int? ?? 0) == 1,
          mediaPath: r['media_path'] as String?,
          filePath: r['file_path'] as String?,
          fileName: r['file_name'] as String?,
          voiceDisguised: (r['voice_disguised'] as int? ?? 0) == 1,
          saved: (r['saved'] as int? ?? 0) == 1,
        );
        m.rowid = (r['rowid'] as int?) ?? 0;
        final pvRaw = r['preview'] as String?;
        if (pvRaw != null && pvRaw.isNotEmpty) {
          try {
            final dd = jsonDecode(pvRaw) as Map<String, dynamic>;
            m.preview = dd.map((k, v) => MapEntry(k, v.toString()));
          } catch (_) {}
        }
        if (uid != null) {
          uids.add(uid);
          _seenUids.add(uid);
        }
        older.add(m);
      }
      final reactionMap = await db.loadReactionsFor(uids);
      for (final m in older) {
        final entries = reactionMap[m.msgUid];
        if (entries == null) continue;
        for (final en in entries) {
          m.reactions[en.key] = en.value;
        }
      }
      if (!mounted || older.isEmpty) return;
      setState(() {
        _messages.insertAll(0, older);
        _normaliseMessages();
      });
    } finally {
      _loadingOlder = false;
    }
  }

  void _onScrollPage() {
    if (!_hasMore || !_scrollCtrl.hasClients) return;
    final p = _scrollCtrl.position;
    if (p.pixels > p.maxScrollExtent - 600) _loadOlder();
  }

  // keyed by the message the divider sits above, not by the day, so two
  // dividers can never hold the same key. _dayMsOf maps a key back to the
  // day it represents for the sticky header.
  final Map<String, GlobalKey> _dayKeys = {};
  final Map<String, int> _dayMsOf = {};

  // the keys belong to messages, so they go when the messages do
  void _forgetDayKeys() {
    _dayKeys.clear();
    _dayMsOf.clear();
  }

  final GlobalKey _listKey = GlobalKey();
  final ValueNotifier<String?> _stickyLabel = ValueNotifier(null);
  final ValueNotifier<bool> _stickyShown = ValueNotifier(false);
  int? _stickyDayMs;
  String? _revealedUid;
  Timer? _stickyHideTimer;
  bool _suppressSticky = true;
  final List<_Msg> _messages = [];

  // every path that touches the list ends here. the day dividers key off
  // "is this message a different day from the one before it", so an
  // out-of-order list emits two dividers for one day - and both grab the
  // same GlobalKey, which takes the whole chat out of the widget tree.
  void _normaliseMessages() {
    _messages.sort((a, b) => a.when.compareTo(b.when));
    final seen = <String>{};
    _messages.retainWhere((m) {
      final id = m.msgUid;
      if (id == null) return true;
      return seen.add(id);
    });
    // quoted replies resolve through here rather than scanning the list once
    // per visible row.
    _byUid
      ..clear()
      ..addEntries(
        _messages
            .where((m) => m.msgUid != null)
            .map((m) => MapEntry(m.msgUid!, m)),
      );
  }

  final Map<String, _Msg> _byUid = {};

  bool _loaded = false;
  Atmo _atmosphere = Atmo.none;
  String _status = '';
  bool _loading = false;
  bool _reloadPending = false;
  Timer? _pollTimer;
  bool _sending = false;
  // serialize signal encryption across sends. a fast burst must not encrypt
  // every message against the same pre-session state, or they all come out as
  // prekey messages fighting over one one-time key and only the first lands.
  Future<void> _encryptGate = Future.value();
  // seed from the qr/contact key so the relay path works on the first send,
  // even on the scanned side before any session exists. the session lookup in
  // initState only refreshes it; it must not be the sole source.
  late String? _peerXPub = widget.peerXPub.isEmpty ? null : widget.peerXPub;
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
  String? _liftedUid;
  List<int> _matches = [];
  // same hits as _matches, for the per-row "is this one" test
  Set<int> _matchSet = {};
  int _matchPos = 0;
  final Map<int, GlobalKey> _matchKeys = {};
  final GlobalKey _jumpKey = GlobalKey();
  int? _jumpIndex;
  String? _nickname;
  late int? _peerFace = widget.avatarChoice;
  bool _blocked = false;
  bool _muted = false;
  bool _verified = false;
  String? _peerBadge;
  bool _keyChanged = false;

  Future<void> _dismissKeyChanged() async {
    await db.setKeyChanged(widget.peerHaloId, false);
    if (mounted) setState(() => _keyChanged = false);
  }

  // request-lock state: a stranger we haven't accepted, capped at 2 sent msgs.
  bool _accepted = true; // assume ok until loaded, so normal chats don't flash
  bool _peerEngaged = false; // they've replied/back-paired -> lock lifts
  int _sentCount = 0;
  int _recvCount =
      0; // messages they've sent us; >0 + unaccepted = a request TO us
  // sender-side lock: messaging a stranger who hasn't accepted, past the cap.
  // once they engage (reply/back-pair) or we accept them, it clears.
  bool get _requestPending => !_peerEngaged && _recvCount == 0;
  bool get _requestLocked => _requestPending && _sentCount >= 2 && !_vouched;
  // receiver-side: a stranger has messaged us and we haven't accepted yet.
  bool get _incomingRequest => !_accepted && _recvCount > 0;
  // friends vouched for this peer. no sender-side cap then: the other end
  // skips its gate for us, so locking ourselves would be the only lock left.
  List<String> _voucherNames = const [];
  String? _voucherSeed; // first voucher, whose face the chip wears
  int? _voucherAvatar;
  bool _voucherVerified = false;
  bool get _vouched => _voucherNames.isNotEmpty;
  // what the scam shield saw on this stranger, if anything and not ignored
  ShieldFlag? _flag;
  // the shield looked at their opener and found nothing
  bool _shieldClean = false;
  bool _showScrollDown = false;
  int _seenCount = 0;
  String? _rippleUid;
  _Msg? _replyFlash;
  String? _note;

  @override
  void initState() {
    super.initState();

    _applySecureContent();
    WidgetsBinding.instance.addObserver(this);
    _reconcileSending();
    appState.loadGhostPref().then((p) {
      if (mounted) {
        setState(() {
          _ghost = p.$1;
          _burnSeconds = p.$2;
          _lastGhost = p.$1;
          _lastBurnSeconds = p.$2;
        });
      }
    });
    appState.loadDisguisePref().then((d) {
      if (mounted) setState(() => _disguise = d);
    });
    appState.addListener(_onAppStateChanged);
    appState.loadSendMode();
    currentChatPeer = widget.peerHaloId;
    db.clearUnread(widget.peerHaloId).then((_) => appState.refreshContacts());
    unawaited(clearNotificationsFor(widget.peerHaloId));
    _unreadAfterMs =
        _lastReadPerPeer[widget.peerHaloId] ??
        DateTime.now().millisecondsSinceEpoch;
    if (widget.initialText != null) {
      _msgCtrl.text = widget.initialText!;
    } else {
      _msgCtrl.text = _draftPerPeer[widget.peerHaloId] ?? '';
    }
    // save the draft live on every keystroke so it survives leaving the chat
    // regardless of when dispose runs.
    _msgCtrl.addListener(() {
      final t = _msgCtrl.text;
      if (t.trim().isEmpty) {
        _draftPerPeer.remove(widget.peerHaloId);
      } else {
        _draftPerPeer[widget.peerHaloId] = t;
      }
    });
    db.getContact(widget.peerHaloId).then((c) {
      if (mounted) {
        setState(() {
          _nickname = c?['nickname'] as String?;
          _note = c?['note'] as String?;
          _peerFace = (c?['avatar'] as num?)?.toInt() ?? _peerFace;
        });
      }
    });
    _loadVouches();
    _loadShield();
    db.getAtmosphere(widget.peerHaloId).then((a) {
      if (mounted) setState(() => _atmosphere = atmoFromName(a));
    });
    signalSession.peerXPubHex(widget.peerHaloId).then((v) {
      // only adopt the session value if we don't already have the widget key;
      // never clobber a good key with a null the store hasn't filled yet.
      if (mounted && v != null && v.isNotEmpty) {
        setState(() => _peerXPub = v);
      }
    });
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    db.keyChanged(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _keyChanged = v);
    });
    _scrollCtrl.addListener(_onScrollPage);
    db.isBlocked(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _blocked = v);
    });
    db.isMuted(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _muted = v);
    });
    db.isVerified(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _verified = v);
    });
    db.getContact(widget.peerHaloId).then((c) {
      if (mounted) {
        setState(() => _peerBadge = c?['supporter_badge'] as String?);
      }
    });
    // request lock: are they an accepted contact, have they engaged, and how
    // many messages have we already sent while unaccepted.
    db.isAccepted(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _accepted = v);
    });
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _peerEngaged = v);
    });
    db.countMessagesTo(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _sentCount = v);
    });
    db.countMessagesFrom(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _recvCount = v);
    });
    _scrollCtrl.addListener(_onScroll);
    _scrollCtrl.addListener(_updateSticky);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _suppressSticky = false;
    });
    _loadMessages();
    _burnTick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      // one pass, and no list unless something actually burnt. most chats
      // carry no ghosts at all, and this runs ten times a second for as long
      // as the chat is open.
      List<_Msg>? expired;
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
          // wait for the full _BurnFade dissolve (520ms) before pulling the
          // row, else the animation cuts off and the message pops away.
          Future.delayed(const Duration(milliseconds: 560), () async {
            if (mounted) setState(() => _messages.remove(m));
            if (m.msgUid != null) await db.deleteMessage(m.msgUid!);
            // the home row was previewing what just burned
            unawaited(appState.refreshContacts());
          });
        }
        HapticFeedback.lightImpact();
      }
      // _BurnFade dissolves itself, so the timer only has to repaint when
      // something just expired or the countdown text changes second.
      final sec = now ~/ 1000;
      if (expired != null || sec != _lastBurnSec) {
        _lastBurnSec = sec;
        setState(() {});
      }
    });

    _autoRetryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _autoRetryTick(),
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkInbox();
      _refreshPreviews();
    });
  }

  int _lastRev = -1;

  void _onAppStateChanged() {
    if (!mounted) return;
    _retryFailedOnReconnect();
    // only touch the message list when this thread actually changed -
    // reloading on every app notify was a lag spike in long chats.
    final rev = appState.chatRevOf(widget.peerHaloId);
    if (rev != _lastRev) {
      _lastRev = rev;
      _tryAppendNew();
      unawaited(_refreshDelivered());
    }
    _refreshRequestState();
    if (!_accepted && _flag == null) _loadShield();
  }

  // who vouched, as we know them. only accepted contacts come back, so a
  // voucher we deleted since simply stops being named.
  Future<void> _loadVouches() async {
    final vs = await db.vouchesFor(widget.peerHaloId);
    if (!mounted) return;
    setState(() {
      _voucherNames = [
        for (final v in vs)
          (v['nickname'] as String?) ?? v['voucher_id'] as String,
      ];
      if (vs.isNotEmpty) {
        _voucherSeed = vs.first['voucher_id'] as String;
        _voucherAvatar = (vs.first['avatar'] as num?)?.toInt();
        _voucherVerified =
            vs.length == 1 && (vs.first['verified'] as int? ?? 0) == 1;
      }
    });
  }

  Future<void> _loadShield() async {
    if (await db.isAccepted(widget.peerHaloId)) return;
    final row = await db.shieldFor(widget.peerHaloId);
    final f = ShieldFlag.fromRow(row);
    final clean = ShieldFlag.cleanRow(row);
    if (mounted && (f != _flag || clean != _shieldClean)) {
      setState(() {
        _flag = f;
        _shieldClean = clean;
      });
    }
  }

  Future<void> _openShield() async {
    final f = _flag;
    if (f == null) return;
    final c = await showShieldSheet(context, widget.peerHaloId, f);
    if (!mounted || c == null) return;
    if (c == ShieldChoice.ignore) {
      setState(() => _flag = null);
    } else {
      Navigator.pop(context);
    }
  }

  // lock state loads once on open, so a reply landing while the sender sits
  // in the locked chat never flipped it. re-check whenever something arrives.
  void _refreshRequestState() {
    if (_accepted && _peerEngaged && _recvCount > 0) return;
    db.isAccepted(widget.peerHaloId).then((v) {
      if (mounted && v != _accepted) setState(() => _accepted = v);
    });
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted && v != _peerEngaged) setState(() => _peerEngaged = v);
    });
    db.countMessagesFrom(widget.peerHaloId).then((v) {
      if (mounted && v != _recvCount) setState(() => _recvCount = v);
    });
  }

  // when tor comes back (down -> reachable), re-fire anything that failed while
  // offline. only touches messages already marked failed - never the ones still
  // 'sending' (those have a live future). fires once per reconnect via the
  // _wasReachable edge, so a stream of status ticks won't spam resends.
  void _retryAny(_Msg m) {
    if (m.mediaPath != null) {
      _retryImage(m);
    } else if (m.filePath != null) {
      _retryMedia(m);
    } else {
      _retry(m);
    }
  }

  Timer? _autoRetryTimer;
  // online, a failed send goes again on its own: half a minute apart, six
  // goes, then it is shown as failed. the reconnect retry below covers the
  // offline case; this covers a route that was simply slow or flaky.
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
      _retryAny(m);
    }
  }

  void _retryFailedOnReconnect() {
    final reachable = _torReadyToSend();
    if (reachable && !_wasReachable) {
      // clear any stale send error - we're reconnected and about to resend.
      if (_status.isNotEmpty) setState(() => _status = '');
      for (final m in _messages) {
        if (m.direction == 'out' && m.failed && m.msgUid != null) {
          if (m.mediaPath != null) {
            _retryImage(m);
          } else if (m.filePath != null) {
            _retryMedia(m);
          } else {
            _retry(m);
          }
        }
      }
    }
    _wasReachable = reachable;
  }

  // fast path for a live message landing while you're in the chat. pulls only
  // rows newer than the newest we hold and tacks them on, so the list doesn't
  // rebuild from scratch (that full reload was eating the bubble-in animation
  // and felt laggy). falls back to a full reload if anything looks off - an
  // edit, a delete, a reaction, or a row we already have.
  // a link-preview update arrives as a separate control message and only
  // updates an existing row's preview column - _tryAppendNew won't see it (no
  // new row). so each tick, pull previews for messages that have a url but no
  // card yet and patch them in live. cheap: only runs while a preview is
  // genuinely missing.
  Future<void> _refreshPreviews() async {
    if (!_loaded) return;
    final pending = _messages
        .where((m) => m.preview == null && firstUrl(m.text) != null)
        .toList();
    if (pending.isEmpty) return;
    var changed = false;
    for (final m in pending) {
      if (m.msgUid == null) continue;
      final pv = await db.getMsgPreview(m.msgUid!);
      if (pv != null && pv.isNotEmpty) {
        try {
          final d = jsonDecode(pv) as Map<String, dynamic>;
          m.preview = d.map((k, v) => MapEntry(k, v.toString()));
          changed = true;
        } catch (_) {}
      }
    }
    if (changed && mounted) setState(() {});
  }

  // a delivery receipt flipped `delivered` in the db for a message already on
  // screen. _tryAppendNew won't catch it (no new row), so re-read the flag for
  // any out-message not yet marked delivered and update the bubble in place.
  Future<void> _refreshDelivered() async {
    final pending = _messages
        .where((m) => m.direction == 'out' && !m.delivered && m.msgUid != null)
        .toList();
    if (pending.isEmpty) return;
    var changed = false;
    for (final m in pending) {
      final ok = await db.isDelivered(m.msgUid!);
      if (ok && !m.delivered) {
        m.delivered = true;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _tryAppendNew() async {
    if (!_loaded || _searching) {
      _loadMessages();
      return;
    }
    final lastRowid = _messages.isEmpty
        ? 0
        : _messages.map((m) => m.rowid).reduce((a, b) => a > b ? a : b);
    final rows = await db.messagesAfter(widget.peerHaloId, lastRowid);
    if (!mounted) return;
    final have = _messages.map((m) => m.msgUid).toSet();
    // any new row we don't already hold? if not, fall back to a full reload -
    // covers edits/reactions/deletes and clock-skew (a received msg whose
    // sent_at is older than our local newest, e.g. voice notes).
    final brandNew = rows
        .where(
          (r) =>
              (r['msg_uid'] as String?) != null &&
              !have.contains(r['msg_uid'] as String?),
        )
        .toList();
    if (brandNew.isEmpty) {
      _loadMessages();
      return;
    }
    final fresh = <_Msg>[];
    for (final r in brandNew) {
      final uid = r['msg_uid'] as String?;
      final m = _Msg(
        r['direction'] as String,
        r['plaintext'] as String,
        DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
        burnAt: r['burn_at'] as int?,
        msgUid: uid,
        replyTo: r['reply_to'] as String?,
        secure: (r['secure'] as int? ?? 0) == 1,
        edited: (r['edited'] as int? ?? 0) == 1,
        pinned: (r['pinned'] as int? ?? 0) == 1,
        mediaPath: r['media_path'] as String?,
        filePath: r['file_path'] as String?,
        fileName: r['file_name'] as String?,
        voiceDisguised: (r['voice_disguised'] as int? ?? 0) == 1,
        saved: (r['saved'] as int? ?? 0) == 1,
        delivered: (r['delivered'] as int? ?? 0) == 1,
        sending:
            (r['direction'] as String) == 'out' &&
            (r['sent'] as int? ?? 1) == 0,
      );
      m.rowid = (r['rowid'] as int?) ?? 0;
      final pvRaw = r['preview'] as String?;
      if (pvRaw != null && pvRaw.isNotEmpty) {
        try {
          final d = jsonDecode(pvRaw) as Map<String, dynamic>;
          m.preview = d.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {}
      }
      if (m.direction != 'out' && uid != null) m.fresh = true;
      fresh.add(m);
      if (uid != null) _seenUids.add(uid);
    }
    setState(() {
      _messages.addAll(fresh);
      _normaliseMessages();
    });
    _applySecureContent();
    // a message landing while we're actually reading this chat left the home
    // badge lit - clear it. but this runs on every appState notify, and a
    // backed-out chat is still in the tree for a while, so it would wipe a dot
    // nobody had seen. only the open chat gets to clear.
    if (fresh.any((m) => m.direction != 'out') &&
        currentChatPeer == widget.peerHaloId) {
      unawaited(db.clearUnread(widget.peerHaloId));
      unawaited(appState.refreshContacts());
    }
    _scrollToEnd();
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
              'New messages',
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
    // the page holds the last sixty; a search wants all of it
    _loadMessages();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchCtrl.clear();
      _matches = [];
      _matchSet = {};
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
      _matchSet = matches.toSet();
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
      // reversed list: newest is at offset 0, so a message at index idx sits at
      // roughly (len-1-idx)/len of the extent.
      final frac = (_messages.length - 1 - idx) / _messages.length;
      final approx = frac * _scrollCtrl.position.maxScrollExtent;
      if (_scrollReady) {
        _scrollCtrl.jumpTo(
          approx.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        );
      }
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

  // floating reaction picker - WhatsApp-style pill above the long-pressed
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
    if (!mounted || !bubbleContext.mounted) return;
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final bubbleSize = box.size;
    const pickerH = 54.0;
    const menuH = 200.0;
    final screenH = MediaQuery.of(context).size.height;
    final safeTop = MediaQuery.of(context).padding.top + 8;
    final safeBottom = screenH - MediaQuery.of(context).padding.bottom - 12;
    final bubbleTop = offset.dy;
    final bubbleBottom = offset.dy + bubbleSize.height;
    final aboveTop = bubbleTop - pickerH - 14;
    double reactTop;
    double? menuTop;
    double? menuBottom;
    if (aboveTop >= safeTop && safeBottom - bubbleBottom >= menuH + 14) {
      reactTop = aboveTop;
      menuTop = bubbleBottom + 10;
    } else if (aboveTop >= safeTop) {
      reactTop = aboveTop;
      menuBottom = screenH - (reactTop - 8);
    } else {
      reactTop = bubbleBottom + 10;
      menuTop = reactTop + pickerH + 8;
    }
    // pin the bar to the message's side so reply + edit never
    // run off the right edge. 12px margin from screen edge.
    final alignRight = target.direction == 'out';

    if (mounted) setState(() => _liftedUid = target.msgUid);
    late OverlayEntry entry;
    void dismiss() {
      if (entry.mounted) entry.remove();
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
            Positioned(
              left: offset.dx,
              top: offset.dy,
              width: bubbleSize.width,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: Material(
                    type: MaterialType.transparency,
                    child: _Bubble(msg: target),
                  ),
                  builder: (_, t, child) =>
                      Transform.scale(scale: 1.0 + 0.04 * t, child: child),
                ),
              ),
            ),

            Positioned(
              top: reactTop,
              left: alignRight ? null : 12,
              right: alignRight ? 12 : null,
              child: MenuPop(
                fromRight: alignRight,
                child: _EmojiPickerBubble(
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
                    setState(() {
                      _replyTo = target;
                      _replyFlash = target;
                    });
                    Future.delayed(const Duration(milliseconds: 700), () {
                      if (mounted && identical(_replyFlash, target)) {
                        setState(() => _replyFlash = null);
                      }
                    });
                  },
                ),
              ),
            ),
            Positioned(
              top: menuTop,
              bottom: menuBottom,
              left: alignRight ? null : 12,
              right: alignRight ? 12 : null,
              child: MenuPop(
                fromRight: alignRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: target.direction == 'out'
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          dismiss();
                          HapticFeedback.selectionClick();
                          _toggleSaved(target);
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
                              Icon(
                                target.saved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                size: 16,
                                color: target.saved
                                    ? HaloColors.amber
                                    : HaloColors.text2,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                target.saved ? 'Unsave' : 'save',
                                style: HaloType.sans(
                                  size: 13,
                                  color: HaloColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                            'Forward',
                            style: HaloType.sans(
                              size: 13,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (target.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            dismiss();
                            HapticFeedback.selectionClick();
                            Clipboard.setData(ClipboardData(text: target.text));
                            showHaloToast(context, 'copied!');
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
                              'Copy',
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                            target.pinned ? 'Unpin' : 'pin',
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
                                Icon(
                                  Icons.delete_outline,
                                  size: 14,
                                  color: HaloColors.rose,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Unsend',
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
                      // words can be edited; a photo, a file or a voice note
                      // is what it is
                      if (target.mediaPath == null &&
                          target.filePath == null) ...[
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
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: HaloColors.amber,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edit',
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
                  ],
                ),
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
    await showHaloSheet<void>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Pinned messages',
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
                      Icon(
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
                      Semantics(
                        label: 'Close',
                        button: true,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _togglePin(m);
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
    // the confirm sheet hands focus back to the composer on close, which pops
    // the keyboard for no reason. let go of it now and again after.
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
                'Unsend message',
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
                      'Unsend',
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
    FocusManager.instance.primaryFocus?.unfocus();
    if (confirm != true) return;
    if (mounted) setState(() => m.removing = true);
    // let the burn dissolve finish before the row is pulled (was 300ms, cut the
    // 520ms _BurnFade short and looked janky).
    await Future.delayed(const Duration(milliseconds: 560));
    await db.deleteMessage(m.msgUid!);
    if (mounted) setState(() => _messages.remove(m));
    // the home row was still previewing the message just unsent
    unawaited(appState.refreshContacts());
    try {
      final wrapped = await wrapMessage('', unsend: m.msgUid);
      final cipher = await signalEncrypt(widget.peerHaloId, wrapped);
      final useDirectOnion = !_backPaired || _peerXPub == null;
      await (useDirectOnion
          ? Future(() => engine.sendTo(widget.peerOnion, cipher))
          : Future(() => engine.nostrSend(_peerXPub!, cipher)));
    } catch (e) {
      dlog('unsend send failed: $e');
    }
  }

  Future<void> _togglePin(_Msg m) async {
    if (m.msgUid == null) return;
    if (!m.pinned) {
      final count = _messages.where((x) => x.pinned).length;
      if (count >= 3) {
        if (mounted) {
          showHaloToast(context, 'Max 3 pinned');
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
    setState(() => _jumpIndex = idx);
    final max = _scrollCtrl.position.maxScrollExtent;
    final frac = (_messages.length - 1 - idx) / _messages.length;
    final approx = (frac * max - _scrollCtrl.position.viewportDimension * 0.3)
        .clamp(0.0, max);
    _safeJump(approx.clamp(0.0, max));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _jumpKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: Duration.zero,
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      }
      _jumpIndex = null;
      if (m.msgUid != null) {
        setState(() => _rippleUid = m.msgUid);
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted && _rippleUid == m.msgUid) {
            setState(() => _rippleUid = null);
          }
        });
      }
    });
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
    if (!mounted) return;
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
              'Edit message',
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
                    'Cancel',
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: Text(
                    'Save',
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
    ctrl.dispose();
    if (result == null) return;
    final newText = result.trim();
    if (newText.isEmpty || newText == m.text) return;
    setState(() {
      m.text = newText;
      m.edited = true;
    });
    await db.editMessage(m.msgUid!, newText);
    // queued first, sent now: if the route is down the outbox carries it,
    // the way it carries a message. the home row shows the new text too.
    await db.queueEdit(m.msgUid!, widget.peerHaloId, newText);
    unawaited(appState.refreshContacts());
    unawaited(appState.sendEdit(widget.peerHaloId, m.msgUid!, newText));
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
      dlog('reaction send failed: $e');
    }
  }

  final Set<String> _seenUids = <String>{};

  Future<void> _loadMessages() async {
    if (_loading) {
      _reloadPending = true;
      return;
    }
    _loading = true;
    try {
      await _loadMessagesInner();
    } finally {
      _loading = false;
      if (_reloadPending && mounted) {
        _reloadPending = false;
        _loadMessages();
      }
    }
  }

  Future<void> _loadMessagesInner() async {
    await db.purgeExpiredBurns();
    db.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    db.isBlocked(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _blocked = v);
    });
    db.isMuted(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _muted = v);
    });
    final wantAll = _searching || widget.jumpToUid != null || _pagedOut;
    final rows = wantAll
        ? await db.messagesFor(widget.peerHaloId)
        : await db.messagesPage(widget.peerHaloId, limit: _pageSize + 1);
    _hasMore = !wantAll && rows.length > _pageSize;
    if (_hasMore) rows.removeAt(0);
    if (wantAll) _hasMore = false;
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
          secure: (r['secure'] as int? ?? 0) == 1,
          edited: (r['edited'] as int? ?? 0) == 1,
          pinned: (r['pinned'] as int? ?? 0) == 1,
          mediaPath: r['media_path'] as String?,
          filePath: r['file_path'] as String?,
          fileName: r['file_name'] as String?,
          voiceDisguised: (r['voice_disguised'] as int? ?? 0) == 1,
          saved: (r['saved'] as int? ?? 0) == 1,
          delivered: (r['delivered'] as int? ?? 0) == 1,
          sending:
              (r['direction'] as String) == 'out' &&
              (r['sent'] as int? ?? 1) == 0,
        ),
      );
      final pvRaw = r['preview'] as String?;
      if (pvRaw != null && pvRaw.isNotEmpty) {
        try {
          final d = jsonDecode(pvRaw) as Map<String, dynamic>;
          loaded.last.preview = d.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {}
      }
      loaded.last.rowid = (r['rowid'] as int?) ?? 0;
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
    final newSeen = <String>{};
    for (final m in loaded) {
      if (m.msgUid != null) newSeen.add(m.msgUid!);
    }
    if (_loaded) {
      for (final m in loaded) {
        if (m.direction != 'out' &&
            m.msgUid != null &&
            !_seenUids.contains(m.msgUid)) {
          m.fresh = true;
        }
      }
    }
    _seenUids
      ..clear()
      ..addAll(newSeen);
    if (!_unreadResolved) {
      _firstUnreadIndex = -1;
      for (var i = 0; i < loaded.length; i++) {
        if (loaded[i].direction != 'out' &&
            loaded[i].when.millisecondsSinceEpoch > _unreadAfterMs) {
          _firstUnreadIndex = i;
          break;
        }
      }
      _unreadResolved = true;
    }
    // any reloaded 'sending' out-message is dead - its send future doesn't
    // survive a reload, so it can never resolve. flip to failed so you get
    // tap-to-retry instead of a permanent '3 hops' zombie. runs every load,
    // not just first, so old stuck messages always become retryable. live
    // sends from THIS session aren't in `loaded` yet, so they're untouched.
    final staleCutoff = DateTime.now().subtract(const Duration(seconds: 60));
    // while tor is still warming, a pending send isn't dead - it's queued,
    // and the reconnect retry fires it the moment tor lands. calling it
    // failed here killed the send pill mid-warmup.
    // 'reachable' was the wrong bar though: a phone whose onion will not
    // publish sits at 'publishing' for good, so this never ran and the
    // pill stayed a zombie. carrying traffic is what matters here.
    final torUp = appState.torReady;
    final backPaired = await db.isBackPaired(widget.peerHaloId);
    for (final m in loaded) {
      // under a minute old the send future may still be running in the
      // background - marking it failed here caused dup resends.
      if (torUp &&
          m.direction == 'out' &&
          m.sending &&
          m.when.isBefore(staleCutoff)) {
        m.sending = false;
        if (backPaired) {
          m.failed = true;
        } else {
          m.parked = true;
        }
      }
    }
    // a reload rebuilds every row; the retry count rides across, or a
    // failed send never reached its cap
    final carry = {
      for (final m in _messages)
        if (m.msgUid != null) m.msgUid!: (m.autoRetries, m.gaveUp),
    };
    for (final m in loaded) {
      final c = carry[m.msgUid];
      if (c != null) {
        m.autoRetries = c.$1;
        m.gaveUp = c.$2;
      }
    }
    setState(() {
      _loaded = true;
      _forgetDayKeys();
      _messages
        ..clear()
        ..addAll(loaded);
      _normaliseMessages();
      if (loaded.isNotEmpty) {
        final last = loaded.last.when;
        _stickyDayMs = DateTime(
          last.year,
          last.month,
          last.day,
        ).millisecondsSinceEpoch;
      }
    });
    // if a search is active, recompute matches against the fresh list.
    if (_searching && _query.isNotEmpty) {
      _onQueryChanged(_query);
    } else if (!_didJump && widget.jumpToUid != null) {
      _didJump = true;
      _jumpToUid(widget.jumpToUid!);
    } else {
      _scrollToEnd(instant: true);
    }
  }

  bool _didJump = false;
  bool _wasReachable = false;
  bool _jumpActive = false;

  // scroll a specific message into view and pulse it, for jump-from-saved.
  void _jumpToUid(String uid) {
    final idx = _messages.indexWhere((m) => m.msgUid == uid);
    if (idx < 0) {
      _scrollToEnd();
      return;
    }
    // the list isn't laid out yet when this fires from the load tail, so a
    // position read here is stale and the jump lands at the bottom. wait a
    // frame, rough-jump so the target builds, wait once more, then ensureVisible
    // on the real context. attach _jumpKey via _jumpIndex so the key lands on
    // the target bubble.
    _jumpActive = true;
    setState(() => _jumpIndex = idx);

    // under lag the list isn't fully laid out after one frame, so a single
    // rough-jump lands short and the target's context never builds. poll: each
    // frame, jump to the running estimate; once the scroll extent stops growing
    // the list is built, then ensureVisible on the real context.
    var attempts = 0;
    double lastMax = -1;
    void step() {
      if (!mounted || !_scrollReady) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      final frac = (_messages.length - 1 - idx) / _messages.length;
      final approx = (frac * max - _scrollCtrl.position.viewportDimension * 0.3)
          .clamp(0.0, max);
      _safeJump(approx);
      final ctx = _jumpKey.currentContext;
      final settled = (max - lastMax).abs() < 1.0 && attempts > 1;
      lastMax = max;
      attempts++;
      if ((ctx != null && settled) || attempts > 8) {
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            alignment: 0.4,
          );
        }
        // start the pulse after the scroll lands so the full 820ms plays on
        // the settled message, not during the jump.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _rippleUid = uid);
        });
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => step());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => step());
    Future.delayed(const Duration(milliseconds: 2600), () {
      _jumpActive = false;
      if (mounted && _rippleUid == uid) setState(() => _rippleUid = null);
    });
  }

  // hasClients is not enough: the controller attaches before the list has
  // been laid out, and a jump then reads a null minScrollExtent - which takes
  // the whole chat screen down with it.
  // .position asserts exactly one attached scroll view, and during a route
  // transition two can be attached at once - the assert then throws mid
  // layout, which paints nothing and looks like a dead conversation.
  // .positions is the safe plural form.
  bool get _scrollReady =>
      _scrollCtrl.positions.length == 1 &&
      _scrollCtrl.positions.first.hasContentDimensions;

  void _safeJump(double to) {
    if (_scrollReady) _scrollCtrl.jumpTo(to);
  }

  void _scrollToEnd({bool instant = false}) {
    if (_jumpActive) return;
    // reversed list: the newest message lives at offset 0, so "scroll to end"
    // is just jump/animate to 0. no post-layout settling needed - the list is
    // naturally pinned to the bottom.
    if (!_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollReady) _scrollCtrl.jumpTo(0);
      });
      return;
    }
    if (instant) {
      _safeJump(0);
    } else {
      if (!_scrollReady) return;
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // the global receiver in main.dart owns the engine inbox and routes every
  // incoming message through _applyIncomingPayload (which handles reactions,
  // previews, unsends and empty-body control frames correctly). this used to
  // drain the same inbox in parallel and save control frames as blank stub
  // bubbles - a race. now it just pulls any new/changed rows from the db.
  Future<void> _checkInbox() async {
    if (!_loaded || _searching) return;
    // cheap tick: pull only rows strictly newer than our newest by rowid and
    // append them. never full-reload here - that rebuilds the whole list every
    // second and makes everything blink + snaps the scroll. edits/reactions/
    // previews come through their own refresh paths.
    final lastRowid = _messages.isEmpty
        ? 0
        : _messages.map((m) => m.rowid).reduce((a, b) => a > b ? a : b);
    final rows = await db.messagesAfter(widget.peerHaloId, lastRowid);
    if (!mounted || rows.isEmpty) return;
    final have = _messages.map((m) => m.msgUid).toSet();
    final brandNew = rows
        .where(
          (r) =>
              (r['msg_uid'] as String?) != null &&
              !have.contains(r['msg_uid'] as String?),
        )
        .toList();
    if (brandNew.isEmpty) return;
    // genuinely new rows arrived - let the existing append path build them.
    await _tryAppendNew();
  }

  Future<void> _retry(_Msg msg) async {
    if (_sending) return;
    setState(() {
      msg.failed = false;
      msg.sending = true;
      _status = '';
    });
    // a stranger's opener rides its nonce again. without it the far side's
    // gate dropped every manual retry of a first message, quietly.
    final nonce = msg.msgUid == null ? null : await db.powNonceOf(msg.msgUid!);
    final String cipher;
    try {
      final wrapped = await wrapMessage(
        msg.text,
        msgUid: msg.msgUid,
        powNonce: nonce,
        powBitsUsed: nonce == null ? null : powBits,
        replyTo: msg.replyTo,
        burnSeconds: msg.burnSecs,
        preview: msg.preview,
        secure: msg.secure,
        supporterBadge: await appState.sharedBadge(),
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
    // fire-and-forget. optimistic ✓ now; failure marks tap-to-retry
    // stays in 'sending' until the transport replies below.
    // before the peer back-pairs with us, force direct-onion so their
    // drain triggers the back-pair flow. nostr would dead-end because
    // they aren't subscribed to our xpub yet. once we receive anything
    // from them, _backPaired flips and we can use nostr.
    // try direct tor first if peer hasn't back-paired and we have their onion.
    // on tor failure / timeout, fall back to nostr store-and-forward.
    final sendFuture = Future<String>(() async {
      var torWait = 0;
      while (!_torReadyToSend() && torWait < 300000) {
        await Future.delayed(const Duration(milliseconds: 400));
        torWait += 400;
      }
      if (!_torReadyToSend()) return 'error: tor not ready';
      String? tor;
      if (!_backPaired && widget.peerOnion.isNotEmpty) {
        tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
        if (tor == 'ok') return 'ok';
        dlog('chat send: tor direct failed ($tor), trying nostr');
      }
      // peer xpub may be null on a fresh back-pair / reconnect (it's loaded
      // once at open). re-fetch from the session before giving up, so the relay
      // route is available instead of dead-ending on 'no transport'.
      var xpub = _peerXPub;
      xpub ??= widget.peerXPub.isEmpty ? null : widget.peerXPub;
      xpub ??= await signalSession.peerXPubHex(widget.peerHaloId);
      if (xpub != null) {
        _peerXPub = xpub;
        // before they back-pair, the pair address is one they cannot
        // derive yet. their first-contact address is the only relay
        // route that reaches them.
        final fcPk = appState.peerFcFor(widget.peerHaloId);
        if (!_backPaired && fcPk != null && fcPk.isNotEmpty) {
          final fr = await engine.sendFirstContact(xpub, fcPk, cipher);
          if (fr == 'ok') return 'ok';
          dlog('chat send: first-contact failed ($fr)');
        }
        final r = await Future(() => engine.nostrSend(xpub!, cipher));
        // the pair address is a drop box they read only once they add us
        // back. stored there is not delivered.
        if (r == 'ok' && !_backPaired) return 'parked';
        return r;
      }
      return tor ?? 'error: no transport';
    });
    sendFuture.then((result) async {
      if (result == 'ok' && msg.msgUid != null) {
        await db.markSent(msg.msgUid!);
      }
      if (result == 'ok' && msg.burnSecs != null && msg.msgUid != null) {
        final ba = DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
        await db.setMsgBurnAt(msg.msgUid!, ba);
        msg.burnAt = ba;
      }
      if (!mounted) return;
      if (result == 'ok') {
        setState(() {
          msg.sending = false;
          msg.parked = false;
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
      } else if (result == 'parked') {
        setState(() {
          msg.sending = false;
          msg.parked = true;
        });
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
    showHaloSheet<void>(
      context,
      builder: (ctx) => SafeArea(
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
                  Text(
                    'Ghost timer',
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
                'How long before sent messages burn?',
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
                      _lastBurnSeconds = e.key;
                      _lastGhost = true;
                      appState.saveGhostPref(true, e.key);
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
                          Icon(
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
    _sendChunkedMedia(
      b64: b64,
      msgUid: msgUid,
      caption: msg.text,
      burnSeconds: msg.burnSecs,
      secure: msg.secure,
    ).then((result) => _finishMediaSend(msg, result));
  }

  // resend failed voice / file the same way - re-read from disk, chunk, go.
  Future<void> _retryMedia(_Msg msg) async {
    final path = msg.filePath;
    if (path == null || msg.fileName == null) return;
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
    _sendChunkedMedia(
      b64: b64,
      msgUid: msgUid,
      fileName: msg.fileName!,
      voice: msg.fileName == 'voice.wav',
      voiceDisguised: msg.voiceDisguised,
      burnSeconds: msg.burnSecs,
    ).then((result) => _finishMediaSend(msg, result));
  }

  // bottom sheet: camera or gallery, instead of jumping straight to gallery.
  void _showAttachSheet() {
    HapticFeedback.selectionClick();
    showHaloSheet<void>(
      context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 6),
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: HaloColors.amber,
                  size: 22,
                ),
                title: Text(
                  'Camera',
                  style: HaloType.sans(size: 15, color: HaloColors.text),
                ),
                subtitle: Text(
                  'No exif, never saved to your photos',
                  style: HaloType.mono(size: 10, color: HaloColors.text3),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _openCamera();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: HaloColors.amber,
                  size: 22,
                ),
                title: Text(
                  'Gallery',
                  style: HaloType.sans(size: 15, color: HaloColors.text),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickAndSendMultiple();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.gif_box_outlined,
                  color: HaloColors.amber,
                  size: 22,
                ),
                title: Text(
                  'Gif from phone',
                  style: HaloType.sans(size: 15, color: HaloColors.text),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickAndSendGif();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.attach_file,
                  color: HaloColors.amber,
                  size: 22,
                ),
                title: Text(
                  'File',
                  style: HaloType.sans(size: 15, color: HaloColors.text),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickAndSendFile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _toggleDisguise() {
    setState(() => _disguise = !_disguise);
    appState.saveDisguisePref(_disguise);
    HapticFeedback.selectionClick();
  }

  void _onVoiceComplete(String path, int ms, bool cancelled) {
    if (cancelled || path.isEmpty) return;
    _sendVoice(path, ms);
  }

  Future<void> _sendVoice(String srcPath, int ms) async {
    if (_requestLocked) return;
    if (_requestPending) setState(() => _sentCount++);
    final src = File(srcPath);
    if (!await src.exists()) return;
    var bytes = await src.readAsBytes();
    if (_disguise) bytes = disguiseWav(bytes);
    final msgUid = _newMsgUid();
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final dest = File('${mediaDir.path}/vn_$msgUid.wav');
    await dest.writeAsBytes(bytes);
    final filePath = dest.path;
    final b64 = base64Encode(bytes);
    final msg = _Msg(
      'out',
      '',
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      filePath: filePath,
      fileName: 'voice.wav',
      voiceDisguised: _disguise,
      burnSecs: _ghost ? _burnSeconds : null,
      burnAt: null,
    );
    setState(() {
      _messages.add(msg);
      _normaliseMessages();
      _status = '';
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await db.saveMessage(
      widget.peerHaloId,
      'out',
      '',
      msgUid: msgUid,
      filePath: filePath,
      fileName: 'voice.wav',
      voiceDisguised: _disguise,
      burnAt: msg.burnAt,
      burnSecs: msg.burnSecs,
      sent: 0,
    );
    _sendChunkedMedia(
      b64: b64,
      msgUid: msgUid,
      fileName: 'voice.wav',
      voice: true,
      voiceDisguised: _disguise,
      burnSeconds: _ghost ? _burnSeconds : null,
    ).then((result) => _finishMediaSend(msg, result));
  }

  // rough wire time for a payload. each 16k slice is its own encrypted
  // message with a full tor round trip, call it ~1.1s a slice, and base64
  // inflates the bytes by a third on the way out.
  String _wireEstimate(int bytes) {
    // five slices in flight, about two seconds a round over tor. the old
    // figure was one slice at a time.
    final slices = ((bytes * 4 / 3) / (16 * 1024)).ceil();
    final secs = ((slices / 5).ceil() * 2.2).round();
    if (secs < 20) return 'A few seconds';
    if (secs < 90) return 'Under a minute';
    final mins = (secs / 60).round();
    return 'Roughly $mins min';
  }

  String _humanBytes(int b) {
    if (b < 1024) return '$b b';
    if (b < 1024 * 1024) return '${(b / 1024).round()} kb';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} mb';
  }

  // anything big enough to be a wait gets a confirm first. small stuff goes
  // straight out - a dialog on a 40kb photo would just be noise.
  Future<bool> _confirmBigSend(int bytes, String what) async {
    if (bytes < 512 * 1024) return true;
    if (!mounted) return false;
    final ok = await showHaloSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Text(
                'Send this $what?',
                style: HaloType.serif(size: 19, color: HaloColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                appState.sendMode == 'private'
                    ? '${_humanBytes(bytes)} · ${_wireEstimate(bytes)} over tor'
                    : _humanBytes(bytes),
                style: HaloType.mono(size: 12, color: HaloColors.amber),
              ),
              const SizedBox(height: 6),
              Text(
                'Big files go out in small encrypted pieces, so they take a '
                'while. Keep the app open and it keeps going.',
                style: HaloType.sans(
                  size: 12,
                  color: HaloColors.text2,
                ).copyWith(height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: HaloColors.line),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          'Cancel',
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: HaloColors.amber,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          'Send it',
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.onAmber,
                          ),
                        ),
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
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    return ok == true;
  }

  Future<void> _pickAndSendFile() async {
    final res = await lockState.hold(
      () => FilePicker.pickFiles(withData: true),
    );
    if (res == null || res.files.isEmpty) return;
    final data = res.files.first.bytes;
    final name = res.files.first.name;
    await shredPicked(res);
    if (data == null) return;
    await _sendFileBytes(data, name);
  }

  // the in-app camera: a stripped photo goes through the caption screen like
  // a picked one; a clip goes as a file and its private copy is shredded
  // once it has been read
  Future<void> _openCamera() async {
    final r = await Navigator.of(
      context,
    ).push<CaptureResult>(haloRoute<CaptureResult>(const CameraScreen()));
    if (r == null || !mounted) return;
    if (r.photo != null) {
      final caption = await Navigator.of(
        context,
      ).push<String?>(haloRoute<String?>(_ImageCaptionScreen(bytes: r.photo!)));
      if (caption == null) return;
      await _sendOneImage(r.photo!, caption);
      return;
    }
    final path = r.videoPath;
    if (path == null) return;
    final data = await File(path).readAsBytes();
    await shredFile(path);
    if (!mounted) return;
    await _sendFileBytes(
      data,
      'clip_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  Future<void> _sendFileBytes(Uint8List data, String name) async {
    if (_requestLocked) return;
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, 'File too big · 8 mb max');
      return;
    }
    if (_requestPending) setState(() => _sentCount++);
    if (!await _confirmBigSend(data.length, 'file')) return;
    final msgUid = _newMsgUid();
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${mediaDir.path}/f_${msgUid}_$safe');
    await dest.writeAsBytes(data);
    final filePath = dest.path;
    final b64 = base64Encode(data);
    final msg = _Msg(
      'out',
      '',
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      filePath: filePath,
      fileName: name,
      burnSecs: _ghost ? _burnSeconds : null,
      burnAt: null,
    );
    setState(() {
      _messages.add(msg);
      _normaliseMessages();
      _status = '';
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await db.saveMessage(
      widget.peerHaloId,
      'out',
      '',
      msgUid: msgUid,
      filePath: filePath,
      fileName: name,
      burnAt: msg.burnAt,
      burnSecs: msg.burnSecs,
      sent: 0,
    );
    _sendChunkedMedia(
      b64: b64,
      msgUid: msgUid,
      fileName: name,
      burnSeconds: _ghost ? _burnSeconds : null,
    ).then((result) => _finishMediaSend(msg, result));
  }

  // voice + files went out as one giant envelope - a 5s wav is ~200kb of b64,
  // over every public relay's event cap, so they bounced. this is the same
  // 16kb slicing + per-chunk retries + xpub re-fetch the image path uses.
  // fileName == null means image lane (imageB64), else file lane (fileB64).
  // the shared sender does the work; this hands it what the screen knows
  Future<String> _sendChunkedMedia({
    required String b64,
    required String msgUid,
    String caption = '',
    String? fileName,
    bool voice = false,
    bool voiceDisguised = false,
    int? burnSeconds,
    bool secure = false,
  }) async {
    return sendChunkedMediaTo(
      peerId: widget.peerHaloId,
      peerOnion: widget.peerOnion,
      peerXPub: _peerXPub ?? (widget.peerXPub.isEmpty ? null : widget.peerXPub),
      backPaired: _backPaired,
      needPow: _recvCount == 0 || !await hasSessionWith(widget.peerHaloId),
      b64: b64,
      msgUid: msgUid,
      caption: caption,
      fileName: fileName,
      voice: voice,
      voiceDisguised: voiceDisguised,
      burnSeconds: burnSeconds,
      secure: secure,
      sender: SenderInfo(
        haloId: appState.myId,
        edPub: engine.myEdPubkey(),
        onion: appState.myOnion,
        xPub: engine.myXPubkey(),
        avatar: appState.myAvatar,
      ),
    );
  }

  Future<void> _finishMediaSend(_Msg msg, String result) async {
    // another sender already has this one; its verdict comes later
    if (result == 'busy') return;
    if (msg.msgUid != null) mediaProgressEnd(msg.msgUid!);
    if (result == 'ok' && msg.msgUid != null) await db.markSent(msg.msgUid!);
    if (result == 'ok' && msg.burnSecs != null && msg.msgUid != null) {
      final ba = DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
      await db.setMsgBurnAt(msg.msgUid!, ba);
      msg.burnAt = ba;
    }
    if (!mounted) return;
    setState(() {
      msg.sending = false;
      msg.parked = result == 'parked';
      if (result != 'ok' && result != 'parked') {
        msg.failed = true;
        _status = result;
      }
    });
  }

  Future<void> _pickAndSendGif() async {
    final res = await lockState.hold(
      () => FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['gif'],
      ),
    );
    if (res == null || res.files.isEmpty) return;
    final data = res.files.first.bytes;
    await shredPicked(res);
    if (data == null) return;
    // a gif must NOT be re-encoded (that kills the animation), so it skips the
    // image-quality resize path and sends raw bytes. big gifs choke tor on one
    // un-chunked envelope, so cap at ~4mb until chunked transfer lands.
    // chunked transfer splits big media across envelopes, so gifs can be larger
    // now. still cap to keep send time + memory sane over tor on weak phones.
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, 'Gif too big · 8 mb max');
      return;
    }
    // send raw through the image path - Image.memory animates gifs by the bytes,
    // the .jpg filename doesn't matter.
    await _sendOneImage(data, '');
  }

  Future<void> _sendOneImage(Uint8List bytes, String caption) async {
    // two of anything before they accept, photos included: the third sat
    // at a single tick while the far side held it
    if (_requestLocked) return;
    if (_requestPending) setState(() => _sentCount++);
    final msgUid = _newMsgUid();
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final mediaFile = File('${mediaDir.path}/$msgUid.jpg');
    await mediaFile.writeAsBytes(bytes);
    final mediaPath = mediaFile.path;
    final b64 = base64Encode(bytes);
    // read it once - the toggle is cleared below and the save reads it after.
    final wantSecure = _secureNext;
    final msg = _Msg(
      'out',
      caption,
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      mediaPath: mediaPath,
      burnSecs: _ghost ? _burnSeconds : null,
      burnAt: null,
      secure: wantSecure,
    );
    setState(() {
      _messages.add(msg);
      _normaliseMessages();
      _status = '';
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await db.saveMessage(
      widget.peerHaloId,
      'out',
      caption,
      msgUid: msgUid,
      mediaPath: mediaPath,
      burnAt: msg.burnAt,
      burnSecs: msg.burnSecs,
      sent: 0,
      secure: wantSecure,
    );
    if (wantSecure && mounted) setState(() => _secureNext = false);
    unawaited(
      _sendChunkedMedia(
        b64: b64,
        msgUid: msgUid,
        caption: caption,
        burnSeconds: _ghost ? _burnSeconds : null,
        secure: wantSecure,
      ).then((r) => _finishMediaSend(msg, r)),
    );
  }

  Future<void> _pickAndSendMultiple() async {
    final picked = await lockState.hold(
      () => ImagePicker().pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      ),
    );
    if (picked.isEmpty) return;
    // one photo picked: same preview + caption screen the camera path gets.
    if (picked.length == 1) {
      final bytes = await picked.first.readAsBytes();
      await shredPickedImages(picked);
      if (!mounted) return;
      final caption = await Navigator.of(
        context,
      ).push<String?>(haloRoute<String?>(_ImageCaptionScreen(bytes: bytes)));
      if (caption == null) return;
      await _sendOneImage(bytes, caption);
      return;
    }
    final all = [for (final x in picked) await x.readAsBytes()];
    await shredPickedImages(picked);
    for (final bytes in all) {
      if (!mounted) return;
      await _sendOneImage(bytes, '');
    }
  }

  bool _torReadyToSend() {
    // outside onion nothing is routed through tor, so there is nothing to
    // wait for. waiting anyway is how a working relay looked like a broken
    // app somewhere tor is blocked.
    if (appState.sendMode != 'private') return appState.online;
    final s = appState.torStatus;
    return s == TorStatus.bootstrapped ||
        s == TorStatus.publishing ||
        s == TorStatus.reachable;
  }

  // pull the first http(s) url out of a message, or null.

  // the sender side: a preview fetched over tor by this phone, waiting to
  // ride inside the next message. null when nothing is attached
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
              ? 'Tor is not up yet · sending without'
              : html.startsWith('error:')
              ? "couldn't reach it · sending without"
              : 'No title came back · sending without',
        );
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _pendingPreview = senderPreview(url, title));
    } catch (_) {
      if (mounted) {
        showHaloToast(context, "couldn't fetch it · sending without");
      }
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    // hard stop: a stranger gets 2 messages into the request, then the chat is
    // locked until they accept. the input bar already swaps to a locked state,
    // this guards the send itself so nothing slips past the cap.
    if (_requestLocked) return;
    final msgUid = _newMsgUid();
    final replyToUid = _replyTo?.msgUid;
    // a pending preview only belongs to a message that still holds its link
    final url = firstUrl(text);
    final preview = url != null && _pendingPreview?['url'] == url
        ? _pendingPreview
        : null;
    final msg = _Msg(
      'out',
      text,
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      replyTo: replyToUid,
      burnSecs: _ghost ? _burnSeconds : null,
      burnAt: null,
    );
    msg.preview = preview;
    setState(() {
      _messages.add(msg);
      _normaliseMessages();
      _sending = true;
      _status = '';
      _replyTo = null;
      _pendingPreview = null;
    });
    _msgCtrl.clear();
    _scrollToEnd();
    HapticFeedback.lightImpact();

    try {
      await db.saveMessage(
        widget.peerHaloId,
        'out',
        text,
        burnAt: msg.burnAt,
        burnSecs: msg.burnSecs,
        msgUid: msgUid,
        replyTo: replyToUid,
        sent: 0,
        preview: preview == null ? null : jsonEncode(preview),
      );
    } catch (e) {
      // a throw here used to leave _sending true, which disabled the
      // composer and the auto retry until the chat was reopened
      dlog('send: save failed: $e');
      if (!mounted) return;
      setState(() {
        msg.sending = false;
        msg.failed = true;
        _sending = false;
      });
      return;
    }
    // the home row moves up on what you sent too, not only on what arrived
    unawaited(appState.refreshContacts());
    // first-contact proof-of-work: grind a nonce (~2s, off the ui thread) while
    // the peer hasn't back-paired with us. until they reply they still see us as
    // a stranger and their gate requires the pow. once _peerEngaged flips we stop.
    // keyed off _peerEngaged not _accepted: _accepted defaults true (avoids a
    // banner flash) and races the db load, so it would skip the grind on a fast
    // first send. seed is the raw text - matches the receiver's verifyPow.
    int? powNonce;
    final String cipher;
    try {
      // a fresh session is an opener whatever the history: the far side
      // may have let us go and its gate asks again
      final fresh = !await hasSessionWith(widget.peerHaloId);
      if (_recvCount == 0 || fresh) {
        final n = await compute(_grindPowTask, text);
        powNonce = n;
        // kept on the row so a retry from the outbox carries the same nonce
        await db.setPowNonce(msgUid, n);
      }
      final wrapped = await wrapMessage(
        text,
        powNonce: powNonce,
        powBitsUsed: powNonce == null ? null : powBits,
        burnSeconds: _ghost ? _burnSeconds : null,
        msgUid: msgUid,
        replyTo: replyToUid,
        preview: preview,
        supporterBadge: await appState.sharedBadge(),
        sender: SenderInfo(
          haloId: appState.myId,
          edPub: engine.myEdPubkey(),
          onion: appState.myOnion,
          xPub: engine.myXPubkey(),
        ),
      );
      final prev = _encryptGate;
      final gate = Completer<void>();
      _encryptGate = gate.future;
      try {
        await prev;
        cipher = await signalEncryptSerial(widget.peerHaloId, wrapped);
      } finally {
        gate.complete();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.sending = false;
        msg.failed = true;
        _sending = false;
        _status = 'No signal session - re-pair';
      });
      return;
    }
    // fire-and-forget. optimistic ✓ now; failure marks tap-to-retry
    setState(() {
      _sending = false;
      _status = '';
      if (_requestPending) _sentCount++;
    });
    // before the peer back-pairs with us, force direct-onion so their
    // drain triggers the back-pair flow. nostr would dead-end because
    // they aren't subscribed to our xpub yet. once we receive anything
    // from them, _backPaired flips and we can use nostr.
    // try direct tor first if peer hasn't back-paired and we have their onion.
    // on tor failure / timeout, fall back to nostr store-and-forward.
    final sendFuture = Future<String>(() async {
      var torWait = 0;
      while (!_torReadyToSend() && torWait < 300000) {
        await Future.delayed(const Duration(milliseconds: 400));
        torWait += 400;
      }
      if (!_torReadyToSend()) return 'error: tor not ready';
      String? tor;
      if (!_backPaired && widget.peerOnion.isNotEmpty) {
        tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
        if (tor == 'ok') return 'ok';
        dlog('chat send: tor direct failed ($tor), trying nostr');
      }
      // peer xpub may be null on a fresh back-pair / reconnect (it's loaded
      // once at open). re-fetch from the session before giving up, so the relay
      // route is available instead of dead-ending on 'no transport'.
      var xpub = _peerXPub;
      xpub ??= widget.peerXPub.isEmpty ? null : widget.peerXPub;
      xpub ??= await signalSession.peerXPubHex(widget.peerHaloId);
      if (xpub != null) {
        _peerXPub = xpub;
        // before they back-pair, the pair address is one they cannot
        // derive yet. their first-contact address is the only relay
        // route that reaches them.
        final fcPk = appState.peerFcFor(widget.peerHaloId);
        if (!_backPaired && fcPk != null && fcPk.isNotEmpty) {
          final fr = await engine.sendFirstContact(xpub, fcPk, cipher);
          if (fr == 'ok') return 'ok';
          dlog('chat send: first-contact failed ($fr)');
        }
        final r = await Future(() => engine.nostrSend(xpub!, cipher));
        // the pair address is a drop box they read only once they add us
        // back. stored there is not delivered.
        if (r == 'ok' && !_backPaired) return 'parked';
        return r;
      }
      return tor ?? 'error: no transport';
    });
    sendFuture.then((result) async {
      if (result == 'ok' && msg.msgUid != null) {
        await db.markSent(msg.msgUid!);
      }
      if (result == 'ok' && msg.burnSecs != null && msg.msgUid != null) {
        final ba = DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
        await db.setMsgBurnAt(msg.msgUid!, ba);
        msg.burnAt = ba;
      }
      if (!mounted) return;
      if (result == 'ok') {
        setState(() {
          msg.sending = false;
          msg.parked = false;
          if (msg.burnSecs != null) {
            msg.burnAt =
                DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
          }
        });
        if (msg.burnAt != null) {
          await db.setMsgBurnAt(msgUid, msg.burnAt!);
        }
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
        });
      } else if (result == 'parked') {
        setState(() {
          msg.sending = false;
          msg.parked = true;
        });
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
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollReady) return;
      if (MediaQuery.of(context).viewInsets.bottom > 0) {
        // reversed list: bottom (newest) is offset 0.
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // mirror groups: when we leave the app, this chat is no longer the
    // one being read, so incoming messages must bump the unread dot
    // instead of being silently marked read. dispose() alone missed
    // this because leaving to home doesn't dispose the chat.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      if (currentChatPeer == widget.peerHaloId) currentChatPeer = null;
    } else if (state == AppLifecycleState.resumed) {
      // only re-claim "this chat is open" if we're actually the visible route.
      // without the check, backing out to home and resuming later left this
      // peer marked as open forever, and their unread dot never lit again.
      final visible = ModalRoute.of(context)?.isCurrent ?? false;
      if (!visible) {
        if (currentChatPeer == widget.peerHaloId) currentChatPeer = null;
        return;
      }
      currentChatPeer = widget.peerHaloId;
      db.clearUnread(widget.peerHaloId).then((_) => appState.refreshContacts());
      _reconcileSending();
    }
  }

  // a send that finished while we were backgrounded may have marked the db
  // sent without clearing the in-memory spinner (the !mounted guard skips the
  // setState). on resume, sync stuck spinners back from the db.
  Future<void> _reconcileSending() async {
    final stuck = _messages
        .where((m) => m.direction == 'out' && m.sending && m.msgUid != null)
        .toList();
    if (stuck.isEmpty) return;
    var changed = false;
    for (final m in stuck) {
      if (await db.isSent(m.msgUid!)) {
        m.sending = false;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void deactivate() {
    // popped or covered: stop claiming this chat is the one being read, so a
    // message arriving right after we leave still lights the home dot.
    if (currentChatPeer == widget.peerHaloId) currentChatPeer = null;
    super.deactivate();
  }

  // any message in this conversation the sender marked. one is enough:

  // android's flag is per-window, not per-view.

  Widget _buildRow(BuildContext c, int i, bool searchActive) {
    final ix = _messages.length - 1 - i;
    final m = _messages[ix];
    // a leaked empty control message (an old reaction/preview frame that fell
    // through) renders as a blank stub bubble. skip anything with no content.
    if (m.text.isEmpty &&
        m.mediaPath == null &&
        m.filePath == null &&
        m.preview == null) {
      return const SizedBox.shrink();
    }
    String? quoted;
    String? quotedAuthor;
    if (m.replyTo != null) {
      final original = _byUid[m.replyTo];
      if (original == null) {
        quoted = 'Message unavailable';
      } else {
        quotedAuthor = original.direction == 'out' ? 'you' : 'them';
        if (original.text.isNotEmpty) {
          quoted = original.text;
        } else if (original.mediaPath != null) {
          quoted = 'photo';
        } else if (original.fileName == 'voice.wav') {
          quoted = 'voice message';
        } else if (original.fileName != null) {
          quoted = original.fileName;
        } else {
          quoted = 'Message unavailable';
          quotedAuthor = null;
        }
      }
    }
    final isMatch = searchActive && _matchSet.contains(ix);
    final isCurrent =
        searchActive && _matches.isNotEmpty && _matches[_matchPos] == ix;
    final dimmed = searchActive && !isMatch;
    final showDate = ix == 0 || !_sameDay(_messages[ix - 1].when, m.when);
    final prevMsg = ix > 0 ? _messages[ix - 1] : null;
    final nextMsg = ix < _messages.length - 1 ? _messages[ix + 1] : null;
    bool sameRun(_Msg? o) =>
        o != null &&
        o.direction == m.direction &&
        !o.removing &&
        _sameDay(o.when, m.when) &&
        (m.when.difference(o.when).inSeconds).abs() < 120;
    final firstInGroup = !sameRun(prevMsg) || ix == _firstUnreadIndex;
    final lastInGroup = !sameRun(nextMsg);
    return RepaintBoundary(
      child: Column(
        key: ObjectKey(m),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDate) _dateDivider(m.when, m.msgUid ?? 'r${m.rowid}'),
          if (ix == _firstUnreadIndex) _newMessagesDivider(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: m.removing ? 0.0 : 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: SwipeToReply(
              onReply: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _replyTo = m;
                  _replyFlash = m;
                });
                Future.delayed(const Duration(milliseconds: 700), () {
                  if (mounted && identical(_replyFlash, m)) {
                    setState(() => _replyFlash = null);
                  }
                });
              },
              child: SizedBox(
                width: double.infinity,
                child: AnimatedScale(
                  scale: m.removing ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                  child: AnimatedOpacity(
                    opacity:
                        (m.removing ||
                            (m.msgUid != null && m.msgUid == _liftedUid))
                        ? 0.0
                        : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: _Bubble(
                      key: isMatch
                          ? _matchKeys[i]
                          : (i == _jumpIndex ? _jumpKey : null),
                      msg: m,
                      linkTitle: m.preview?['title'],
                      linkBySender: m.preview?['by'] == 'sender',
                      firstInGroup: firstInGroup,
                      lastInGroup: lastInGroup,
                      revealed: m.msgUid != null && m.msgUid == _revealedUid,
                      onReveal: m.msgUid == null
                          ? null
                          : () => setState(
                              () => _revealedUid = _revealedUid == m.msgUid
                                  ? null
                                  : m.msgUid,
                            ),
                      onRetry: (m) {
                        m.autoRetries = 0;
                        m.gaveUp = false;
                        _retryAny(m);
                      },
                      onLongPress: (ctx) => _showEmojiPickerAt(ctx, m),
                      secure: m.secure,
                      quotedText: quoted,
                      onQuoteTap: m.replyTo == null
                          ? null
                          : () {
                              for (final x in _messages) {
                                if (x.msgUid != null && x.msgUid == m.replyTo) {
                                  _scrollToMessage(x);
                                  break;
                                }
                              }
                            },
                      quotedAuthor: quotedAuthor,
                      query: searchActive ? _query : '',
                      isCurrentMatch: isCurrent,
                      dimmed: dimmed,
                      ripple:
                          m.msgUid != null &&
                          (m.msgUid == _rippleUid || identical(m, _replyFlash)),
                    ),
                  ),
                ),
              ),
            ),
            builder: (_, f, child) => ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: f,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // the whole-conversation lock is gone. protection now lives in the viewer,
  // so a marked photo is covered and the chat around it stays usable.
  void _applySecureContent() {}

  @override
  void dispose() {
    _pollTimer?.cancel();
    _autoRetryTimer?.cancel();
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
    _stickyHideTimer?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.removeListener(_updateSticky);
    _stickyLabel.dispose();
    _stickyShown.dispose();
    _scrollCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openMediaGallery() async {
    final rows = await db.messagesFor(widget.peerHaloId);
    final paths = <String>[];
    final securePaths = <String>{};
    for (final r in rows) {
      final mp = r['media_path'] as String?;
      if (mp != null && mp.isNotEmpty && await File(mp).exists()) {
        paths.add(mp);
        if ((r['secure'] as int? ?? 0) == 1) securePaths.add(mp);
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      haloRoute(
        MediaGalleryScreen(
          paths: paths.reversed.toList(),
          securePaths: securePaths,
          title: _nickname ?? widget.peerHaloId,
        ),
      ),
    );
  }

  Future<void> _chatActions() async {
    final contact = await db.getContact(widget.peerHaloId);
    final pinned = (contact?['pinned'] as int? ?? 0) == 1;
    if (!mounted) return;
    final action = await showHaloSheet<String>(
      context,
      scroll: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: staggerAll([
              const SheetHandle(),
              // the person themselves: name, verification, vouches, media,
              // all on one page now
              InkWell(
                onTap: () => Navigator.pop(ctx, 'contact'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: HaloColors.amber,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'View contact',
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
              ),
              _IntroduceRow(
                enabled: _accepted,
                onTap: () => Navigator.pop(ctx, 'introduce'),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx, 'photos'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 18,
                        color: HaloColors.text2,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Shared photos',
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
                        _muted ? 'Unmute notifications' : 'Mute notifications',
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
                      Icon(
                        Icons.archive_outlined,
                        size: 18,
                        color: HaloColors.text2,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Archive chat',
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx, 'atmosphere'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: HaloColors.text2,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Wallpaper',
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx, 'clear'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        size: 18,
                        color: HaloColors.text2,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Clear conversation',
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx, 'note'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 18,
                        color: HaloColors.text2,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Note on this contact',
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx, 'pin'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 18,
                        color: HaloColors.text2,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        pinned ? 'Unpin' : 'pin to top',
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
                      Icon(Icons.block, size: 18, color: HaloColors.rose),
                      const SizedBox(width: 14),
                      Text(
                        'Block contact',
                        style: HaloType.sans(size: 14, color: HaloColors.rose),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'contact') {
      _openContact();
    } else if (action == 'verify') {
      _openKeyVerification();
    } else if (action == 'vouchers') {
      await showVouchersSheet(context, widget.peerHaloId);
    } else if (action == 'introduce') {
      await showIntroduceSheet(
        context,
        peerId: widget.peerHaloId,
        peerName: _nickname ?? widget.peerHaloId,
      );
    } else if (action == 'mute') {
      await _toggleMute();
    } else if (action == 'archive') {
      await appState.archive(widget.peerHaloId);
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'block') {
      await _blockContact();
    } else if (action == 'clear') {
      await _clearConversation();
    } else if (action == 'atmosphere') {
      await _pickAtmosphere();
    } else if (action == 'note') {
      await _editNote();
      final c = await db.getContact(widget.peerHaloId);
      if (mounted) setState(() => _note = c?['note'] as String?);
    } else if (action == 'pin') {
      await _toggleContactPin();
    } else if (action == 'photos') {
      await _openMediaGallery();
    }
  }

  // the page for this person. the head taps land here, and the chat's own
  // state reloads on the way back since a nickname or block may have changed
  Future<void> _openContact() async {
    await Navigator.of(context).push(
      haloRoute(
        ContactScreen(
          haloId: widget.peerHaloId,
          avatarSeed: widget.avatarSeed,
          peerXPub: widget.peerXPub,
          face: _peerFace,
        ),
      ),
    );
    if (!mounted) return;
    final c = await db.getContact(widget.peerHaloId);
    if (!mounted) return;
    setState(() {
      _nickname = c?['nickname'] as String?;
      _muted = (c?['muted'] as int? ?? 0) == 1;
      _verified = (c?['verified'] as int? ?? 0) == 1;
      _blocked = (c?['blocked'] as int? ?? 0) == 1;
    });
    unawaited(appState.refreshContacts());
  }

  Future<void> _toggleContactPin() async {
    final contact = await db.getContact(widget.peerHaloId);
    final pinned = (contact?['pinned'] as int? ?? 0) == 1;
    await db.setContactPinned(widget.peerHaloId, !pinned);
    await appState.refreshContacts();
    if (mounted) {
      showHaloToast(context, pinned ? 'Unpinned' : 'pinned to top');
    }
  }

  Future<void> _editNote() async {
    final contact = await db.getContact(widget.peerHaloId);
    final current = (contact?['note'] as String?) ?? '';
    final ctrl = TextEditingController(text: current);
    if (!mounted) return;
    await showHaloSheet<void>(
      context,
      scroll: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(
              'Note on this contact',
              style: HaloType.serif(size: 18, color: HaloColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Just for you. Never sent, never leaves this phone.',
              style: HaloType.sans(size: 12, color: HaloColors.text2),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              cursorColor: HaloColors.amber,
              style: HaloType.serif(
                size: 16,
                italic: true,
                color: HaloColors.text,
              ),
              decoration: InputDecoration(
                hintText: 'A quiet reminder…',
                hintStyle: HaloType.serif(
                  size: 16,
                  italic: true,
                  color: HaloColors.text3,
                ),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () async {
                  await db.setNote(widget.peerHaloId, ctrl.text.trim());
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (mounted) showHaloToast(context, 'Note saved');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Save',
                    style: HaloType.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: HaloColors.amber,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // the sheet previews live: each swatch changes the room behind it, and
  // backing out puts the old one back
  Future<void> _pickAtmosphere() async {
    final before = _atmosphere;
    final picked = await showWallpaperSheet(
      context,
      before,
      onPreview: (a) {
        if (mounted) setState(() => _atmosphere = a);
      },
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _atmosphere = before);
      return;
    }
    HapticFeedback.selectionClick();
    await db.setAtmosphere(widget.peerHaloId, picked.name);
    if (!mounted) return;
    setState(() => _atmosphere = picked);
  }

  Future<void> _clearConversation() async {
    final confirm = await showHaloSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Text(
                'Clear this conversation?',
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                'Every message here is erased from this phone. This only '
                'clears your copy - it does not touch their device.',
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'Cancel',
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Clear',
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: HaloColors.rose,
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
    HapticFeedback.selectionClick();
    await db.clearConversation(widget.peerHaloId);
    await appState.refreshContacts();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _normaliseMessages();
    });
  }

  void _openKeyVerification() {
    Navigator.of(context).push(
      haloRoute(
        KeyVerificationScreen(
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
    final confirm = await showHaloSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Row(
                children: [
                  Icon(Icons.block, size: 15, color: HaloColors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Block this contact?',
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
                'Their messages stop arriving and they disappear from your chats. '
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
                      'Cancel',
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Block',
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

  Future<void> _acceptRequestPeer() async {
    HapticFeedback.selectionClick();
    await db.acceptRequest(widget.peerHaloId);
    await appState.afterAccept(widget.peerHaloId);
    if (mounted) {
      setState(() {
        _accepted = true;
        _flag = null;
      });
    }
  }

  Future<void> _declineRequestPeer() async {
    HapticFeedback.selectionClick();
    await db.declineRequest(widget.peerHaloId);
    await appState.refreshContacts();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _blockRequestPeer() async {
    HapticFeedback.selectionClick();
    await appState.block(widget.peerHaloId);
    await db.clearUnread(widget.peerHaloId);
    await appState.refreshContacts();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleSaved(_Msg m) async {
    if (m.msgUid == null) return;
    final next = !m.saved;
    setState(() => m.saved = next);
    await db.setSaved(m.msgUid!, next);
    if (mounted) {
      showHaloToast(context, next ? 'Saved' : 'Removed from saved');
    }
  }

  Future<void> _forwardMessage(_Msg m) async {
    final targets = appState.contacts.where((c) => !c.blocked).toList();
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
                'Forward to',
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
                  'No contacts to forward to',
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
          avatarChoice: (row['avatar'] as num?)?.toInt(),
          initialText: m.text,
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // reversed list: bottom is offset 0, so 'scrolled up from bottom' is
    // simply pixels past a threshold.
    final show = pos.pixels > 240;
    if (!show) _seenCount = _messages.length;
    if (show != _showScrollDown && mounted) {
      setState(() => _showScrollDown = show);
    }
  }

  void _scrollToBottom() {
    if (!_scrollReady) return;
    setState(() => _seenCount = _messages.length);
    // reversed list: newest sits at offset 0.
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _lastSticky = DateTime.fromMillisecondsSinceEpoch(0);
  void _updateSticky() {
    if (_suppressSticky || !_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.maxScrollExtent <= 0) return;
    // throttle: this does a layout query per day-divider, and the raw scroll
    // stream fires many times a frame. cap it to ~10x a second so a fast flick
    // doesn't drown in geometry work (that was the scroll lag).
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
                ? SearchHead(
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
                    note: _note,
                    verified: _verified,
                    supporterBadge: _peerBadge,
                    onBlock: _openContact,
                    onMore: _chatActions,
                    avatarSeed: widget.avatarSeed,
                    face: _peerFace,
                    onBack: () => Navigator.pop(context),
                    onSearch: _openSearch,
                    onRename: _openContact,
                    pinnedCount: _messages.where((m) => m.pinned).length,
                    onPinned: _showPinnedSheet,
                  ),
            if (_messages.any((m) => m.pinned))
              _PinnedBar(
                message: _messages.lastWhere((m) => m.pinned),
                onTap: () =>
                    _scrollToMessage(_messages.lastWhere((m) => m.pinned)),
              ),
            if (_flag != null && !_accepted)
              const SizedBox.shrink()
            else if (_vouched && !_accepted && _recvCount == 0)
              _IntroBanner(
                names: _voucherNames,
                seed: _voucherSeed!,
                avatar: _voucherAvatar,
                verified: _voucherVerified,
              )
            else if (_requestPending && _sentCount > 0)
              const _RequestBanner(),
            if (_keyChanged)
              _KeyChangedBanner(
                peerName: _nickname ?? widget.peerHaloId,
                onVerify: _openKeyVerification,
                onDismiss: _dismissKeyChanged,
              ),
            Expanded(
              child: AtmoScope(
                atmo: _atmosphere,
                child: Stack(
                  key: _listKey,
                  children: [
                    if (_atmosphere != Atmo.none)
                      Positioned.fill(child: AtmosphereWash(_atmosphere)),
                    !_loaded
                        ? const SizedBox.shrink()
                        : _messages.isEmpty
                        ? const _EmptyConversation()
                        : ListView.builder(
                            controller: _scrollCtrl,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (c, i) {
                              // one unbuildable message must never cost
                              // the whole conversation. draw a stub and
                              // carry on.
                              try {
                                return _buildRow(c, i, searchActive);
                              } catch (e) {
                                dlog('bubble failed: $e');
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
                                  Semantics(
                                    label: 'Jump to the newest',
                                    button: true,
                                    child: GestureDetector(
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
                                              color: HaloColors.amber
                                                  .withValues(alpha: 0.18),
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
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
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
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
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
                                          color: HaloColors.surface2.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: HaloColors.line,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: HaloType.serif(
                                            size: 12,
                                            italic: true,
                                            color: HaloColors.text2,
                                            weight: FontWeight.w300,
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
            ),
            if (_friendlyStatus(_status).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _friendlyStatus(_status),
                  style: HaloType.mono(size: 10, color: HaloColors.amber),
                ),
              ),
            // tor still warming: say so where the eye already is. messages
            // typed now are queued and go out the moment the route is up.
            if (appState.sendMode == 'private' && !_torReadyToSend())
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TorHalo(),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Building a private route · first connect is the slow '
                        'one, later ones are quick. Anything you send now is '
                        'queued and delivers itself.',
                        style: HaloType.sans(
                          size: 10.5,
                          color: HaloColors.text2,
                        ).copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            if (_flag != null && !_accepted && !_blocked)
              NoticeBanner(
                glyph: NoticeGlyph.shield,
                text: _flag!.headline,
                color: HaloColors.rose,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                onTap: _openShield,
              )
            else if (_shieldClean && !_accepted && !_blocked)
              // the calm state. same banner, softest colour, nothing to tap
              NoticeBanner(
                glyph: NoticeGlyph.shield,
                text: 'Looks safe · nothing suspicious in their first message',
                color: HaloColors.text2,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
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
            IncomingMediaBanner(chatKey: widget.peerHaloId),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(
                  _blocked
                      ? 'bar_blocked'
                      : _incomingRequest
                      ? 'bar_request'
                      : _requestLocked
                      ? 'bar_locked'
                      : 'bar_composer',
                ),
                child: _blocked
                    ? _BlockedBar(onUnblock: _unblockContact)
                    : _incomingRequest
                    ? _AcceptRequestBar(
                        introducer: _vouched ? vouchNames(_voucherNames) : null,
                        onAccept: _acceptRequestPeer,
                        onDecline: _declineRequestPeer,
                        onBlock: _blockRequestPeer,
                      )
                    : _requestLocked
                    ? const _RequestLockBar()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _msgCtrl,
                            // offered only while tor is up: the fetch goes
                            // over tor or not at all, so without it there is
                            // nothing to offer
                            builder: (_, v, _) => PreviewStrip(
                              url: sendLinkPreviews && _accepted && _torUp
                                  ? firstUrl(v.text)
                                  : null,
                              pending: _pendingPreview,
                              busy: _previewBusy,
                              onAdd: _addPreview,
                              onDrop: () =>
                                  setState(() => _pendingPreview = null),
                            ),
                          ),
                          _Composer(
                            onAttach: _showAttachSheet,
                            onCamera: _openCamera,
                            ghost: _ghost,
                            secure: _secureNext,
                            onToggleSecure: () {
                              HapticFeedback.selectionClick();
                              setState(() => _secureNext = !_secureNext);
                              showHaloToast(
                                context,
                                _secureNext
                                    ? 'The next photo you send opens protected · '
                                          'they cannot screenshot it'
                                    : 'Photo protection off',
                              );
                            },
                            onToggleGhost: () => setState(() {
                              _ghost = !_ghost;
                              _lastGhost = _ghost;
                              appState.saveGhostPref(_ghost, _burnSeconds);
                            }),
                            onPickBurn: _pickBurnDuration,
                            burnSeconds: _burnSeconds,
                            controller: _msgCtrl,
                            sending: _sending,
                            onSend: _send,
                            disguise: _disguise,
                            onToggleDisguise: _toggleDisguise,
                            onVoiceComplete: _onVoiceComplete,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// quick press-down scale for the request buttons.
class _ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleTap({required this.child, required this.onTap});
  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// shown at the bottom of a chat when a stranger has messaged us and we
// haven't accepted them yet. accept opens the chat; decline dismisses quietly.
class _AcceptRequestBar extends StatelessWidget {
  final String? introducer; // set when a friend vouched for them
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;
  const _AcceptRequestBar({
    this.introducer,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            introducer == null
                ? 'Accept to reply - they get one more message in until you do.'
                : '$introducer introduced you. Accept to reply.',
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _reqBtn('block', HaloColors.rose, HaloColors.surface2, onBlock),
              const SizedBox(width: 8),
              _reqBtn(
                'decline',
                HaloColors.text,
                HaloColors.surface2,
                onDecline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _reqBtn(
                  'accept',
                  HaloColors.onAmber,
                  HaloColors.amber,
                  onAccept,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reqBtn(
    String label,
    Color fg,
    Color bg,
    VoidCallback onTap, {
    bool bold = false,
  }) {
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: bg == HaloColors.surface2
              ? Border.all(color: HaloColors.line, width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: HaloType.sans(
            size: 13,
            color: fg,
          ).copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
    );
  }
}

// shown above the thread when a friend introduced this peer and neither side
// has said anything yet. takes the place of the stranger warning.
class _IntroBanner extends StatelessWidget {
  final List<String> names;
  final String seed;
  final int? avatar;
  final bool verified;
  const _IntroBanner({
    required this.names,
    required this.seed,
    this.avatar,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.08),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntroducedBy(
            label: introducedByLine(names),
            seed: seed,
            avatar: avatar,
            verified: verified,
            delay: const Duration(milliseconds: 120),
          ),
          const SizedBox(height: 7),
          Text(
            '${vouchNames(names)} introduced you. Say hello - they got your card too.',
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// the "introduce to..." row in the contact sheet. greyed with a reason while
// the contact is still a request - you cannot vouch for someone you have not
// accepted yourself.
class _IntroduceRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _IntroduceRow({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.people_outline,
              size: 18,
              color: enabled ? HaloColors.amber : HaloColors.text3,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Introduce to...',
                    style: HaloType.sans(
                      size: 14,
                      color: enabled ? HaloColors.text : HaloColors.text3,
                    ),
                  ),
                  if (!enabled)
                    Text(
                      'Accept them first',
                      style: HaloType.mono(size: 9.5, color: HaloColors.text3),
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

// shown above the thread when we're messaging someone who hasn't accepted us.
class _RequestBanner extends StatelessWidget {
  const _RequestBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.08),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 13, color: HaloColors.amber),
              const SizedBox(width: 7),
              Text(
                'Message request',
                style: HaloType.serif(size: 13, color: HaloColors.text),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'They need to accept before you can keep chatting.',
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// replaces the composer once we've hit the 2-message request cap.
class _RequestLockBar extends StatelessWidget {
  const _RequestLockBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 15, color: HaloColors.amber),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Waiting for them to accept your request',
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              ),
            ],
          ),
        ],
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
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 15, color: HaloColors.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You blocked this contact',
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
              'Unblock',
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
  final int? face;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onRename;
  final VoidCallback onBlock;
  final VoidCallback onMore;
  final int pinnedCount;
  final VoidCallback onPinned;
  final bool verified;
  final String? note;
  final String? supporterBadge;
  const _ChatHead({
    required this.haloId,
    this.nickname,
    required this.avatarSeed,
    this.face,
    required this.onBack,
    required this.onSearch,
    required this.onRename,
    required this.onMore,
    required this.onBlock,
    this.pinnedCount = 0,
    required this.onPinned,
    this.verified = false,
    this.note,
    this.supporterBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
            onPressed: onBack,
          ),
          GestureDetector(
            onTap: onBlock, // avatar -> contact actions + verify
            behavior: HitTestBehavior.opaque,
            // the same face flies in from the list row
            child: Hero(
              tag: 'face-$avatarSeed',
              child: KryfoAvatar(seed: avatarSeed, size: 36, choice: face),
            ),
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
                        Icon(
                          Icons.verified_user,
                          size: 13,
                          color: HaloColors.amber,
                        ),
                      ],
                      if (supporterBadge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: HaloColors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: HaloColors.amber.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Supporter',
                            style: HaloType.mono(
                              size: 7.5,
                              color: HaloColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (nickname != null)
                    Text(
                      haloId,
                      style: HaloType.mono(size: 10, color: HaloColors.text2),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 10,
                          color: HaloColors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          appState.sendMode == 'balanced'
                              ? 'Encrypted · via relay'
                              : appState.sendMode == 'fast'
                              ? 'Encrypted · direct'
                              : 'Encrypted · over tor',
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((note ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 11,
                            color: HaloColors.amber,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.serif(
                                size: 12,
                                italic: true,
                                color: HaloColors.amber,
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

          if (pinnedCount > 0)
            IconButton(
              tooltip: 'Pin',
              icon: Icon(
                Icons.push_pin_outlined,
                color: HaloColors.amber,
                size: 19,
              ),
              onPressed: onPinned,
            ),
          IconButton(
            tooltip: 'Search this chat',
            icon: Icon(Icons.search_rounded, color: HaloColors.text2, size: 21),
            onPressed: onSearch,
          ),
          IconButton(
            tooltip: 'Contact options',
            icon: Icon(Icons.more_vert, color: HaloColors.text2, size: 21),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

// search bar that replaces the chat header when search is active. slides
// + fades in. magnifier glyph, italic-serif hint, mono match counter, and
// up/down chevrons to jump between hits. matches the search_mockup spec.
class SearchHead extends StatefulWidget {
  final TextEditingController controller;
  final int matchCount;
  final int matchPos; // 1-based; 0 when no matches
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;
  const SearchHead({
    super.key,
    required this.controller,
    required this.matchCount,
    required this.matchPos,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  @override
  State<SearchHead> createState() => _SearchHeadState();
}

class _SearchHeadState extends State<SearchHead> {
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
        decoration: BoxDecoration(
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
                  tooltip: 'Close',
                  icon: Icon(
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
                        Icon(
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
                              hintText: 'Find in conversation',
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
                                      ? 'No matches'
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
                            label: 'Previous match',
                            enabled: widget.matchCount > 0,
                            onTap: widget.onPrev,
                          ),
                          const SizedBox(width: 5),
                          _NavBtn(
                            icon: Icons.keyboard_arrow_down_rounded,
                            label: 'Next match',
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
  final String label;
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: enabled ? HaloColors.amberSoft : HaloColors.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: enabled
                  ? HaloColors.amber.withValues(alpha: 0.45)
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
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  // uids whose entrance animation already played, so a list rebuild doesn't
  // replay it (that was the periodic + on-open blink).
  static final Set<String> _entered = {};
  final _Msg msg;
  final void Function(_Msg)? onRetry;
  final void Function(BuildContext)? onLongPress;
  final bool secure;
  final String? quotedText;
  final String? quotedAuthor;
  final VoidCallback? onQuoteTap;
  // search context: the live query (empty when not searching), whether
  // this bubble is the current hit (gets a soft amber kryfo), and whether
  // it should dim (search active but this isn't a match).
  final String query;
  final bool isCurrentMatch;
  final bool dimmed;
  final bool ripple;
  final bool revealed;
  final VoidCallback? onReveal;
  final bool firstInGroup;
  final bool lastInGroup;
  // a link in the text: the title the sender shipped, if any
  final String? linkTitle;
  final bool linkBySender;
  const _Bubble({
    super.key,
    required this.msg,
    this.onRetry,
    this.onLongPress,
    this.secure = false,
    this.quotedText,
    this.quotedAuthor,
    this.onQuoteTap,
    this.query = '',
    this.isCurrentMatch = false,
    this.dimmed = false,
    this.ripple = false,
    this.revealed = false,
    this.onReveal,
    this.linkTitle,
    this.linkBySender = false,
    this.firstInGroup = true,
    this.lastInGroup = true,
  });

  // builds the message body, underlining query matches in amber. plain
  // Text when there's no active query.
  Widget _body(bool isOut, {bool image = false}) {
    final base = image
        ? HaloType.serif(size: 13.5, italic: true, color: HaloColors.text)
        : HaloType.sans(
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
    final failedShown = _sendLooksFailed(msg);
    final parked = msg.parked && !msg.sending && !msg.failed;
    final pending = msg.sending || (msg.failed && !failedShown);
    final showMeta = isOut && !pending && !failedShown && !parked;
    final showPill = isOut && pending;
    final metaColor = (isOut && !isImage)
        ? HaloColors.onAmber.withValues(alpha: 0.55)
        : HaloColors.text3;
    final remainingMs = msg.burnAt != null
        ? msg.burnAt! - DateTime.now().millisecondsSinceEpoch
        : 9999999;
    final isExpiring = msg.burnAt != null && remainingMs < 900;
    // freshly-sent outgoing bubble: play a one-shot lift-in. the time window
    // keeps it from re-firing on old bubbles when opening or scrolling a chat.
    final justSent =
        isOut &&
        !msg.failed &&
        DateTime.now().difference(msg.when).inMilliseconds < 900;
    // a message's entrance should play once. fresh was never cleared, so every
    // rebuild replayed it (the blink). gate on a seen-set keyed by uid.
    final entranceKey = msg.msgUid ?? '';
    final alreadyPlayed = _Bubble._entered.contains(entranceKey);
    final justArrived = !isOut && !msg.failed && msg.fresh && !alreadyPlayed;
    final willAnimate = (justArrived || (isOut && msg.fresh && !alreadyPlayed));
    if (willAnimate && entranceKey.isNotEmpty) {
      _Bubble._entered.add(entranceKey);
      // insertion-ordered set - drop the oldest so this never grows unbounded
      if (_Bubble._entered.length > 400) {
        _Bubble._entered.remove(_Bubble._entered.first);
      }
    }
    // clear fresh after the entrance plays so a later rebuild can't replay it
    // (that was the residual blink). belt-and-suspenders alongside _entered,
    // and it also covers messages whose uid was null when they arrived.
    if (msg.fresh && willAnimate) {
      Future.delayed(const Duration(milliseconds: 650), () {
        msg.fresh = false;
      });
    }
    return AnimatedOpacity(
      duration: Duration(milliseconds: isExpiring ? 440 : 250),
      curve: Curves.easeOut,
      opacity: dimmed ? 0.28 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (failedShown || parked) && onRetry != null
            ? () => onRetry!(msg)
            : onReveal,
        onLongPress: onLongPress == null ? null : () => onLongPress!(context),
        child: Padding(
          padding: EdgeInsets.only(
            top: firstInGroup ? 4 : 1,
            // a reaction hangs ~13px below the bubble. reserve room so the
            // next message does not overlap and clip the pill.
            bottom: msg.reactions.isNotEmpty ? 16 : (lastInGroup ? 4 : 1),
          ),
          child: Column(
            crossAxisAlignment: isOut
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              _bubbleEntrance(
                isOut: isOut,
                active: isOut ? justSent : justArrived,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    BurnFade(
                      active: isExpiring,
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
                              : isImage
                              ? null
                              : isOut
                              ? HaloColors.amber
                              : atmoBubbleIn(context),
                          gradient: null,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(
                              isOut ? 14 : (lastInGroup ? 4 : 14),
                            ),
                            bottomRight: Radius.circular(
                              isOut ? (lastInGroup ? 4 : 14) : 14,
                            ),
                          ),
                          border: isCurrentMatch
                              ? Border.all(color: HaloColors.amber, width: 1)
                              : null,
                          boxShadow: isCurrentMatch
                              ? [
                                  BoxShadow(
                                    color: HaloColors.amber.withValues(
                                      alpha: 0.28,
                                    ),
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
                        child: IntrinsicWidth(
                          child: Column(
                            crossAxisAlignment: isOut
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (quotedText != null)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onQuoteTap,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? HaloColors.onAmber.withValues(
                                              alpha: 0.1,
                                            )
                                          : HaloColors.amber.withValues(
                                              alpha: 0.08,
                                            ),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Container(
                                            width: 3,
                                            color: isOut
                                                ? HaloColors.onAmber.withValues(
                                                    alpha: 0.7,
                                                  )
                                                : HaloColors.amber,
                                          ),
                                          const SizedBox(width: 9),
                                          Flexible(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    0,
                                                    6,
                                                    10,
                                                    6,
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
                                                        size: 10,
                                                        color: isOut
                                                            ? HaloColors.onAmber
                                                                  .withValues(
                                                                    alpha: 0.85,
                                                                  )
                                                            : HaloColors.amber,
                                                        letter: 0.4,
                                                      ),
                                                    ),
                                                  if (quotedAuthor != null)
                                                    const SizedBox(height: 2),
                                                  Text(
                                                    quotedText!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: HaloType.sans(
                                                      size: 12.5,
                                                      color: isOut
                                                          ? HaloColors.onAmber
                                                                .withValues(
                                                                  alpha: 0.85,
                                                                )
                                                          : HaloColors.text2,
                                                      height: 1.25,
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
                                ),
                              if (msg.fileName == 'voice.wav' &&
                                  msg.filePath != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: _VoiceBubble(
                                    key: ValueKey('vb_${msg.filePath}'),
                                    path: msg.filePath!,
                                    isOut: isOut,
                                    disguised: msg.voiceDisguised,
                                  ),
                                )
                              else if (msg.fileName != null)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (msg.filePath != null) {
                                      lockState.hold(
                                        () => SharePlus.instance.share(
                                          ShareParams(
                                            files: [XFile(msg.filePath!)],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: _fileCard(msg, isOut),
                                  ),
                                ),
                              if (msg.mediaPath != null)
                                GestureDetector(
                                  onTap: () => _openFullImage(
                                    context,
                                    msg.mediaPath!,
                                    secure: msg.secure,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: msg.text.isNotEmpty
                                        ? const BorderRadius.vertical(
                                            top: Radius.circular(14),
                                          )
                                        : BorderRadius.circular(14),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 280,
                                          ),
                                          // the bubble sizes itself with
                                          // IntrinsicWidth, and an Image
                                          // answers that with its own width -
                                          // infinity, until the file decodes.
                                          // pin one so the answer holds either
                                          // way.
                                          child: SizedBox(
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.78,
                                            child: Image.file(
                                              File(msg.mediaPath!),
                                              gaplessPlayback: true,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, e, _) {
                                                dlog(
                                                  'Image failed: '
                                                  '${msg.mediaPath} / $e',
                                                );
                                                return Container(
                                                  height: 120,
                                                  alignment: Alignment.center,
                                                  color: Colors.black26,
                                                  child: Text(
                                                    'Photo unavailable',
                                                    style: HaloType.mono(
                                                      size: 11,
                                                      color: HaloColors.text2,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
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
                                                  if (!pending &&
                                                      !failedShown) ...[
                                                    Text(
                                                      '✓',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        height: 1,
                                                      ),
                                                    ),
                                                    if (msg.delivered) ...[
                                                      const SizedBox(width: 4),
                                                      const Text(
                                                        'Delivered',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'JetBrains Mono',
                                                          fontSize: 8.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
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
                                  crossAxisAlignment: msg.mediaPath != null
                                      ? CrossAxisAlignment.start
                                      : CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.text.isNotEmpty)
                                      _body(
                                        isOut,
                                        image: msg.mediaPath != null,
                                      ),
                                    if (firstUrl(msg.text) case final u?) ...[
                                      const SizedBox(height: 6),
                                      LinkStub(
                                        url: u,
                                        isOut: isOut,
                                        title: linkTitle,
                                        bySender: linkBySender,
                                      ),
                                    ],
                                    if (showMeta && msg.mediaPath == null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (msg.secure) ...[
                                            Icon(
                                              Icons.shield_rounded,
                                              size: 10,
                                              color: metaColor,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
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
                                              'Edited',
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
                                          if (msg.delivered) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              'Delivered',
                                              style: TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w600,
                                                color: metaColor,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                          if (msg.burnAt != null) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons
                                                  .local_fire_department_outlined,
                                              size: 11,
                                              color: metaColor,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              _fmtBurn(msg.burnAt!),
                                              style: HaloType.mono(
                                                size: 9.5,
                                                color: metaColor,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    if (!isOut &&
                                        msg.edited &&
                                        msg.mediaPath == null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Edited',
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          color: HaloColors.amber.withValues(
                                            alpha: 0.55,
                                          ),
                                          fontStyle: FontStyle.italic,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],

                                    // a sent photo has no meta row, so its
                                    // countdown lives here like an incoming one
                                    if (msg.burnAt != null &&
                                        !pending &&
                                        (!showMeta ||
                                            msg.mediaPath != null)) ...[
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
                                                  : HaloColors.amber.withValues(
                                                      alpha: 0.75,
                                                    ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _fmtBurn(msg.burnAt!),
                                              style: HaloType.mono(
                                                size: 9.5,
                                                color: (isOut && !isImage)
                                                    ? HaloColors.onAmber
                                                    : HaloColors.amber
                                                          .withValues(
                                                            alpha: 0.75,
                                                          ),
                                                weight: FontWeight.w600,
                                              ).copyWith(letterSpacing: 0.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (failedShown || parked) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        parked
                                            ? 'Waiting for them to come online or add you back'
                                            : 'Failed · tap to retry',
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 10,
                                          color: HaloColors.onAmber.withValues(
                                            alpha: 0.95,
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
                    ),
                    if (msg.reactions.isNotEmpty)
                      Positioned(
                        // ig-style: hangs below the bubble, on the sender's
                        // side. your own reactions tuck bottom-right, everyone
                        // else's bottom-left. works the same in groups since
                        // it keys off direction, not a two-person assumption.
                        bottom: -13,
                        right: isOut ? 10 : null,
                        left: isOut ? null : 10,
                        child: Wrap(
                          spacing: 3,
                          children: _buildReactionChips(msg),
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
                                        isOut ? 14 : (lastInGroup ? 4 : 14),
                                      ),
                                      bottomRight: Radius.circular(
                                        isOut ? (lastInGroup ? 4 : 14) : 14,
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
              if (revealed)
                Padding(
                  // a reaction pill hangs ~13px below the bubble. when the
                  // timestamp reveals, push it clear so they don't overlap.
                  padding: EdgeInsets.only(
                    top: msg.reactions.isNotEmpty ? 16 : 4,
                    left: 4,
                    right: 4,
                  ),
                  child: Text(
                    _fmtFull(msg.when),
                    style: HaloType.mono(
                      size: 9.5,
                      color: HaloColors.text3,
                      letter: 0.3,
                    ),
                  ),
                ),
              if (showPill) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.msgUid != null &&
                          (msg.mediaPath != null || msg.filePath != null)) ...[
                        SendProgressLabel(msgUid: msg.msgUid!),
                        const SizedBox(width: 6),
                      ],
                      SendPill(mode: _pmFrom(appState.sendMode)),
                    ],
                  ),
                ),
              ],
            ],
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
    return counts.entries.map<Widget>((e) {
      final emoji = e.key;
      final count = e.value;
      // ig-style single pill that sits half over the bubble corner. dark
      // translucent fill, thin ring, soft shadow, emoji + count.
      return _ReactionPop(
        key: ValueKey(emoji),
        popKey: '${m.msgUid}:$emoji',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            // ig-style: emoji on a pill the colour of the chat background, so it
            // reads as a little tab cut below the bubble, not a smudge on top.
            // solid ink (not translucent), no border, no shadow.
            color: HaloColors.ink,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13, height: 1.2)),
              if (count > 1) ...[
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: HaloType.mono(
                    size: 10,
                    color: HaloColors.text2,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }
}

// a reaction chip springing onto the bubble when added. keyed by emoji so
// existing chips keep their state and only a new one animates.
class _ReactionPop extends StatefulWidget {
  final Widget child;
  final String popKey;
  const _ReactionPop({super.key, required this.child, required this.popKey});

  // emojis that have already played their pop. on a chat rebuild we don't want
  // every existing reaction to spring in again (that read as a blink). a chip
  // animates the first time it's seen, then renders settled forever after.
  static final Set<String> _popped = {};

  @override
  State<_ReactionPop> createState() => _ReactionPopState();
}

class _ReactionPopState extends State<_ReactionPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (_ReactionPop._popped.contains(widget.popKey)) {
      _c.value = 1.0; // already animated before - render settled, no blink.
    } else {
      _ReactionPop._popped.add(widget.popKey);
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _c,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
      child: ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: 1.18,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 62,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.18,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 38,
          ),
        ]).animate(_c),
        child: widget.child,
      ),
    );
  }
}

class _PinnedBar extends StatelessWidget {
  final _Msg message;
  final VoidCallback onTap;
  const _PinnedBar({required this.message, required this.onTap});

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
                      'Pinned',
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
      decoration: BoxDecoration(
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
                  'Replying to ${target.direction == 'out' ? 'yourself' : 'them'}',
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
            tooltip: 'Close',
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
// rounded pill, scale + fade entrance. matches kryfo's surface3 + line
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
    // same growth as the menu under it, so the two read as one thing
    final scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_ctrl);
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
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...widget.emojis.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final n = widget.emojis.length;
                  final start = (i / n) * 0.55;
                  final pop = CurvedAnimation(
                    parent: _ctrl,
                    curve: Interval(
                      start,
                      (start + 0.45).clamp(0.0, 1.0),
                      curve: Curves.easeOutBack,
                    ),
                  );
                  return ScaleTransition(
                    scale: pop,
                    child: _EmojiTap(
                      emoji: e,
                      selected: e == widget.selected,
                      onTap: () => widget.onPick(e),
                    ),
                  );
                }),
                Container(
                  width: 0.5,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: HaloColors.line2,
                ),
                Semantics(
                  label: 'Reply',
                  button: true,
                  child: _ActionTap(
                    icon: Icons.reply_rounded,
                    onTap: widget.onReply,
                  ),
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
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HaloColors.amberSoft,
                  border: Border.all(
                    color: HaloColors.amber.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HaloColors.amber.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: HaloColors.amber,
                  size: 25,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Say hi.',
                textAlign: TextAlign.center,
                style: HaloType.serif(
                  size: 24,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Just the two of you, end-to-end encrypted.',
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// pitch-shift a 16-bit pcm wav so the voice is harder to recognize.
// resamples the body by a fixed ratio then plays it back at the original
// rate. moves pitch and formants together (not formant-preserving), so
// label it "harder to recognize", never "anonymous".
Uint8List disguiseWav(Uint8List wav) {
  if (wav.length < 44) return wav;
  // wav header is 44 bytes; samples are 16-bit little-endian after it.
  const headerLen = 44;
  final header = wav.sublist(0, headerLen);
  final body = wav.buffer.asInt16List(
    wav.offsetInBytes + headerLen,
    (wav.length - headerLen) ~/ 2,
  );
  // ratio < 1 keeps more samples = lower, slower-sounding voice once
  // played at the original rate. 0.82 is a noticeable but still-clear drop.
  const ratio = 0.80;
  final outLen = (body.length / ratio).floor();
  final out = Int16List(outLen);
  for (var i = 0; i < outLen; i++) {
    final srcF = i * ratio;
    final i0 = srcF.floor();
    final i1 = (i0 + 1 < body.length) ? i0 + 1 : i0;
    final frac = srcF - i0;
    out[i] = (body[i0] * (1 - frac) + body[i1] * frac).round();
  }
  final outBytes = out.buffer.asUint8List();
  // patch the two little-endian length fields in the header to match.
  final result = Uint8List(headerLen + outBytes.length);
  result.setRange(0, headerLen, header);
  result.setRange(headerLen, result.length, outBytes);
  final dataLen = outBytes.length;
  final riffLen = 36 + dataLen;
  result[4] = riffLen & 0xff;
  result[5] = (riffLen >> 8) & 0xff;
  result[6] = (riffLen >> 16) & 0xff;
  result[7] = (riffLen >> 24) & 0xff;
  result[40] = dataLen & 0xff;
  result[41] = (dataLen >> 8) & 0xff;
  result[42] = (dataLen >> 16) & 0xff;
  result[43] = (dataLen >> 24) & 0xff;
  return result;
}

class _VoiceBubble extends StatefulWidget {
  final String path;
  final bool isOut;
  final bool disguised;
  const _VoiceBubble({
    super.key,
    required this.path,
    required this.isOut,
    this.disguised = false,
  });
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _missing = false;
  bool _playing = false;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;

  @override
  void initState() {
    super.initState();
    // don't call _load() here - it allocates a native media handle per bubble,
    // and a chat with several voice notes exhausts android's codec pool so the
    // later ones fail to play. just check the file exists (cheap); the real
    // load happens lazily on first tap in _toggle.
    _checkExists();
    _player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
      if (st.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        if (mounted) setState(() => _playing = false);
      }
    });
    // only rebuild on position ticks while actually playing. idle bubbles
    // streaming setState every tick was a real scroll cost.
    _player.positionStream.listen((p) {
      if (mounted && _playing) setState(() => _pos = p);
    });
  }

  // flag missing files, and read just the clip length with a throwaway player
  // so the bubble can show the real duration. the probe is disposed right after
  // so we don't hold a codec handle per bubble (holding them all was the
  // exhaustion that stopped later notes playing).
  // duration read once per file, ever. opening a chat with many voice notes used
  // to spin up + tear down a player per bubble and froze weak phones.
  static final Map<String, Duration> _durCache = {};

  Future<void> _checkExists() async {
    if (!await File(widget.path).exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final cached = _durCache[widget.path];
    if (cached != null) {
      if (mounted) setState(() => _dur = cached);
      return;
    }
    // probe just once, off the first frame so it never blocks chat-open layout.
    Future.delayed(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final probe = AudioPlayer();
      try {
        final d = await probe.setFilePath(widget.path);
        if (d != null) {
          _durCache[widget.path] = d;
          if (mounted) setState(() => _dur = d);
        }
      } catch (_) {
      } finally {
        await probe.dispose();
      }
    });
  }

  // called after every list rebuild. a marked message arriving while the chat
  // is open has to turn protection on too, not only one that was already
  // there when it opened.
  Future<void> _load() async {
    // old notes can point at a file that got wiped/moved between installs.
    // flag it so the bubble shows 'audio unavailable' instead of a dead shell.
    if (!await File(widget.path).exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    // setFilePath can fail if the player's native resources got recycled (it
    // happens after a bubble's been alive a while) or the file isn't flushed
    // yet on a just-recorded note. retry a couple times before giving up so the
    // bubble doesn't render as a dead half-shell.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        _dur = await _player.setFilePath(widget.path) ?? Duration.zero;
        if (mounted) setState(() => _ready = true);
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _toggle() async {
    if (!_ready) {
      await _load();
      if (!_ready) return;
    }
    if (_playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isOut ? HaloColors.onAmber : HaloColors.amber;
    final track = widget.isOut
        ? HaloColors.onAmber.withValues(alpha: 0.3)
        : HaloColors.text3.withValues(alpha: 0.4);
    final progress = (_dur.inMilliseconds == 0)
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    final shown = _pos > Duration.zero ? _pos : _dur;
    return GestureDetector(
      onTap: _missing ? null : _toggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 168,
        child: _missing
            ? Row(
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    size: 20,
                    color: fg.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audio unavailable',
                    style: HaloType.mono(
                      size: 11,
                      color: fg.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 26,
                    color: fg,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: track,
                            valueColor: AlwaysStoppedAnimation(fg),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              _fmt(shown),
                              style: HaloType.mono(
                                size: 10,
                                color: widget.isOut
                                    ? HaloColors.onAmber
                                    : HaloColors.text3,
                              ),
                            ),
                            if (widget.disguised) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.theater_comedy_outlined,
                                size: 11,
                                color: widget.isOut
                                    ? HaloColors.onAmber
                                    : HaloColors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Hidden',
                                style: HaloType.mono(
                                  size: 9,
                                  color: widget.isOut
                                      ? HaloColors.onAmber
                                      : HaloColors.amber,
                                ),
                              ),
                            ],
                          ],
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

class _HoldToTalkMic extends StatefulWidget {
  final bool disguise;
  final VoidCallback onToggleDisguise;
  final void Function(String path, int ms, bool cancelled) onComplete;
  const _HoldToTalkMic({
    required this.disguise,
    required this.onToggleDisguise,
    required this.onComplete,
  });
  @override
  State<_HoldToTalkMic> createState() => _HoldToTalkMicState();
}

class _HoldToTalkMicState extends State<_HoldToTalkMic> {
  final _rec = AudioRecorder();
  OverlayEntry? _overlay;
  Timer? _ticker;
  int _ms = 0;
  bool _willCancel = false;
  double _dragDx = 0;
  bool _busy = false;
  bool _live = false;
  String? _path;
  double _bottomInset = 0;
  // the keyboard's height at the moment the hold began: the overlay is in
  // the root overlay, which never sees the keyboard, and drew under it
  double _keyboardInset = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _overlay?.remove();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    if (!await _rec.hasPermission()) {
      _busy = false;
      if (mounted) showHaloToast(context, 'Mic permission needed');
      return;
    }
    // the permission prompt eats the long-press: by the time the user grants,
    // the finger is gone and nothing would ever stop the recording. bail out
    // and let them hold again.
    if (!_live) {
      _busy = false;
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
    _ms = 0;
    _willCancel = false;
    _dragDx = 0;
    HapticFeedback.mediumImpact();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _ms += 100;
      _overlay?.markNeedsBuild();
    });
    if (mounted) {
      final mq = MediaQuery.of(context);
      _bottomInset = mq.padding.bottom;
      _keyboardInset = mq.viewInsets.bottom;
    }
    _overlay = OverlayEntry(builder: (_) => _bar());
    if (mounted) Overlay.of(context).insert(_overlay!);
    _busy = false;
  }

  Future<void> _end() async {
    _ticker?.cancel();
    _ticker = null;
    _overlay?.remove();
    _overlay = null;
    final path = await _rec.stop();
    final ms = _ms;
    final cancel = _willCancel || ms < 400;
    if (cancel) {
      final p = path ?? _path;
      if (p != null) {
        // a cancelled note is still a recording of a voice: shredded
        await shredFile(p);
      }
      HapticFeedback.lightImpact();
      widget.onComplete('', 0, true);
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onComplete(path ?? _path ?? '', ms, false);
  }

  // kill the recording from the bar itself - covers any state where the
  // finger isn't down anymore but the mic is still going.
  void _abort() {
    _willCancel = true;
    _end();
  }

  String get _time {
    final s = _ms ~/ 1000;
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Widget _bar() {
    final cancel = _willCancel;
    // fade the slide hint out as the finger approaches the cancel threshold.
    final slideProgress = (_dragDx / -90).clamp(0.0, 1.0);
    return Positioned(
      left: 0,
      right: 0,
      bottom: _keyboardInset,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 44),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + _bottomInset),
            decoration: BoxDecoration(
              color: HaloColors.surface,
              border: Border(
                top: BorderSide(
                  color: cancel ? HaloColors.rose : HaloColors.line,
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                // pulsing record dot
                TweenAnimationBuilder<double>(
                  key: const ValueKey('rec-dot'),
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeInOut,
                  builder: (_, v, _) => Opacity(
                    opacity: cancel ? 1.0 : v,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HaloColors.rose,
                      ),
                    ),
                  ),
                  onEnd: () => _overlay?.markNeedsBuild(),
                ),
                const SizedBox(width: 12),
                Text(
                  _time,
                  style: HaloType.mono(size: 14, color: HaloColors.text),
                ),
                Expanded(
                  child: cancel
                      ? Center(
                          child: Text(
                            'Release to cancel',
                            style: HaloType.mono(
                              size: 12,
                              color: HaloColors.rose,
                            ),
                          ),
                        )
                      : Transform.translate(
                          offset: Offset(_dragDx * 0.5, 0),
                          child: Opacity(
                            opacity: (1 - slideProgress * 0.7),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: widget.disguise
                                  ? [
                                      Icon(
                                        Icons.theater_comedy_outlined,
                                        size: 14,
                                        color: HaloColors.amber,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Voice hidden · slide to cancel',
                                        style: HaloType.mono(
                                          size: 11,
                                          color: HaloColors.amber,
                                        ),
                                      ),
                                    ]
                                  : [
                                      Icon(
                                        Icons.chevron_left,
                                        size: 16,
                                        color: HaloColors.text3,
                                      ),
                                      Text(
                                        'Slide to cancel',
                                        style: HaloType.mono(
                                          size: 11,
                                          color: HaloColors.text3,
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                ),
                Semantics(
                  label: 'Close',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _abort,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: HaloColors.text2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) {
        _live = true;
        _start();
      },
      onLongPressMoveUpdate: (d) {
        _dragDx = d.offsetFromOrigin.dx.clamp(-160.0, 0.0);
        final wc = d.offsetFromOrigin.dx < -90;
        if (wc != _willCancel) {
          _willCancel = wc;
          if (wc) HapticFeedback.mediumImpact();
        }
        _overlay?.markNeedsBuild();
      },
      onLongPressEnd: (_) {
        _live = false;
        _end();
      },
      child: Icon(Icons.mic_none_rounded, size: 22, color: HaloColors.text2),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool ghost;
  final VoidCallback onToggleGhost;
  final bool secure;
  final VoidCallback onToggleSecure;
  final VoidCallback onPickBurn;
  final int burnSeconds;
  final VoidCallback onAttach;
  final VoidCallback onCamera;
  final bool disguise;
  final VoidCallback onToggleDisguise;
  final void Function(String path, int ms, bool cancelled) onVoiceComplete;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.ghost,
    required this.onToggleGhost,
    required this.secure,
    required this.onToggleSecure,
    required this.onPickBurn,
    required this.burnSeconds,
    required this.onAttach,
    required this.onCamera,
    required this.disguise,
    required this.onToggleDisguise,
    required this.onVoiceComplete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                      bottom: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_outlined,
                          size: 13,
                          color: HaloColors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ghost mode',
                          style: HaloType.serif(
                            size: 12,
                            color: HaloColors.amber,
                            italic: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Messages burn after ${_humanBurn(burnSeconds)}',
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
              PressScale(
                label: 'Timed messages',
                onTap: onToggleGhost,
                onLongPress: onPickBurn,
                scale: 0.88,
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
                              color: HaloColors.amber.withValues(alpha: 0.45),
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
              // shield hidden until it can be verified end to end on a
              // device. the flag, the wire and the viewer are all still
              // wired - only the way to turn it on is gone.
              const SizedBox(width: 10),
              // the camera that keeps its photos inside kryfo
              PressScale(
                label: 'Open the camera',
                onTap: onCamera,
                scale: 0.86,
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 22,
                  color: HaloColors.text2,
                ),
              ),
              const SizedBox(width: 10),
              PressScale(
                label: 'Attach a photo',
                onTap: onAttach,
                scale: 0.86,
                child: Icon(
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
                    hintText: 'Message',
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
                      borderSide: BorderSide(
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
                  final hasText = value.text.trim().isNotEmpty;
                  final canSend = !sending && hasText;
                  // mic and send trade places with a small pop instead of a cut
                  final Widget end = (!hasText && !sending)
                      ? KeyedSubtree(
                          key: const ValueKey('mic'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                label: 'Disguise voice',
                                button: true,
                                child: GestureDetector(
                                  onTap: onToggleDisguise,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      disguise
                                          ? Icons.record_voice_over
                                          : Icons.voice_over_off,
                                      size: 20,
                                      color: disguise
                                          ? HaloColors.amber
                                          : HaloColors.text3,
                                    ),
                                  ),
                                ),
                              ),
                              _HoldToTalkMic(
                                disguise: disguise,
                                onToggleDisguise: onToggleDisguise,
                                onComplete: onVoiceComplete,
                              ),
                            ],
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('send'),
                          child: PressScale(
                            label: 'Send',
                            onTap: canSend ? onSend : null,
                            scale: 0.86,
                            haptic: false, // _send already fires its own impact
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
                                  Icons.arrow_upward,
                                  size: 18,
                                  color: canSend
                                      ? HaloColors.onAmber
                                      : HaloColors.text3,
                                ),
                              ),
                            ),
                          ),
                        );
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: end,
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
class MediaGalleryScreen extends StatelessWidget {
  final List<String> paths;
  // which of them the sender marked. a protected photo must stay protected
  // wherever it is opened from, or the gallery is a second door.
  final Set<String> securePaths;
  final String title;
  const MediaGalleryScreen({
    super.key,
    required this.paths,
    this.securePaths = const {},
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, size: 20),
          color: HaloColors.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Shared photos',
              style: HaloType.serif(size: 17, color: HaloColors.text),
            ),
            Text(
              '${paths.length} ${paths.length == 1 ? 'photo' : 'photos'} · $title',
              style: HaloType.mono(size: 10, color: HaloColors.text3),
            ),
          ],
        ),
      ),
      body: paths.isEmpty
          ? Center(
              child: Text(
                'No photos in this chat yet',
                style: HaloType.sans(size: 13, color: HaloColors.text3),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: paths.length,
              itemBuilder: (context, i) {
                final path = paths[i];
                return GestureDetector(
                  onTap: () => _openFullImage(
                    context,
                    path,
                    secure: securePaths.contains(path),
                  ),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                    filterQuality: FilterQuality.low,
                  ),
                );
              },
            ),
    );
  }
}

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
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back, color: HaloColors.text2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Send photo',
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
                        hintText: 'Add a caption…',
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
                  Semantics(
                    label: 'Send',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop(_ctrl.text.trim());
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HaloColors.amber,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_upward,
                          size: 20,
                          color: HaloColors.onAmber,
                        ),
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

// the receiving side: a softer arrival that slides in from the left and
// settles, distinct from the sender's amber send-off.
Widget _arriveEntrance({required bool active, required Widget child}) {
  if (!active) return child;
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

Widget _bubbleEntrance({
  required bool isOut,
  required bool active,
  required Widget child,
}) {
  if (!active) return child;
  return isOut
      ? _sendOffEntrance(active: true, child: child)
      : _arriveEntrance(active: true, child: child);
}

// a message burning away: the bubble dissolves bottom-up along a rising
// edge while sparks peel off the burn line. one tween drives both.

// map the saved mode string to the pill's enum. private = full tor (3 hops),
// the real route for every message today.
PrivacyMode _pmFrom(String m) => m == 'fast'
    ? PrivacyMode.fast
    : m == 'balanced'
    ? PrivacyMode.normal
    : PrivacyMode.private;

// shown at the top of a chat when a known contact's identity key changed.
// a reinstall looks the same as an attack, so we prompt to verify instead
// of alarming. ok dismisses until the key changes again.
class _KeyChangedBanner extends StatelessWidget {
  final String peerName;
  final VoidCallback onVerify;
  final VoidCallback onDismiss;
  const _KeyChangedBanner({
    required this.peerName,
    required this.onVerify,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.10),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_outlined, size: 15, color: HaloColors.amber),
              const SizedBox(width: 7),
              Text(
                'Security code changed',
                style: TextStyle(
                  color: HaloColors.amber,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '$peerName may have reinstalled, or someone could be impersonating them. Compare safety numbers to be sure.',
            style: TextStyle(
              color: HaloColors.text.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ScaleTap(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'Ok',
                    style: TextStyle(color: HaloColors.text, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScaleTap(
                  onTap: onVerify,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: HaloColors.amber,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      'Verify',
                      style: TextStyle(
                        color: HaloColors.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
