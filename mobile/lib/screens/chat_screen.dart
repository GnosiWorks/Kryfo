// SPDX-License-Identifier: GPL-3.0-or-later
// chat screen: bubbles, composer, live receive over tor.

import '../lock_state.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../drafts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../picked.dart';
import '../sent_name.dart';
import 'dart:io';
import 'dart:convert';
import 'key_verification_screen.dart';
import 'contact_screen.dart';
import 'wallpaper_sheet.dart';
import 'introduce_sheet.dart';
import 'shield_sheet.dart';
import '../vouch_text.dart';
import '../widgets/intro_chip.dart';
import '../widgets/media_bubbles.dart' show ImageCaptionScreen, VoiceBubble;
import '../widgets/voice_mic.dart';
import '../widgets/owned_text.dart';
import '../voice_mask.dart' show maskWavOff;
import '../widgets/confirm_sheet.dart';
import '../widgets/hidden_mark.dart';
import '../widgets/pins.dart';
import '../widgets/remembered_height.dart';
import '../widgets/row_anchor.dart';
import '../widgets/video_bubble.dart';
import '../widgets/kryfo_link_text.dart';
import '../open_file.dart';
import '../widgets/notice_banner.dart';
import '../widgets/swipe_to_reply.dart';
import '../signal_session.dart';
import '../message_envelope.dart'
    show wrapMessage, SenderInfo, grindPow, powBits;
import '../outbox.dart' show powFits;
import '../theme.dart';
import '../media_progress.dart';
import '../media_send.dart'
    show sendChunkedMediaTo, cancelMediaSend, mediaInflight;
import '../image_strip.dart';
import '../mp4_strip.dart';
import '../widgets/decode_px.dart';
import '../notifications.dart' show clearNotificationsFor;
import '../devchat/dev_chat.dart' show DevChatRow, DevRow, DevState;
import '../devchat/dev_key.dart' show DevKeyStatus, isDevChat;
import '../devchat/dev_start.dart';
import '../widgets/dev_note.dart';
import 'dev_about_sheet.dart'
    show
        deleteDevChat,
        devChatRoute,
        devForwardTarget,
        setDevArchived,
        setDevMuted,
        setDevPinned,
        showDevAboutSheet,
        startNewDevChat;
import '../widgets/kryfo_avatar.dart';
import '../widgets/name_check_mark.dart';
import '../main.dart'
    show
        engine,
        kNameAsk,
        kNotSent,
        nameAsks,
        nameCheckOf,
        nameUnchecked,
        session,
        sessionQuiet,
        signalEncrypt,
        hasSessionWith,
        appState,
        currentChatPeer,
        claimChat,
        newMsgUid,
        releaseChat,
        shredFile,
        torStrictGetOnIsolate,
        torValve,
        TorHalo;
import '../widgets/reconnect_valve.dart';
import '../widgets/press_scale.dart';
import '../widgets/say_hi_card.dart';
import '../stickers/sticker_bubble.dart';
import '../stickers/sticker_flight.dart';
import '../stickers/sticker_pack.dart'
    show Sticker, StickerLibrary, StickerPack;
import '../stickers/sticker_sheet.dart'
    show GifPick, PhoneGifPick, StickerButton, StickerPick, showStickerSheet;
import '../gifs/gif_engine.dart' show appGifTabs;
import '../gifs/gif_picture.dart';
import '../stickers/sticker_view.dart' show StickerBudget;
import '../stickers/sticker_wire.dart' show StickerWire;
import '../widgets/motion.dart';
import '../widgets/burn_fade.dart';
import '../seen_timers.dart';
import '../read_burn.dart';
import '../dlog.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/chat_parts.dart';
import '../widgets/message_menu.dart';
import '../widgets/attach_grid.dart';
import '../widgets/link_stub.dart';
import '../widgets/place_stub.dart';
import '../widgets/preview_strip.dart';
import 'camera_screen.dart';
import '../link_preview.dart'
    show titleFromHtml, firstUrl, senderPreview, WordLinks;
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
import '../widgets/moved_strip.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/marked.dart';
import '../l10n/numbers.dart';
import '../widgets/video_viewer.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/swap.dart';
import '../widgets/written_field.dart';
import '../bidi_safe.dart';
import '../back_on_top.dart';
import '../forward.dart';
import 'forward_sheet.dart';
import '../widgets/key_held.dart';
import '../first_contact.dart' show routeText, waitsForReceipt;
import '../text_send.dart';
import '../lock_guard.dart' show LockDropped, lockGuard, onScreen;

// the chats open in the stack, by id: shared words land in the one on top
// rather than in a second copy of it
final Map<String, List<_ChatScreenState>> _openChats = {};

/// [words] under what [id]'s chat holds in its composer, when that chat
/// is the page on top. false otherwise: nothing above it is ever closed
bool landInOpenChat(String id, String words) {
  for (final s in _openChats[id] ?? const <_ChatScreenState>[]) {
    if (s.mounted && (ModalRoute.of(s.context)?.isCurrent ?? false)) {
      s._takeWords(words);
      return true;
    }
  }
  return false;
}

/// a deleted chat's unsent words go with it, from an open composer too
void dropChatDraft(String id) {
  for (final s in _openChats[id] ?? const <_ChatScreenState>[]) {
    if (s.mounted) s._msgCtrl.clear();
  }
  draftPerPeer.remove(session.chatKey(id));
}

