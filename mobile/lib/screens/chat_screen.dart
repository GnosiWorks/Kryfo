// SPDX-License-Identifier: GPL-3.0-or-later
// chat screen. message bubbles, composer, live receive over tor.
// matches 08_complete_spec.html "the everyday" chat tile.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:convert';
import 'key_verification_screen.dart';
import '../signal_session.dart';
import '../message_envelope.dart'
    show
        wrapMessage,
        SenderInfo,
        ReactionFrame,
        EditFrame,
        loadPeerEndpoint,
        grindPow,
        powBits;
import '../theme.dart';
import '../media_progress.dart';
import '../widgets/kryfo_avatar.dart';
import '../main.dart'
    show
        engine,
        db,
        signalEncrypt,
        appState,
        currentChatPeer,
        torGetOnIsolate,
        torGetB64OnIsolate,
        TorHalo;
import '../widgets/motion.dart';
import '../widgets/burn_fade.dart';

// persists last-seen cipher per peer across ChatScreen instances
final Map<String, String> _seenCipherPerPeer = {};
// chunk indices already accepted by the peer, per media msg_uid. lets a
// retry resume instead of re-uploading the whole file over tor.
final Map<String, Set<int>> _chunkDone = {};
// when each resume record was last touched, so a stale one can be dropped.
final Map<String, int> _chunkDoneAt = {};
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
  final String? jumpToUid;

  const ChatScreen({
    super.key,
    required this.peerHaloId,
    required this.peerOnion,
    required this.peerXPub,
    required this.avatarSeed,
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
  bool sending;
  bool failed;
  bool delivered;
  bool edited;
  bool pinned;
  bool removing;
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
    this.sending = false,
    this.failed = false,
    this.edited = false,
    this.pinned = false,
    this.removing = false,
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

void _openFullImage(BuildContext context, String path) {
  // drop the composer's focus first, else popping the viewer restores it and
  // the keyboard springs up over the chat.
  FocusManager.instance.primaryFocus?.unfocus();
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
      .then((_) => FocusManager.instance.primaryFocus?.unfocus());
}

String _friendlyStatus(String raw) {
  if (raw.isEmpty) return '';
  if (!appState.online && raw.startsWith('error:')) {
    return "you are offline · this sends itself when you reconnect";
  }
  if (raw.startsWith('error:') && !appState.torReady) {
    return "still connecting to tor · it'll go out on its own";
  }
  if (raw.startsWith('error: dial:') || raw.contains('host unreachable')) {
    return "couldn't reach them directly · trying the relay instead";
  }
  if (raw.contains('no relays accepted')) {
    return "no relay took it · retrying, nothing is lost";
  }
  if (raw.contains('timeout')) {
    return "took too long · queued for another go";
  }
  if (raw.startsWith('error:')) {
    return "didn't send · it stays queued and retries";
  }
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
      setState(() => _messages.insertAll(0, older));
    } finally {
      _loadingOlder = false;
    }
  }

  void _onScrollPage() {
    if (!_hasMore || !_scrollCtrl.hasClients) return;
    final p = _scrollCtrl.position;
    if (p.pixels > p.maxScrollExtent - 600) _loadOlder();
  }

  final Map<int, GlobalKey> _dayKeys = {};
  final GlobalKey _listKey = GlobalKey();
  final ValueNotifier<String?> _stickyLabel = ValueNotifier(null);
  final ValueNotifier<bool> _stickyShown = ValueNotifier(false);
  int? _stickyDayMs;
  String? _revealedUid;
  Timer? _stickyHideTimer;
  bool _suppressSticky = true;
  final List<_Msg> _messages = [];
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
  int _matchPos = 0;
  final Map<int, GlobalKey> _matchKeys = {};
  final GlobalKey _jumpKey = GlobalKey();
  int? _jumpIndex;
  String? _nickname;
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
  bool get _requestLocked => _requestPending && _sentCount >= 2;
  // receiver-side: a stranger has messaged us and we haven't accepted yet.
  bool get _incomingRequest => !_accepted && _recvCount > 0;
  bool _showScrollDown = false;
  int _seenCount = 0;
  String? _rippleUid;
  _Msg? _replyFlash;
  String? _note;

  @override
  void initState() {
    super.initState();

    if (appState.secureChats) appState.forceSecure(true);
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
        });
      }
    });
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
      final expired = _messages
          .where(
            (m) =>
                m.burnAt != null &&
                m.burnAt! <= now &&
                !m.removing &&
                !m.sending &&
                !m.failed,
          )
          .toList();
      for (final m in expired) {
        m.removing = true;
        // wait for the full _BurnFade dissolve (520ms) before pulling the row,
        // else the animation cuts off and the message pops away.
        Future.delayed(const Duration(milliseconds: 560), () {
          if (mounted) setState(() => _messages.remove(m));
          if (m.msgUid != null) db.deleteMessage(m.msgUid!);
        });
      }
      if (expired.isNotEmpty) HapticFeedback.lightImpact();
      // avoid repainting the whole list every 250ms for a ghost's full life.
      // repaint near the burn moment and once a second for the countdown.
      int? soonest;
      for (final m in _messages) {
        if (m.burnAt == null) continue;
        final r = m.burnAt! - now;
        if (soonest == null || r < soonest) soonest = r;
      }
      // the _BurnFade dissolve animates itself - the timer doesn't need to
      // repaint the whole list every 250ms while a ghost burns (that was the
      // jank). only repaint when something just expired, or once a second for
      // the countdown text.
      final sec = now ~/ 1000;
      final ticked = soonest != null && sec != _lastBurnSec;
      if (expired.isNotEmpty || ticked) {
        _lastBurnSec = sec;
        setState(() {});
      }
    });

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
    setState(() => _messages.addAll(fresh));
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
      // reversed list: newest is at offset 0, so a message at index idx sits at
      // roughly (len-1-idx)/len of the extent.
      final frac = (_messages.length - 1 - idx) / _messages.length;
      final approx = frac * _scrollCtrl.position.maxScrollExtent;
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
    if (!mounted) return;
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
                child: const _MenuBackdrop(),
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
              child: _MenuPop(
                side: alignRight,
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
              child: _MenuPop(
                side: alignRight,
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
                                target.saved ? 'unsave' : 'save',
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
                            'forward',
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
                              'copy',
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
                                Icon(
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
                      InkWell(
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
    FocusManager.instance.primaryFocus?.unfocus();
    if (confirm != true) return;
    if (mounted) setState(() => m.removing = true);
    // let the burn dissolve finish before the row is pulled (was 300ms, cut the
    // 520ms _BurnFade short and looked janky).
    await Future.delayed(const Duration(milliseconds: 560));
    await db.deleteMessage(m.msgUid!);
    if (mounted) setState(() => _messages.remove(m));
    try {
      final wrapped = await wrapMessage('', unsend: m.msgUid);
      final cipher = await signalEncrypt(widget.peerHaloId, wrapped);
      final useDirectOnion = !_backPaired || _peerXPub == null;
      await (useDirectOnion
          ? Future(() => engine.sendTo(widget.peerOnion, cipher))
          : Future(() => engine.nostrSend(_peerXPub!, cipher)));
    } catch (e) {
      debugPrint('unsend send failed: $e');
    }
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
    setState(() => _jumpIndex = idx);
    final max = _scrollCtrl.position.maxScrollExtent;
    final frac = (_messages.length - 1 - idx) / _messages.length;
    final approx = (frac * max - _scrollCtrl.position.viewportDimension * 0.3)
        .clamp(0.0, max);
    _scrollCtrl.jumpTo(approx.clamp(0.0, max));
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
    for (final m in loaded) {
      // under a minute old the send future may still be running in the
      // background - marking it failed here caused dup resends.
      if (torUp &&
          m.direction == 'out' &&
          m.sending &&
          m.when.isBefore(staleCutoff)) {
        m.sending = false;
        m.failed = true;
      }
    }
    setState(() {
      _loaded = true;
      _messages
        ..clear()
        ..addAll(loaded);
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
      if (!mounted || !_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      final frac = (_messages.length - 1 - idx) / _messages.length;
      final approx = (frac * max - _scrollCtrl.position.viewportDimension * 0.3)
          .clamp(0.0, max);
      _scrollCtrl.jumpTo(approx);
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

  void _scrollToEnd({bool instant = false}) {
    if (_jumpActive) return;
    // reversed list: the newest message lives at offset 0, so "scroll to end"
    // is just jump/animate to 0. no post-layout settling needed - the list is
    // naturally pinned to the bottom.
    if (!_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      });
      return;
    }
    if (instant) {
      _scrollCtrl.jumpTo(0);
    } else {
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
    final String cipher;
    try {
      final wrapped = await wrapMessage(
        msg.text,
        msgUid: msg.msgUid,
        replyTo: msg.replyTo,
        burnSeconds: msg.burnSecs,
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
        debugPrint('chat send: tor direct failed ($tor), trying nostr');
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
          debugPrint('chat send: first-contact failed ($fr)');
        }
        return await Future(() => engine.nostrSend(xpub!, cipher));
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
          if (msg.burnSecs != null) {
            msg.burnAt =
                DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
          }
        });
        // preview was lost when the first send failed; re-fetch off-thread so
        // the card comes back on a successful retry.
        final retryUrl = firstUrl(msg.text);
        if (retryUrl != null && msg.preview == null && msg.msgUid != null) {
          unawaited(_enrichPreview(msg, retryUrl, msg.msgUid!));
        }
        loadPeerEndpoint(widget.peerHaloId).then((endpoint) {
          if (endpoint != null && endpoint.isNotEmpty) {
            Future(() => engine.ntfyPing(endpoint));
          }
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
                  Icon(
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
      burnSeconds: msg.burnSecs,
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
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: HaloColors.amber,
                  size: 22,
                ),
                title: Text(
                  'gallery',
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
                  'gif from phone',
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
                  'file',
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
    final slices = ((bytes * 4 / 3) / (16 * 1024)).ceil();
    final secs = (slices * 1.1).round();
    if (secs < 20) return 'a few seconds';
    if (secs < 90) return 'under a minute';
    final mins = (secs / 60).round();
    return 'roughly $mins min';
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
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'send this $what?',
                style: HaloType.serif(size: 19, color: HaloColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                '${_humanBytes(bytes)} · ${_wireEstimate(bytes)} over tor',
                style: HaloType.mono(size: 12, color: HaloColors.amber),
              ),
              const SizedBox(height: 6),
              Text(
                'big files go out in small encrypted pieces, so they take a '
                'while. keep the app open and it keeps going.',
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
                          'cancel',
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
                          'send it',
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
    final res = await FilePicker.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final data = res.files.first.bytes;
    final name = res.files.first.name;
    if (data == null) return;
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, 'file too big · 8 mb max');
      return;
    }
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
  Future<String> _sendChunkedMedia({
    required String b64,
    required String msgUid,
    String caption = '',
    String? fileName,
    bool voice = false,
    bool voiceDisguised = false,
    int? burnSeconds,
  }) async {
    var torWait = 0;
    while (!_torReadyToSend() && torWait < 300000) {
      await Future.delayed(const Duration(milliseconds: 400));
      torWait += 400;
    }
    if (!_torReadyToSend()) return 'error: tor not ready';
    const chunkSize = 16 * 1024;
    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += chunkSize) {
      chunks.add(b64.substring(i, math.min(i + chunkSize, b64.length)));
    }
    final total = chunks.length;
    if (total > 1) mediaProgressStart(msgUid, chatKey: widget.peerHaloId);
    // stranger gate wants pow on every envelope. two grinds max: one for the
    // chunk-0 payload, one for the '' the rest carry.
    int? powCap;
    int? powRest;
    if (_recvCount == 0) {
      powCap = await compute(_grindPowTask, caption);
      powRest = powCap; // caption rides every chunk, one seed fits all
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final since = now - (_chunkDoneAt[msgUid] ?? now);
    if (since > 240000) {
      // too old to trust - the peer may have restarted and lost its buffer.
      _chunkDone.remove(msgUid);
    }
    _chunkDoneAt[msgUid] = now;
    final done = _chunkDone.putIfAbsent(msgUid, () => <int>{});
    if (done.isNotEmpty && total > 1) {
      debugPrint('MEDIA resume $msgUid: ${done.length}/$total already landed');
      mediaProgressUpdate(msgUid, done.length / total);
    }
    for (var i = 0; i < total; i++) {
      if (done.contains(i)) continue; // peer already has this slice
      final String cipher;
      try {
        // name + voice flags ride every slice: the receiver rebuilds off
        // whichever chunk lands last, and that one decides file vs image.
        final wrapped = await wrapMessage(
          caption,
          msgUid: msgUid,
          imageB64: fileName == null ? chunks[i] : null,
          fileB64: fileName != null ? chunks[i] : null,
          fileName: fileName,
          voice: voice,
          voiceDisguised: voiceDisguised,
          mediaId: total > 1 ? msgUid : null,
          chunkIndex: total > 1 ? i : null,
          chunkTotal: total > 1 ? total : null,
          burnSeconds: burnSeconds,
          powNonce: i == 0 ? powCap : powRest,
          powBitsUsed: (i == 0 ? powCap : powRest) == null ? null : powBits,
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
        return 'error: encrypt';
      }
      var sent = false;
      String lastErr = 'error: no transport';
      for (var attempt = 0; attempt < 3 && !sent; attempt++) {
        String? tor;
        if (!_backPaired && widget.peerOnion.isNotEmpty) {
          tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
          if (tor == 'ok') {
            sent = true;
            break;
          }
          if (tor != null) lastErr = tor;
        }
        var xpub = _peerXPub;
        xpub ??= widget.peerXPub.isEmpty ? null : widget.peerXPub;
        xpub ??= await signalSession.peerXPubHex(widget.peerHaloId);
        if (xpub != null) {
          _peerXPub = xpub;
          final r = await Future(() => engine.nostrSend(xpub!, cipher));
          if (r == 'ok') {
            sent = true;
            break;
          }
          lastErr = r;
        }
        if (!sent) await Future.delayed(const Duration(milliseconds: 600));
      }
      if (!sent) {
        debugPrint('MEDIA CHUNK $i/$total failed: $lastErr');
        // keep what landed so tap-to-retry resumes from here.
        return lastErr;
      }
      done.add(i);
      _chunkDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
      mediaProgressUpdate(msgUid, done.length / total);
    }
    // whole file is across - drop the resume record.
    _chunkDone.remove(msgUid);
    _chunkDoneAt.remove(msgUid);
    return 'ok';
  }

  Future<void> _finishMediaSend(_Msg msg, String result) async {
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
      if (result != 'ok') {
        msg.failed = true;
        _status = result;
      }
    });
  }

  Future<void> _pickAndSendGif() async {
    final res = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['gif'],
    );
    if (res == null || res.files.isEmpty) return;
    final data = res.files.first.bytes;
    if (data == null) return;
    // a gif must NOT be re-encoded (that kills the animation), so it skips the
    // image-quality resize path and sends raw bytes. big gifs choke tor on one
    // un-chunked envelope, so cap at ~4mb until chunked transfer lands.
    // chunked transfer splits big media across envelopes, so gifs can be larger
    // now. still cap to keep send time + memory sane over tor on weak phones.
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, 'gif too big · 8 mb max');
      return;
    }
    // send raw through the image path - Image.memory animates gifs by the bytes,
    // the .jpg filename doesn't matter.
    await _sendOneImage(data, '');
  }

  Future<void> _sendOneImage(Uint8List bytes, String caption) async {
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
      burnAt: null,
    );
    setState(() {
      _messages.add(msg);
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
      sent: 0,
    );
    // chunk the base64 so no single envelope exceeds the transport limit. small
    // images stay one chunk and behave exactly as before. big ones split into
    // ~60kb slices that the receiver reassembles by mediaId.
    // 30kb keeps each chunk + envelope overhead under the public relay event
    // size limit (many cap ~32-64kb). bigger chunks got 'no relays accepted'.
    // gift wrap doubles the payload on the wire - 16k keeps the wrapped
    // event under relay size caps.
    const chunkSize = 16 * 1024;
    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += chunkSize) {
      chunks.add(b64.substring(i, math.min(i + chunkSize, b64.length)));
    }
    final total = chunks.length;
    final sendFuture = Future<String>(() async {
      var torWait = 0;
      while (!_torReadyToSend() && torWait < 300000) {
        await Future.delayed(const Duration(milliseconds: 400));
        torWait += 400;
      }
      if (!_torReadyToSend()) return 'error: tor not ready';
      // send each chunk in order. caption + burn ride chunk 0 only so the
      // reassembled message carries them once. any chunk failing fails the send.
      for (var i = 0; i < total; i++) {
        final String cipher;
        try {
          final wrapped = await wrapMessage(
            caption,
            msgUid: msgUid,
            imageB64: chunks[i],
            mediaId: total > 1 ? msgUid : null,
            chunkIndex: total > 1 ? i : null,
            chunkTotal: total > 1 ? total : null,
            // every chunk carries the burn, not just the first: the receiver
            // rebuilds off the last slice to land, and that one used to arrive
            // with no burn at all, so ghost images never expired on their side.
            burnSeconds: _ghost ? _burnSeconds : null,
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
          return 'error: encrypt';
        }
        // each chunk gets a few tries - a single tor hiccup shouldn't kill the
        // whole multi-chunk send (the slow samsung path drops one now and then).
        var sent = false;
        String lastErr = 'error: no transport';
        for (var attempt = 0; attempt < 3 && !sent; attempt++) {
          String? tor;
          if (!_backPaired && widget.peerOnion.isNotEmpty) {
            tor = await Future(() => engine.sendTo(widget.peerOnion, cipher));
            if (tor == 'ok') {
              sent = true;
              break;
            }
            if (tor != null) lastErr = tor;
          }
          var xpub = _peerXPub;
          xpub ??= await signalSession.peerXPubHex(widget.peerHaloId);
          if (xpub != null) {
            _peerXPub = xpub;
            final r = await Future(() => engine.nostrSend(xpub!, cipher));
            if (r == 'ok') {
              sent = true;
              break;
            }
            lastErr = r;
          }
          if (!sent) await Future.delayed(const Duration(milliseconds: 600));
        }
        if (!sent) {
          debugPrint('CHUNK $i/$total failed after retries: $lastErr');
          return lastErr;
        }
      }
      return 'ok';
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
          if (msg.burnSecs != null) {
            msg.burnAt =
                DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
          }
        });
        if (msg.burnAt != null) {
          await db.setMsgBurnAt(msgUid, msg.burnAt!);
        }
      } else {
        setState(() {
          msg.sending = false;
          msg.failed = true;
          _status = result;
        });
      }
    });
  }

  Future<void> _pickAndSendMultiple() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (picked.isEmpty) return;
    // one photo picked: same preview + caption screen the camera path gets.
    if (picked.length == 1) {
      final bytes = await picked.first.readAsBytes();
      if (!mounted) return;
      final caption = await Navigator.of(
        context,
      ).push<String?>(haloRoute<String?>(_ImageCaptionScreen(bytes: bytes)));
      if (caption == null) return;
      await _sendOneImage(bytes, caption);
      return;
    }
    for (final x in picked) {
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      await _sendOneImage(bytes, '');
    }
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
    final caption = await Navigator.of(
      context,
    ).push<String?>(haloRoute<String?>(_ImageCaptionScreen(bytes: bytes)));
    if (caption == null) return;
    await _sendOneImage(bytes, caption);
  }

  bool _torReadyToSend() {
    final s = appState.torStatus;
    return s == TorStatus.bootstrapped ||
        s == TorStatus.publishing ||
        s == TorStatus.reachable;
  }

  // pull the first http(s) url out of a message, or null.

  // fetch a link preview over tor (sender-side, so the receiver never has to
  // fetch and leak their ip). best-effort: any failure just means no card.
  // runs after the message is already sent, updates the row + ui when ready.
  Future<void> _enrichPreview(_Msg msg, String url, String msgUid) async {
    try {
      final html = await torGetOnIsolate(url);
      debugPrint(
        'PREVIEW-FETCH url=$url len=${html.length} head=${html.substring(0, html.length < 60 ? html.length : 60)}',
      );
      if (html.startsWith('error:') || html.isEmpty) {
        return;
      }
      String? grab(String prop) {
        final re = RegExp(
          '<meta[^>]+(?:property|name)=["\']' +
              RegExp.escape(prop) +
              '["\'][^>]+content=["\']([^"\']+)',
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
        return;
      }
      // fetch the thumbnail over tor too and embed the bytes, so the card
      // renders from local data and never leaks an ip to the image host.
      String? imageData;
      if (image != null) {
        try {
          final raw = await torGetB64OnIsolate(image);
          if (raw.startsWith('ok:')) imageData = raw.substring(3);
        } catch (_) {}
      }
      final pv = <String, String>{
        'url': url,
        if (title != null) 'title': unescapeHtml(title),
        if (imageData != null) 'img': imageData,
        if (site != null) 'site': unescapeHtml(site),
      };
      if (!mounted) return;
      // show the full card (with image) live on the sender.
      setState(() => msg.preview = pv);
      // a big base64 image makes jsonEncode + the db write hitch the ui thread.
      // store a capped copy: small images keep their thumbnail, huge ones drop
      // it (card still shows title/site). avoids the send-time lag spike.
      final stored = Map<String, String>.from(pv);
      final simg = stored['img'];
      if (simg != null && simg.length > 80 * 1024) stored.remove('img');
      await db.setMsgPreview(msgUid, jsonEncode(stored));
      // option A: re-send the original message (same uid) now carrying the
      // resolved preview, over the normal message route. the empty-body control
      // frame we used before kept vanishing over tor; a real message rides the
      // reliable path. the peer's receiver dedups on uid - it patches the card
      // onto the bubble it already has instead of making a second one.
      try {
        final pvOut = Map<String, String>.from(pv);
        final img = pvOut['img'];
        // three lanes for the thumbnail: small rides the text card whole;
        // medium gets pulled out and chunked (pvImg); huge drops to text-only.
        const pvWhole = 80 * 1024; // fits one envelope
        const pvChunkCap = 150 * 1024; // above this, not worth the envelopes
        final chunkThumb =
            img != null && img.length > pvWhole && img.length <= pvChunkCap;
        if (img != null && img.length > pvWhole) {
          pvOut.remove('img'); // card goes without img; chunks carry it if any
        }
        debugPrint(
          'PREVIEW-SEND resend uid=$msgUid keys=${pvOut.keys.toList()} chunkThumb=$chunkThumb',
        );
        Future<void> _fire(String cipher) async {
          final useDirectOnion = !_backPaired || _peerXPub == null;
          final f = useDirectOnion
              ? Future(() => engine.sendTo(widget.peerOnion, cipher))
              : Future(() => engine.nostrSend(_peerXPub!, cipher));
          await f;
        }

        // text card first, so the bubble patches instantly.
        final wrapped = await wrapMessage(
          msg.text,
          msgUid: msgUid,
          replyTo: msg.replyTo,
          preview: pvOut,
        );
        await _fire(await signalEncrypt(widget.peerHaloId, wrapped));
        // then the thumbnail as pvImg chunks, reassembled onto the card.
        if (chunkThumb) {
          const cs = 16 * 1024;
          final slices = <String>[];
          for (var i = 0; i < img!.length; i += cs) {
            slices.add(img.substring(i, math.min(i + cs, img.length)));
          }
          final pvid = 'pv_$msgUid';
          for (var i = 0; i < slices.length; i++) {
            final w = await wrapMessage(
              '',
              msgUid: msgUid,
              imageB64: slices[i],
              mediaId: pvid,
              chunkIndex: i,
              chunkTotal: slices.length,
              pvImg: true,
            );
            await _fire(await signalEncrypt(widget.peerHaloId, w));
          }
        }
      } catch (_) {}
    } catch (_) {}
  }

  // minimal html entity cleanup for preview text.

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    // hard stop: a stranger gets 2 messages into the request, then the chat is
    // locked until they accept. the input bar already swaps to a locked state,
    // this guards the send itself so nothing slips past the cap.
    if (_requestLocked) return;
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
      burnAt: null,
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
    await db.saveMessage(
      widget.peerHaloId,
      'out',
      text,
      burnAt: msg.burnAt,
      msgUid: msgUid,
      replyTo: replyToUid,
      sent: 0,
    );
    // best-effort link preview over tor, fire-and-forget so it never delays
    // the send. pops the card in when (if) it resolves.
    final url = firstUrl(text);
    if (url != null) {
      unawaited(_enrichPreview(msg, url, msgUid));
    }
    // first-contact proof-of-work: grind a nonce (~2s, off the ui thread) while
    // the peer hasn't back-paired with us. until they reply they still see us as
    // a stranger and their gate requires the pow. once _peerEngaged flips we stop.
    // keyed off _peerEngaged not _accepted: _accepted defaults true (avoids a
    // banner flash) and races the db load, so it would skip the grind on a fast
    // first send. seed is the raw text - matches the receiver's verifyPow.
    int? powNonce;
    if (_recvCount == 0) {
      powNonce = await compute(_grindPowTask, text);
      debugPrint('pow: ground nonce=$powNonce len=${text.length}');
    }
    final String cipher;
    try {
      final wrapped = await wrapMessage(
        text,
        powNonce: powNonce,
        powBitsUsed: powNonce == null ? null : powBits,
        burnSeconds: _ghost ? _burnSeconds : null,
        msgUid: msgUid,
        replyTo: replyToUid,
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
        cipher = await signalEncrypt(widget.peerHaloId, wrapped);
      } finally {
        gate.complete();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.sending = false;
        msg.failed = true;
        _sending = false;
        _status = 'no signal session - re-pair';
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
        debugPrint('chat send: tor direct failed ($tor), trying nostr');
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
          debugPrint('chat send: first-contact failed ($fr)');
        }
        return await Future(() => engine.nostrSend(xpub!, cipher));
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
      if (!mounted || !_scrollCtrl.hasClients) return;
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

  @override
  void dispose() {
    if (appState.secureChats) appState.forceSecure(false);
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
    for (final r in rows) {
      final mp = r['media_path'] as String?;
      if (mp != null && mp.isNotEmpty && await File(mp).exists()) {
        paths.add(mp);
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      haloRoute(
        MediaGalleryScreen(
          paths: paths.reversed.toList(),
          title: _nickname ?? widget.peerHaloId,
        ),
      ),
    );
  }

  Future<void> _chatActions() async {
    final contact = await db.getContact(widget.peerHaloId);
    final pinned = (contact?['pinned'] as int? ?? 0) == 1;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HaloColors.surface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
                      Icon(
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
                        'shared photos',
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
                      Icon(
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
                        'atmosphere',
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
                        'clear conversation',
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
                        'note on this contact',
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
                        pinned ? 'unpin' : 'pin to top',
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

  Future<void> _toggleContactPin() async {
    final contact = await db.getContact(widget.peerHaloId);
    final pinned = (contact?['pinned'] as int? ?? 0) == 1;
    await db.setContactPinned(widget.peerHaloId, !pinned);
    await appState.refreshContacts();
    if (mounted) {
      showHaloToast(context, pinned ? 'unpinned' : 'pinned to top');
    }
  }

  Future<void> _editNote() async {
    final contact = await db.getContact(widget.peerHaloId);
    final current = (contact?['note'] as String?) ?? '';
    final ctrl = TextEditingController(text: current);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
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
            Text(
              'note on this contact',
              style: HaloType.serif(size: 18, color: HaloColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'just for you. never sent, never leaves this phone.',
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
                hintText: 'a quiet reminder…',
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
                  Navigator.pop(ctx);
                  if (mounted) showHaloToast(context, 'note saved');
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
                    'save',
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

  Future<void> _pickAtmosphere() async {
    final picked = await showModalBottomSheet<Atmo>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'atmosphere',
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'a quiet wash behind this conversation. yours only.',
                style: HaloType.sans(size: 12, color: HaloColors.text2),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: Atmo.values.map((a) {
                  final sel = a == _atmosphere;
                  final accent = atmoAccent(a);
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, a),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: a == Atmo.none
                                ? HaloColors.surface3
                                : accent.withValues(alpha: 0.18),
                            border: Border.all(
                              color: sel ? HaloColors.amber : HaloColors.line,
                              width: sel ? 1.5 : 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: a == Atmo.none
                              ? Icon(
                                  Icons.not_interested,
                                  size: 16,
                                  color: HaloColors.text3,
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          atmoLabel(a),
                          style: HaloType.mono(
                            size: 10,
                            color: sel ? HaloColors.amber : HaloColors.text3,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    await db.setAtmosphere(widget.peerHaloId, picked.name);
    if (!mounted) return;
    setState(() => _atmosphere = picked);
  }

  Future<void> _clearConversation() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'clear this conversation?',
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                'every message here is erased from this phone. this only '
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
                      'cancel',
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'clear',
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
                  Icon(Icons.block, size: 15, color: HaloColors.amber),
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

  Future<void> _acceptRequestPeer() async {
    HapticFeedback.selectionClick();
    await db.acceptRequest(widget.peerHaloId);
    await appState.refreshContacts();
    if (mounted) setState(() => _accepted = true);
    unawaited(appState.sendAcceptAck(widget.peerHaloId));
  }

  Future<void> _declineRequestPeer() async {
    HapticFeedback.selectionClick();
    await db.declineRequest(widget.peerHaloId);
    await appState.refreshContacts();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _blockRequestPeer() async {
    HapticFeedback.selectionClick();
    await db.setBlocked(widget.peerHaloId, true);
    await appState.refreshContacts();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleSaved(_Msg m) async {
    if (m.msgUid == null) return;
    final next = !m.saved;
    setState(() => m.saved = next);
    await db.setSaved(m.msgUid!, next);
    if (mounted) {
      showHaloToast(context, next ? 'saved' : 'removed from saved');
    }
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
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.line2),
                ),
                focusedBorder: UnderlineInputBorder(
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
    // reversed list: bottom is offset 0, so 'scrolled up from bottom' is
    // simply pixels past a threshold.
    final show = pos.pixels > 240;
    if (!show) _seenCount = _messages.length;
    if (show != _showScrollDown && mounted) {
      setState(() => _showScrollDown = show);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
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
    _dayKeys.forEach((dayMs, key) {
      final obj = key.currentContext?.findRenderObject();
      if (obj is! RenderBox) return;
      final dy = obj.localToGlobal(Offset.zero).dy;
      if (dy <= top + 6 && dy > bestDy) {
        bestDy = dy;
        best = dayMs;
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

  Widget _dateDivider(DateTime when) {
    final dayMs = DateTime(
      when.year,
      when.month,
      when.day,
    ).millisecondsSinceEpoch;
    final key = _dayKeys.putIfAbsent(dayMs, () => GlobalKey());
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
                    onBlock: _chatActions,
                    avatarSeed: widget.avatarSeed,
                    onBack: () => Navigator.pop(context),
                    onSearch: _openSearch,
                    onRename: _renameContact,
                    pinnedCount: _messages.where((m) => m.pinned).length,
                    onPinned: _showPinnedSheet,
                  ),
            if (_messages.any((m) => m.pinned))
              _PinnedBar(
                message: _messages.lastWhere((m) => m.pinned),
                onTap: () =>
                    _scrollToMessage(_messages.lastWhere((m) => m.pinned)),
              ),
            if (_requestPending && _sentCount > 0) const _RequestBanner(),
            if (_keyChanged)
              _KeyChangedBanner(
                peerName: _nickname ?? widget.peerHaloId,
                onVerify: _openKeyVerification,
                onDismiss: _dismissKeyChanged,
              ),
            Expanded(
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
                              final original = _messages.firstWhere(
                                (x) => x.msgUid == m.replyTo,
                                orElse: () => _Msg('', '', DateTime.now()),
                              );
                              if (original.text.isNotEmpty) {
                                quoted = original.text;
                                quotedAuthor = original.direction == 'out'
                                    ? 'you'
                                    : 'them';
                              } else if (original.mediaPath != null) {
                                quoted = 'photo';
                                quotedAuthor = original.direction == 'out'
                                    ? 'you'
                                    : 'them';
                              } else if (original.fileName == 'voice.wav') {
                                quoted = 'voice message';
                                quotedAuthor = original.direction == 'out'
                                    ? 'you'
                                    : 'them';
                              } else if (original.fileName != null) {
                                quoted = original.fileName;
                                quotedAuthor = original.direction == 'out'
                                    ? 'you'
                                    : 'them';
                              } else {
                                quoted = 'message unavailable';
                              }
                            }
                            final isMatch =
                                searchActive && _matches.contains(ix);
                            final isCurrent =
                                searchActive &&
                                _matches.isNotEmpty &&
                                _matches[_matchPos] == ix;
                            final dimmed = searchActive && !isMatch;
                            final showDate =
                                ix == 0 ||
                                !_sameDay(_messages[ix - 1].when, m.when);
                            final prevMsg = ix > 0 ? _messages[ix - 1] : null;
                            final nextMsg = ix < _messages.length - 1
                                ? _messages[ix + 1]
                                : null;
                            bool sameRun(_Msg? o) =>
                                o != null &&
                                o.direction == m.direction &&
                                !o.removing &&
                                _sameDay(o.when, m.when) &&
                                (m.when.difference(o.when).inSeconds).abs() <
                                    120;
                            final firstInGroup =
                                !sameRun(prevMsg) || ix == _firstUnreadIndex;
                            final lastInGroup = !sameRun(nextMsg);
                            return RepaintBoundary(
                              child: Column(
                                key: ObjectKey(m),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showDate) _dateDivider(m.when),
                                  if (ix == _firstUnreadIndex)
                                    _newMessagesDivider(),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 1.0,
                                      end: m.removing ? 0.0 : 1.0,
                                    ),
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOut,
                                    child: _SwipeToReply(
                                      onReply: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _replyTo = m;
                                          _replyFlash = m;
                                        });
                                        Future.delayed(
                                          const Duration(milliseconds: 700),
                                          () {
                                            if (mounted &&
                                                identical(_replyFlash, m)) {
                                              setState(
                                                () => _replyFlash = null,
                                              );
                                            }
                                          },
                                        );
                                      },
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: AnimatedScale(
                                          scale: m.removing ? 0.92 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeIn,
                                          child: AnimatedOpacity(
                                            opacity:
                                                (m.removing ||
                                                    (m.msgUid != null &&
                                                        m.msgUid == _liftedUid))
                                                ? 0.0
                                                : 1.0,
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            child: _Bubble(
                                              key: isMatch
                                                  ? _matchKeys[i]
                                                  : (i == _jumpIndex
                                                        ? _jumpKey
                                                        : null),
                                              msg: m,
                                              firstInGroup: firstInGroup,
                                              lastInGroup: lastInGroup,
                                              revealed:
                                                  m.msgUid != null &&
                                                  m.msgUid == _revealedUid,
                                              onReveal: m.msgUid == null
                                                  ? null
                                                  : () => setState(
                                                      () => _revealedUid =
                                                          _revealedUid ==
                                                              m.msgUid
                                                          ? null
                                                          : m.msgUid,
                                                    ),
                                              onRetry: (m) =>
                                                  m.mediaPath != null
                                                  ? _retryImage(m)
                                                  : m.filePath != null
                                                  ? _retryMedia(m)
                                                  : _retry(m),
                                              onLongPress: (ctx) =>
                                                  _showEmojiPickerAt(ctx, m),
                                              quotedText: quoted,
                                              onQuoteTap: m.replyTo == null
                                                  ? null
                                                  : () {
                                                      for (final x
                                                          in _messages) {
                                                        if (x.msgUid != null &&
                                                            x.msgUid ==
                                                                m.replyTo) {
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
                                                  (m.msgUid == _rippleUid ||
                                                      identical(
                                                        m,
                                                        _replyFlash,
                                                      )),
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
                                    child: Icon(
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
                          builder: (_, shown, __) => AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            opacity: shown ? 1.0 : 0.0,
                            child: ValueListenableBuilder<String?>(
                              valueListenable: _stickyLabel,
                              builder: (_, label, __) => label == null
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
                                        borderRadius: BorderRadius.circular(20),
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
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _friendlyStatus(_status),
                  style: HaloType.mono(size: 10, color: HaloColors.amber),
                ),
              ),
            // tor still warming: say so where the eye already is. messages
            // typed now are queued and go out the moment the route is up.
            if (!_torReadyToSend())
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TorHalo(),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'building a private route · first connect is the slow '
                        'one, later ones are quick. anything you send now is '
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
                        onAccept: _acceptRequestPeer,
                        onDecline: _declineRequestPeer,
                        onBlock: _blockRequestPeer,
                      )
                    : _requestLocked
                    ? const _RequestLockBar()
                    : _Composer(
                        onAttach: _showAttachSheet,
                        ghost: _ghost,
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
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;
  const _AcceptRequestBar({
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
            'accept to reply - they can\'t message again until you do.',
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
                'message request',
                style: HaloType.serif(size: 13, color: HaloColors.text),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'they need to accept before you can keep chatting.',
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
                  'waiting for them to accept your request',
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
  final String? note;
  final String? supporterBadge;
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
            tooltip: 'back',
            icon: Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
            onPressed: onBack,
          ),
          GestureDetector(
            onTap: onBlock, // avatar -> contact actions + verify
            behavior: HitTestBehavior.opaque,
            child: KryfoAvatar(seed: avatarSeed, size: 36),
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
                  Text(
                    nickname != null ? haloId : 'onion',
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
                          'encrypted · over tor',
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
              icon: Icon(
                Icons.push_pin_outlined,
                color: HaloColors.amber,
                size: 19,
              ),
              onPressed: onPinned,
            ),
          IconButton(
            tooltip: 'search this chat',
            icon: Icon(Icons.search_rounded, color: HaloColors.text2, size: 21),
            onPressed: onSearch,
          ),
          IconButton(
            tooltip: 'contact options',
            icon: Icon(Icons.more_vert, color: HaloColors.text2, size: 21),
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
class SearchHead extends StatefulWidget {
  final TextEditingController controller;
  final int matchCount;
  final int matchPos; // 1-based; 0 when no matches
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;
  const SearchHead({
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
    );
  }
}

// blurred, dimmed backdrop behind the long-press menu. fades the blur in
// so the chat recedes instead of just darkening.
// the long-press menu blooming out: scale + fade from the bubble's side.
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeToReply({required this.child, required this.onReply});
  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
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

class _MenuPop extends StatefulWidget {
  final bool side;
  final Widget child;
  const _MenuPop({required this.side, required this.child});

  @override
  State<_MenuPop> createState() => _MenuPopState();
}

class _MenuPopState extends State<_MenuPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final v = _c.value.clamp(0.0, 1.0);
        final t = Curves.easeOutBack.transform(v);
        return Opacity(
          opacity: v,
          child: Transform.scale(
            scale: 0.8 + 0.2 * t,
            alignment: widget.side
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            child: child,
          ),
        );
      },
    );
  }
}

class _MenuBackdrop extends StatefulWidget {
  const _MenuBackdrop();

  @override
  State<_MenuBackdrop> createState() => _MenuBackdropState();
}

class _MenuBackdropState extends State<_MenuBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeOut.transform(_c.value);
        // animate only the dark overlay (cheap). the blur sigma stays fixed -
        // animating BackdropFilter blur recomputes the whole blur every frame
        // and janks the long-press menu on weaker phones.
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: Colors.black.withValues(alpha: 0.42 * t)),
        );
      },
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
  const _Bubble({
    super.key,
    required this.msg,
    this.onRetry,
    this.onLongPress,
    this.quotedText,
    this.quotedAuthor,
    this.onQuoteTap,
    this.query = '',
    this.isCurrentMatch = false,
    this.dimmed = false,
    this.ripple = false,
    this.revealed = false,
    this.onReveal,
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
    final showMeta = isOut && !msg.sending && !msg.failed;
    final showPill = isOut && msg.sending;
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
        onTap: msg.failed && onRetry != null ? () => onRetry!(msg) : onReveal,
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
                              : const Color(0xFF3B332A),
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
                                      Share.shareXFiles([XFile(msg.filePath!)]);
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
                                  onTap: () =>
                                      _openFullImage(context, msg.mediaPath!),
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
                                          child: Image.file(
                                            File(msg.mediaPath!),
                                            cacheWidth: 1080,
                                            gaplessPlayback: true,
                                            filterQuality: FilterQuality.medium,
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
                                                  if (!msg.sending &&
                                                      !msg.failed) ...[
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
                                                        'delivered',
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
                                    if (msg.preview != null) ...[
                                      const SizedBox(height: 6),
                                      LinkPreviewCard(
                                        preview: msg.preview!,
                                        isOut: isOut,
                                      ),
                                    ],
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
                                          if (msg.delivered) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              'delivered',
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
                                        'edited',
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

                                    if (msg.burnAt != null &&
                                        !msg.sending &&
                                        !showMeta) ...[
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
                                    if (msg.failed) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'failed · tap to retry',
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
    final scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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

enum Atmo { none, ember, dusk, moss, rose }

Atmo atmoFromName(String? n) => switch (n) {
  'ember' => Atmo.ember,
  'dusk' => Atmo.dusk,
  'moss' => Atmo.moss,
  'rose' => Atmo.rose,
  _ => Atmo.none,
};

Color atmoAccent(Atmo a) => switch (a) {
  Atmo.ember => HaloColors.amber,
  Atmo.dusk => HaloColors.violet,
  Atmo.moss => HaloColors.green,
  Atmo.rose => HaloColors.rose,
  Atmo.none => HaloColors.surface,
};

String atmoLabel(Atmo a) => switch (a) {
  Atmo.none => 'none',
  Atmo.ember => 'ember',
  Atmo.dusk => 'dusk',
  Atmo.moss => 'moss',
  Atmo.rose => 'rose',
};

class AtmosphereWash extends StatelessWidget {
  final Atmo atmo;
  const AtmosphereWash(this.atmo);
  @override
  Widget build(BuildContext context) {
    if (atmo == Atmo.none) return const SizedBox.shrink();
    final accent = atmoAccent(atmo);
    final deep = Color.lerp(accent, HaloColors.ink, 0.55)!;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.17),
                    accent.withValues(alpha: 0.05),
                    deep.withValues(alpha: 0.13),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -1.0),
                  radius: 1.2,
                  colors: [
                    accent.withValues(alpha: 0.15),
                    accent.withValues(alpha: 0.0),
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
                'say hi.',
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
                'just the two of you, end-to-end encrypted.',
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
                    'audio unavailable',
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
                                'hidden',
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
      if (mounted) showHaloToast(context, 'mic permission needed');
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
    if (mounted) _bottomInset = MediaQuery.of(context).padding.bottom;
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
        try {
          await File(p).delete();
        } catch (_) {}
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
      bottom: 0,
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
                  builder: (_, v, __) => Opacity(
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
                            'release to cancel',
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
                                        'voice hidden · slide to cancel',
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
                                        'slide to cancel',
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
                GestureDetector(
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
  final VoidCallback onPickBurn;
  final int burnSeconds;
  final VoidCallback onAttach;
  final bool disguise;
  final VoidCallback onToggleDisguise;
  final void Function(String path, int ms, bool cancelled) onVoiceComplete;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.ghost,
    required this.onToggleGhost,
    required this.onPickBurn,
    required this.burnSeconds,
    required this.onAttach,
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
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onAttach,
                behavior: HitTestBehavior.opaque,
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
                              color: disguise
                                  ? HaloColors.amber
                                  : HaloColors.text3,
                            ),
                          ),
                        ),
                        _HoldToTalkMic(
                          disguise: disguise,
                          onToggleDisguise: onToggleDisguise,
                          onComplete: onVoiceComplete,
                        ),
                      ],
                    );
                  }
                  final canSend = !sending && hasText;
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
  final String title;
  const MediaGalleryScreen({
    super.key,
    required this.paths,
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
          icon: const Icon(Icons.arrow_back, size: 20),
          color: HaloColors.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'shared photos',
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
                'no photos in this chat yet',
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
                  onTap: () => _openFullImage(context, path),
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
                    icon: Icon(Icons.arrow_back, color: HaloColors.text2),
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
// link preview card. data is fetched sender-side over tor and embedded, so
// rendering never makes a network request - the receiver's ip stays private.
class LinkPreviewCard extends StatelessWidget {
  final Map<String, String> preview;
  final bool isOut;
  final bool fill;
  const LinkPreviewCard({
    super.key,
    required this.preview,
    required this.isOut,
    this.fill = false,
  });

  // decode each preview image once and keep the bytes, so list repaints (burn
  // ticks, scroll) don't re-decode base64 every frame and make the card blink.
  static final Map<String, Uint8List> _imgCache = {};
  static Uint8List? _decode(String? b64) {
    if (b64 == null) return null;
    final hit = _imgCache[b64];
    if (hit != null) return hit;
    try {
      final bytes = base64Decode(b64);
      _imgCache[b64] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = preview['title'];
    final imgB64 = preview['img'];
    final imgBytes = _decode(imgB64);
    final site = preview['site'];
    final url = preview['url'];
    final fg = isOut ? HaloColors.onAmber : HaloColors.text;
    final sub = isOut
        ? HaloColors.onAmber.withValues(alpha: 0.7)
        // text3 sank into the card - one step brighter reads without
        // stealing weight from the title.
        : HaloColors.text2;
    final line = isOut
        ? HaloColors.onAmber.withValues(alpha: 0.25)
        : HaloColors.line;

    return GestureDetector(
      onTap: url == null
          ? null
          : () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        width: fill ? double.infinity : null,
        constraints: fill ? null : const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          border: Border.all(color: line, width: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imgBytes != null)
              AspectRatio(
                aspectRatio: 1.91,
                child: Image.memory(
                  imgBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // decode at card width, not full res - lighter on weak phones
                  // while scrolling (samsung).
                  cacheWidth: 520,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (site != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        site.toLowerCase(),
                        style: HaloType.mono(
                          size: 9.5,
                          color: sub,
                          letter: 0.04,
                        ),
                      ),
                    ),
                  if (title != null)
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(
                        size: 12.5,
                        color: fg,
                        weight: FontWeight.w600,
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

// map the saved mode string to the pill's enum. private = full tor (3 hops),
// the real route for every message today.
PrivacyMode _pmFrom(String m) => m == 'fast'
    ? PrivacyMode.fast
    : m == 'normal'
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
                'security code changed',
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
            '$peerName may have reinstalled, or someone could be impersonating them. compare safety numbers to be sure.',
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
                    'ok',
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
                      'verify',
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

String? firstUrl(String text) {
  final m = RegExp(r'https?://[^\s]+').firstMatch(text);
  return m?.group(0);
}

String unescapeHtml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