/// the note on a contact. [save] runs before the sheet goes; true when it
/// did
@visibleForTesting
Future<bool> showNoteSheet(
  BuildContext context, {
  required String initial,
  required Future<void> Function(String note) save,
}) async {
  final r = await showHaloSheet<bool>(
    context,
    scroll: true,
    builder: (_) => OwnedText(
      initial: initial,
      builder: (ctx, ctrl) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          // the keyboard, or the navigation bar when it is down
          bottom:
              math.max(
                MediaQuery.paddingOf(ctx).bottom,
                MediaQuery.viewInsetsOf(ctx).bottom,
              ) +
              22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(
              l10n.chatNoteOnThisContact,
              style: HaloType.serif(size: 18, color: HaloColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.chatJustForYouNever,
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
                hintText: l10n.chatAQuietReminder,
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
              alignment: AlignmentDirectional.centerEnd,
              child: GestureDetector(
                onTap: () async {
                  await save(ctrl.text.trim());
                  // a second tap while it saved must not close the chat
                  if (!ctx.mounted) return;
                  if (ModalRoute.of(ctx)?.isCurrent ?? false) {
                    Navigator.pop(ctx, true);
                  }
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
                    l10n.commonSave,
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
    ),
  );
  return r == true;
}

// newest message ms seen when the chat was last left, keyed by
// session.chatKey like the drafts
final Map<String, int> _lastReadPerPeer = {};

class ChatScreen extends StatefulWidget {
  final String peerHaloId;
  final String peerOnion;
  final String peerXPub;
  final String avatarSeed;
  // the face they picked, handed over so the hero never lands on the
  // letter fallback while the row is still loading
  final int? avatarChoice;
  // the name given them, from the row tapped, so the header never opens on
  // their three words while the row loads
  final String? nickname;
  final String? initialText;
  final String? jumpToUid;
  // a support chat on the developer's own phone: the composer instead of
  // accept and decline, and the first reply takes it on
  final bool support;

  const ChatScreen({
    super.key,
    required this.peerHaloId,
    required this.peerOnion,
    required this.peerXPub,
    required this.avatarSeed,
    this.avatarChoice,
    this.nickname,
    this.initialText,
    this.jumpToUid,
    this.support = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Msg with WordLinks {
  final String direction;
  @override
  String text;
  final DateTime when;
  int? burnAt;
  // the burn window: ours is lit into burnAt when it goes, theirs when it
  // is first read
  int? burnSecs;
  // theirs, counting since before it was read (kBurnWaitMost)
  bool burnUnseen;
  String? msgUid;
  // msg_uid of the message this one replies to, or null.
  final String? replyTo;
  // sender asked that this not be screenshotted
  final bool secure;
  bool sending;
  bool failed = false;
  // online, a failed row retries itself and reads as pending. past the cap
  // it shows as failed and the tap is the only way on.
  int autoRetries = 0;
  bool gaveUp = false;
  // stored at an address they do not read yet: not sent, not failed. the
  // outbox keeps trying routes that reach them until they add us back.
  bool parked = false;
  // a block kept it from going: shown failed, and only a tap sends it
  bool notSent = false;
  bool delivered;
  bool edited;
  bool pinned;
  bool removing = false;
  // it burned on its own timer: leaving, only its row still has to fold
  bool burnedAway = false;
  String? mediaPath;
  String? filePath;
  String? fileName;
  bool voiceDisguised;
  bool saved;
  Map<String, String> reactions;
  bool fresh = false;
  int rowid = 0; // db insertion order, for append tracking
  Map<String, String>? preview; // link preview card, decoded from stored json
  // a sticker: drawn from our pack; text is its emoji
  final StickerWire? sticker;
  // the developer chat's first line, from the app itself: never stored,
  // sent or counted, and nothing can be done to it but copy it
  final bool welcome;
  // a contact's, through the developer chat: his phone tags it
  final bool viaDev;
  _Msg(
    this.direction,
    this.text,
    this.when, {
    this.sticker,
    this.welcome = false,
    this.burnAt,
    this.burnSecs,
    this.burnUnseen = false,
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
    this.viaDev = false,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? <String, String>{};

  // came in timed and not read yet: its clock waits for the first read
  bool get burnWaits => direction == 'in' && burnAt == null && burnSecs != null;

  // not read yet, its clock waiting or running: reading it is still owed
  bool get burnUnread => burnWaits || (burnUnseen && burnAt != null);

  // what the countdown shows: the time left, or the whole window while it
  // waits. null for a message with no clock to show
  String? get burnLabel => burnAt != null
      ? _fmtBurn(burnAt!)
      : burnWaits
      ? burnLeft(burnSecs! * 1000)
      : null;
}

String _humanSize(int bytes) {
  if (bytes < 1024) return l10n.chatB(whole(bytes));
  if (bytes < 1024 * 1024) {
    return l10n.chatKb(whole(((bytes / 1024)).round()));
  }
  return l10n.chatMb(decimal((bytes / (1024 * 1024)), 1));
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
  } catch (_) {
    // gone or unreadable: the card shows no size
  }
  final ext = (msg.fileName ?? '').contains('.')
      ? msg.fileName!.split('.').last.toUpperCase()
      : l10n.chatFile;
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

// out of the bubble it was tapped in, or a tile of the shared photos. a
// marked photo stays protected wherever it is opened from
void _openFullImage(
  BuildContext context,
  String path, {
  bool secure = false,
  Object? tag,
  double radius = 0,
}) => openPhoto(context, path, tag: tag, radius: radius, secure: secure);

// the time and tick on a photo or a video with no caption: a small dark pill
// in the corner, since there is no bubble under it to carry them
Widget _mediaStamp(_Msg msg) {
  final mono = TextStyle(
    fontFamily: HaloType.monoFamily,
    fontFamilyFallback: HaloType.monoFallbackNow,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    letterSpacing: track(0.4),
  );
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_fmtTime(msg.when), style: mono),
        // a received one has its time alone
        if (msg.direction == 'out') ...[
          const SizedBox(width: 3),
          SentTick(
            delivered: msg.delivered,
            deliveredLabel: l10n.chatDelivered,
            color: Colors.white,
            labelStyle: mono.copyWith(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: track(0.3),
            ),
          ),
        ],
      ],
    ),
  );
}

// the tick on a text of ours, or a clock while it is sent and not delivered
// yet to someone who has not added us back
Widget _outMark(
  BuildContext context,
  _Msg msg, {
  required bool unconfirmed,
  required Color color,
}) => AnimatedSwitcher(
  duration: motionStill(context)
      ? Duration.zero
      : const Duration(milliseconds: 200),
  child: unconfirmed
      ? Icon(
          Icons.schedule_rounded,
          key: const ValueKey('unconfirmed'),
          size: 10,
          color: color,
        )
      : SentTick(
          key: const ValueKey('sent'),
          delivered: msg.delivered,
          deliveredLabel: l10n.chatDelivered,
          color: color,
          labelStyle: TextStyle(
            fontFamily: HaloType.monoFamily,
            fontFamilyFallback: HaloType.monoFallbackNow,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: track(0.3),
          ),
        ),
);

// the corner of a photo or a video: its time and tick once it is there, a
// mark when it failed or waits, so the picture itself carries the state
Widget _mediaCorner(
  _Msg msg, {
  required bool showMeta,
  required bool failedShown,
  required bool parked,
}) {
  final Widget child;
  if (showMeta) {
    child = KeyedSubtree(key: const ValueKey('stamp'), child: _mediaStamp(msg));
  } else if (failedShown || parked) {
    child = Container(
      key: ValueKey(failedShown ? 'failed' : 'parked'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: Icon(
        failedShown ? Icons.error_outline_rounded : Icons.schedule_rounded,
        size: 15,
        color: failedShown ? HaloColors.rose : HaloColors.amber,
      ),
    );
  } else {
    child = const SizedBox.shrink(key: ValueKey('none'));
  }
  return CornerSwap(child: child);
}

// the phone cannot send at all: no network, or onion mode without a route
bool _cannotSend() => !appState.online || !appState.torReady;

// a failed send only reads as failed when the phone cannot send, or when
// it has retried itself to the cap. online, the row keeps going on its own
// and shows as pending.
bool _sendLooksFailed(_Msg m) =>
    m.failed && (m.gaveUp || m.notSent || _cannotSend());

// a row a block held back reads as not sent
void _readNotSent(_Msg m, Map<String, Object?> r) {
  if (r['sent'] != kNotSent) return;
  m.failed = true;
  m.notSent = true;
}

String _friendlyStatus(String raw) {
  if (raw.isEmpty || raw == 'parked') return '';
  if (!appState.online && raw.startsWith('error:')) {
    return l10n.chatYouAreOfflineThis;
  }
  if (raw.startsWith('error:') && !appState.torReady) {
    return l10n.chatStillConnectingToTor;
  }
  // online, a transport error is not the user's problem: the row retries
  // itself and the bubble stays pending. no line.
  if (raw.startsWith('error:')) return '';
  return raw;
}

String _fmtFull(DateTime d) {
  return '${dayMonthMaybeYear(d)} · ${hourMinute(d)}';
}

String _fmtTime(DateTime d) => hourMinute(d);

String _humanBurn(int seconds) {
  if (seconds < 60) return l10n.chatS(whole(seconds));
  if (seconds < 3600) return l10n.chatM(whole(seconds ~/ 60));
  if (seconds < 86400) return l10n.chatH(whole(seconds ~/ 3600));
  return l10n.chatD(whole(seconds ~/ 86400));
}

// the countdown, as groups show it too (burnLeft)
String _fmtBurn(int burnAtMs) =>
    burnLeft(burnAtMs - DateTime.now().millisecondsSinceEpoch);

// isolate entrypoint for compute(): grinds first-contact pow
int _grindPowTask(String seed) => grindPow(seed, powBits);

// stands in for the isolate in widget tests, whose clock never waits on one
@visibleForTesting
int Function(String seed)? grindPowForTest;

int _lastBurnSeconds = 300;
bool _lastGhost = false;

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, BackOnTop<ChatScreen> {
  final _msgCtrl = TextEditingController();
  // a reply raises the keyboard at once, like a tap on the field
  final _composerFocus = FocusNode();
  int _unreadAfterMs = 0;
  // the row the new messages divider sits above, by its key: an index
  // would slip as older pages come in above it
  String? _firstUnreadKey;
  bool _unreadResolved = false;
  bool _ghost = _lastGhost; // restored from last use this session.
  // marks the next message so the other phone blocks screenshots of it. off
  // by default, since then neither side can screenshot the chat.
  bool _secureNext = false;
  // this chat's voice notes go out disguised
  bool _disguise = false;
  int _burnSeconds = _lastBurnSeconds; // restored from last use this session.
  // the burn, the inbox poll and the auto retry run only while the chat is
  // in view, and catch up the moment it is back
  final _timers = SeenTimers();
  late final SeenJob _burn;
  int _lastBurnSec = 0;
  final _scrollCtrl = HoldScrollController();
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
      final real = _messages.where((m) => !m.welcome);
      final oldest = real.isEmpty ? null : real.first.rowid;
      final rows = await session.messagesPage(
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
          sticker: StickerWire.parse(r['sticker']),
          burnAt: r['burn_at'] as int?,
          burnSecs: (r['burn_secs'] as num?)?.toInt(),
          burnUnseen: r['burn_unseen'] == 1,
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
          viaDev: r['via_dev'] == 1,
          delivered: (r['delivered'] as int? ?? 0) == 1,
          sending:
              (r['direction'] as String) == 'out' &&
              (r['sent'] as int? ?? 1) == 0,
        );
        m.rowid = (r['rowid'] as int?) ?? 0;
        _readNotSent(m, r);
        final pvRaw = r['preview'] as String?;
        if (pvRaw != null && pvRaw.isNotEmpty) {
          try {
            final dd = jsonDecode(pvRaw) as Map<String, dynamic>;
            m.preview = dd.map((k, v) => MapEntry(k, v.toString()));
          } catch (_) {
            // a preview that does not parse is not shown
          }
        }
        if (uid != null) {
          uids.add(uid);
          _seenUids.add(uid);
        }
        older.add(m);
      }
      final reactionMap = await session.loadReactionsFor(uids);
      for (final m in older) {
        final entries = reactionMap[m.msgUid];
        if (entries == null) continue;
        for (final en in entries) {
          m.reactions[en.key] = en.value;
        }
      }
      // the whole thread is in: his first line goes before it
      if (!_hasMore && !_messages.any((m) => m.welcome)) {
        final w = _welcomeBefore([...older, ..._messages]);
        if (w != null) older.insert(0, w);
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

  // every path that touches the list ends here. an out-of-order list gives
  // one day two dividers, and their shared GlobalKey takes the whole chat
  // out of the widget tree.
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

  // a reload rebuilds every row from the database. a message already leaving
  // keeps its row so the burn and fold carry on, and one gone from the
  // database since leaves the same way instead of popping out
  void _keepLeaving(List<_Msg> before) {
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
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final o in before) {
      final uid = o.msgUid;
      if (uid == null || present.contains(uid) || o.sending) continue;
      // older than the page now loaded: scrolled out, not gone
      if (oldest != null && o.when.isBefore(oldest)) continue;
      if (!o.removing) {
        o.removing = true;
        o.burnedAway = o.burnAt != null && o.burnAt! <= now;
        Future.delayed(kLeaveGone, () {
          if (mounted) setState(() => _messages.remove(o));
        });
      }
      _messages.add(o);
    }
  }

  bool _loaded = false;
  Atmo _atmosphere = Atmo.none;
  // a photo of their own behind this chat. lives in the app's folder, so
  // it goes with a wipe; stored as image:<path> in the atmosphere column.
  String? _wallpaperPath;
  String _status = '';
  bool _loading = false;
  bool _reloadPending = false;
  bool _sending = false;
  // stickers and waves being sealed. the composer does not wait for them,
  // a retry does
  int _stickerSends = 0;
  // the pack's waving sticker, once the packs are read; null for the emoji
  (StickerPack, Sticker)? _hi;
  bool _hiKnown = false;
  // at most six stickers play at once in the whole chat
  final _stickers = StickerBudget(6);
  // stickers flying in from the sheet, by message uid. a bubble stays
  // hidden until its flight is down
  final Map<String, StickerLanding> _landings = {};
  final List<VoidCallback> _flights = [];
  // serialize signal encryption across sends. a fast burst must not encrypt
  // every message against the same pre-session state, or they all come out as
  // prekey messages fighting over one one-time key and only the first lands.
  Future<void> _encryptGate = Future.value();
  // seeded from the qr/contact key so the first send works before any
  // session exists. the session lookup in initState only refreshes it.
  late String? _peerXPub = widget.peerXPub.isEmpty ? null : widget.peerXPub;
  bool _backPaired = false;
  // the message being replied to. cleared after send or by the X in the
  // quote bar.
  _Msg? _replyTo;

  // search in chat. _matches are indices into _messages, _matchPos the
  // current hit, _matchKeys let a hit be scrolled into view.
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _liftedUid;
  List<int> _matches = [];
  // same hits as _matches, for the per-row "is this one" test
  Set<int> _matchSet = {};
  int _matchPos = 0;
  final Map<int, GlobalKey> _matchKeys = {};
  late String? _nickname = widget.nickname;
  late int? _peerFace = widget.avatarChoice;
  bool _blocked = false;
  // the bottom bar is drawn once blocked and request state are read, the
  // first one with no transition
  bool _barKnown = false;
  bool _barSettled = false;
  bool _muted = false;
  bool _verified = false;
  String? _peerBadge;
  bool _keyChanged = false;
  // verified under one key, holding another now: nothing goes to them until
  // the new number is checked or the new key accepted
  bool _keyHeld = false;
  bool _keyReading = false;
  // a read asked for while one runs runs again after it
  bool _keyAgain = false;
  // their words came with a request, an introduction or a group and
  // nothing has checked them
  bool _nameUnchecked = false;
  // the chat asks for the safety number: added by a code or a link, or
  // taken in from a request, and not verified
  bool _nameAsks = false;
  int _nameFlags = 0;

  // what this chat shows about their key, read again whenever a key changes
  // or a mark is set somewhere else
  Future<void> _readKeyState() async {
    if (_isDev) return;
    if (_keyReading) {
      _keyAgain = true;
      return;
    }
    _keyReading = true;
    try {
      final changed = await session.keyChanged(widget.peerHaloId);
      final verified = await session.isVerified(widget.peerHaloId);
      final held = await session.keyHeld(widget.peerHaloId);
      final row = await session.getContact(widget.peerHaloId);
      final unchecked = nameUnchecked(row);
      final asks = nameAsks(row);
      if (!mounted) return;
      _nameFlags = nameCheckOf(row);
      if (changed != _keyChanged ||
          verified != _verified ||
          held != _keyHeld ||
          unchecked != _nameUnchecked ||
          asks != _nameAsks) {
        setState(() {
          _keyChanged = changed;
          _verified = verified;
          _keyHeld = held;
          _nameUnchecked = unchecked;
          _nameAsks = asks;
        });
      }
    } catch (e) {
      dlog('key state: not read (${e.runtimeType})');
    } finally {
      _keyReading = false;
    }
    if (_keyAgain && mounted) {
      _keyAgain = false;
      await _readKeyState();
    }
  }

  // the new key taken as it is: the mark and the banner go, sending goes on
  Future<void> _acceptNewKey() async {
    final name = _nickname ?? widget.peerHaloId;
    if (!await acceptNewKeyAsked(context, widget.peerHaloId, name)) return;
    await _readKeyState();
  }

  Future<void> _dismissKeyChanged() async {
    await session.setKeyChanged(widget.peerHaloId, false);
    if (mounted) setState(() => _keyChanged = false);
  }

  // the compare card put away for this chat. the words stay not checked
  Future<void> _compareLater() async {
    setState(() => _nameAsks = false);
    await session.setNameCheck(widget.peerHaloId, _nameFlags & ~kNameAsk);
    await _readKeyState();
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
  bool get _requestLocked =>
      _requestPending && _sentCount >= (_isDev ? kDevCap : 2) && !_vouched;
  // receiver-side: a stranger has messaged us and we haven't accepted yet.
  bool get _incomingRequest => !_accepted && _recvCount > 0 && !widget.support;
  // a reaction says this phone read it: none in a request or a block
  bool get _canReact => !_blocked && !_incomingRequest;
  // someone added here who knows nothing of it: nothing went to them and
  // nothing came (anything that came marks them engaged), so they hear of
  // this phone only with a first message
  bool get _sayHi =>
      _loaded &&
      _barKnown &&
      _hiKnown &&
      _messages.isEmpty &&
      _accepted &&
      !_peerEngaged &&
      _sentCount == 0 &&
      !_blocked &&
      !_keyHeld &&
      !_isDev &&
      !widget.support;
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
  // their messages that came in while reading back, for the jump button.
  // counted as they arrive: older pages and reloads add none
  int _unseenNew = 0;
  String? _rippleUid;
  _Msg? _replyFlash;
  String? _note;

  // the developer chat: his header and first line, the note before the
  // first send, and the one start every kind of message asks for
  late final bool _isDev = isDevChat(widget.peerHaloId);
  DevOpening? _devOpening;
  // this chat in the session that opened it, for what is kept between visits
  late final String _memo;
  // its row in this session's database, for when the chat was made
  DevChatRow? _devChat;
  // the pinned key did not check out: nothing was sent
  bool _devKeyFailed = false;

  // the dev chat as home shows it, while it is this one
  DevRow? get _devShown {
    final d = appState.devRow;
    return d != null && d.chatId == widget.peerHaloId ? d : null;
  }

  // written anonymously, or about to be: a voice goes out disguised
  bool get _devAnon => _devOpening?.anon ?? false;
  bool get _voiceDisguise => _disguise || _devAnon;

  // anonymous and restored without the name it was made with: it reads,
  // and a new chat can take its place
  bool get _devNameless =>
      (_devShown?.nameless ?? false) || (_devChat?.nameless ?? false);

  // why nothing more goes out of his chat, said in place of the composer:
  // a retired key, or a made name that stayed where it was made. null while
  // it can send
  String? get _devStop => _devRetired
      ? l10n.devKeyRetired
      : _devNameless
      ? l10n.devNamelessLine
      : null;

  bool get _devRetired => _devShown?.status == DevKeyStatus.retired;

  // the nameless chat goes, once asked, and a fresh one opens in its place
  Future<void> _startNewDevChat() async {
    HapticFeedback.selectionClick();
    final nav = Navigator.of(context);
    final id = await startNewDevChat(context, widget.peerHaloId);
    if (id == null || !mounted) return;
    nav.pushReplacement(devChatRoute(id));
  }

  void _onDevOpening() {
    if (mounted) setState(() {});
  }

  // what the database and home say now: started here or on another screen
  void _syncDev() {
    final o = _devOpening;
    if (o == null) return;
    final r = _devChat;
    if (r != null && r.started) {
      o.sync(started: true, anon: r.state == DevState.anon);
    }
    final d = _devShown;
    if (d != null && d.started) o.sync(started: true, anon: d.anonymous);
  }

  // at the top of every way a message leaves, before anything of it is
  // saved: the first one starts the chat with the name chosen in the note,
  // and a key that does not check out stops it there
  Future<bool> _ensureDevStarted() async {
    final o = _devOpening;
    if (o == null) return true;
    // a first send tried again says it again if it fails again
    if (!o.started && _devKeyFailed) setState(() => _devKeyFailed = false);
    final r = await o.ensure();
    if (!mounted) return false;
    switch (r) {
      case DevStart.ok:
        return true;
      case DevStart.keyFailed:
        HapticFeedback.heavyImpact();
        setState(() => _devKeyFailed = true);
        return false;
      case DevStart.none:
        return false;
    }
  }

  void _chooseDevName(bool anon) => _devOpening?.choose(anon: anon);

  @override
  void initState() {
    super.initState();
    _memo = session.chatKey(widget.peerHaloId);
    if (_isDev) {
      final d = _devShown;
      _devOpening = DevOpening(
        memo: '${session.container.id}|${widget.peerHaloId}',
        started: d?.started ?? false,
        anon: d?.anonymous ?? false,
        begin: devBeginOf(appState.devBegin),
      )..addListener(_onDevOpening);
    }

    _applySecureContent();
    WidgetsBinding.instance.addObserver(this);
    // read once, before the first sticker row asks for it. a failure here is
    // the row's to show when it loads again, and the card waves the emoji
    final ready = StickerLibrary.ready;
    if (ready != null) {
      _hi = wavingSticker(ready);
      _hiKnown = true;
    } else {
      StickerLibrary.load()
          .then<void>(
            (lib) => _hi = wavingSticker(lib),
            onError: (Object e) => dlog('sticker pack: $e'),
          )
          .whenComplete(() {
            if (mounted) setState(() => _hiKnown = true);
          });
    }
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
    appState.loadChatDisguise(widget.peerHaloId).then((d) {
      if (mounted) setState(() => _disguise = d);
    });
    appState.addListener(_onAppStateChanged);
    lockState.addListener(_lockLifted);
    claimChat(widget.peerHaloId);
    (_openChats[widget.peerHaloId] ??= []).add(this);
    // opened under the lock: marked read once it lifts
    lockGuard.isLocked() ? _underLock = true : _markRead();
    _unreadAfterMs =
        _lastReadPerPeer[_memo] ?? DateTime.now().millisecondsSinceEpoch;
    _msgCtrl.text = composerWith(draftPerPeer[_memo] ?? '', widget.initialText);
    // save the draft live on every keystroke so it survives leaving the chat
    // regardless of when dispose runs.
    _msgCtrl.addListener(() {
      final t = _msgCtrl.text;
      if (t.trim().isEmpty) {
        draftPerPeer.remove(_memo);
      } else {
        draftPerPeer[_memo] = t;
      }
    });
    session.getContact(widget.peerHaloId).then((c) {
      if (mounted) {
        setState(() {
          _nickname = c?['nickname'] as String?;
          _note = c?['note'] as String?;
          _peerFace = (c?['avatar'] as num?)?.toInt() ?? _peerFace;
        });
      }
    });
    // no one vouches for him and the shield never reads him
    if (!_isDev) {
      _loadVouches();
      _loadShield();
    }
    session.getAtmosphere(widget.peerHaloId).then((a) {
      if (!mounted) return;
      setState(() {
        if (a != null && a.startsWith('image:')) {
          _wallpaperPath = a.substring(6);
          _atmosphere = Atmo.none;
        } else {
          _atmosphere = atmoFromName(a);
        }
      });
    });
    signalSession.peerXPubHex(widget.peerHaloId).then((v) {
      // only adopt the session value if we don't already have the widget key;
      // never clobber a good key with a null the store hasn't filled yet.
      if (mounted && v != null && v.isNotEmpty) {
        setState(() => _peerXPub = v);
      }
    });
    session.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    _scrollCtrl.addListener(_onScrollPage);
    final blockedRead = session.isBlocked(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _blocked = v);
    });
    session.isMuted(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _muted = v);
    });
    session.isVerified(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _verified = v);
    });
    session.getContact(widget.peerHaloId).then((c) {
      if (mounted) {
        setState(() => _peerBadge = c?['supporter_badge'] as String?);
      }
    });
    // request lock: are they an accepted contact, have they engaged, and how
    // many messages have we already sent while unaccepted.
    final barReads = <Future<void>>[
      blockedRead,
      session.isAccepted(widget.peerHaloId).then((v) {
        if (mounted) setState(() => _accepted = v);
      }),
      session.isBackPaired(widget.peerHaloId).then((v) {
        if (mounted) setState(() => _peerEngaged = v);
      }),
      session.countMessagesTo(widget.peerHaloId).then((v) {
        if (mounted) setState(() => _sentCount = v);
      }),
      session.countMessagesFrom(widget.peerHaloId).then((v) {
        if (mounted) setState(() => _recvCount = v);
      }),
      // a held chat never shows the composer first
      _readKeyState(),
    ];
    // the bottom bar waits for these, so a blocked chat or a request never
    // shows the composer first
    Future.wait(barReads)
        .then<void>((_) {}, onError: (Object e) => dlog('chat: bar read $e'))
        .whenComplete(() {
          if (!mounted) return;
          setState(() => _barKnown = true);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _barSettled = true,
          );
        });
    _scrollCtrl.addListener(_onScroll);
    _scrollCtrl.addListener(_updateSticky);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _suppressSticky = false;
    });
    // read once more against the app as it is now: what failed while the
    // chat was shut is tried, and what changed while it loaded is shown
    _loadMessages().then((_) => _onAppStateChanged());
    _burn = _timers.until(_burnWait, _burnTick);
    // back in view: what shows now has been read
    _reads.keepTime(_timers);
    _scrollCtrl.addListener(_reads.look);
    _timers.every(const Duration(seconds: 30), _autoRetryTick);
    _timers.every(const Duration(seconds: 1), () {
      if (mounted) _checkInbox();
    });
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
        starts.add(burnStartBy(m.when.millisecondsSinceEpoch, now));
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
      final s = burnStartBy(m.when.millisecondsSinceEpoch, now);
      if (s > now) continue;
      m.burnAt = s + m.burnSecs! * 1000;
      m.burnUnseen = true;
    }
  }

  void _burnTick(bool back) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _startWaited(now);
    // one pass, and no list unless something burnt
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
        m.burnedAway = true;
      }
      if (back) {
        // it burned while the chat was out of view: gone, as it would be
        // by now, with no burn played for it
        _messages.removeWhere(expired.contains);
        for (final m in expired) {
          unawaited(_forgetBurnt(m));
        }
      } else {
        for (final m in expired) {
          // the bubble burned on its own; its row folds (LeaveFold) before
          // it is pulled, else the messages around it jump
          Future.delayed(kLeaveGone, () async {
            if (mounted) setState(() => _messages.remove(m));
            await _forgetBurnt(m);
          });
        }
        HapticFeedback.lightImpact();
      }
    }
    // _BurnFade dissolves itself, so the tick only has to repaint when
    // something just expired or the countdown text changes second.
    final sec = now ~/ 1000;
    if (expired != null || sec != _lastBurnSec) {
      _lastBurnSec = sec;
      setState(() {});
    }
  }

  Future<void> _forgetBurnt(_Msg m) async {
    if (m.msgUid != null) await session.deleteMessage(m.msgUid!);
    // the home row was previewing what just burned
    unawaited(appState.refreshContacts());
  }

  int _lastRev = -1;

  void _onAppStateChanged() {
    if (!mounted) return;
    _retryFailedOnReconnect();
    // only touch the message list when this thread changed: reloading on
    // every app notify is a lag spike in long chats
    final rev = appState.chatRevOf(widget.peerHaloId);
    if (rev != _lastRev) {
      _lastRev = rev;
      _tryAppendNew();
      unawaited(_refreshDelivered());
    }
    _refreshRequestState();
    unawaited(_readKeyState());
    if (!_accepted && _flag == null && !_isDev) _loadShield();
    if (_isDev) {
      _syncDev();
      // his key's status and the chat's flags, as the header and menu show
      final d = _devShown;
      final seen = (d?.status, d?.muted, d?.pinned, d?.archived);
      if (seen != _devSeen) setState(() => _devSeen = seen);
    }
  }

  Object? _devSeen;

  // who vouched, as we know them. only accepted contacts come back, so a
  // voucher we deleted since simply stops being named.
  Future<void> _loadVouches() async {
    final vs = await session.vouchesFor(widget.peerHaloId);
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
    if (await session.isAccepted(widget.peerHaloId)) return;
    final row = await session.shownShieldFor(widget.peerHaloId);
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

  // a reply can land while the sender sits in the locked chat, so re-check
  // whenever something arrives
  void _refreshRequestState() {
    if (_accepted && _peerEngaged && _recvCount > 0) return;
    session.isAccepted(widget.peerHaloId).then((v) {
      if (mounted && v != _accepted) setState(() => _accepted = v);
    });
    session.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted && v != _peerEngaged) setState(() => _peerEngaged = v);
    });
    session.countMessagesFrom(widget.peerHaloId).then((v) {
      if (mounted && v != _recvCount) setState(() => _recvCount = v);
    });
  }

  // a tap on a row that failed or waits. while this container's block
  // holds it stays not sent, and says why. the tap alone puts it back
  Future<void> _tapRetry(_Msg m) async {
    final uid = m.msgUid;
    if (await session.isBlocked(widget.peerHaloId)) {
      if (uid != null) await session.holdBack(uid);
      if (!mounted) return;
      setState(() {
        m.sending = false;
        m.parked = false;
        m.failed = true;
        m.notSent = true;
      });
      showHaloToast(context, l10n.chatYouBlockedThisContact);
      return;
    }
    m
      ..autoRetries = 0
      ..gaveUp = false;
    if (!m.notSent || uid == null) return _retryAny(m);
    // the outbox leaves it be while this tap sends it
    if (!appState.claimSend(uid)) return;
    try {
      await session.sendAgain(uid);
      if (!mounted) return;
      m.notSent = false;
      await _retryAny(m, claimed: true);
    } finally {
      appState.releaseSend(uid);
    }
  }

  // a row a block kept from going: only a tap puts it back (sendAgain)
  Future<bool> _stillHeld(_Msg m) async {
    final uid = m.msgUid;
    if (uid == null || !await session.heldBack(uid)) return false;
    if (mounted) {
      setState(() {
        m.sending = false;
        m.parked = false;
        m.failed = true;
        m.notSent = true;
      });
    }
    return true;
  }

  // done once the send has its verdict. [claimed]: the caller holds its uid
  Future<void> _retryAny(_Msg m, {bool claimed = false}) {
    if (m.mediaPath != null) return _retryImage(m);
    if (m.filePath != null) return _retryMedia(m);
    return _retry(m, claimed: claimed);
  }

  // online, a failed send goes again on its own: half a minute apart, six
  // goes, then it is shown as failed. the reconnect retry below covers the
  // offline case; this covers a route that was simply slow or flaky.
  void _autoRetryTick() {
    if (!mounted || _sending || _stickerSends > 0 || _cannotSend()) return;
    for (final m in _messages) {
      if (m.direction != 'out' ||
          !m.failed ||
          m.gaveUp ||
          m.notSent ||
          m.msgUid == null) {
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

  // when tor comes back, re-fire what failed while offline, never rows still
  // sending, here or in the outbox. the _wasReachable edge makes it once
  // per reconnect.
  void _retryFailedOnReconnect() {
    final reachable = _torReadyToSend();
    if (reachable && !_wasReachable) {
      // clear any stale send error, we're about to resend
      if (_status.isNotEmpty) setState(() => _status = '');
      for (final m in _messages) {
        if (m.direction == 'out' &&
            m.failed &&
            !m.notSent &&
            m.msgUid != null &&
            !appState.sendInflight(m.msgUid!)) {
          _retryAny(m);
        }
      }
    }
    _wasReachable = reachable;
  }

  // a receipt flips `delivered` in the db for a bubble already on screen,
  // which _tryAppendNew won't catch, so re-read it in place. the send state
  // too: a long upload may have been finished by an earlier screen, and the
  // database is the one that knows.
  Future<void> _refreshDelivered() async {
    final pending = _messages
        .where(
          (m) =>
              m.direction == 'out' &&
              m.msgUid != null &&
              (!m.delivered || m.sending || m.parked || m.failed),
        )
        .toList();
    if (pending.isEmpty) return;
    var changed = false;
    for (final m in pending) {
      final s = await session.sendState(m.msgUid!);
      if (s.delivered && !m.delivered) {
        m.delivered = true;
        changed = true;
      }
      final done = s.delivered || (s.sent && !mediaInflight.contains(m.msgUid));
      if (done && (m.sending || m.parked || m.failed)) {
        m.sending = false;
        m.parked = false;
        m.failed = false;
        if (m.msgUid != null) mediaProgressEnd(m.msgUid!);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  // fast path for a live message: append rows newer than the newest we hold,
  // so a full rebuild does not eat the bubble-in animation
  Future<void> _tryAppendNew() async {
    if (!_loaded || _searching) {
      _loadMessages();
      return;
    }
    final lastRowid = _messages.isEmpty
        ? 0
        : _messages.map((m) => m.rowid).reduce((a, b) => a > b ? a : b);
    final rows = await session.messagesAfter(widget.peerHaloId, lastRowid);
    if (!mounted) return;
    final have = _messages.map((m) => m.msgUid).toSet();
    // no new row we don't already hold means a full reload: covers edits,
    // reactions, deletes and clock skew (a received msg older than our newest)
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
    // someone reading back stays where they are. near the newest, where the
    // jump button is not shown, they are taken down to it
    final snap = _nearNewest;
    final fresh = <_Msg>[];
    for (final r in brandNew) {
      final uid = r['msg_uid'] as String?;
      final m = _Msg(
        r['direction'] as String,
        r['plaintext'] as String,
        DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
        sticker: StickerWire.parse(r['sticker']),
        burnAt: r['burn_at'] as int?,
        burnSecs: (r['burn_secs'] as num?)?.toInt(),
        burnUnseen: r['burn_unseen'] == 1,
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
        viaDev: r['via_dev'] == 1,
        delivered: (r['delivered'] as int? ?? 0) == 1,
        sending:
            (r['direction'] as String) == 'out' &&
            (r['sent'] as int? ?? 1) == 0,
      );
      m.rowid = (r['rowid'] as int?) ?? 0;
      _readNotSent(m, r);
      final pvRaw = r['preview'] as String?;
      if (pvRaw != null && pvRaw.isNotEmpty) {
        try {
          final d = jsonDecode(pvRaw) as Map<String, dynamic>;
          m.preview = d.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {
          // a preview that does not parse is not shown
        }
      }
      if (m.direction != 'out' && uid != null) m.fresh = true;
      fresh.add(m);
      if (uid != null) _seenUids.add(uid);
    }
    final theirs = fresh.where((m) => m.direction != 'out').length;
    final follow = snap || theirs < fresh.length;
    if (!follow && !_jumpActive) {
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
    _applySecureContent();
    // clear the home badge for what we are reading. a backed-out chat stays
    // in the tree for a while, so only the open chat gets to clear.
    if (fresh.any((m) => m.direction != 'out') &&
        currentChatPeer == widget.peerHaloId) {
      unawaited(session.clearUnread(widget.peerHaloId));
      unawaited(appState.refreshContacts());
    }
    if (follow) _scrollToEnd();
  }

  Widget _newMessagesDivider() => UnreadDivider(l10n.chatNewMessages);

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
        // a sticker has no words; its emoji is not what was said. his
        // first line is the app's, not the chat's
        if (_messages[i].sticker == null &&
            !_messages[i].welcome &&
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

  // rough jump so the match gets built, then ensureVisible to centre it.
  // saves a scroll-to-index dependency.
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

  // the reaction pill above the long-pressed bubble, in an OverlayEntry so
  // the list does not clip it
  Future<void> _showEmojiPickerAt(
    BuildContext bubbleContext,
    _Msg target,
  ) async {
    HapticFeedback.selectionClick();
    _touched(target);
    // his first line is the app's own: it is copied and nothing else
    final welcome = target.welcome;
    // a row without a uid gets a local one. the peer doesn't know it, so the
    // reaction stays local.
    if (target.msgUid == null && !welcome) {
      final uid = newMsgUid();
      target.msgUid = uid;
      await session.assignUidIfMissing(
        widget.peerHaloId,
        target.when.millisecondsSinceEpoch,
        uid,
      );
    }
    if (!mounted) return;
    await keyboardDown(context);
    // the lock went up while the uid was written: no menu
    if (!mounted || !bubbleContext.mounted || lockGuard.isLocked()) return;
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final bubbleSize = box.size;
    const pickerH = 54.0;
    // the card's height from its rows, so it is placed where it fits
    final out = target.direction == 'out';
    final media = target.mediaPath != null || target.filePath != null;
    final rows = welcome
        ? 1
        : 3 +
              (target.text.isNotEmpty && target.sticker == null ? 1 : 0) +
              (target.sticker == null ? 1 : 0) +
              (target.filePath != null && target.fileName != 'voice.wav'
                  ? 1
                  : 0) +
              (out && !media && target.sticker == null ? 1 : 0) -
              (out ? 0 : 1);
    final rowH =
        20 + math.max(17.0, MediaQuery.textScalerOf(context).scale(13.5) * 1.3);
    final menuH = rows * rowH + 16;
    final screenH = MediaQuery.of(context).size.height;
    final safeTop = MediaQuery.of(context).padding.top + 8;
    // above a keyboard that would not go, too
    final safeBottom =
        screenH -
        math.max(
          MediaQuery.of(context).padding.bottom,
          MediaQuery.viewInsetsOf(context).bottom,
        ) -
        12;
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
    // pin the bar to the message's side so it never runs off the edge
    final alignRight = target.direction == 'out';
    final still = motionStill(context);

    if (mounted) setState(() => _liftedUid = _rowKey(target));
    late OverlayEntry entry;
    VoidCallback? unguard;
    // not entry.mounted: an entry closed before its first frame is not
    // mounted yet and has to go all the same
    var gone = false;
    var removed = false;
    // the menu folds back the way it came before it goes
    var closing = false;
    // what the picked action does to the row, held until the copy is back
    VoidCallback? landed;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
      // the copy has landed on the row: the row shows again at once
      if (mounted) setState(() => _liftedUid = null);
      final run = landed;
      landed = null;
      if (mounted) run?.call();
    }

    // [then] runs once the copy is back on the row, so a change that moves
    // the row (a reaction's room, the reply bar) does not move it under
    // the copy
    void dismiss({bool now = false, VoidCallback? then}) {
      if (gone && !now) return;
      if (!gone) landed = then;
      gone = true;
      unguard?.call();
      unguard = null;
      if (now || !mounted) {
        remove();
        return;
      }
      closing = true;
      entry.markNeedsBuild();
      Future.delayed(
        still ? const Duration(milliseconds: 160) : kHouseTime,
        remove,
      );
    }

    entry = OverlayEntry(
      builder: (_) {
        return IgnorePointer(
          ignoring: closing,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: dismiss,
                  child: MenuBackdrop(closing: closing),
                ),
              ),
              // the offset is from the left edge, in either direction
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: bubbleSize.width,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: still || closing ? 0.0 : 1.0),
                    duration: kHouseTime,
                    curve: kHouseCurve,
                    child: Material(
                      type: MaterialType.transparency,
                      child: _Bubble(msg: target),
                    ),
                    builder: (_, t, child) => Transform.scale(
                      scale: 1.0 + 0.04 * t,
                      alignment: alignRight
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: child,
                    ),
                  ),
                ),
              ),

              if (!welcome && _canReact)
                PositionedDirectional(
                  top: reactTop,
                  start: alignRight ? null : 12,
                  end: alignRight ? 12 : null,
                  child: MenuPop(
                    fromRight: alignRight,
                    closing: closing,
                    child: ReactionPicker(
                      replyLabel: l10n.chatReply,
                      emojis: const ['❤️', '👍', '😂', '😮', '😢', '🔥'],
                      selected: target.reactions[''],
                      onPick: (e) => dismiss(
                        then: () {
                          final added = target.reactions[''] != e;
                          _toggleReaction(target, e);
                          if (added) _flashReaction(target);
                        },
                      ),
                      // no reply bar or keyboard over the lock
                      onReply: () => dismiss(
                        then: () {
                          if (!lockGuard.isLocked()) _replyWith(target);
                        },
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                top: menuTop,
                bottom: menuBottom,
                start: alignRight ? null : 12,
                end: alignRight ? 12 : null,
                child: MenuPop(
                  fromRight: alignRight,
                  closing: closing,
                  child: MessageMenuCard(
                    actions: [
                      // his first line: copy, and nothing else
                      if (!welcome)
                        MenuAction(
                          icon: target.pinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          label: target.pinned ? l10n.chatUnpin : l10n.chatPin,
                          onTap: () {
                            dismiss();
                            _togglePin(target);
                          },
                        ),
                      if (!welcome)
                        MenuAction(
                          icon: target.saved
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          label: target.saved
                              ? l10n.chatUnsave
                              : l10n.commonSave,
                          tint: target.saved ? HaloColors.amber : null,
                          onTap: () =>
                              dismiss(then: () => _toggleSaved(target)),
                        ),
                      MenuAction(
                        icon: Icons.copy_rounded,
                        label: l10n.commonCopy,
                        onTap: target.text.isEmpty || target.sticker != null
                            ? null
                            : () {
                                dismiss();
                                Clipboard.setData(
                                  ClipboardData(text: target.text),
                                );
                                showHaloToast(context, l10n.commonCopied);
                              },
                      ),
                      // a sticker is not forwarded, copied or edited, and
                      // a photo, a file or a voice note is not forwarded
                      if (!welcome)
                        MenuAction(
                          icon: Icons.forward_rounded,
                          label: l10n.chatForward,
                          onTap:
                              !canForward(
                                text: target.text,
                                mediaPath: target.mediaPath,
                                filePath: target.filePath,
                                sticker: target.sticker != null,
                              )
                              ? null
                              : () {
                                  // a sheet takes its place: no copy over it
                                  dismiss(now: true);
                                  _forwardMessage(target);
                                },
                        ),
                      // a tap opens a file, so sharing it lives here
                      MenuAction(
                        icon: Icons.ios_share_rounded,
                        label: l10n.commonShare,
                        onTap:
                            target.filePath == null ||
                                target.fileName == 'voice.wav'
                            ? null
                            : () {
                                dismiss(now: true);
                                lockState.hold(
                                  () => shareFileOut(
                                    target.filePath!,
                                    name: target.fileName,
                                  ),
                                );
                              },
                      ),
                      // words can be edited; a photo, a file or a voice note
                      // is what it is
                      MenuAction(
                        icon: Icons.edit_outlined,
                        label: l10n.commonEdit,
                        tint: HaloColors.amber,
                        onTap:
                            target.direction != 'out' ||
                                target.mediaPath != null ||
                                target.filePath != null ||
                                target.sticker != null
                            ? null
                            : () {
                                dismiss(now: true);
                                _editMessage(target);
                              },
                      ),
                      MenuAction(
                        icon: Icons.delete_outline,
                        danger: true,
                        label:
                            target.sending &&
                                (target.mediaPath != null ||
                                    target.filePath != null)
                            ? l10n.chatStopSending
                            : l10n.chatUnsend,
                        onTap: target.direction != 'out'
                            ? null
                            : () {
                                dismiss(now: true);
                                // a photo or file still on its way stops here
                                // and the other side drops what it has
                                if (target.sending &&
                                    (target.mediaPath != null ||
                                        target.filePath != null)) {
                                  _stopSending(target);
                                } else {
                                  _unsendMessage(target);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(entry);
    // the lock closes it at once, with what it shows
    unguard = lockGuard.closeOnLock(() => dismiss(now: true));
  }

  // the list is read from the database, not from the rows on screen: a pin
  // far up the thread is still a pin when only the last page is loaded
  Future<List<PinEntry>> _loadPins() async {
    final rows = await _shownPins();
    final nick = _nickname;
    final them = _isDev
        ? l10n.devName
        : (nick != null && nick.isNotEmpty)
        ? nick
        : widget.peerHaloId;
    return [
      for (final r in rows)
        PinEntry(
          uid: r['msg_uid'] as String,
          author: r['direction'] == 'out' ? l10n.chatYou : them,
          authorSeed: r['direction'] == 'out'
              ? appState.sessionId
              : widget.avatarSeed,
          face: r['direction'] == 'out' ? appState.myAvatar : _peerFace,
          when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
          text: (r['plaintext'] as String?) ?? '',
          imagePath: r['media_path'] as String?,
          fileName: r['file_name'] as String?,
          sticker: StickerWire.parse(r['sticker']),
        ),
    ];
  }

  // a timed message not read yet stays out of the pins, as it does out of
  // the photos: it shows in the thread, where reading it starts its clock
  Future<List<Map<String, Object?>>> _shownPins() async => [
    for (final r in await session.pinnedIn(peerId: widget.peerHaloId))
      if (!burnWaitsRow(r)) r,
  ];

  int _pinCount = 0;
  Future<void> _refreshPinCount() async {
    final n = (await _shownPins()).length;
    if (mounted && n != _pinCount) setState(() => _pinCount = n);
  }

  Future<void> _showPinnedSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showPinsSheet(
      context,
      load: _loadPins,
      onJump: (e) => _jumpToPin(e.uid),
      onUnpin: (e) => _setPinned(e.uid, false),
    );
  }

  Future<void> _setPinned(String uid, bool on) async {
    // for both of us: the other side mirrors it
    await appState.pinInChat(widget.peerHaloId, uid, on);
    if (!mounted) return;
    setState(() {
      for (final m in _messages) {
        if (m.msgUid == uid) m.pinned = on;
      }
    });
    await _refreshPinCount();
  }

  Future<void> _jumpToPin(String uid) async {
    if (!_messages.any((m) => m.msgUid == uid)) {
      // pinned above what is loaded: bring the whole thread in, and hold
      // the reload's own snap to the newest message off while we do
      _pagedOut = true;
      _jumpActive = true;
      await _loadMessages();
      if (!mounted) return;
    }
    _jumpToUid(uid);
  }

  // the unsend frame on its own, queued like an edit so one made offline
  // still goes. the other side drops the row, or the half-file and its
  // banner if it never landed.
  Future<void> _sendUnsendFrame(String uid) =>
      appState.unsendInChat(widget.peerHaloId, uid);

  // stop a photo or file mid-send. the workers end between slices, the row
  // and the file go here, and the other side is told to drop its part.
  Future<void> _stopSending(_Msg m) async {
    final uid = m.msgUid;
    if (uid == null) return;
    cancelMediaSend(uid);
    mediaProgressEnd(uid);
    if (mounted) setState(() => m.removing = true);
    await Future.delayed(kLeaveGone);
    await session.deleteMessage(uid);
    if (mounted) setState(() => _messages.remove(m));
    unawaited(appState.refreshContacts());
    unawaited(_sendUnsendFrame(uid));
  }

  Future<void> _unsendMessage(_Msg m) async {
    if (m.msgUid == null) return;
    // the confirm sheet hands focus back to the composer on close, which pops
    // the keyboard for no reason. let go of it now and again after.
    FocusManager.instance.primaryFocus?.unfocus();
    final confirm = await showConfirmSheet(
      context,
      title: l10n.chatUnsendMessage,
      line: l10n.chatItDisappearsWithNo,
      yes: l10n.chatUnsend,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (confirm != true) return;
    if (mounted) setState(() => m.removing = true);
    // it burns, then its row folds (LeaveFold); pulled sooner, it pops
    await Future.delayed(kLeaveGone);
    await session.deleteMessage(m.msgUid!);
    if (mounted) setState(() => _messages.remove(m));
    // the home row still previews the message just unsent
    unawaited(appState.refreshContacts());
    await _sendUnsendFrame(m.msgUid!);
  }

  Future<void> _togglePin(_Msg m) async {
    if (m.msgUid == null) return;
    if (!m.pinned) {
      final count = (await session.pinnedIn(peerId: widget.peerHaloId)).length;
      if (count >= kMaxPins) {
        if (mounted) {
          showHaloToast(context, l10n.chatThisChatHasPins(kMaxPins));
        }
        return;
      }
    }
    if (!mounted) return;
    final ok = await showConfirmSheet(
      context,
      title: m.pinned ? l10n.chatUnpinThisMessage : l10n.chatPinThisMessage,
      line: m.pinned ? l10n.chatItLeavesThePinned : l10n.chatItGoesUnderThe,
      yes: m.pinned ? l10n.chatUnpin : l10n.chatPinIt,
      keep: l10n.chatNotNow,
      rose: false,
    );
    if (!ok) return;
    await _setPinned(m.msgUid!, !m.pinned);
  }

  // every jump to a message lands through here: a pin, a quoted reply, a
  // saved message opened from outside. see row_anchor.dart.
  final RowAnchors _anchors = RowAnchors();

  // the bubbles alone, without the date and the new messages line above
  // them: what says a message has been read
  final RowAnchors _readAnchors = RowAnchors();

  // the route this chat is on: a sheet, a dialog or a see-through page over
  // it leaves it drawn but not read
  ModalRoute<Object?>? _route;

  // their timed messages start counting once read here
  late final _reads = ReadBurns(
    anchors: _readAnchors,
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

  // what is acted on is read: opened, played, held or answered
  void _touched(_Msg m) {
    if (m.burnUnread) _reads.touched(m.msgUid);
  }

  Future<Map<String, int>> _lightRead(List<String> uids) async {
    final at = await session.lightReadBurns(widget.peerHaloId, uids);
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
    // a pin that waited shows now, and the chat list line its words
    unawaited(_refreshPinCount());
    unawaited(appState.refreshContacts());
    return at;
  }

  void _scrollToMessage(_Msg m) => _landOn(_rowKey(m));

  void _landOn(String rowKey) {
    final at = _messages.lastIndexWhere((m) => _rowKey(m) == rowKey);
    if (at < 0) return;
    final uid = _messages[at].msgUid;
    _jumpActive = true;
    landOnRow(
      ctrl: _scrollCtrl,
      anchors: _anchors,
      id: rowKey,
      alive: () => mounted,
      indexOf: (k) {
        final i = _messages.lastIndexWhere((m) => _rowKey(m) == k);
        return i < 0 ? null : i;
      },
      reversed: true,
      rough: () {
        final p = _scrollCtrl.positions.first;
        final i = _messages.lastIndexWhere((m) => _rowKey(m) == rowKey);
        final frac = (_messages.length - 1 - i) / _messages.length;
        return frac * p.maxScrollExtent - p.viewportDimension * 0.5;
      },
      done: (landed) {
        _jumpActive = false;
        if (!mounted || !landed || uid == null) return;
        setState(() => _rippleUid = uid);
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted && _rippleUid == uid) setState(() => _rippleUid = null);
        });
      },
    );
  }

  // open an edit sheet for own message m. saves locally + tells the peer.
  Future<void> _editMessage(_Msg m) async {
    if (m.msgUid == null) {
      final uid = newMsgUid();
      m.msgUid = uid;
      await session.assignUidIfMissing(
        widget.peerHaloId,
        m.when.millisecondsSinceEpoch,
        uid,
      );
    }
    if (!mounted) return;
    final result = await showInputSheet(
      context,
      title: l10n.chatEditMessage,
      initial: m.text,
      multiline: true,
    );
    if (result == null) return;
    final newText = result.trim();
    if (newText.isEmpty || newText == m.text) return;
    setState(() {
      m.text = newText;
      m.edited = true;
    });
    await session.editMessage(m.msgUid!, newText);
    await appState.editInChat(widget.peerHaloId, m.msgUid!, newText);
    // the home row shows the new text too
    unawaited(appState.refreshContacts());
  }

  // toggle a reaction on a message. tap same emoji again to remove.
  // tap a different emoji to replace.
  Future<void> _toggleReaction(_Msg m, String emoji) async {
    // read before anything is written: a block this screen has not seen yet
    // keeps the reaction off both sides
    if (await appState.blockedAnywhere(widget.peerHaloId)) return;
    if (m.msgUid == null) {
      final uid = newMsgUid();
      m.msgUid = uid;
      await session.assignUidIfMissing(
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
    if (remove) {
      await session.removeReaction(m.msgUid!, '');
    } else {
      await session.addReaction(m.msgUid!, '', emoji);
    }
    // queued first, sent now: if the route is down the outbox carries it
    await appState.reactInChat(widget.peerHaloId, m.msgUid!, newEmoji);
  }

  final Set<String> _seenUids = <String>{};

  // Marios's first line, from the app itself, before everything else in
  // the chat: dated when the chat was made, never stored, fetched or sent
  _Msg? _welcomeBefore(List<_Msg> rows) {
    if (!_isDev) return null;
    final made = _devChat?.createdAt ?? 0;
    var when = made > 0
        ? DateTime.fromMillisecondsSinceEpoch(made)
        : DateTime.now();
    final first = rows.isEmpty ? null : rows.first.when;
    if (first != null && !when.isBefore(first)) {
      when = first.subtract(const Duration(milliseconds: 1));
    }
    return _Msg('in', l10n.devWelcome, when, welcome: true);
  }

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
    await session.purgeExpiredBurns();
    if (_isDev) {
      _devChat = await session.devChat.load();
      _syncDev();
    }
    session.isBackPaired(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _backPaired = v);
    });
    session.isBlocked(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _blocked = v);
    });
    session.isMuted(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _muted = v);
    });
    final wantAll = _searching || widget.jumpToUid != null || _pagedOut;
    // a reload keeps the pages already scrolled in: a receipt, a reaction
    // or an edit must not drop what is being read
    final keepFrom = wantAll || !_loaded ? null : _oldestHeldRowid();
    final List<Map<String, Object?>> rows;
    if (wantAll) {
      rows = await session.messagesFor(widget.peerHaloId);
      _hasMore = false;
    } else if (keepFrom != null) {
      rows = List.of(
        await session.messagesAfter(widget.peerHaloId, keepFrom - 1),
      );
    } else {
      rows = List.of(
        await session.messagesPage(widget.peerHaloId, limit: _pageSize + 1),
      );
      _hasMore = rows.length > _pageSize;
      if (_hasMore) rows.removeAt(0);
    }
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
          sticker: StickerWire.parse(r['sticker']),
          burnAt: r['burn_at'] as int?,
          burnSecs: (r['burn_secs'] as num?)?.toInt(),
          burnUnseen: r['burn_unseen'] == 1,
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
          viaDev: r['via_dev'] == 1,
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
        } catch (_) {
          // a preview that does not parse is not shown
        }
      }
      loaded.last.rowid = (r['rowid'] as int?) ?? 0;
      _readNotSent(loaded.last, r);
      if (uid != null) uids.add(uid);
    }
    final reactionMap = await session.loadReactionsFor(uids);
    for (final m in loaded) {
      if (m.msgUid == null) continue;
      final entries = reactionMap[m.msgUid!];
      if (entries == null) continue;
      for (final e in entries) {
        m.reactions[e.key] = e.value;
      }
    }
    if (!mounted) return;
    if (!_hasMore) {
      final w = _welcomeBefore(loaded);
      if (w != null) {
        // it arrives once, as the chat first opens with nothing sent yet
        w.fresh = !_loaded && !(_devOpening?.started ?? true);
        loaded.insert(0, w);
      }
    }
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
      _firstUnreadKey = null;
      for (var i = 0; i < loaded.length; i++) {
        if (loaded[i].direction != 'out' &&
            !loaded[i].welcome &&
            loaded[i].when.millisecondsSinceEpoch > _unreadAfterMs) {
          _firstUnreadKey = _rowKey(loaded[i]);
          break;
        }
      }
      _unreadResolved = true;
    }
    // a reloaded 'sending' row has no send future left to resolve it, so it
    // becomes failed (or parked) and retryable
    final backPaired = await session.isBackPaired(widget.peerHaloId);
    // a text that waits on their card after a restore is going, not dead
    final waits = appState.waitsForCard(widget.peerHaloId);
    for (final m in loaded) {
      // a text this screen is still sending keeps its pill: a failed mark
      // would make the retry send it twice. files are sendLooksDead's
      if (m.msgUid != null && appState.sendInflight(m.msgUid!)) continue;
      if (waits && m.mediaPath == null && m.filePath == null) continue;
      if (m.direction == 'out' &&
          m.sending &&
          appState.sendLooksDead(m.when, msgUid: m.msgUid)) {
        m.sending = false;
        if (backPaired) {
          m.failed = true;
        } else {
          m.parked = true;
        }
      }
    }
    // a reload rebuilds every row; the retry count rides across, or a
    // failed send never reaches its cap
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
    unawaited(_refreshPinCount());
    // someone reading back stays where they are
    final snap = !_loaded || _atNewest;
    setState(() {
      final before = List<_Msg>.of(_messages);
      final wasLoaded = _loaded;
      _loaded = true;
      _forgetDayKeys();
      _messages
        ..clear()
        ..addAll(loaded);
      if (wasLoaded) _keepLeaving(before);
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
    } else if (snap) {
      _scrollToEnd(instant: true);
    }
  }

  // the oldest row on screen that the database has, if any
  int? _oldestHeldRowid() {
    int? oldest;
    for (final m in _messages) {
      if (m.welcome || m.rowid <= 0) continue;
      if (oldest == null || m.rowid < oldest) oldest = m.rowid;
    }
    return oldest;
  }

  // reversed list: the newest message sits at offset 0
  bool get _atNewest =>
      !_scrollReady || _scrollCtrl.positions.first.pixels < 64;

  // above this the jump button shows
  static const _jumpButtonAt = 240.0;
  bool get _nearNewest =>
      !_scrollReady || _scrollCtrl.positions.first.pixels <= _jumpButtonAt;

  bool _didJump = false;
  bool _wasReachable = false;
  bool _jumpActive = false;

  // scroll a specific message into view and pulse it, for jump-from-saved.
  void _jumpToUid(String uid) {
    final idx = _messages.indexWhere((m) => m.msgUid == uid);
    if (idx < 0) {
      _jumpActive = false;
      _scrollToEnd();
      return;
    }
    _landOn(_rowKey(_messages[idx]));
  }

  // hasClients is not enough: the controller attaches before layout, and a
  // jump then reads a null minScrollExtent. .position asserts one attached
  // view, and a route transition can attach two, so .positions it is.
  bool get _scrollReady =>
      _scrollCtrl.positions.length == 1 &&
      _scrollCtrl.positions.first.hasContentDimensions;

  void _safeJump(double to) {
    if (_scrollReady) _scrollCtrl.jumpTo(to);
  }

  void _scrollToEnd({bool instant = false}) {
    if (_jumpActive) return;
    // reversed list: the newest message lives at offset 0
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

  // the receiver in main.dart owns the engine inbox and routes every message
  // through _applyIncomingPayload. this only pulls new rows from the db.
  Future<void> _checkInbox() async {
    if (!_loaded || _searching) return;
    // cheap tick: only rows newer than our newest. never a full reload here,
    // once a second that blinks the list and snaps the scroll.
    final lastRowid = _messages.isEmpty
        ? 0
        : _messages.map((m) => m.rowid).reduce((a, b) => a > b ? a : b);
    final rows = await session.messagesAfter(widget.peerHaloId, lastRowid);
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
    // new rows: the append path builds them
    await _tryAppendNew();
  }

  // a text's cipher onto the wire once a route is up, unless it was taken
  // back while it waited
  Future<String> _wireText(String? uid, String cipher) => wireWhenReady(
    ready: _torReadyToSend,
    kept: () async => uid == null || await session.messageExists(uid),
    send: () => _routeText(cipher, uid),
  );

  // before the peer back-pairs, direct onion first so their drain runs the
  // back-pair flow, with the first-contact copy beside it (routeText)
  Future<String> _routeText(String cipher, [String? uid]) async {
    // a quiet session keeps it here, waiting. a block here keeps it not
    // sent, one in the other container only waits
    if (sessionQuiet || appState.everydayHeld) return 'parked';
    if (await appState.blockedAnywhere(widget.peerHaloId)) {
      return await session.isBlocked(widget.peerHaloId)
          ? kSendBlocked
          : 'parked';
    }
    return routeText(
      backPaired: _backPaired,
      onion: widget.peerOnion,
      viaOnion: () => Future(() => engine.sendTo(widget.peerOnion, cipher)),
      // the xpub may be null on a fresh back-pair or reconnect: from the
      // session then
      xPub: () async {
        var xpub = _peerXPub;
        xpub ??= widget.peerXPub.isEmpty ? null : widget.peerXPub;
        xpub ??= await signalSession.peerXPubHex(widget.peerHaloId);
        if (xpub != null) _peerXPub = xpub;
        return xpub;
      },
      fc: appState.peerFcFor(widget.peerHaloId),
      viaFirst: (x, fc) => engine.sendFirstContact(x, fc, cipher),
      viaRelay: (x) => Future(() => engine.nostrSend(x, cipher)),
      log: (l) => dlog('chat send: $l'),
      // both its copies went: past their two it waits held, not lost
      bothWent: uid == null
          ? null
          : () => unawaited(
              session.noteOpenerBoth(uid).catchError((Object e) {
                dlog('chat send: not noted (${e.runtimeType})');
              }),
            ),
    );
  }

  // the verdict goes to every row drawn for this message: a reload since
  // the send began may have put a new object in its place
  Future<void> _finishTextSend(_Msg msg, String result) async {
    // taken back before it went: there is no row left to finish
    if (result == kTextTakenBack) return;
    final uid = msg.msgUid;
    if (result == 'ok' && uid != null) await session.markSent(uid);
    if (result == kSendBlocked && uid != null) await session.holdBack(uid);
    // not sent is the row's word, not the send's: a block that came while
    // it went has marked it already
    final held = result != 'ok' && uid != null && await session.heldBack(uid);
    int? burnAt;
    if (result == 'ok' && msg.burnSecs != null && uid != null) {
      burnAt = DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
      await session.setMsgBurnAt(uid, burnAt);
      msg.burnAt = burnAt;
    }
    if (!mounted) {
      // left and reopened while it went: tell the screen showing it now
      appState.chatChanged(widget.peerHaloId);
      return;
    }
    final shown = {
      msg,
      for (final m in _messages)
        if (uid != null && m.msgUid == uid) m,
    };
    setState(() {
      for (final m in shown) {
        m.sending = false;
        m.parked = result == 'parked' && !held;
        m.failed = held || (result != 'ok' && result != 'parked');
        m.notSent = held;
        if (burnAt != null) m.burnAt = burnAt;
      }
      if (result != 'ok' &&
          result != 'parked' &&
          result != kSendBlocked &&
          !held) {
        _status = result;
      }
    });
  }

  Future<void> _retry(_Msg msg, {bool claimed = false}) async {
    if (_sending || _stickerSends > 0) return;
    if (await _stillHeld(msg)) return;
    // still going, here or in the outbox, or it went after all: a second
    // copy is only a duplicate
    final uid = msg.msgUid;
    final own = !claimed && uid != null;
    if (own && !appState.claimSend(uid)) return;
    var handed = false;
    try {
      if (uid != null && await session.isSent(uid)) {
        // a receipt said it went: a timed one starts its clock now
        final burnAt = await session.lightBurn(uid);
        if (!mounted) return;
        setState(() {
          msg.sending = false;
          msg.failed = false;
          msg.parked = false;
          if (burnAt != null) msg.burnAt = burnAt;
        });
        return;
      }
      if (_isDev && !await _ensureDevStarted()) return;
      // a quiet session sends nothing: it goes on waiting
      if (sessionQuiet) {
        setState(() {
          msg.failed = false;
          msg.parked = true;
        });
        return;
      }
      setState(() {
        msg.failed = false;
        msg.sending = true;
        _status = '';
      });
      // a stranger's opener rides its nonce again, or the far side's gate
      // drops the retry. one ground before an edit is ground again
      var nonce = msg.msgUid == null
          ? null
          : await session.powNonceOf(msg.msgUid!);
      if (nonce != null && !powFits(msg.text, nonce)) {
        final text = msg.text;
        nonce =
            grindPowForTest?.call(text) ?? await compute(_grindPowTask, text);
        await session.setPowNonce(msg.msgUid!, nonce);
        if (!mounted) return;
      }
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
            haloId: appState.sessionId,
            edPub: appState.sessionEdPub,
            onion: appState.sessionOnion,
            xPub: appState.sessionXPub,
          ),
          // or a retried sticker arrives as its emoji
          sticker: msg.sticker?.value,
          // when it was written, not now
          writtenAt: msg.when.millisecondsSinceEpoch,
        );
        cipher = await signalEncrypt(widget.peerHaloId, wrapped);
      } catch (e) {
        if (!mounted) return;
        // waiting on their card: still going, as the first send has it
        if (e is StartingAfresh || e is KeyHeld) return;
        setState(() {
          msg.sending = false;
          msg.failed = true;
          if (devKeyFailed(e)) _devKeyFailed = true;
        });
        return;
      }
      if (_devKeyFailed && mounted) setState(() => _devKeyFailed = false);
      handed = true;
      await Future<String>(() => _wireText(uid, cipher))
          .whenComplete(() {
            if (own) appState.releaseSend(uid);
          })
          .then((result) => _finishTextSend(msg, result));
    } finally {
      if (!handed && own) appState.releaseSend(uid);
    }
  }

  Future<void> _pickBurnDuration() async {
    final picked = await showChoiceSheet<int>(
      context,
      title: l10n.chatGhostTimer,
      line: l10n.chatHowLongAfterReading,
      current: _burnSeconds,
      choices: [
        SheetChoice(30, l10n.chat30Seconds),
        SheetChoice(60, l10n.chat1Minute),
        SheetChoice(300, l10n.chat5Minutes),
        SheetChoice(3600, l10n.chat1Hour),
        SheetChoice(86400, l10n.chat24Hours),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _burnSeconds = picked;
      _ghost = true;
      _lastBurnSeconds = picked;
      _lastGhost = true;
      appState.saveGhostPref(true, picked);
    });
  }

  // a one-shot amber ring on a bubble when a reaction lands on it
  void _flashReaction(_Msg msg) {
    HapticFeedback.selectionClick();
    if (msg.msgUid == null) return;
    setState(() => _rippleUid = msg.msgUid);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_rippleUid == msg.msgUid) setState(() => _rippleUid = null);
    });
  }

  // a retry has nothing to do for a file that went, or is going. a reload
  // can paint a row failed from a stale read, and sending on that alone
  // puts the same file on the wire twice.
  Future<bool> _alreadyGoing(_Msg msg) async {
    final uid = msg.msgUid;
    if (uid == null) return false;
    if (mediaInflight.contains(uid)) {
      if (mounted) {
        setState(() {
          msg.failed = false;
          msg.sending = true;
        });
      }
      return true;
    }
    if (await session.isSent(uid)) {
      final burnAt = await session.lightBurn(uid);
      if (mounted) {
        setState(() {
          msg.failed = false;
          msg.sending = false;
          if (burnAt != null) msg.burnAt = burnAt;
        });
      }
      return true;
    }
    return false;
  }

  // resend a failed image from the saved file
  Future<void> _retryImage(_Msg msg) async {
    final path = msg.mediaPath;
    if (path == null) return;
    if (_isDev && !await _ensureDevStarted()) return;
    if (await _stillHeld(msg)) return;
    if (await _alreadyGoing(msg)) return;
    final file = File(path);
    if (!await file.exists()) {
      setState(() => msg.failed = true);
      return;
    }
    setState(() {
      msg.failed = false;
      msg.sending = true;
    });
    final msgUid = msg.msgUid ?? newMsgUid();
    msg.msgUid = msgUid;
    await _sendChunkedMedia(
      path: path,
      msgUid: msgUid,
      caption: msg.text,
      burnSeconds: msg.burnSecs,
      secure: msg.secure,
      replyTo: msg.replyTo,
      writtenAt: msg.when.millisecondsSinceEpoch,
    ).then((result) => _finishMediaSend(msg, result));
  }

  // a failed voice note or file, the same way
  Future<void> _retryMedia(_Msg msg) async {
    final path = msg.filePath;
    if (path == null || msg.fileName == null) return;
    if (_isDev && !await _ensureDevStarted()) return;
    if (await _stillHeld(msg)) return;
    if (await _alreadyGoing(msg)) return;
    final file = File(path);
    if (!await file.exists()) {
      setState(() => msg.failed = true);
      return;
    }
    setState(() {
      msg.failed = false;
      msg.sending = true;
    });
    final msgUid = msg.msgUid ?? newMsgUid();
    msg.msgUid = msgUid;
    await _sendChunkedMedia(
      path: path,
      msgUid: msgUid,
      fileName: msg.fileName!,
      voice: msg.fileName == 'voice.wav',
      voiceDisguised: msg.voiceDisguised,
      burnSeconds: msg.burnSecs,
      replyTo: msg.replyTo,
      writtenAt: msg.when.millisecondsSinceEpoch,
    ).then((result) => _finishMediaSend(msg, result));
  }

  Future<void> _showStickers() async {
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
    if (pick is GifPick) return _sendOneImage(pick.bytes, '');
    if (pick is PhoneGifPick) return _pickAndSendGif();
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
    await _sendBody(
      s.emoji,
      sticker: StickerWire.of(pack, s),
      onRow: (m) => _fly(m, s, pick.from, pick.at),
    );
  }

  // the card's wave: the waving sticker, flying from the card to its row,
  // or the emoji. a first message like any, by the same way out. its row is
  // in before this returns, so the card is gone for a second tap
  void _wave(Rect from, double at) {
    if (!_sayHi) return;
    final hi = _hi;
    if (hi == null) {
      unawaited(_sendBody(kWaveEmoji, fromComposer: false));
    } else {
      final (pack, s) = hi;
      unawaited(
        _sendBody(
          s.emoji,
          sticker: StickerWire.of(pack, s),
          onRow: (m) => _fly(m, s, from, at),
        ),
      );
    }
  }

  // the sticker flies from where it was drawn to the new row. under reduced
  // motion there is no flight and the bubble fades in
  void _fly(_Msg m, Sticker s, Rect from, double at) {
    final uid = m.msgUid;
    if (uid == null || from.isEmpty) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final landing = _landings[uid] = StickerLanding();
    VoidCallback? unguard;
    late final VoidCallback land;
    land = flySticker(
      context,
      sticker: s,
      from: from,
      at: at,
      landing: landing,
      fallback: () => _landingGuess(rtl) ?? from,
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
    const side = kStickerBubble, pad = 16.0;
    return Rect.fromLTWH(
      rtl ? r.left + pad : r.right - pad - side,
      r.bottom - 12 - side,
      side,
      side,
    );
  }

  // the same tiles as the group chat's, so attaching looks one way
  void _showAttachSheet() {
    HapticFeedback.selectionClick();
    showHaloSheet<void>(
      context,
      builder: (sheetCtx) => AttachGrid(
        note: l10n.chatNoExifNeverSaved,
        items: [
          AttachItem(
            icon: (c) => Icon(Icons.photo_camera_outlined, color: c),
            tint: HaloColors.amber,
            label: l10n.chatCamera,
            onTap: _openCamera,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.photo_library_outlined, color: c),
            tint: HaloColors.violet,
            label: l10n.chatGallery,
            onTap: _pickAndSendMultiple,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.videocam_outlined, color: c),
            tint: HaloColors.rose,
            label: l10n.chatVideo,
            onTap: _pickAndSendVideo,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.gif_box_outlined, color: c),
            tint: HaloColors.violet,
            label: l10n.chatGifFromPhone,
            onTap: _pickAndSendGif,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.attach_file, color: c),
            tint: HaloColors.amber,
            label: l10n.chatFile2,
            onTap: _pickAndSendFile,
          ),
        ],
      ),
    );
  }

  // remembered in the container that holds the chat
  Future<void> _setDisguise(bool on) async {
    setState(() => _disguise = on);
    await appState.saveChatDisguise(widget.peerHaloId, on);
  }

  Future<void> _sendVoice(VoiceTake take) async {
    final srcPath = take.path;
    final src = File(srcPath);
    // the chat went while the note was made: the raw voice goes, unsent
    if (!mounted || _requestLocked) {
      // one that will not go is swept at the next start
      shredFile(srcPath).ignore();
      return;
    }
    if (!await src.exists()) return;
    if (!mounted) return shredFile(srcPath);
    if (_isDev && !await _ensureDevStarted()) {
      await shredFile(srcPath);
      return;
    }
    // read after the start: an anonymous chat is disguised whatever the
    // note says
    final disguise = take.disguise || _devAnon;
    // the recorder's own file is the voice before any disguise, so it goes
    // once read. the copy kept with the message is below
    final raw = await takeRecording(srcPath);
    if (raw == null) return;
    final bytes = disguise ? take.masked ?? await maskWavOff(raw) : raw;
    // never sent as recorded when it was to go disguised
    if (bytes == null) {
      if (mounted) showHaloToast(context, l10n.voiceNotDisguised);
      return;
    }
    if (!identical(bytes, raw)) raw.fillRange(0, raw.length, 0);
    if (!mounted) return;
    if (_requestPending) setState(() => _sentCount++);
    final msgUid = newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.peerHaloId);
    final dest = File('${mediaDir.path}/vn_$msgUid.wav');
    await dest.writeAsBytes(bytes);
    final filePath = dest.path;
    final replyToUid = _replyTo?.msgUid;
    final msg = _Msg(
      'out',
      '',
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      replyTo: replyToUid,
      filePath: filePath,
      fileName: 'voice.wav',
      voiceDisguised: disguise,
      burnSecs: _ghost ? _burnSeconds : null,
      burnAt: null,
    );
    setState(() {
      _messages.add(msg);
      _normaliseMessages();
      _status = '';
      _replyTo = null;
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await _answerSupport();
    await session.saveMessage(
      widget.peerHaloId,
      'out',
      '',
      msgUid: msgUid,
      replyTo: replyToUid,
      filePath: filePath,
      fileName: 'voice.wav',
      voiceDisguised: disguise,
      burnAt: msg.burnAt,
      burnSecs: msg.burnSecs,
      sent: 0,
    );
    // the home row moves up on what you sent too
    unawaited(appState.refreshContacts());
    _sendChunkedMedia(
      path: filePath,
      msgUid: msgUid,
      fileName: 'voice.wav',
      voice: true,
      voiceDisguised: disguise,
      burnSeconds: _ghost ? _burnSeconds : null,
      replyTo: replyToUid,
      writtenAt: msg.when.millisecondsSinceEpoch,
    ).then((result) => _finishMediaSend(msg, result));
  }

  // rough wire time: 16k slices, base64 adds a third, five in flight at
  // about two seconds a round over tor
  String _wireEstimate(int bytes) {
    final slices = ((bytes * 4 / 3) / (16 * 1024)).ceil();
    final secs = ((slices / 5).ceil() * 2.2).round();
    if (secs < 20) return l10n.chatAFewSeconds;
    if (secs < 90) return l10n.chatUnderAMinute;
    final mins = (secs / 60).round();
    return l10n.chatRoughlyMin(mins);
  }

  String _humanBytes(int b) {
    if (b < 1024) return l10n.chatB2(whole(b));
    if (b < 1024 * 1024) return l10n.chatKb2(whole((b / 1024).round()));
    return l10n.chatMb2(decimal((b / (1024 * 1024)), 1));
  }

  // anything big enough to be a wait gets a confirm first. small stuff goes
  // straight out - a dialog on a 40kb photo would just be noise.
  Future<bool> _confirmBigSend(int bytes) async {
    if (bytes < 512 * 1024) return true;
    if (!mounted) return false;
    final ok = await showConfirmSheet(
      context,
      title: l10n.chatSendThis,
      figure: appState.sendMode == 'private'
          ? l10n.chatOverTor(_humanBytes(bytes), _wireEstimate(bytes))
          : _humanBytes(bytes),
      line: l10n.chatBigFilesGoOut,
      yes: l10n.chatSendIt,
      keep: l10n.commonCancel,
      rose: false,
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    return ok;
  }

  // the picker hands back a path to its own copy, copied from there into the
  // media folder, so no byte array crosses the plugin channel. withData
  // keeps three copies in memory and gives null bytes on 32-bit phones.
  Future<void> _pickAndSendFile() async {
    final PlatformFile? res;
    try {
      res = await lockState.hold(() => FilePicker.pickFile());
    } on LockDropped {
      // the session it was picked in is gone: nothing to say
      return;
    } catch (e) {
      // the picker could not copy what was chosen: a provider that will
      // not hand the file over, a gone download. say so instead of nothing.
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    if (res == null) return;
    final path = res.path;
    final name = res.name;
    if (path != null) await _sendFileFrom(path, name);
    await shredPicked([res]);
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
      ).push<String?>(haloRoute<String?>(ImageCaptionScreen(bytes: r.photo!)));
      if (caption == null) return;
      await _sendOneImage(r.photo!, caption);
      return;
    }
    final path = r.videoPath;
    if (path == null) return;
    if (!mounted) return;
    await _sendFileFrom(path, madeVideoName());
    await shredFile(path);
  }

  // src is a file this app can read: the picker's copy or a camera clip.
  // it is copied into the media folder, never read into memory.
  Future<void> _sendFileFrom(String src, String picked) async {
    if (_requestLocked) return;
    final name = sentFileName(picked);
    final int size;
    try {
      size = await File(src).length();
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    // an empty file would read as sent with nothing gone
    if (size == 0) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    if (size > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, l10n.chatFileTooBig8);
      return;
    }
    if (!await _confirmBigSend(size)) return;
    // after the confirm, so a cancelled send does not spend one of the two
    // slots a stranger gets. taken now, before the awaits below, so a second
    // send cannot slip past the limit; one that does not go gives it back
    final slot = _requestPending;
    if (slot) setState(() => _sentCount++);
    void giveBack() {
      if (slot && mounted) setState(() => _sentCount--);
    }

    final msgUid = newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.peerHaloId);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${mediaDir.path}/f_${msgUid}_$safe');
    await File(src).copy(dest.path);
    // a gallery video carries where, on what and when, like a photo. it is
    // stripped in place on our own copy, and one that cannot be walked is
    // not sent.
    if (videoNameNeedsStrip(name)) {
      final ok = await stripMp4Metadata(dest.path);
      final left = ok == null ? null : await mp4MetadataCount(dest.path);
      if (ok == null || left != 0) {
        await shredFile(dest.path);
        giveBack();
        if (mounted) showHaloToast(context, l10n.chatCouldNotCleanThat);
        return;
      }
    }
    // a picture sent as a file is cleaned like one sent as a photo. it is
    // told by its bytes, not its name: jpeg, png, webp, heic, avif. one the
    // app cannot read through is not sent; the photo button re-encodes and
    // will take it.
    else if (await stripPictureFileOffUi(dest.path) == null) {
      await shredFile(dest.path);
      giveBack();
      if (mounted) {
        showHaloToast(context, l10n.chatCouldNotCleanThatPictureSend);
      }
      return;
    }
    if (_isDev && !await _ensureDevStarted()) {
      await shredFile(dest.path);
      giveBack();
      return;
    }
    final filePath = dest.path;
    final replyToUid = _replyTo?.msgUid;
    final msg = _Msg(
      'out',
      '',
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      replyTo: replyToUid,
      filePath: filePath,
      fileName: name,
      burnSecs: _ghost ? _burnSeconds : null,
      burnAt: null,
    );
    setState(() {
      _messages.add(msg);
      _normaliseMessages();
      _status = '';
      _replyTo = null;
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await _answerSupport();
    await session.saveMessage(
      widget.peerHaloId,
      'out',
      '',
      msgUid: msgUid,
      replyTo: replyToUid,
      filePath: filePath,
      fileName: name,
      burnAt: msg.burnAt,
      burnSecs: msg.burnSecs,
      sent: 0,
    );
    unawaited(appState.refreshContacts());
    _sendChunkedMedia(
      path: filePath,
      msgUid: msgUid,
      fileName: name,
      burnSeconds: _ghost ? _burnSeconds : null,
      replyTo: replyToUid,
      writtenAt: msg.when.millisecondsSinceEpoch,
    ).then((result) => _finishMediaSend(msg, result));
  }

  // a 5s wav is ~200kb of base64, over every public relay's event cap, so
  // all media goes in 16kb slices. fileName null means the image lane. the
  // shared sender does the work; this hands it what the screen knows.
  Future<String> _sendChunkedMedia({
    required String path,
    required String msgUid,
    String caption = '',
    String? fileName,
    bool voice = false,
    bool voiceDisguised = false,
    int? burnSeconds,
    bool secure = false,
    String? replyTo,
    // when its row was written
    required int writtenAt,
  }) async {
    // a quiet session keeps it here: it waits, and nothing leaves
    if (sessionQuiet || appState.everydayHeld) return 'parked';
    return sendChunkedMediaTo(
      peerId: widget.peerHaloId,
      peerOnion: widget.peerOnion,
      peerXPub: _peerXPub ?? (widget.peerXPub.isEmpty ? null : widget.peerXPub),
      backPaired: _backPaired,
      needPow: _recvCount == 0 || !await hasSessionWith(widget.peerHaloId),
      path: path,
      msgUid: msgUid,
      caption: caption,
      fileName: fileName,
      voice: voice,
      voiceDisguised: voiceDisguised,
      burnSeconds: burnSeconds,
      secure: secure,
      replyTo: replyTo,
      writtenAt: writtenAt,
      sender: SenderInfo(
        haloId: appState.sessionId,
        edPub: appState.sessionEdPub,
        onion: appState.sessionOnion,
        xPub: appState.sessionXPub,
        avatar: appState.myAvatar,
      ),
      progressKey: _memo,
      blockedHere: () => session.isBlocked(widget.peerHaloId),
    );
  }

  Future<void> _finishMediaSend(_Msg msg, String result) async {
    // another sender already has this one; its verdict comes later. a
    // cancelled one has no row left to finish.
    if (result == 'busy' || result == 'cancelled') return;
    if (msg.msgUid != null) mediaProgressEnd(msg.msgUid!);
    if (result == 'ok' && msg.msgUid != null) {
      await session.markSent(msg.msgUid!);
    }
    final uid = msg.msgUid;
    if (result == kSendBlocked && uid != null) await session.holdBack(uid);
    // not sent is the row's word, as for a text
    final held = result != 'ok' && uid != null && await session.heldBack(uid);
    if (result == 'ok' && msg.burnSecs != null && msg.msgUid != null) {
      final ba = DateTime.now().millisecondsSinceEpoch + msg.burnSecs! * 1000;
      await session.setMsgBurnAt(msg.msgUid!, ba);
      msg.burnAt = ba;
    }
    if (!mounted) {
      // left and reopened while it uploaded: tell the screen showing it now
      appState.chatChanged(widget.peerHaloId);
      return;
    }
    // a reload since the send began left [msg] off screen and a new object
    // in its place; the verdict goes to the one being drawn as well
    final shown = _messages.where(
      (m) => m.msgUid != null && m.msgUid == msg.msgUid,
    );
    setState(() {
      for (final m in {msg, ...shown}) {
        m.sending = false;
        m.parked = result == 'parked' && !held;
        m.failed = held || (result != 'ok' && result != 'parked');
        m.notSent = held;
      }
      // his key did not check out: the line says it, not the raw error
      if (result == kDevKeyFailed) {
        _devKeyFailed = true;
      } else if (result != 'ok' &&
          result != 'parked' &&
          result != kSendBlocked &&
          !held) {
        _status = result;
      } else if (result == 'ok') {
        _devKeyFailed = false;
      }
    });
  }

  Future<void> _pickAndSendGif() async {
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
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    if (res == null) return;
    // read from the picker's copy: one copy of the bytes, not three
    final path = res.path;
    final data = path == null ? null : await File(path).readAsBytes();
    await shredPicked([res]);
    if (data == null) return;
    // a gif must not be re-encoded, that kills the animation, so it skips the
    // resize path. capped to keep send time and memory sane over tor.
    if (data.length > 8 * 1024 * 1024) {
      if (mounted) showHaloToast(context, l10n.chatGifTooBig8);
      return;
    }
    // raw, but not with what rode along: a gif's comment and xmp blocks
    // go, its frames and its loop count stay. whatever was picked under
    // the gif filter is cleaned as the kind of file its bytes say it is.
    final clean = stripPictureBytes(data);
    if (clean == null) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotCleanThatGif);
      return;
    }
    // send raw through the image path - Image.memory animates gifs by the bytes,
    // the name follows the bytes.
    await _sendOneImage(clean, '');
  }

  Future<void> _sendOneImage(Uint8List raw, String caption) async {
    // the gallery's re-encode copies the tags across; nothing leaves with
    // them. first, so a photo that is dropped spends no request slot
    final bytes = await photoToSendOffUi(raw);
    if (bytes == null) {
      if (mounted) showHaloToast(context, l10n.cameraCouldNotStripThat);
      return;
    }
    // two of anything before they accept, photos included: the far side
    // holds a third
    if (_requestLocked) return;
    if (_isDev && !await _ensureDevStarted()) return;
    if (_requestPending) setState(() => _sentCount++);
    final msgUid = newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.peerHaloId);
    // a png, gif, webp or heic keeps its own kind, and its name says so
    final mediaFile = File('${mediaDir.path}/$msgUid.${pictureExt(bytes)}');
    await mediaFile.writeAsBytes(bytes);
    final mediaPath = mediaFile.path;
    // read it once - the toggle is cleared below and the save reads it after.
    final wantSecure = _secureNext;
    // a few photos at once: the first one answers
    final replyToUid = _replyTo?.msgUid;
    final msg = _Msg(
      'out',
      caption,
      DateTime.now(),
      sending: true,
      msgUid: msgUid,
      replyTo: replyToUid,
      mediaPath: mediaPath,
      burnSecs: _ghost ? _burnSeconds : null,
      burnAt: null,
      secure: wantSecure,
    );
    setState(() {
      _messages.add(msg);
      _normaliseMessages();
      _status = '';
      _replyTo = null;
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();
    await _answerSupport();
    await session.saveMessage(
      widget.peerHaloId,
      'out',
      caption,
      msgUid: msgUid,
      replyTo: replyToUid,
      mediaPath: mediaPath,
      burnAt: msg.burnAt,
      burnSecs: msg.burnSecs,
      sent: 0,
      secure: wantSecure,
    );
    unawaited(appState.refreshContacts());
    if (wantSecure && mounted) setState(() => _secureNext = false);
    unawaited(
      _sendChunkedMedia(
        path: mediaPath,
        msgUid: msgUid,
        caption: caption,
        burnSeconds: _ghost ? _burnSeconds : null,
        secure: wantSecure,
        replyTo: replyToUid,
        writtenAt: msg.when.millisecondsSinceEpoch,
      ).then((r) => _finishMediaSend(msg, r)),
    );
  }

  // its own tile rather than a mixed picker: on android 12 and older the
  // mixed one is the system file browser. the clip goes the file way, which
  // strips it and copies it out of the picker's cache.
  Future<void> _pickAndSendVideo() async {
    final x = await lockState.hold(
      () => ImagePicker().pickVideo(source: ImageSource.gallery),
    );
    if (x == null) return;
    try {
      // a screen gone meanwhile sends nothing, and the copy still goes
      if (!mounted) return;
      await _sendFileFrom(x.path, madeVideoName(x.name));
    } finally {
      await shredPickedImages([x]);
    }
  }

  Future<void> _pickAndSendMultiple() async {
    // whole, each in a folder of its own: see readPickedPhotos
    final picked = await lockState.hold(() => ImagePicker().pickMultiImage());
    if (picked.isEmpty) return;
    // the bytes are all that is kept
    final bytesOf = await readPickedPhotos(picked);
    // one photo picked: same preview + caption screen the camera path gets.
    if (bytesOf.length == 1) {
      if (!mounted) return;
      final caption = await Navigator.of(context).push<String?>(
        haloRoute<String?>(ImageCaptionScreen(bytes: bytesOf[0])),
      );
      if (caption == null) return;
      await _sendOneImage(bytesOf[0], caption);
      return;
    }
    for (final bytes in bytesOf) {
      if (!mounted) return;
      await _sendOneImage(bytes, '');
    }
  }

  // when the oldest of ours still going was written. a file that is
  // plainly moving is not waiting, and neither is a row that already reads
  // as failed
  DateTime? _waitingSince() {
    DateTime? oldest;
    for (final m in _messages) {
      if (m.direction != 'out' ||
          !(m.sending || (m.failed && !_sendLooksFailed(m)))) {
        continue;
      }
      if (appState.linkUp &&
          m.msgUid != null &&
          mediaInflight.contains(m.msgUid)) {
        continue;
      }
      if (oldest == null || m.when.isBefore(oldest)) oldest = m.when;
    }
    return oldest;
  }

  // the outbox's own test: a network, and in onion a tor a relay has got
  // through since the route was last torn down. tor's word alone can say
  // ready while nothing gets through
  bool _torReadyToSend() => appState.linkUp;

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
              ? l10n.chatTorIsNotUp
              : html.startsWith('error:')
              ? l10n.chatCouldnTReachIt
              : l10n.chatNoTitleCameBack,
        );
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _pendingPreview = senderPreview(url, title));
    } catch (_) {
      if (mounted) {
        showHaloToast(context, l10n.chatCouldnTFetchIt);
      }
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending || (_devOpening?.busy ?? false)) return;
    await _sendBody(text);
  }

  // the one way out for words: a sticker rides it with its emoji as the
  // words, so it gets the same save, proof of work, seal, route, ticks and
  // retry. [onRow] sees the row before it is on screen. words from
  // elsewhere than the composer leave what is typed there as it is
  Future<void> _sendBody(
    String text, {
    StickerWire? sticker,
    void Function(_Msg)? onRow,
    bool fromComposer = true,
  }) async {
    // a stranger gets 2 messages, then the chat locks until they accept. the
    // input bar shows it; this guards the send itself.
    if (_requestLocked) return;
    // the slot is taken before any await, so a sticker and a text sent side
    // by side cannot both pass the check above. one that does not go gives
    // it back
    final slot = _requestPending;
    if (slot) setState(() => _sentCount++);
    void giveBack() {
      if (slot && mounted) setState(() => _sentCount--);
    }

    if (_isDev && !await _ensureDevStarted()) {
      giveBack();
      return;
    }
    if (!mounted) return;
    final typed = sticker == null && fromComposer;
    final msgUid = newMsgUid();
    // claimed from the start: a reload while it grinds or seals keeps it
    // sending, and no retry sends it alongside
    appState.claimSend(msgUid);
    var handed = false;
    try {
      final replyToUid = _replyTo?.msgUid;
      // a pending preview only belongs to a message that still holds its link
      final url = typed ? firstUrl(text) : null;
      final preview = url != null && _pendingPreview?['url'] == url
          ? _pendingPreview
          : null;
      final msg = _Msg(
        'out',
        text,
        DateTime.now(),
        sticker: sticker,
        sending: true,
        msgUid: msgUid,
        replyTo: replyToUid,
        burnSecs: _ghost ? _burnSeconds : null,
        burnAt: null,
      );
      msg.preview = preview;
      onRow?.call(msg);
      // a sticker or a wave leaves the composer as it is: what was typed
      // stays typed
      void sealing(bool on) {
        if (typed) {
          _sending = on;
        } else {
          _stickerSends += on ? 1 : -1;
        }
      }

      setState(() {
        _messages.add(msg);
        _normaliseMessages();
        sealing(true);
        _status = '';
        _replyTo = null;
        if (typed) _pendingPreview = null;
      });
      if (typed) _msgCtrl.clear();
      _scrollToEnd();
      // the sheet or the card already fired it
      if (typed) HapticFeedback.lightImpact();

      await _answerSupport();
      try {
        await session.saveMessage(
          widget.peerHaloId,
          'out',
          text,
          burnAt: msg.burnAt,
          burnSecs: msg.burnSecs,
          msgUid: msgUid,
          replyTo: replyToUid,
          sent: 0,
          preview: preview == null ? null : jsonEncode(preview),
          sticker: sticker?.value,
        );
      } catch (e) {
        // a throw must not leave _sending true: that disables the composer
        // and the auto retry until the chat is reopened
        dlog('send: save failed: $e');
        if (!mounted) return;
        giveBack();
        setState(() {
          msg.sending = false;
          msg.failed = true;
          sealing(false);
        });
        return;
      }
      // the home row moves up on what you sent too, not only on what arrived
      unawaited(appState.refreshContacts());
      // a quiet session keeps the row here, unsent. it is never sealed: the
      // seal would move the everyday identity's session with this person on
      if (sessionQuiet) {
        if (!mounted) return;
        setState(() {
          msg.sending = false;
          msg.parked = true;
          sealing(false);
        });
        return;
      }
      // first-contact proof of work, ground off the ui thread: until they have
      // written to us their gate sees a stranger. the seed is the raw text, as
      // the receiver's verifyPow expects.
      int? powNonce;
      final String cipher;
      try {
        // a fresh session is an opener whatever the history: the far side
        // may have let us go and its gate asks again
        final fresh = !await hasSessionWith(widget.peerHaloId);
        if (_recvCount == 0 || fresh) {
          final int n =
              grindPowForTest?.call(text) ?? await compute(_grindPowTask, text);
          powNonce = n;
          // kept on the row so a retry from the outbox carries the same nonce
          await session.setPowNonce(msgUid, n);
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
            haloId: appState.sessionId,
            edPub: appState.sessionEdPub,
            onion: appState.sessionOnion,
            xPub: appState.sessionXPub,
          ),
          sticker: sticker?.value,
          writtenAt: msg.when.millisecondsSinceEpoch,
        );
        // an opener goes again as these very words (sendOpenersAgain)
        if (!_backPaired) {
          await session.keepOpenerWire(msgUid, wrapped).catchError((Object e) {
            dlog('send: opener not kept (${e.runtimeType})');
          });
        }
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
          sealing(false);
          // one waiting on their card after a restore is no broken session
          // and no failed send: it stays going, and the outbox sends it
          // once their card is here
          if (e is StartingAfresh || e is KeyHeld) return;
          msg.sending = false;
          msg.failed = true;
          if (slot) _sentCount--;
          if (devKeyFailed(e)) {
            _devKeyFailed = true;
          } else {
            _status = l10n.chatNoSignalSessionRe;
          }
        });
        return;
      }
      // fire and forget: a failure marks the row for retry. left while it
      // ground or sealed, it still goes from here
      void sealed() {
        sealing(false);
        _status = '';
        _devKeyFailed = false;
      }

      mounted ? setState(sealed) : sealed();
      handed = true;
      Future<String>(() => _wireText(msgUid, cipher))
          .whenComplete(() => appState.releaseSend(msgUid))
          .then((result) => _finishTextSend(msg, result));
    } finally {
      if (!handed) appState.releaseSend(msgUid);
    }
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

  // the lock lifted with this chat on top: it is the one being read again,
  // so its messages are not counted unread and a tap on one of its
  // notifications does not open a second copy of it
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
    claimChat(widget.peerHaloId);
    _markRead();
    _catchUp();
  }

  // a chat pushed over this one closed: this is the one being read again
  @override
  void backOnTop() {
    // a copy of this chat opened over it may have changed the draft
    final draft = draftPerPeer[_memo] ?? '';
    if (draft.trim() != _msgCtrl.text.trim()) _takeDraft(draft);
    if (lockGuard.isLocked()) {
      _underLock = true;
      return;
    }
    claimChat(widget.peerHaloId);
    _markRead();
    _catchUp();
  }

  void _markRead() {
    _reads.look();
    session
        .clearUnread(widget.peerHaloId)
        .then((_) => appState.refreshContacts());
    unawaited(clearNotificationsFor(widget.peerHaloId));
  }

  // back in front: what changed while it was away is read from the
  // database, whatever the notes on the way said
  void _catchUp() {
    _lastRev = appState.chatRevOf(widget.peerHaloId);
    _loadMessages();
    unawaited(_refreshDelivered());
    unawaited(_reconcileSending());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // out of the app this chat is not being read, so incoming messages must
    // light the unread dot. leaving to home does not dispose the chat.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      releaseChat(widget.peerHaloId);
    } else if (state == AppLifecycleState.resumed) {
      // only re-claim "this chat is open" as the visible route with no lock
      // over it, or a backed-out chat stays open for good and its unread dot
      // never lights. under the lock the claim waits for _lockLifted.
      if (!onScreen(context)) {
        releaseChat(widget.peerHaloId);
        return;
      }
      claimChat(widget.peerHaloId);
      // what rang while it was away has been seen now
      _markRead();
      _catchUp();
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
      if (await session.isSent(m.msgUid!)) {
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
    releaseChat(widget.peerHaloId);
    super.deactivate();
  }

  // a page title only while the words still lead with its link: an edit
  // to another link leaves it behind
  static Map<String, String>? _linkPreview(_Msg m) {
    final pv = m.preview;
    return pv != null && pv['url'] == m.url ? pv : null;
  }

  static String _rowKey(_Msg m) =>
      m.welcome ? 'welcome' : (m.msgUid ?? 'r${m.rowid}');

  // where a row went when the list under it changed, so its state follows
  // the message and not the slot
  int? _indexOfRow(Key key) {
    if (key is! ValueKey<String>) return null;
    final ix = _messages.lastIndexWhere((m) => _rowKey(m) == key.value);
    return ix < 0 ? null : _messages.length - 1 - ix;
  }

  Widget _buildRow(BuildContext c, int i, bool searchActive) {
    final ix = _messages.length - 1 - i;
    final m = _messages[ix];
    // an empty control message that leaked through would be a blank bubble.
    // a sticker this version does not have may have no text at all
    if (m.text.isEmpty &&
        m.sticker == null &&
        m.mediaPath == null &&
        m.filePath == null &&
        m.preview == null) {
      return const SizedBox.shrink();
    }
    String? quoted;
    String? quotedAuthor;
    StickerWire? quotedSticker;
    if (m.replyTo != null) {
      final original = _byUid[m.replyTo];
      if (original == null) {
        quoted = l10n.chatMessageUnavailable;
      } else {
        quotedAuthor = original.direction == 'out'
            ? l10n.chatYou2
            : l10n.chatThem;
        // a timed message not read yet says only that it is one: its words
        // show on its own bubble, where reading them starts its clock
        if (original.burnUnread) {
          quoted = l10n.timedMessageLabel;
        } else if (original.sticker != null) {
          quoted = l10n.stickerLabel;
          quotedSticker = original.sticker;
        } else if (original.text.isNotEmpty) {
          quoted = original.text;
        } else if (original.mediaPath != null) {
          quoted = l10n.chatQuotedPhoto;
        } else if (original.fileName == 'voice.wav') {
          quoted = l10n.chatVoiceMessage;
        } else if (original.fileName != null) {
          quoted = original.fileName;
        } else {
          quoted = l10n.chatMessageUnavailable;
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
    final firstUnread = _rowKey(m) == _firstUnreadKey;
    final firstInGroup = !sameRun(prevMsg) || firstUnread;
    final lastInGroup = !sameRun(nextMsg);
    final bubble = SizedBox(
      width: double.infinity,
      child: AnimatedOpacity(
        opacity: _rowKey(m) == _liftedUid ? 0.0 : 1.0,
        // back with no fade: the menu's copy has just landed right on it
        duration: _rowKey(m) == _liftedUid
            ? const Duration(milliseconds: 300)
            : Duration.zero,
        child: _Bubble(
          key: isMatch ? _matchKeys[ix] : null,
          msg: m,
          stickers: _stickers,
          stickerOrder: i,
          landing: m.msgUid == null ? null : _landings[m.msgUid],
          quotedSticker: quotedSticker,
          linkTitle: _linkPreview(m)?['title'],
          linkBySender: _linkPreview(m)?['by'] == 'sender',
          firstInGroup: firstInGroup,
          lastInGroup: lastInGroup,
          revealed: m.msgUid != null && m.msgUid == _revealedUid,
          onReveal: m.msgUid == null
              ? null
              : () => setState(
                  () =>
                      _revealedUid = _revealedUid == m.msgUid ? null : m.msgUid,
                ),
          onRetry: _tapRetry,
          onLongPress: (ctx) => _showEmojiPickerAt(ctx, m),
          onAct: () => _touched(m),
          onReact: m.welcome || !_canReact
              ? null
              : (e) {
                  final added = m.reactions[''] != e;
                  _toggleReaction(m, e);
                  if (added) _flashReaction(m);
                },
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
          unconfirmed:
              !m.welcome &&
              m.msgUid != null &&
              waitsForReceipt(
                out: m.direction == 'out',
                sent: !m.sending && !m.failed && !m.parked,
                delivered: m.delivered,
                backPaired: _backPaired,
              ),
        ),
      ),
    );
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDate) _dateDivider(m.when, m.msgUid ?? 'r${m.rowid}'),
          if (firstUnread) _newMessagesDivider(),
          // the bubble alone: what says it has been read
          RowAnchor(
            anchors: _readAnchors,
            id: _rowKey(m),
            child: LeaveFold(
              leaving: m.removing,
              // a timed bubble has burned already; any other burns now
              after: m.burnedAway ? Duration.zero : kBurnDissolve,
              // his first line takes no reply
              child: m.welcome
                  ? bubble
                  : SwipeToReply(
                      onReply: () {
                        HapticFeedback.selectionClick();
                        _replyWith(m);
                      },
                      child: bubble,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // nothing to do: protection lives in the viewer, so a marked photo is
  // covered and the chat around it stays usable
  void _applySecureContent() {}

  // the quote goes up over the composer and the keyboard comes with it
  void _replyWith(_Msg m) {
    _touched(m);
    setState(() {
      _replyTo = m;
      _replyFlash = m;
    });
    _composerFocus.requestFocus();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && identical(_replyFlash, m)) {
        setState(() => _replyFlash = null);
      }
    });
  }

  @override
  void dispose() {
    for (final land in List.of(_flights)) {
      land();
    }
    _timers.dispose();
    _reads.dispose();
    releaseChat(widget.peerHaloId);
    final open = _openChats[widget.peerHaloId]?..remove(this);
    if (open != null && open.isEmpty) _openChats.remove(widget.peerHaloId);
    lockState.removeListener(_lockLifted);
    appState.removeListener(_onAppStateChanged);
    _devOpening
      ?..removeListener(_onDevOpening)
      ..dispose();
    _lastReadPerPeer[_memo] = _messages.isNotEmpty
        ? _messages.last.when.millisecondsSinceEpoch
        : 0;
    final draft = _msgCtrl.text;
    if (draft.trim().isEmpty) {
      draftPerPeer.remove(_memo);
    } else {
      draftPerPeer[_memo] = draft;
    }
    _msgCtrl.dispose();
    _composerFocus.dispose();
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
    final rows = await session.messagesFor(widget.peerHaloId);
    final paths = <String>[];
    final securePaths = <String>{};
    for (final r in rows) {
      // one not read yet shows in the thread alone
      if (burnWaitsRow(r)) continue;
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
          title: _isDev ? l10n.devName : _nickname ?? widget.peerHaloId,
        ),
      ),
    );
  }

  // his chat's menu: its photos and what his sheet does. no contact page,
  // introduction, note, wallpaper, clear, block or hide
  Future<void> _devActions() async {
    final d = _devShown;
    if (d == null) return;
    final action = await showHaloSheet<String>(
      context,
      scroll: true,
      builder: (ctx) {
        void pick(String a) => Navigator.pop(ctx, a);
        return SingleChildScrollView(
          child: MenuSheet(
            groups: [
              [
                MenuSheetRow(
                  icon: Icons.photo_library_outlined,
                  label: l10n.chatSharedPhotos,
                  onTap: () => pick('photos'),
                ),
              ],
              [
                MenuSheetRow(
                  icon: d.muted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  label: d.muted
                      ? l10n.chatUnmuteNotifications
                      : l10n.chatMuteNotifications,
                  onTap: () => pick('mute'),
                ),
                MenuSheetRow(
                  icon: d.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  label: d.pinned ? l10n.chatUnpin : l10n.chatPinToTop,
                  onTap: () => pick('pin'),
                ),
                MenuSheetRow(
                  icon: d.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  label: d.archived
                      ? l10n.archivedUnarchive
                      : l10n.chatArchiveChat,
                  onTap: () => pick('archive'),
                ),
              ],
              [
                MenuSheetRow(
                  icon: Icons.delete_outline,
                  label: l10n.contactDeleteChat,
                  danger: true,
                  onTap: () => pick('delete'),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    final nav = Navigator.of(context);
    switch (action) {
      case 'photos':
        await _openMediaGallery();
      case 'mute':
        await setDevMuted(!d.muted);
      case 'pin':
        await setDevPinned(!d.pinned);
        if (mounted) {
          showHaloToast(
            context,
            d.pinned ? l10n.chatUnpinned : l10n.chatPinnedToTop,
          );
        }
      case 'archive':
        await setDevArchived(!d.archived);
        // out of the list: back to it, as an archived chat is left
        if (!d.archived) nav.popUntil((r) => r.isFirst);
      case 'delete':
        if (await deleteDevChat(context, d)) nav.popUntil((r) => r.isFirst);
    }
  }

  Future<void> _chatActions() async {
    if (_isDev) return _devActions();
    final contact = await session.getContact(widget.peerHaloId);
    final pinned = (contact?['pinned'] as int? ?? 0) == 1;
    // requests and blocked people stay where they are
    final hidden = session.isHidden(widget.peerHaloId);
    final hideable =
        lockState.inVault && _accepted && !_blocked && !widget.support;
    // his phone: a contact's chat that came through the developer chat
    final toInbox =
        !widget.support &&
        !_blocked &&
        await appState.movableToInbox(widget.peerHaloId);
    if (!mounted) return;
    final action = await showHaloSheet<String>(
      context,
      scroll: true,
      // the disguise switch flips in place, the sheet stays
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _chatMenu(
          ctx,
          hidden: hidden,
          hideable: hideable,
          toInbox: toInbox,
          pinned: pinned,
          onDisguise: () async {
            await _setDisguise(!_disguise);
            setSheet(() {});
          },
        ),
      ),
    );
    if (!mounted) return;
    await _onChatAction(action, hidden: hidden);
  }

  Widget _chatMenu(
    BuildContext ctx, {
    required bool hidden,
    required bool hideable,
    required bool toInbox,
    required bool pinned,
    required VoidCallback onDisguise,
  }) {
    void pick(String a) => Navigator.pop(ctx, a);
    return SingleChildScrollView(
      child: MenuSheet(
        groups: [
          // the person themselves: name, verification, vouches, media
          [
            MenuSheetRow(
              icon: Icons.person_outline,
              label: l10n.chatViewContact,
              onTap: () => pick('contact'),
            ),
            // greyed with a reason while the contact is still a
            // request: you cannot vouch for someone you have not
            // accepted yourself. someone blocked is not offered
            if (!_blocked)
              MenuSheetRow(
                icon: Icons.people_outline,
                label: l10n.chatIntroduceTo,
                sub: _accepted ? null : l10n.chatAcceptThemFirst,
                onTap: _accepted ? () => pick('introduce') : null,
              ),
            MenuSheetRow(
              icon: Icons.photo_library_outlined,
              label: l10n.chatSharedPhotos,
              onTap: () => pick('photos'),
            ),
          ],
          [
            MenuSheetRow(
              icon: _muted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              label: _muted
                  ? l10n.chatUnmuteNotifications
                  : l10n.chatMuteNotifications,
              onTap: () => pick('mute'),
            ),
            MenuSheetRow(
              icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: pinned ? l10n.chatUnpin : l10n.chatPinToTop,
              onTap: () => pick('pin'),
            ),
            MenuSheetRow(
              icon: Icons.archive_outlined,
              label: l10n.chatArchiveChat,
              onTap: () => pick('archive'),
            ),
            if (toInbox)
              MenuSheetRow(
                icon: Icons.support_agent,
                label: l10n.supportMoveToInbox,
                onTap: () => pick('inbox'),
              ),
            // hidden chats open: out of the everyday list, or back in it
            if (hideable)
              MenuSheetRow(
                icon: hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                label: hidden ? l10n.chatShowInList : l10n.chatHide,
                tint: HaloColors.violet,
                onTap: () => pick('hide'),
              ),
          ],
          [
            MenuSheetRow(
              icon: Icons.theater_comedy_outlined,
              label: l10n.voiceDisguiseHere,
              toggled: _disguise,
              onTap: onDisguise,
            ),
            MenuSheetRow(
              icon: Icons.palette_outlined,
              label: l10n.chatWallpaper,
              onTap: () => pick('atmosphere'),
            ),
            MenuSheetRow(
              icon: Icons.sticky_note_2_outlined,
              label: l10n.chatNoteOnThisContact,
              onTap: () => pick('note'),
            ),
          ],
          [
            MenuSheetRow(
              icon: Icons.delete_sweep_outlined,
              label: l10n.chatClearConversation,
              danger: true,
              onTap: () => pick('clear'),
            ),
            MenuSheetRow(
              icon: Icons.block,
              label: l10n.chatBlockContact,
              danger: true,
              onTap: () => pick('block'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onChatAction(String? action, {required bool hidden}) async {
    if (action == 'contact') {
      _openContact();
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
    } else if (action == 'inbox') {
      // the chat folds out of Chats as it is left
      await appState.moveToInbox(widget.peerHaloId);
      if (!mounted) return;
      showHaloToast(context, l10n.supportMovedToInbox);
      Navigator.of(context).pop();
    } else if (action == 'hide') {
      // its rows move, so the chat is left as an archived one is
      final moved = await moveHiddenChat(
        context,
        widget.peerHaloId,
        group: false,
        hide: !hidden,
      );
      if (moved && mounted) Navigator.of(context).pop();
    } else if (action == 'block') {
      await _blockContact();
    } else if (action == 'clear') {
      await _clearConversation();
    } else if (action == 'atmosphere') {
      await _pickAtmosphere();
    } else if (action == 'note') {
      await _editNote();
      final c = await session.getContact(widget.peerHaloId);
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
    if (_isDev) return showDevAboutSheet(context);
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
    final c = await session.getContact(widget.peerHaloId);
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
    final contact = await session.getContact(widget.peerHaloId);
    final pinned = (contact?['pinned'] as int? ?? 0) == 1;
    await session.setContactPinned(widget.peerHaloId, !pinned);
    await appState.refreshContacts();
    if (mounted) {
      showHaloToast(context, pinned ? l10n.chatUnpinned : l10n.chatPinnedToTop);
    }
  }

  Future<void> _editNote() async {
    final contact = await session.getContact(widget.peerHaloId);
    final current = (contact?['note'] as String?) ?? '';
    if (!mounted) return;
    final saved = await showNoteSheet(
      context,
      initial: current,
      save: (t) => session.setNote(widget.peerHaloId, t),
    );
    if (saved && mounted) showHaloToast(context, l10n.chatNoteSaved);
  }

  // the sheet previews live: each swatch changes the room behind it, and
  // backing out puts the old one back
  Future<void> _pickAtmosphere() async {
    final before = _atmosphere;
    final picked = await showWallpaperSheet(
      context,
      before,
      allowPhoto: true,
      onPreview: (a) {
        if (mounted) setState(() => _atmosphere = a);
      },
    );
    if (!mounted) return;
    if (picked is WallpaperFromPhotos) {
      setState(() => _atmosphere = before);
      await _pickWallpaperImage();
      return;
    }
    if (picked is! Atmo) {
      setState(() => _atmosphere = before);
      return;
    }
    HapticFeedback.selectionClick();
    await _dropWallpaperFile();
    await session.setAtmosphere(widget.peerHaloId, picked.name);
    if (!mounted) return;
    setState(() {
      _atmosphere = picked;
      _wallpaperPath = null;
    });
  }

  Future<void> _dropWallpaperFile() async {
    final old = _wallpaperPath;
    if (old == null) return;
    try {
      await shredFile(old);
    } catch (_) {
      // shredFile logs its own failure
    }
  }

  // a picture from the gallery, shrunk by the picker, copied into the
  // app's own folder. the gallery copy is not touched; ours goes on wipe.
  Future<void> _pickWallpaperImage() async {
    final x = await lockState.hold(
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      ),
    );
    if (x == null) return;
    final Uint8List bytes;
    try {
      bytes = await x.readAsBytes();
    } finally {
      await shredPickedImages([x]);
    }
    final folder = await session.folderOf(widget.peerHaloId, 'wallpapers');
    final file = File('${folder.path}/${widget.peerHaloId}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    await session.setAtmosphere(widget.peerHaloId, 'image:${file.path}');
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _wallpaperPath = file.path;
      _atmosphere = Atmo.none;
    });
  }

  Future<void> _clearConversation() async {
    final confirm = await showConfirmSheet(
      context,
      title: l10n.chatClearThisConversation,
      line: l10n.chatEveryMessageHereIs,
      yes: l10n.chatClear,
      keep: l10n.commonCancel,
    );
    if (confirm != true) return;
    HapticFeedback.selectionClick();
    await session.clearConversation(widget.peerHaloId);
    await appState.refreshContacts();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _normaliseMessages();
    });
  }

  Future<void> _openKeyVerification() async {
    await Navigator.of(context).push(
      haloRoute(
        KeyVerificationScreen(
          peerHaloId: widget.peerHaloId,
          peerName: _nickname ?? widget.peerHaloId,
          myXpub: appState.sessionXPub,
          peerXpub: widget.peerXPub,
          initialVerified: _verified,
        ),
      ),
    );
    // checked again there: what waited for it goes now
    await _readKeyState();
    if (!_keyHeld) unawaited(appState.drainOutbox());
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
    final confirm = await showConfirmSheet(
      context,
      title: l10n.chatBlockThisContact,
      line: l10n.chatTheirMessagesStopArriving,
      yes: l10n.commonBlock,
      keep: l10n.commonCancel,
    );
    if (confirm != true) return;
    await appState.block(widget.peerHaloId);
    if (mounted) setState(() => _blocked = true);
  }

  Future<void> _unblockContact() async {
    await appState.unblock(widget.peerHaloId);
    if (mounted) setState(() => _blocked = false);
  }

  // a support chat's first reply takes it on: accepted, listened for, told
  // it is in, and still in the support inbox
  Future<void> _answerSupport() async {
    if (!widget.support || !await appState.answerSupport(widget.peerHaloId)) {
      return;
    }
    if (mounted) {
      setState(() {
        _accepted = true;
        _flag = null;
      });
    }
  }

  Future<void> _acceptRequestPeer() async {
    HapticFeedback.selectionClick();
    await session.acceptRequest(widget.peerHaloId);
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
    await session.declineRequest(widget.peerHaloId);
    await appState.refreshContacts();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _blockRequestPeer() async {
    HapticFeedback.selectionClick();
    await appState.block(widget.peerHaloId);
    await session.clearUnread(widget.peerHaloId);
    await appState.refreshContacts();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleSaved(_Msg m) async {
    if (m.msgUid == null) return;
    final next = !m.saved;
    setState(() => m.saved = next);
    await session.setSaved(m.msgUid!, next);
    if (mounted) {
      showHaloToast(context, next ? l10n.chatSaved : l10n.chatRemovedFromSaved);
    }
  }

  Future<void> _forwardMessage(_Msg m) async {
    final id = await pickWordsChat(
      context,
      title: l10n.chatForwardTo,
      empty: l10n.chatNoContactsToForward,
      // the developer chat, once it has started, and not from itself
      dev: _isDev ? null : devForwardTarget,
    );
    if (id == null || !mounted) return;
    // to this very chat: under what its composer holds, never a second
    // copy of it on top
    if (id == widget.peerHaloId) {
      _takeWords(m.text);
      return;
    }
    final route = await wordsRoute(id, m.text);
    if (route == null || !mounted) return;
    Navigator.of(context).push(route);
  }

  // words shared from another app, under what the composer holds
  void _takeWords(String words) =>
      _takeDraft(composerWith(_msgCtrl.text, words));

  void _takeDraft(String t) {
    _msgCtrl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // reversed list: bottom is offset 0
    final show = pos.pixels > _jumpButtonAt;
    if (!show) _unseenNew = 0;
    if (show != _showScrollDown && mounted) {
      setState(() => _showScrollDown = show);
    }
  }

  void _scrollToBottom() {
    if (!_scrollReady) return;
    setState(() => _unseenNew = 0);
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
    // about ten times a second: this queries layout per day divider, and the
    // raw scroll stream fires many times a frame
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
      // the floating chip sits at the top of this same list, so a divider
      // has only passed once its bottom edge is above the top, or the day
      // shows twice
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

  String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(when.year, when.month, when.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return l10n.chatToday;
    if (diff == 1) return l10n.chatYesterday;
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

  // above the composer in his chat: the line when his key did not check
  // out, and until the first message the note that says what he will see.
  // the note folds away as that message goes out
  List<Widget> _devAboveComposer(BuildContext context) {
    final o = _devOpening;
    final note =
        o != null &&
        !o.started &&
        _devStop == null &&
        !_requestLocked &&
        !appState.movedAway;
    return [
      _Fold(
        _devKeyFailed
            ? NoticeBanner(
                key: const ValueKey('dev-key'),
                glyph: NoticeGlyph.shield,
                text: l10n.devKeyCheckFailed,
                color: HaloColors.rose,
                margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              )
            : const SizedBox(key: ValueKey('dev-key-none'), width: 0),
      ),
      _Fold(
        time: const Duration(milliseconds: 240),
        note
            ? DevNote(
                key: const ValueKey('dev-note'),
                anon: o.anon,
                busy: o.busy,
                onChoose: _chooseDevName,
                onWho: () => showDevWhoSheet(context),
              )
            : const SizedBox(key: ValueKey('dev-note-none'), width: 0),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // a message that just started counting down gets its burn on time
    _burn.poke();
    // and one that waits is read once this frame shows it
    _reads.look();
    final searchActive = _searching && _query.isNotEmpty;
    // the height the chat has above the keyboard
    final visible =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final short = visible < 480;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // search and the head cross over both ways
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
                  : _isDev
                  ? DevChatHead(
                      key: const ValueKey('head'),
                      anon: (_devOpening?.started ?? false) && _devAnon,
                      onBack: () => Navigator.pop(context),
                      onAbout: () => showDevAboutSheet(context),
                      onSearch: _openSearch,
                      onMore: _devActions,
                      pinnedCount: _pinCount,
                      onPinned: _showPinnedSheet,
                    )
                  : _ChatHead(
                      key: const ValueKey('head'),
                      haloId: widget.peerHaloId,
                      nickname: _nickname,
                      note: _note,
                      verified: _verified,
                      nameUnchecked: _nameUnchecked,
                      supporterBadge: _peerBadge,
                      onBlock: _openContact,
                      onMore: _chatActions,
                      avatarSeed: widget.avatarSeed,
                      face: _peerFace,
                      onBack: () => Navigator.pop(context),
                      onSearch: _openSearch,
                      onRename: _openContact,
                      pinnedCount: _pinCount,
                      onPinned: _showPinnedSheet,
                    ),
            ),
            // each line around the thread grows in and folds away, so the
            // thread does not jump. a short room (keyboard up, big text)
            // gets them tight, and at most a share of it: past that they
            // scroll, never push the composer off
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(48, visible * 0.3),
              ),
              child: SingleChildScrollView(
                primary: false,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Fold(
                      // his chat is no request: its lock line says the rest
                      (_flag != null && !_accepted) || _isDev
                          ? const SizedBox(key: ValueKey('top-none'), width: 0)
                          : _vouched && !_accepted && _recvCount == 0
                          ? _IntroBanner(
                              key: const ValueKey('intro'),
                              names: _voucherNames,
                              seed: _voucherSeed!,
                              avatar: _voucherAvatar,
                              verified: _voucherVerified,
                            )
                          : _requestPending && _sentCount > 0
                          ? _RequestBanner(
                              key: const ValueKey('request'),
                              compact: short,
                            )
                          : const SizedBox(key: ValueKey('top-none'), width: 0),
                    ),
                    // his key moved on: this chat still reads and writes
                    _Fold(
                      _devShown?.status == DevKeyStatus.previous
                          ? NoticeBanner(
                              key: const ValueKey('dev-moved'),
                              glyph: NoticeGlyph.shield,
                              text: l10n.devNewKey,
                              color: HaloColors.amber,
                              margin: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                            )
                          : const SizedBox(
                              key: ValueKey('dev-moved-none'),
                              width: 0,
                            ),
                    ),
                    _Fold(
                      _keyChanged && !_keyHeld && !_isDev
                          ? _KeyChangedBanner(
                              key: const ValueKey('key-changed'),
                              peerName: _nickname ?? widget.peerHaloId,
                              onVerify: _openKeyVerification,
                              onDismiss: _dismissKeyChanged,
                            )
                          : const SizedBox(key: ValueKey('key-none'), width: 0),
                    ),
                    // added by a code or a link, or taken in from a request:
                    // the safety number is what says who they are
                    _Fold(
                      _nameAsks &&
                              !_keyChanged &&
                              !_keyHeld &&
                              !_isDev &&
                              !widget.support
                          ? _CompareCard(
                              key: const ValueKey('compare'),
                              peerName: _nickname ?? widget.peerHaloId,
                              onVerify: _openKeyVerification,
                              onLater: _compareLater,
                            )
                          : const SizedBox(
                              key: ValueKey('compare-none'),
                              width: 0,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AtmoScope(
                atmo: _atmosphere,
                child: Stack(
                  key: _listKey,
                  children: [
                    if (_wallpaperPath != null) ...[
                      Positioned.fill(
                        child: Image.file(
                          File(_wallpaperPath!),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          cacheWidth: screenPx(context),
                        ),
                      ),
                      // a wash so the bubbles keep reading over any photo
                      Positioned.fill(
                        child: ColoredBox(
                          color: HaloColors.ink.withValues(alpha: 0.42),
                        ),
                      ),
                    ],
                    if (_atmosphere != Atmo.none)
                      Positioned.fill(child: AtmosphereWash(_atmosphere)),
                    // a slow first read fades the thread up, not a cut
                    FadeSwap(
                      // an empty chat waits for what its card depends on,
                      // so the card never follows the plain empty state
                      child:
                          !_loaded ||
                              (_messages.isEmpty && !(_barKnown && _hiKnown))
                          ? const SizedBox.shrink(key: ValueKey('wait'))
                          : _messages.isEmpty
                          ? _sayHi
                                // holds the room the card sits over
                                ? const SizedBox.expand(key: ValueKey('hi'))
                                : const _EmptyConversation(
                                    key: ValueKey('empty'),
                                  )
                          : ListView.builder(
                              key: const ValueKey('list'),
                              controller: _scrollCtrl,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              itemCount: _messages.length,
                              findChildIndexCallback: _indexOfRow,
                              itemBuilder: (c, i) {
                                // one unbuildable message must never cost
                                // the whole conversation. draw a stub and
                                // carry on.
                                try {
                                  // keyed by the message at the top, where
                                  // the list looks: in a reversed list every
                                  // arrival moves every index, and a voice
                                  // note must keep its player. the same id
                                  // is the anchor a jump lands on.
                                  final id = _rowKey(
                                    _messages[_messages.length - 1 - i],
                                  );
                                  return RowAnchor(
                                    key: ValueKey(id),
                                    anchors: _anchors,
                                    id: id,
                                    child: _buildRow(c, i, searchActive),
                                  );
                                } catch (e) {
                                  dlog('bubble failed: $e');
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      l10n.chatThisMessageCanT,
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
                    // over the thread, so its first row comes in under it
                    // as it goes
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_sayHi,
                        child: _SayHiSwap(
                          child: _sayHi
                              ? SayHiCard(
                                  key: const ValueKey('say-hi'),
                                  sticker: _hi?.$2,
                                  onWave: _wave,
                                )
                              : const SizedBox.shrink(key: ValueKey('no-hi')),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: JumpDownButton(
                          shown: _showScrollDown,
                          count: _unseenNew,
                          label: l10n.chatJumpToTheNewest,
                          onTap: _scrollToBottom,
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
            _Fold(
              _friendlyStatus(_status).isNotEmpty && !appState.movedAway
                  ? Padding(
                      key: const ValueKey('status'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      // new words rise in over the last ones
                      child: RiseSwap(
                        alignment: Alignment.center,
                        child: Text(
                          _friendlyStatus(_status),
                          key: ValueKey(_friendlyStatus(_status)),
                          textAlign: TextAlign.center,
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.amber,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('status-none'), width: 0),
            ),
            // tor still warming: messages typed now are queued. not on a
            // phone whose identity has moved, where tor is off on purpose.
            _Fold(
              appState.sendMode == 'private' &&
                      !appState.torUsable &&
                      !appState.movedAway
                  ? Padding(
                      key: const ValueKey('tor-warm'),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TorHalo(),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              l10n.chatBuildingAPrivateRoute,
                              style: HaloType.sans(
                                size: 10.5,
                                color: HaloColors.text2,
                              ).copyWith(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(key: ValueKey('tor-none'), width: 0),
            ),
            // a send that has waited on tor a minute gets a way out
            ReconnectValve(
              valve: torValve,
              waitingSince: appState.movedAway ? null : _waitingSince(),
              private: appState.sendMode == 'private',
              quiet: sessionQuiet,
              online: appState.online,
              linkUp: appState.linkUp,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            ),
            _Fold(
              _flag != null && !_accepted && !_blocked
                  ? NoticeBanner(
                      key: const ValueKey('shield-flag'),
                      glyph: NoticeGlyph.shield,
                      text: _flag!.headline,
                      color: HaloColors.rose,
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      onTap: _openShield,
                    )
                  : _shieldClean && !_accepted && !_blocked
                  // the calm state. same banner, softest colour, nothing to
                  // tap
                  ? NoticeBanner(
                      key: const ValueKey('shield-clean'),
                      glyph: NoticeGlyph.shield,
                      text: l10n.chatLooksSafeNothingSuspicious,
                      color: HaloColors.text2,
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    )
                  : const SizedBox(key: ValueKey('shield-none'), width: 0),
            ),
            if (_isDev) ..._devAboveComposer(context),
            AnimatedSwitcher(
              duration: motionStill(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
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
            IncomingMediaBanner(
              chatKey: _memo,
              onCancel: (uid) {
                for (final m in _messages) {
                  if (m.msgUid == uid) {
                    _stopSending(m);
                    return;
                  }
                }
              },
            ),
            AnimatedSwitcher(
              duration: motionStill(context) || !_barSettled
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(
                  !_barKnown
                      ? 'bar_wait'
                      : _blocked
                      ? 'bar_blocked'
                      : _devStop != null
                      ? 'bar_dev_stop'
                      : _incomingRequest
                      ? 'bar_request'
                      : _requestLocked
                      ? 'bar_locked'
                      : _keyHeld && !_isDev
                      ? 'bar_held'
                      : 'bar_composer',
                ),
                child: !_barKnown
                    ? const SizedBox(width: double.infinity)
                    : _blocked
                    ? _BlockedBar(onUnblock: _unblockContact)
                    : _devStop != null
                    ? _RequestLockBar(
                        line: _devStop,
                        icon: _devNameless && !_devRetired
                            ? Icons.person_off_outlined
                            : Icons.key_off_outlined,
                        action: _devNameless && !_devRetired
                            ? l10n.devStartNewChat
                            : null,
                        onAction: _startNewDevChat,
                      )
                    : _incomingRequest
                    ? _AcceptRequestBar(
                        introducer: _vouched ? vouchNames(_voucherNames) : null,
                        onAccept: _acceptRequestPeer,
                        onDecline: _declineRequestPeer,
                        onBlock: _blockRequestPeer,
                      )
                    : _requestLocked
                    ? _RequestLockBar(line: _isDev ? l10n.devLockLine : null)
                    : _keyHeld && !_isDev
                    ? KeyHeldCard(
                        peerName: _nickname ?? widget.peerHaloId,
                        onCheck: _openKeyVerification,
                        onAccept: _acceptNewKey,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _msgCtrl,
                            // offered only while tor is up: the fetch goes
                            // over tor or not at all, so without it there is
                            // nothing to offer. never in a quiet session
                            builder: (_, v, _) => PreviewStrip(
                              url: _accepted && !sessionQuiet && _torUp
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
                            onStickers: _showStickers,
                            onCamera: _openCamera,
                            ghost: _ghost,
                            secure: _secureNext,
                            onToggleSecure: () {
                              HapticFeedback.selectionClick();
                              setState(() => _secureNext = !_secureNext);
                              showHaloToast(
                                context,
                                _secureNext
                                    ? l10n.chatTheNextPhotoYou
                                    : l10n.chatPhotoProtectionOff,
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
                            focusNode: _composerFocus,
                            sending: _sending,
                            onSend: _send,
                            disguise: _voiceDisguise,
                            disguiseLocked: _devAnon,
                            onVoice: _sendVoice,
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

// the say hi card comes in on its own rise. it goes as its wave leaves:
// held a beat while the hand waves, then shrinking away as the first row
// comes in. nothing moves when the phone asks for no movement
class _SayHiSwap extends StatelessWidget {
  final Widget child;
  const _SayHiSwap({required this.child});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedSwitcher(
      duration: Duration.zero,
      reverseDuration: still
          ? Duration.zero
          : const Duration(milliseconds: 380),
      switchOutCurve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
      layoutBuilder: (top, gone) =>
          Stack(fit: StackFit.passthrough, children: [...gone, ?top]),
      transitionBuilder: (c, a) => AnimatedBuilder(
        animation: a,
        builder: (_, c) {
          final v = a.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.92 + 0.08 * v, child: c),
          );
        },
        child: c,
      ),
      child: child,
    );
  }
}

// a line around the thread that grows in and folds away instead of
// popping, so the thread does not jump. instant when the phone asks for no
// movement. [child] is keyed by what it shows
class _Fold extends StatelessWidget {
  final Widget child;
  final Duration time;
  const _Fold(this.child, {this.time = const Duration(milliseconds: 220)});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: motionStill(context) ? Duration.zero : time,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, anim) => SizeTransition(
      sizeFactor: anim,
      axisAlignment: -1,
      child: FadeTransition(opacity: anim, child: child),
    ),
    child: child,
  );
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
        duration: motionStill(context)
            ? Duration.zero
            : const Duration(milliseconds: 90),
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
                ? l10n.chatAcceptToReplyThey
                : l10n.chatIntroducedYouAcceptTo('$introducer'),
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 11),
          // every button takes a share of the row, so a long word or a big
          // font shrinks a label instead of pushing the row off the screen
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _barBtn(
                  l10n.chatBlock,
                  HaloColors.rose,
                  HaloColors.surface2,
                  onBlock,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _barBtn(
                  l10n.chatDecline,
                  HaloColors.text,
                  HaloColors.surface2,
                  onDecline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _barBtn(
                  l10n.chatAccept,
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
}

// a button in the bars around the thread: the request bar and the security
// code notice share one shape
Widget _barBtn(
  String label,
  Color fg,
  Color bg,
  VoidCallback onTap, {
  bool bold = false,
}) {
  return _ScaleTap(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: bg == HaloColors.surface2
            ? Border.all(color: HaloColors.line, width: 0.5)
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: HaloType.sans(
            size: 13,
            color: fg,
          ).copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
    ),
  );
}

// shown above the thread when a friend introduced this peer and neither side
// has said anything yet. takes the place of the stranger warning.
class _IntroBanner extends StatelessWidget {
  final List<String> names;
  final String seed;
  final int? avatar;
  final bool verified;
  const _IntroBanner({
    super.key,
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
            l10n.chatIntroducedYouSayHello(vouchNames(names)),
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

// shown above the thread when we're messaging someone who hasn't accepted us.
class _RequestBanner extends StatelessWidget {
  // little room: closer in, and the line under the title on one line
  final bool compact;
  const _RequestBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: compact
          ? const EdgeInsets.fromLTRB(16, 6, 16, 2)
          : const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 6, 12, 7)
          : const EdgeInsets.fromLTRB(13, 10, 13, 11),
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
              Flexible(
                child: Text(
                  l10n.chatMessageRequest,
                  style: HaloType.serif(size: 13, color: HaloColors.text),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 2 : 5),
          Text(
            l10n.chatTheyNeedToAccept,
            maxLines: compact ? 1 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
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

// replaces the composer once we've hit the 2-message request cap. the
// developer chat says it its own way, a retired key the same way, and a
// chat that only reads with its one way on
class _RequestLockBar extends StatelessWidget {
  const _RequestLockBar({
    this.line,
    this.icon = Icons.lock_outline,
    this.action,
    this.onAction,
  });
  final String? line;
  final IconData icon;
  // one way on, under the line
  final String? action;
  final VoidCallback? onAction;

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
              Icon(icon, size: 15, color: HaloColors.amber),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  line ?? l10n.chatWaitingForThemTo,
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              ),
            ],
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            _ScaleTap(
              onTap: onAction!,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 18,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  action!,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.onAmber,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 15, color: HaloColors.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.chatYouBlockedThisContact,
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
              l10n.commonUnblock,
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
  final bool nameUnchecked;
  final String? note;
  final String? supporterBadge;
  const _ChatHead({
    super.key,
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
    this.nameUnchecked = false,
    this.note,
    this.supporterBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonBack,
            icon: Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
            onPressed: onBack,
          ),
          Semantics(
            container: true,
            button: true,
            label: l10n.chatViewContact,
            child: GestureDetector(
              onTap: onBlock, // avatar opens the contact page
              behavior: HitTestBehavior.opaque,
              // the same face flies in from the list row
              child: Hero(
                tag: 'face-$avatarSeed',
                child: KryfoAvatar(seed: avatarSeed, size: 36, choice: face),
              ),
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
                            child: motionStill(context)
                                ? child
                                : ScaleTransition(
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
                      if (nameUnchecked && !verified) ...[
                        const SizedBox(width: 6),
                        const NameCheckMark(),
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
                            l10n.chatSupporter,
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
                        // a longer language at a big font size would run
                        // past the header's buttons, so it ends in …
                        Flexible(
                          child: Text(
                            appState.sendMode == 'balanced'
                                ? l10n.chatEncryptedViaRelay
                                : appState.sendMode == 'fast'
                                ? l10n.chatEncryptedDirect
                                : l10n.chatEncryptedOverTor,
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

          PinHeaderButton(count: pinnedCount, onTap: onPinned),
          IconButton(
            tooltip: l10n.chatSearchThisChat,
            icon: Icon(Icons.search_rounded, color: HaloColors.text2, size: 21),
            onPressed: onSearch,
          ),
          IconButton(
            tooltip: l10n.chatContactOptions,
            icon: Icon(Icons.more_vert, color: HaloColors.text2, size: 21),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

// replaces the chat header while searching
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
          offset: Offset(0, motionStill(context) ? 0 : -10 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 12, 11),
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
                  tooltip: l10n.commonClose,
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
                          child: WrittenDir(
                            controller: widget.controller,
                            builder: (dir) => TextField(
                              textDirection: dir,
                              inputFormatters: const [UnmarkedInput()],
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
                                hintText: l10n.chatFindInConversation,
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: motionStill(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
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
                              children: widget.matchCount == 0
                                  ? [
                                      TextSpan(
                                        text: l10n.chatNoMatches,
                                        style: HaloType.mono(
                                          size: 10,
                                          color: HaloColors.text2,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                    ]
                                  : markedSpans(
                                      l10n.chatOf(
                                        widget.matchCount,
                                        widget.matchPos,
                                      ),
                                      HaloType.mono(
                                        size: 10,
                                        color: HaloColors.amber,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                          const Spacer(),
                          _NavBtn(
                            icon: Icons.keyboard_arrow_up_rounded,
                            label: l10n.chatPreviousMatch,
                            enabled: widget.matchCount > 0,
                            onTap: widget.onPrev,
                          ),
                          const SizedBox(width: 5),
                          _NavBtn(
                            icon: Icons.keyboard_arrow_down_rounded,
                            label: l10n.chatNextMatch,
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
  // replay it
  static final Set<String> _entered = {};
  final _Msg msg;
  final void Function(_Msg)? onRetry;
  final void Function(BuildContext)? onLongPress;
  // its photo, video or file opened, or its voice note played
  final VoidCallback? onAct;
  // a tap on a reaction chip: the same emoji from this phone, on or off
  final void Function(String emoji)? onReact;
  final bool secure;
  final String? quotedText;
  final String? quotedAuthor;
  final VoidCallback? onQuoteTap;
  // search: the live query (empty when not searching), whether this bubble
  // is the current hit, and whether it dims as a non-match
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
  // a sticker row: the chat's budget, its place in it, and its flight
  final StickerBudget? stickers;
  final int stickerOrder;
  final StickerLanding? landing;
  // the quoted message is a sticker
  final StickerWire? quotedSticker;
  // sent, with no receipt yet, to someone who has not added us back
  final bool unconfirmed;
  const _Bubble({
    super.key,
    required this.msg,
    this.stickers,
    this.stickerOrder = 0,
    this.landing,
    this.quotedSticker,
    this.onRetry,
    this.onLongPress,
    this.onAct,
    this.onReact,
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
    this.unconfirmed = false,
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
      return KryfoLinkText(
        text: msg.text,
        style: base,
        onAmber: isOut && !image,
        linkColor: (isOut && !image) ? HaloColors.onAmber : HaloColors.amber,
      );
    }
    final text = msg.text;
    return Text.rich(
      TextSpan(
        style: base,
        children: searchLit(text, query, onAmber: isOut && !image),
      ),
      textDirection: writtenDir(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOut = msg.direction == 'out';
    final isImage = msg.mediaPath != null;
    // a video with no caption sits on the chat like a photo: no bubble
    // around it, its time and tick in its corner
    final isVideo =
        msg.filePath != null &&
        msg.text.isEmpty &&
        msg.fileName != 'voice.wav' &&
        nameSaysVideo(msg.fileName);
    final frameless = isImage || isVideo;
    final failedShown = _sendLooksFailed(msg);
    final parked = msg.parked && !msg.sending && !msg.failed;
    final pending = msg.sending || (msg.failed && !failedShown);
    // a finished media send means every slice was accepted somewhere, not
    // that it arrived: a relay taking the bytes is not the peer reading
    // them. so media says nothing until the receipt lands, then Delivered.
    final isMedia = msg.mediaPath != null || msg.filePath != null;
    final ackOk = !isMedia || msg.delivered;
    final showMeta = isOut && !pending && !failedShown && !parked && ackOk;
    // a photo, a video, a file or a voice note that came in says when, as
    // ours do: there is no text of it to place it by
    final showTime = showMeta || (!isOut && isMedia);
    final showPill = isOut && pending;
    final reacted = msg.reactions.isNotEmpty;
    final roomTime = motionStill(context) ? Duration.zero : kHouseTime;
    // lighter than the message, so the words lead
    final metaColor = (isOut && !frameless)
        ? HaloColors.onAmber.withValues(alpha: 0.55)
        : HaloColors.text3;
    // under a photo or a video there is no amber behind the words
    final onAmberText = isOut && !frameless;
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
    // an entrance plays once, gated on a seen-set keyed by uid
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
    // clear fresh after the entrance plays so a later rebuild can't replay
    // it. this also covers messages that arrived without a uid.
    if (msg.fresh && willAnimate) {
      Future.delayed(const Duration(milliseconds: 650), () {
        msg.fresh = false;
      });
    }
    if (msg.sticker case final st?) {
      return _stickerRow(
        context,
        st,
        isOut: isOut,
        failedShown: failedShown,
        parked: parked,
        pending: pending,
        showMeta: showMeta,
        isExpiring: isExpiring,
        // the flight or the pop is its entrance, not the bubble lift
        arriving: isOut ? justSent && landing == null : justArrived,
      );
    }
    return AnimatedOpacity(
      duration: Duration(milliseconds: isExpiring ? 440 : 250),
      curve: Curves.easeOut,
      opacity: dimmed ? 0.4 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (failedShown || parked) && onRetry != null
            ? () => onRetry!(msg)
            : onReveal,
        onLongPress: onLongPress == null ? null : () => onLongPress!(context),
        child: AnimatedPadding(
          duration: roomTime,
          curve: kHouseCurve,
          padding: EdgeInsets.only(
            top: firstInGroup ? 4 : 1,
            bottom: reacted ? 3 : (lastInGroup ? 4 : 1),
          ),
          child: Column(
            crossAxisAlignment: isOut
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              BubbleEntrance(
                isOut: isOut,
                active: isOut ? justSent : justArrived,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // a reaction hangs below the bubble: its room is inside
                    // the stack, so the chip can be tapped, and eases open
                    AnimatedPadding(
                      duration: roomTime,
                      curve: kHouseCurve,
                      padding: EdgeInsets.only(bottom: reacted ? kChipRoom : 0),
                      // the ring sits inside the room, so it follows it open
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          BurnFade(
                            active: isExpiring || msg.removing,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.78,
                              ),
                              padding: frameless
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.fromLTRB(14, 10, 14, 8),
                              decoration: BoxDecoration(
                                color: (isImage && msg.text.isNotEmpty)
                                    ? HaloColors.surface2
                                    : frameless
                                    ? null
                                    : isOut
                                    ? HaloColors.amber
                                    : atmoBubbleIn(context),
                                gradient: null,
                                borderRadius: BorderRadiusDirectional.only(
                                  topStart: const Radius.circular(14),
                                  topEnd: const Radius.circular(14),
                                  bottomStart: Radius.circular(
                                    isOut ? 14 : (lastInGroup ? 4 : 14),
                                  ),
                                  bottomEnd: Radius.circular(
                                    isOut ? (lastInGroup ? 4 : 14) : 14,
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
                                    if (quotedText != null)
                                      PressScale(
                                        scale: 0.97,
                                        haptic: false,
                                        onTap: onQuoteTap,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: isOut
                                                ? HaloColors.onAmber.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : HaloColors.amber.withValues(
                                                    alpha: 0.08,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
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
                                                      ? HaloColors.onAmber
                                                            .withValues(
                                                              alpha: 0.7,
                                                            )
                                                      : HaloColors.amber,
                                                ),
                                                const SizedBox(width: 9),
                                                Flexible(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional.fromSTEB(
                                                          0,
                                                          6,
                                                          10,
                                                          6,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (quotedAuthor !=
                                                            null)
                                                          Text(
                                                            quotedAuthor!,
                                                            style: HaloType.mono(
                                                              size: 10,
                                                              color: isOut
                                                                  ? HaloColors
                                                                        .onAmber
                                                                  : HaloColors
                                                                        .amber,
                                                              letter: 0.4,
                                                            ),
                                                          ),
                                                        if (quotedAuthor !=
                                                            null)
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                        if (quotedSticker
                                                            case final qs?)
                                                          StickerLine(
                                                            qs,
                                                            style: _quoteStyle(
                                                              isOut,
                                                            ),
                                                          )
                                                        else
                                                          Text(
                                                            quotedText!,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: _quoteStyle(
                                                              isOut,
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
                                        child: VoiceBubble(
                                          key: ValueKey('vb_${msg.filePath}'),
                                          path: msg.filePath!,
                                          isOut: isOut,
                                          disguised: msg.voiceDisguised,
                                          onPlay: onAct,
                                        ),
                                      )
                                    else if (msg.filePath != null &&
                                        nameSaysVideo(msg.fileName))
                                      VideoBubble(
                                        key: ValueKey('vid_${msg.filePath}'),
                                        path: msg.filePath!,
                                        fileName: msg.fileName!,
                                        width:
                                            (MediaQuery.of(context).size.width *
                                                    0.66)
                                                .clamp(180.0, 300.0),
                                        onOpen: () {
                                          onAct?.call();
                                          openVideo(
                                            context,
                                            path: msg.filePath!,
                                            fileName: msg.fileName,
                                          );
                                        },
                                        stamp: _mediaCorner(
                                          msg,
                                          showMeta: showTime,
                                          failedShown: failedShown,
                                          parked: parked,
                                        ),
                                      )
                                    else if (msg.fileName != null)
                                      PressScale(
                                        scale: 0.97,
                                        haptic: false,
                                        onTap: () {
                                          onAct?.call();
                                          if (msg.filePath != null) {
                                            openReceivedFile(
                                              context,
                                              msg.filePath!,
                                              msg.fileName,
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
                                      PressScale(
                                        scale: 0.97,
                                        haptic: false,
                                        onTap: () {
                                          onAct?.call();
                                          _openFullImage(
                                            context,
                                            msg.mediaPath!,
                                            secure: msg.secure,
                                            tag: photoHeroTag(
                                              msg.mediaPath!,
                                              'chat',
                                            ),
                                            radius: 14,
                                          );
                                        },
                                        // said as a photo from the start,
                                        // before the picture has faded up
                                        child: Semantics(
                                          image: true,
                                          label: l10n.appPhoto,
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
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxHeight: 280,
                                                      ),
                                                  // the bubble sizes itself with
                                                  // IntrinsicWidth, and an Image
                                                  // answers infinity until the file
                                                  // decodes, so pin a width
                                                  child: RememberedHeight(
                                                    id: msg.mediaPath!,
                                                    child: Hero(
                                                      tag: photoHeroTag(
                                                        msg.mediaPath!,
                                                        'chat',
                                                      ),
                                                      child: SizedBox(
                                                        width:
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width *
                                                            0.78,
                                                        child: ChatPicture(
                                                          path: msg.mediaPath!,
                                                          child: Image.file(
                                                            File(
                                                              msg.mediaPath!,
                                                            ),
                                                            gaplessPlayback:
                                                                true,
                                                            fit: BoxFit.cover,
                                                            cacheWidth:
                                                                screenPx(
                                                                  context,
                                                                  times: 0.78,
                                                                ),
                                                            // fades up once decoded,
                                                            // over a quiet box
                                                            frameBuilder:
                                                                (
                                                                  _,
                                                                  child,
                                                                  frame,
                                                                  sync,
                                                                ) => PhotoTileFade(
                                                                  shown:
                                                                      sync ||
                                                                      frame !=
                                                                          null,
                                                                  child: child,
                                                                ),
                                                            errorBuilder: (_, e, _) {
                                                              dlog(
                                                                'Image failed: '
                                                                '${msg.mediaPath} / $e',
                                                              );
                                                              return Container(
                                                                height: 120,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                color: HaloColors
                                                                    .surface2,
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .image_not_supported_outlined,
                                                                      size: 22,
                                                                      color: HaloColors
                                                                          .text2,
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 6,
                                                                    ),
                                                                    Text(
                                                                      l10n.chatPhotoUnavailable,
                                                                      style: HaloType.mono(
                                                                        size:
                                                                            11,
                                                                        color: HaloColors
                                                                            .text2,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                PositionedDirectional(
                                                  end: 8,
                                                  bottom: 8,
                                                  child: _mediaCorner(
                                                    msg,
                                                    showMeta: showTime,
                                                    failedShown: failedShown,
                                                    parked: parked,
                                                  ),
                                                ),
                                              ],
                                            ),
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
                                        crossAxisAlignment:
                                            msg.mediaPath != null
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (msg.text.isNotEmpty)
                                            writtenStart(
                                              msg.text,
                                              _body(
                                                isOut,
                                                image: msg.mediaPath != null,
                                              ),
                                            ),
                                          if (isOut &&
                                              msg.text.isEmpty &&
                                              msg.mediaPath != null)
                                            GifSentLine(path: msg.mediaPath!),
                                          if (msg.url case final u?) ...[
                                            const SizedBox(height: 6),
                                            LinkStub(
                                              url: u,
                                              isOut: isOut,
                                              title: linkTitle,
                                              bySender: linkBySender,
                                            ),
                                          ],
                                          if (msg.place case final p?) ...[
                                            const SizedBox(height: 6),
                                            PlaceStub(place: p, isOut: isOut),
                                          ],
                                          // the time and tick grow in as the
                                          // sending pill under the bubble folds
                                          GrowSwap(
                                            child: !(showTime && !frameless)
                                                ? const SizedBox.shrink(
                                                    key: ValueKey('no-meta'),
                                                  )
                                                : Padding(
                                                    key: const ValueKey('meta'),
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (msg.secure) ...[
                                                          Icon(
                                                            Icons
                                                                .shield_rounded,
                                                            size: 10,
                                                            color: metaColor,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                        ],
                                                        Text(
                                                          _fmtTime(msg.when),
                                                          style: TextStyle(
                                                            fontFamily: HaloType
                                                                .monoFamily,
                                                            fontFamilyFallback:
                                                                HaloType
                                                                    .monoFallbackNow,
                                                            fontSize: 9,
                                                            color: metaColor,
                                                            letterSpacing:
                                                                track(0.4),
                                                          ),
                                                        ),
                                                        if (msg.edited) ...[
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            l10n.chatEdited,
                                                            style: TextStyle(
                                                              fontFamily: HaloType
                                                                  .monoFamily,
                                                              fontFamilyFallback:
                                                                  HaloType
                                                                      .monoFallbackNow,
                                                              fontSize: 9,
                                                              color: metaColor,
                                                              fontStyle:
                                                                  slant(),
                                                              letterSpacing:
                                                                  track(0.4),
                                                            ),
                                                          ),
                                                        ],
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        if (isOut)
                                                          _outMark(
                                                            context,
                                                            msg,
                                                            unconfirmed:
                                                                unconfirmed,
                                                            color: metaColor,
                                                          ),
                                                        if (msg.burnAt !=
                                                            null) ...[
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .local_fire_department_outlined,
                                                            size: 11,
                                                            color: metaColor,
                                                          ),
                                                          const SizedBox(
                                                            width: 2,
                                                          ),
                                                          Text(
                                                            _fmtBurn(
                                                              msg.burnAt!,
                                                            ),
                                                            style:
                                                                HaloType.mono(
                                                                  size: 9.5,
                                                                  color:
                                                                      metaColor,
                                                                  weight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                          if (!isOut && msg.viaDev) ...[
                                            const SizedBox(height: 3),
                                            const _ViaDevTag(),
                                          ],
                                          if (!isOut &&
                                              msg.edited &&
                                              msg.mediaPath == null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              l10n.chatEdited,
                                              style: TextStyle(
                                                fontFamily: HaloType.monoFamily,
                                                fontFamilyFallback:
                                                    HaloType.monoFallbackNow,
                                                fontSize: 9,
                                                color: HaloColors.amber,
                                                fontStyle: slant(),
                                                letterSpacing: track(0.4),
                                              ),
                                            ),
                                          ],

                                          // a sent photo has no meta row, so its
                                          // countdown lives here like an incoming one.
                                          // one not read yet shows its whole window
                                          if (msg.burnLabel case final burn?
                                              when !pending &&
                                                  (!showMeta ||
                                                      msg.mediaPath !=
                                                          null)) ...[
                                            const SizedBox(height: 4),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child: BurnLine(
                                                burn,
                                                waits: msg.burnWaits,
                                                color: onAmberText
                                                    ? HaloColors.onAmber
                                                    : HaloColors.amber,
                                              ),
                                            ),
                                          ],
                                          if (failedShown) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              l10n.chatFailedTapToRetry,
                                              style: TextStyle(
                                                fontFamily: HaloType.monoFamily,
                                                fontFamilyFallback:
                                                    HaloType.monoFallbackNow,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                // on amber it reads in the bubble's
                                                // ink; under a photo, in the house
                                                // colours, as under a sticker
                                                color: onAmberText
                                                    ? HaloColors.onAmber
                                                    : HaloColors.rose,
                                                letterSpacing: track(0.4),
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
                                                topStart: const Radius.circular(
                                                  14,
                                                ),
                                                topEnd: const Radius.circular(
                                                  14,
                                                ),
                                                bottomStart: Radius.circular(
                                                  isOut
                                                      ? 14
                                                      : (lastInGroup ? 4 : 14),
                                                ),
                                                bottomEnd: Radius.circular(
                                                  isOut
                                                      ? (lastInGroup ? 4 : 14)
                                                      : 14,
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
                    // hangs below the bubble on the sender's side. keyed
                    // off direction, so groups work the same.
                    PositionedDirectional(
                      bottom: 0,
                      end: isOut ? 10 : null,
                      start: isOut ? null : 10,
                      child: _reactionRow(context, isOut),
                    ),
                  ],
                ),
              ),
              // the full date grows in under the bubble and folds away
              GrowSwap(
                alignment: isOut
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: !revealed
                    ? const SizedBox.shrink(key: ValueKey('no-date'))
                    : Padding(
                        key: const ValueKey('full-date'),
                        padding: const EdgeInsets.only(
                          top: 4,
                          left: 4,
                          right: 4,
                        ),
                        child: Text(
                          _fmtFull(msg.when),
                          style: HaloType.mono(
                            size: 9.5,
                            color: HaloColors.text2,
                            letter: 0.3,
                          ),
                        ),
                      ),
              ),
              if (isOut)
                GrowSwap(
                  child: !showPill
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
                              if (msg.msgUid != null &&
                                  (msg.mediaPath != null ||
                                      msg.filePath != null)) ...[
                                SendProgressLabel(msgUid: msg.msgUid!),
                                const SizedBox(width: 6),
                              ],
                              SendPill(mode: _pmFrom(appState.sendMode)),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _quoteStyle(bool isOut) => HaloType.sans(
    size: 12.5,
    color: isOut ? HaloColors.onAmber : HaloColors.text2,
    height: 1.25,
  );

  // a sticker has no bubble: it stands alone, its time in a pill, and keeps
  // the row's gestures, burn, reactions and send states
  Widget _stickerRow(
    BuildContext context,
    StickerWire st, {
    required bool isOut,
    required bool failedShown,
    required bool parked,
    required bool pending,
    required bool showMeta,
    required bool isExpiring,
    required bool arriving,
  }) {
    final quoted = quotedText;
    final burn = msg.burnLabel;
    final reacted = msg.reactions.isNotEmpty;
    final roomTime = motionStill(context) ? Duration.zero : kHouseTime;
    final retry = (failedShown || parked) && onRetry != null
        ? () => onRetry!(msg)
        : null;
    return AnimatedOpacity(
      duration: Duration(milliseconds: isExpiring ? 440 : 250),
      curve: Curves.easeOut,
      opacity: dimmed ? 0.4 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress == null ? null : () => onLongPress!(context),
        child: AnimatedPadding(
          duration: roomTime,
          curve: kHouseCurve,
          padding: EdgeInsets.only(
            top: firstInGroup ? 4 : 1,
            bottom: reacted ? 3 : (lastInGroup ? 4 : 1),
          ),
          child: Column(
            crossAxisAlignment: isOut
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPadding(
                    duration: roomTime,
                    curve: kHouseCurve,
                    padding: EdgeInsets.only(bottom: reacted ? kChipRoom : 0),
                    // the ring sits inside the room, so it follows it open
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        BurnFade(
                          active: isExpiring || msg.removing,
                          child: StickerBubble(
                            wire: st,
                            emoji: msg.text,
                            isOut: isOut,
                            seed: msg.msgUid ?? '',
                            budget: stickers,
                            order: stickerOrder,
                            arriving: arriving,
                            landing: landing,
                            onTap: retry,
                            quote: quoted == null
                                ? null
                                : StickerQuoteCard(
                                    author: quotedAuthor,
                                    text: quoted,
                                    sticker: quotedSticker,
                                    onTap: onQuoteTap,
                                  ),
                            // while it is sending the pill under it says so
                            stamp: pending
                                ? null
                                : StickerStamp(
                                    time: _fmtTime(msg.when),
                                    sent: showMeta && !unconfirmed,
                                    delivered: showMeta && msg.delivered
                                        ? l10n.chatDelivered
                                        : null,
                                    burn: burn,
                                    burnWaits: msg.burnWaits,
                                    alert: failedShown
                                        ? l10n.chatFailedTapToRetry
                                        : null,
                                    alertColor: failedShown
                                        ? HaloColors.rose
                                        : null,
                                  ),
                          ),
                        ),
                        if (ripple)
                          PositionedDirectional(
                            end: isOut ? 0 : null,
                            start: isOut ? null : 0,
                            bottom: 0,
                            width: kStickerBubble,
                            height: kStickerBubble,
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
                                        borderRadius: BorderRadius.circular(28),
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
                  PositionedDirectional(
                    bottom: 0,
                    end: isOut ? 10 : null,
                    start: isOut ? null : 10,
                    child: _reactionRow(context, isOut),
                  ),
                ],
              ),
              // the pill folds as the stamp grows, as under a bubble
              if (isOut)
                GrowSwap(
                  child: !pending
                      ? const SizedBox.shrink(key: ValueKey('no-pill'))
                      : Padding(
                          key: const ValueKey('pill'),
                          padding: const EdgeInsetsDirectional.only(
                            top: 4,
                            end: 4,
                          ),
                          child: SendPill(mode: _pmFrom(appState.sendMode)),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // one chip per emoji, with a count when more than one
  List<Widget> _buildReactionChips(_Msg m) {
    final counts = <String, int>{};
    for (final emoji in m.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final mine = m.reactions[''];
    final react = onReact;
    return [
      for (final e in counts.entries)
        ReactionChip(
          key: ValueKey(e.key),
          emoji: e.key,
          count: e.value,
          mine: e.key == mine,
          popKey: '${m.msgUid}:${e.key}',
          onTap: react == null ? null : () => react(e.key),
        ),
    ];
  }

  // the chips under the bubble. the last one to go scales back out instead
  // of vanishing; a fade alone when the phone asks for no movement
  Widget _reactionRow(BuildContext context, bool isOut) {
    final still = motionStill(context);
    final reacted = msg.reactions.isNotEmpty;
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
              children: _buildReactionChips(msg),
            ),
    );
  }
}

// how a contact's message came: through the developer chat. his phone only
class _ViaDevTag extends StatelessWidget {
  const _ViaDevTag();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('via-dev'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.support_agent, size: 10, color: HaloColors.amber),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            l10n.supportViaDev,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: HaloType.monoFamily,
              fontFamilyFallback: HaloType.monoFallbackNow,
              fontSize: 9,
              color: HaloColors.amber,
              letterSpacing: track(0.4),
            ),
          ),
        ),
      ],
    );
  }
}

// above the composer while writing a reply: a snippet of the target and an
// X to cancel
class _ReplyQuoteBar extends StatelessWidget {
  final _Msg target;
  final VoidCallback onCancel;
  const _ReplyQuoteBar({required this.target, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
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
            margin: const EdgeInsetsDirectional.only(end: 10),
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
                  target.direction == 'out'
                      ? l10n.chatReplyingToYourself
                      : l10n.chatReplyingTo,
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
                    style: HaloType.sans(
                      size: 13,
                      color: HaloColors.text2,
                      height: 1.3,
                    ),
                  )
                else
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
            tooltip: l10n.commonClose,
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

class _EmptyConversation extends StatelessWidget {
  // the shared photos page says it has none the same way
  final IconData icon;
  final String? title;
  final bool withLine;
  const _EmptyConversation({
    super.key,
    this.icon = Icons.lock_outline_rounded,
    this.title,
    this.withLine = true,
  });
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
            offset: Offset(0, motionStill(context) ? 0 : (1 - t) * 12),
            child: child,
          ),
        ),
        // scrolls rather than overflows with the keyboard up at a big font
        child: SingleChildScrollView(
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
                child: Icon(icon, color: HaloColors.amber, size: 25),
              ),
              const SizedBox(height: 20),
              Text(
                title ?? l10n.chatSayHi,
                textAlign: TextAlign.center,
                style: HaloType.serif(
                  size: withLine ? 24 : 20,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              if (withLine) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.chatJustTheTwoOf,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text2,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool sending;
  final VoidCallback onSend;
  final bool ghost;
  final VoidCallback onToggleGhost;
  final bool secure;
  final VoidCallback onToggleSecure;
  final VoidCallback onPickBurn;
  final int burnSeconds;
  final VoidCallback onAttach;
  final VoidCallback onStickers;
  final VoidCallback onCamera;
  final bool disguise;
  // on for good in this chat: the anonymous dev chat
  final bool disguiseLocked;
  final void Function(VoiceTake take) onVoice;

  const _Composer({
    required this.controller,
    this.focusNode,
    required this.sending,
    required this.onSend,
    required this.ghost,
    required this.onToggleGhost,
    required this.secure,
    required this.onToggleSecure,
    required this.onPickBurn,
    required this.burnSeconds,
    required this.onAttach,
    required this.onStickers,
    required this.onCamera,
    required this.disguise,
    this.disguiseLocked = false,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    // a phone whose identity has moved has no engine running: a message
    // typed here would sit in the outbox for good. nowhere to type it.
    if (appState.movedAway) return const MovedStrip();
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
            duration: motionStill(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
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
                        // one line that wraps: a long translation or a big
                        // font never runs off the row
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: l10n.chatGhostMode,
                                  style: HaloType.serif(
                                    size: 12,
                                    color: HaloColors.amber,
                                    italic: true,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' · ${l10n.chatMessagesBurnAfter(_humanBurn(burnSeconds))}',
                                  style: HaloType.mono(
                                    size: 10.5,
                                    color: HaloColors.text2,
                                  ),
                                ),
                              ],
                            ),
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
                label: l10n.chatTimedMessages,
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
              // the shield toggle stays hidden until it is verified end to
              // end. the flag, the wire and the viewer are all in place.
              const SizedBox(width: 1),
              // the camera that keeps its photos inside kryfo. each icon
              // sits in a finger-sized box, so a tap between them lands
              PressScale(
                label: l10n.chatOpenTheCamera,
                onTap: onCamera,
                scale: 0.86,
                child: SizedBox(
                  width: 38,
                  height: 40,
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 22,
                    color: HaloColors.text2,
                  ),
                ),
              ),
              PressScale(
                label: l10n.chatAttachAPhoto,
                onTap: onAttach,
                scale: 0.86,
                child: SizedBox(
                  width: 38,
                  height: 40,
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 22,
                    color: HaloColors.text2,
                  ),
                ),
              ),
              const SizedBox(width: 1),
              Expanded(
                child: WrittenDir(
                  controller: controller,
                  builder: (dir) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textDirection: dir,
                    inputFormatters: const [UnmarkedInput()],
                    cursorColor: HaloColors.amber,
                    style: HaloType.sans(size: 14),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.chatMessage,
                      hintStyle: HaloType.sans(
                        size: 14,
                        color: HaloColors.text3,
                      ),
                      // stickers sit inside the field: no width taken from the row
                      suffixIcon: StickerButton(onTap: onStickers),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 36,
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
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final still = motionStill(context);
                  final hasText = value.text.trim().isNotEmpty;
                  final canSend = !sending && hasText;
                  // mic and send trade places with a small pop instead of a cut
                  final Widget end = (!hasText && !sending)
                      ? KeyedSubtree(
                          key: const ValueKey('mic'),
                          child: HoldToTalkMic(
                            disguise: disguise,
                            disguiseLocked: disguiseLocked,
                            onSend: onVoice,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('send'),
                          child: PressScale(
                            label: l10n.commonSend,
                            onTap: canSend ? onSend : null,
                            scale: 0.86,
                            haptic: false, // _send already fires its own impact
                            child: AnimatedScale(
                              duration: still
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
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
                  // with less movement, a crossfade and nothing that grows
                  return AnimatedSwitcher(
                    duration: Duration(milliseconds: still ? 150 : 200),
                    switchInCurve: still ? Curves.easeOut : Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => still
                        ? FadeTransition(opacity: anim, child: child)
                        : ScaleTransition(
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
          tooltip: l10n.commonBack,
          icon: const Icon(Icons.chevron_left, size: 26),
          color: HaloColors.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.chatSharedPhotos,
              style: HaloType.serif(size: 17, color: HaloColors.text),
            ),
            Text(
              l10n.chatSharedPhotoCount(paths.length, title),
              style: HaloType.mono(size: 10, color: HaloColors.text2),
            ),
          ],
        ),
      ),
      body: paths.isEmpty
          ? _EmptyConversation(
              icon: Icons.photo_library_outlined,
              title: l10n.chatNoPhotosInThis,
              withLine: false,
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
                final tag = photoHeroTag(path, 'gallery');
                return PressScale(
                  scale: 0.96,
                  haptic: false,
                  onTap: () => _openFullImage(
                    context,
                    path,
                    secure: securePaths.contains(path),
                    tag: tag,
                  ),
                  child: Hero(
                    tag: tag,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      filterQuality: FilterQuality.low,
                      // each tile fades up once its photo is decoded
                      frameBuilder: (_, child, frame, sync) => PhotoTileFade(
                        shown: sync || frame != null,
                        child: child,
                      ),
                      // a photo whose file is gone says so, not a black square
                      errorBuilder: (_, _, _) => Container(
                        color: HaloColors.surface2,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 22,
                          color: HaloColors.text3,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// the saved mode string as the pill's enum. private is full tor, 3 hops.
PrivacyMode _pmFrom(String m) => m == 'fast'
    ? PrivacyMode.fast
    : m == 'balanced'
    ? PrivacyMode.normal
    : PrivacyMode.private;

// at the top of a chat added by a code or a link, or taken in from a
// request: three words prove nothing, the safety number does. it goes once
// they are verified, or for later
class _CompareCard extends StatelessWidget {
  final String peerName;
  final VoidCallback onVerify;
  final VoidCallback onLater;
  const _CompareCard({
    super.key,
    required this.peerName,
    required this.onVerify,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        border: Border.all(color: HaloColors.line, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: HaloColors.amber,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  l10n.chatCompareTitle,
                  style: HaloType.serif(size: 13, color: HaloColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            l10n.chatCompareLine(peerName),
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _barBtn(
                  l10n.chatCompareLater,
                  HaloColors.text,
                  HaloColors.surface,
                  onLater,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _barBtn(
                  l10n.chatVerify,
                  HaloColors.onAmber,
                  HaloColors.amber,
                  onVerify,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// shown at the top of a chat when a known contact's identity key changed.
// a reinstall looks the same as an attack, so we prompt to verify instead
// of alarming. ok dismisses until the key changes again.
class _KeyChangedBanner extends StatelessWidget {
  final String peerName;
  final VoidCallback onVerify;
  final VoidCallback onDismiss;
  const _KeyChangedBanner({
    super.key,
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
              Icon(Icons.gpp_maybe_outlined, size: 14, color: HaloColors.amber),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  l10n.chatSecurityCodeChanged,
                  style: HaloType.serif(size: 13, color: HaloColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            l10n.chatMayHaveReinstalledOr(peerName),
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _barBtn(
                  l10n.chatOk,
                  HaloColors.text,
                  HaloColors.surface2,
                  onDismiss,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _barBtn(
                  l10n.chatVerify,
                  HaloColors.onAmber,
                  HaloColors.amber,
                  onVerify,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
