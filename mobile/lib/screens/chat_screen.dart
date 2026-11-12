// SPDX-License-Identifier: GPL-3.0-or-later
// chat screen: bubbles, composer, live receive over tor.

import '../lock_state.dart';
import '../capture_watch.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart' show ContactPreview;
import '../container.dart' show HaloContainer;
import '../devices/own_answer.dart' show kAnswerBurns;
import '../drafts.dart';
import '../heal.dart'
    show
        isDeviceLine,
        kDeviceLineLinked,
        kDeviceLineRemoved,
        kDeviceLineUnchecked,
        kHealLineRestored;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../photo_blur.dart' show makeBlurSoon;
import '../picked.dart';
import '../share_files.dart';
import 'share_files_sheet.dart' show askSendSharedFiles, landFiles;
import '../album.dart';
import '../widgets/file_stack.dart';
import '../widgets/spoiler_cover.dart';
import '../show_in_chat.dart';
import '../viewer_rules.dart';
import '../widgets/select_parts.dart';
import '../widgets/preview_bleed.dart' show fileBubbleFrame;
import '../widgets/file_bubble.dart' show kFilePreviewWidth, warmSentPreview;
import '../widgets/composer_hint.dart';
import '../widgets/desk_menu.dart';
import '../widgets/say.dart' show sayArrivals;
import '../widgets/album_grid.dart';
import '../widgets/album_viewer.dart';
import '../widgets/sealed_picture.dart';
import '../widgets/shared_media.dart' show openShared;
import '../widgets/photo_shape.dart';
import 'media_send_screen.dart';
import '../sent_name.dart';
import '../desktop/desktop_mode.dart' show canShareOut, onDesktop;
import '../desktop/attach_tray.dart';
import '../desktop/drag_in.dart' show DragInZone;
import '../desktop/desktop_trace.dart' show TraceSteps;
import 'dart:io';
import 'dart:convert';
import 'key_verification_screen.dart';
import 'contact_screen.dart';
import 'wallpaper_sheet.dart';
import '../wallpaper.dart';
import '../widgets/chat_backdrop.dart';
import 'introduce_sheet.dart';
import '../vouch_text.dart';
import '../widgets/intro_chip.dart';
import '../widgets/media_bubbles.dart'
    show
        VoiceBubble,
        humanFileSize,
        VoiceMakingBubble,
        fileCard,
        fileTooBigLine,
        voiceLengthKnown;
import '../widgets/voice_mic.dart';
import '../widgets/owned_text.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/hidden_mark.dart';
import '../widgets/pins.dart';
import '../widgets/row_anchor.dart';
import '../widgets/video_bubble.dart';
import '../sound_player.dart' show SoundItem, SoundPlayer;
import '../recent_files.dart';
import '../widgets/send_hold.dart';
import '../widgets/send_sheet.dart';
import '../widgets/file_actions.dart'
    show
        FileView,
        canForwardFile,
        fileHeroTag,
        fileFactsOrName,
        fileViewOf,
        forwardFile,
        openFileOutside,
        viewInKryfo;
import '../widgets/kryfo_link_text.dart';
import '../open_file.dart';
import '../file_drop.dart' show dropDayDone, dropTryLater;
import '../file_kind.dart'
    show
        FileShape,
        fileFactsRead,
        fileFits,
        fileShapeNow,
        knownInstaller,
        readFileFactsFresh,
        sendLaneCleans;
import '../file_save.dart' show saveReceivedFile;
import '../widgets/notice_banner.dart';
import '../widgets/shield_note.dart';
import '../scam_shield.dart' show ShieldFlag;
import '../widgets/swipe_to_reply.dart';
import '../signal_session.dart';
import '../message_envelope.dart'
    show wrapMessage, SenderInfo, grindPow, powBits;
import '../outbox.dart' show powFits;
import '../theme.dart';
import '../tor_valve.dart' show valveWaitFrom;
import '../link_view.dart' show sendReadsBlocked;
import '../media_progress.dart';
import '../transfers.dart' show fileWaitOf, fileWaits;
import '../widgets/file_wait.dart';
import '../msg_order.dart';
import '../widgets/earlier_chip.dart';
import '../media_send.dart'
    show sendChunkedMediaTo, cancelMediaSend, mediaInflight, mediaSendsTick;
import '../clean_media.dart';
import '../image_strip.dart';
import '../widgets/desk_select.dart';
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
import '../main.dart'
    show
        typeLeaf,
        linkedRole,
        deviceReaches,
        deviceReplyLine,
        deviceSealOutcome,
        ownClearLine,
        ownBlockLine,
        engine,
        sendFirstContactNoted,
        AppStatePqRestart,
        AppStateFiles,
        kNotSent,
        session,
        sessionQuiet,
        signalSeal,
        peerXPubOf,
        hasSessionWith,
        appState,
        currentChatPeer,
        claimChat,
        newMsgUid,
        releaseChat,
        shredFile,
        torStrictGetOnIsolate,
        torValve,
        TorHalo,
        LinkViewBuilder,
        AppStateOutbox,
        AppStateInbox,
        AppStateAnswers,
        AppStateHeal,
        AppStateOldPeers,
        HelloWait,
        kNoHelloWait,
        AppStateMessages,
        AppStateRoute,
        AppStatePrefs,
        AppStateProfile,
        AppStateScreen,
        AppStateTyping,
        AppStateVault,
        AppStateContacts,
        AppStateSession,
        AppStateVoice,
        AppStateDevchat,
        AppStatePairing,
        AppStateRefresh;
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
import '../widgets/bubble_meta.dart';
import '../widgets/burn_fade.dart';
import '../seen_timers.dart';
import '../read_burn.dart';
import '../dlog.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/enter_sends.dart';
import '../widgets/shift_tap_guard.dart';
import '../widgets/held_menu.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/chat_parts.dart';
import '../widgets/shots_line.dart';
import '../chat_shots.dart'
    show ChatShots, ShotsPacer, kShotsByMe, kShotsByNone, shotsKeeps;
import '../widgets/message_menu.dart';
import '../widgets/halo_hero.dart';
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
import '../widgets/typing_mark.dart';
import '../typing.dart' show capsOfText, composerEdit, kCapDevices;
import '../widgets/written_field.dart';
import '../bidi_safe.dart';
import '../back_on_top.dart';
import '../forward.dart';
import 'forward_sheet.dart';
import '../widgets/key_held.dart';
import '../first_contact.dart' show routeText, waitsForReceipt;
import '../text_send.dart';
import '../lock_guard.dart' show LockDropped, lockGuard, onScreen;
import '../translate/chat_translation.dart';
import '../translate/hub_live.dart' show translationHubIfOn;
import '../voice/chat_transcripts.dart';
import '../voice/voice_text.dart' show theirWordsLang;
import '../voice/ui/transcript_line.dart';
import '../voice/voice_transcripts.dart' show voiceTranscriptsIfOn;
import '../translate/lang_names.dart';
import '../translate/translate_bar.dart';
import '../translate/translate_bubble.dart';
import '../translate/translate_menu.dart' show neverOffer;
import '../voice_format.dart' show isVoiceName, kVoiceWav;
import '../voice_length.dart' show voiceFileMs;
import '../voice_opus.dart' show voiceForWire;
import '../voice_speed.dart' show VoiceSpeed;
import '../widgets/react_taps.dart';
import '../widgets/burn_sheet.dart';
import '../widgets/voice_parts.dart' show voiceFileFree, voicePeaksSame;
import '../wide/read_width.dart';
import '../wide/wide_pane.dart' show PaneBack, PaneFind;

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

/// what was shared into [id]'s chat (SharedInbox), taken by that chat when
/// it is the page on top. false otherwise
bool landFilesInOpenChat(String id) {
  for (final s in _openChats[id] ?? const <_ChatScreenState>[]) {
    if (s.mounted && (ModalRoute.of(s.context)?.isCurrent ?? false)) {
      s._takeSharedIn();
      return true;
    }
  }
  return false;
}

/// whether [id]'s chat is the page in front, its own sheets over it or
/// not: its composer is being typed in, not a draft left behind
bool chatOnScreen(String id) => (_openChats[id] ?? const []).any(
  (s) => s.mounted && pageInFront(ModalRoute.of(s.context)),
);

/// [id]'s timed draft in [c] went: a composer of it still open empties,
/// its quote too
void emptyChatComposer(HaloContainer c, String id) {
  for (final s in _openChats[id] ?? const <_ChatScreenState>[]) {
    if (s.mounted && s._memo == c.chatKey(id)) s._timedDraftGone();
  }
}

/// a deleted chat's unsent words go with it, from an open composer too
Future<void> dropChatDraft(String id) {
  for (final s in _openChats[id] ?? const <_ChatScreenState>[]) {
    if (s.mounted) s._msgCtrl.clear();
  }
  return dropDraft(session.draftsOf(id), id, group: false);
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
              l10n.chatJustForYouNeverShown,
              style: HaloType.sans(size: 12, color: HaloColors.text),
            ),
            const SizedBox(height: 16),
            ShiftTapGuard(
              controller: ctrl,
              child: TextField(
                controller: ctrl,
                enableIMEPersonalizedLearning: false,
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
                      color: HaloColors.amberText,
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

// the newest row id held when the chat was last left, keyed by
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

// a photo or a file in the media folder under its uid, cleaned and ready
// to go: nothing is shown or sent yet
class _Ready {
  final String uid;
  final String path;
  final String? fileName;
  // a photo inside a file set, blurred until tapped
  final bool spoiler;
  const _Ready(this.uid, this.path, {this.fileName, this.spoiler = false});
}

class _Msg with WordLinks {
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
  String? msgUid;
  // msg_uid of the message this one replies to, or null. set again on a
  // pick's first bubble that is ready when the one before would not go
  String? replyTo;
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
  // a voice note sent while its disguise is made: how far it is
  ValueListenable<double?>? making;
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
  // its place in an album (album.dart). set again while it is still
  // being made ready, when one before it would not go
  AlbumTag? album;
  // shown at once on send, while its photo or video is still cleaned:
  // not saved, not sent yet
  bool preparing = false;
  // a photo sent as a spoiler: blurred until it is tapped
  bool spoiler;
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
    this.album,
    this.spoiler = false,
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

// out of the bubble it was tapped in, or a tile of the shared photos. a
// marked photo stays protected wherever it is opened from
void _openFullImage(
  BuildContext context,
  String path, {
  bool secure = false,
  Object? tag,
  double radius = 0,
}) => openPhoto(context, path, tag: tag, radius: radius, secure: secure);

// an album full screen from its tile [at]: what is here of it, in its
// order. one marked item keeps the whole viewer protected
void _openAlbumAt(BuildContext context, List<_Msg?> shown, int at) {
  // one still to come has nothing to show yet
  String? here(_Msg? x) => x == null || fileWaitOf(x.msgUid) != null
      ? null
      : x.mediaPath ?? x.filePath;
  final items = <AlbumItem>[
    for (final x in shown)
      if (here(x) case final p?)
        AlbumItem(p, video: x!.mediaPath == null, fileName: x.fileName),
  ];
  final paths = [for (final x in shown) here(x)];
  final start = albumOpenAt(paths, at);
  if (start == null) return;
  openAlbum(
    context,
    items,
    start: start,
    secure: shown.any((x) => x?.secure ?? false),
  );
}

// the time and tick on a photo or a video with no caption: a small dark pill
// in the corner, since there is no bubble under it to carry them
Widget _mediaStamp(_Msg msg, {bool word = true}) {
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
        // ours: a clock until their receipt, then the tick and Delivered
        if (msg.direction == 'out') ...[
          const SizedBox(width: 3),
          Builder(
            builder: (context) => _outMark(
              context,
              msg,
              unconfirmed: !msg.delivered,
              color: Colors.white,
              word: word,
            ),
          ),
        ],
      ],
    ),
  );
}

// the tick on a text of ours, or a clock while it is sent and not delivered
// yet to someone who has not added us back. [waits]: not sent yet, kept
// until it can go, as for someone on an older Kryfo
Widget _outMark(
  BuildContext context,
  _Msg msg, {
  required bool unconfirmed,
  required Color color,
  bool waits = false,
  bool word = true,
}) => AnimatedSwitcher(
  duration: motionStill(context)
      ? Duration.zero
      : const Duration(milliseconds: 200),
  child: waits
      ? Icon(
          Icons.schedule_rounded,
          key: const ValueKey('waits'),
          size: 10,
          color: color,
          semanticLabel: l10n.chatWaitsToSend,
        )
      : unconfirmed
      ? Icon(
          Icons.schedule_rounded,
          key: const ValueKey('unconfirmed'),
          size: 10,
          color: color,
          // gone from here, its receipt not back yet
          semanticLabel: l10n.motionSent,
        )
      : SentTick(
          key: const ValueKey('sent'),
          delivered: msg.delivered,
          deliveredLabel: l10n.chatDelivered,
          word: word,
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
  bool word = true,
}) {
  final Widget child;
  if (showMeta) {
    child = KeyedSubtree(
      key: const ValueKey('stamp'),
      child: _mediaStamp(msg, word: word),
    );
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
    m.failed && (m.gaveUp || m.notSent || _readsBlocked() || _fileIdle(m));

// tor still coming up is not a failure: what waits for it reads as sending
bool _readsBlocked() => sendReadsBlocked(
  online: appState.online,
  torReady: appState.torReady,
  link: appState.linkView,
);

// a file of ours no send holds is not moving: it says not sent, and a tap
// sends what is missing. one a send holds draws as sending
bool _fileIdle(_Msg m) =>
    m.direction == 'out' &&
    (m.mediaPath != null || m.filePath != null) &&
    (m.msgUid == null || !mediaInflight.contains(m.msgUid));

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
  // what the pill says while the route is not up, and the long words only
  // while tor is still coming up
  final waiting = appState.linkView.sendLine;
  if (raw.startsWith('error:') && waiting != null) return waiting;
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

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, BackOnTop<ChatScreen>, HeldMenu<ChatScreen> {
  final _msgCtrl = TextEditingController();
  // a reply raises the keyboard at once, like a tap on the field
  final _composerFocus = FocusNode();
  // the newest row held when the chat was last left: what came after it is
  // new, wherever its time puts it
  int? _unreadAfterRow;
  // the row the new messages divider sits above, by its key: an index
  // would slip as older pages come in above it
  String? _firstUnreadKey;
  bool _unreadResolved = false;
  // this chat's own flame (loadChatBurn), off until it is read
  bool _ghost = false;
  // the timed setting read: until then new words keep the draft's timer
  bool _ghostKnown = false;
  // marks the next message so the other phone blocks screenshots of it. off
  // by default, since then neither side can screenshot the chat.
  bool _secureNext = false;
  // this chat's voice notes go out disguised
  bool _disguise = false;
  // the chat's screenshot block, as both phones hold it
  ChatShots _shots = const ChatShots();
  // when this chat went over to post-quantum (pq_restart.dart), for its line
  int? _pqAt;
  // this screen's one hold on the window's flag while the chat blocks
  late final _shotsHold = ShotsPacer(appState.forceSecure);
  int _burnSeconds = 300;
  // the burn, the inbox poll and the auto retry run only while the chat is
  // in view, and catch up the moment it is back
  final _timers = SeenTimers();
  late final SeenJob _burn;
  int _lastBurnSec = 0;
  final _scrollCtrl = HoldScrollController();
  static const _pageSize = 60;
  bool _hasMore = false;
  bool _loadingOlder = false;
  // set once the user paged deep or jumped, so reloads keep the full thread
  // so their scroll position doesn't collapse back to one page.
  bool _pagedOut = false;

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore) return;
    _loadingOlder = true;
    try {
      final oldest = _oldestHeld();
      final rows = await session.messagesPage(
        widget.peerHaloId,
        beforeRowid: oldest?.rowid,
        beforeAt: oldest?.when.millisecondsSinceEpoch,
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
          DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
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
          album: AlbumTag.ofRow(r),
          spoiler: r['spoiler'] == 1,
          delivered: (r['delivered'] as int? ?? 0) == 1,
          sending:
              (r['direction'] as String) == 'out' &&
              (r['sent'] as int? ?? 1) == 0,
        );
        m.rowid = (r['rowid'] as int?) ?? 0;
        m.cameAt = (r['sent_at'] as num?)?.toInt();
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
        _forgetTranslation(o);
        Future.delayed(kLeaveGone, () {
          if (mounted) setState(() => _messages.remove(o));
        });
      }
      _messages.add(o);
    }
  }

  bool _loaded = false;
  // what this chat shows behind it (wallpaper.dart)
  ChatWall _wall = ChatWall.none;
  String _status = '';
  bool _loading = false;
  bool _reloadPending = false;
  // sends being ground and sealed, typed or not. the composer does not
  // wait for them, a retry does
  int _sealing = 0;
  // texts, stickers and waves seal in the order they were sent: a later
  // one grinds beside an earlier one and waits for it to be handed on
  Future<void> _sendTurn = Future.value();
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
  // the quote a kept draft had, until the messages are here to find it in
  String? _draftReply;

  // search in chat. _matches are indices into _messages, _matchPos the
  // current hit, _matchKeys let a hit be scrolled into view.
  bool _searching = false;
  // ctrl+f on the desktop's pane
  final _find = PaneFind();
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
  // on a linked device, a chat it cannot answer: what the bar says instead
  // of the composer (an older Kryfo, a chat with screenshots blocked)
  String? _phoneOnly;
  // a chat of the developer's inbox on a computer linked to his phone: what
  // is written here goes to the phone, which sends it on his key
  bool _viaPhone = false;
  bool _barSettled = false;
  bool _muted = false;
  bool _verified = false;
  String? _peerBadge;
  bool _keyChanged = false;
  // verified under one key, holding another now: nothing goes to them until
  // the new number is checked or the new key accepted
  bool _keyHeld = false;
  // the heal line that holds them (heal.dart), null when no heal does
  int? _healHold;
  // where heals rebuilt their session, and whether this chat waits for
  // them to update after a restore here (Q20)
  List<({int at, int kind})> _healLines = const [];
  bool _pausedForUpdate = false;
  // added by a hello that waits for its answer: what is written waits, and
  // a v3 card's owner may need to update first
  HelloWait _helloWait = kNoHelloWait;
  Timer? _helloWaitTimer;
  bool _keyReading = false;
  // a read asked for while one runs runs again after it
  bool _keyAgain = false;
  // the accept's word to them never got through: they may not know
  bool _ackLost = false;

  // what this chat shows about their key, read again whenever a key changes
  // or a mark is set somewhere else
  // an answer of mine here that waits for the phone to send it
  bool get _answersWait =>
      _messages.any((m) => m.direction == 'out' && m.parked && !m.failed);

  // a linked device answers only a contact whose app reads its copies, and
  // never a chat with screenshots blocked: the phone does
  Future<void> _readPhoneOnly() async {
    if (!linkedRole) return;
    try {
      final row = await session.getContact(widget.peerHaloId);
      if (row == null || !mounted) return;
      // a long name cut, so the line stays a few lines on a narrow window
      final full =
          _nickname ?? (row['nickname'] as String?) ?? widget.peerHaloId;
      final c = full.characters;
      final name = c.length > 24 ? '${c.take(22)}\u2026' : full;
      final String? line;
      var viaPhone = false;
      if (await appState.inboxChatHere(widget.peerHaloId)) {
        // his inbox: only his phone answers on the developer's key, from
        // here when it takes answers
        viaPhone = await appState.answersViaPhone(widget.peerHaloId);
        line = viaPhone ? null : l10n.chatInboxAnswerFromPhone;
      } else if (row['shots_on'] == 1) {
        line = l10n.historyChatStaysShots;
      } else if (!capsOfText(row['caps'] as String?).contains(kCapDevices)) {
        // their caps came without the devices word: an older Kryfo. none
        // came yet: nothing is known of their version
        final known = capsOfText(row['caps'] as String?).isNotEmpty;
        line = await deviceReplyLine(
          widget.peerHaloId,
          name,
          older: known,
          unknown: !known,
        );
      } else if (!await deviceReaches(widget.peerHaloId)) {
        // none of their devices opened to this one yet
        line = await deviceReplyLine(widget.peerHaloId, name, older: false);
      } else {
        line = null;
      }
      if (!mounted) return;
      if (line != _phoneOnly || viaPhone != _viaPhone) {
        setState(() {
          _phoneOnly = line;
          _viaPhone = viaPhone;
          // a shorter clock than the phone sends from here takes its floor
          if (viaPhone && !kAnswerBurns.contains(_burnSeconds)) {
            _burnSeconds = kAnswerBurns.first;
          }
        });
      }
    } catch (e) {
      dlog('chat: phone-only not read (${e.runtimeType})');
    }
  }

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
      final heal = held ? await healHoldShown(widget.peerHaloId) : null;
      if (!mounted) return;
      if (changed != _keyChanged ||
          verified != _verified ||
          held != _keyHeld ||
          heal != _healHold) {
        setState(() {
          _keyChanged = changed;
          _verified = verified;
          _keyHeld = held;
          _healHold = heal;
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

  // a heal's hold looked at: the verified mark stays, sending goes on
  Future<void> _keepChatting() async {
    HapticFeedback.mediumImpact();
    await appState.releaseHealHold(widget.peerHaloId);
    await _readKeyState();
  }

  // the heal lines and the wait for an update, read with the thread
  Future<void> _loadHealLines() async {
    if (_isDev || widget.support) return;
    try {
      final lines = await session.healLines(widget.peerHaloId);
      final paused = await appState.pausedForUpdate(widget.peerHaloId);
      final wait = await appState.helloWaitOf(widget.peerHaloId);
      if (!mounted) return;
      _helloWaitTimer?.cancel();
      final at = wait.updateAt;
      if (at != null) {
        final left = at - DateTime.now().millisecondsSinceEpoch;
        _helloWaitTimer = Timer(
          Duration(milliseconds: left < 0 ? 0 : left + 50),
          () => unawaited(_loadHealLines()),
        );
      }
      // a send that failed for want of a session waits for their answer
      final parks = wait.waits && _parkUnanswered();
      if (!parks &&
          wait == _helloWait &&
          paused == _pausedForUpdate &&
          lines.length == _healLines.length &&
          (lines.isEmpty || lines.last.at == _healLines.last.at)) {
        return;
      }
      setState(() {
        _healLines = lines;
        _pausedForUpdate = paused;
        _helloWait = wait;
      });
    } catch (e) {
      dlog('heal lines: not read (${e.runtimeType})');
    }
  }

  // rows of mine that failed while a hello waits for its answer: they wait
  // with it, and the outbox sends them once a session is up. true when one
  // moved
  bool _parkUnanswered() {
    var moved = false;
    for (final m in _messages) {
      if (m.direction == 'out' &&
          m.failed &&
          !m.notSent &&
          !m.delivered &&
          !m.sending) {
        m
          ..failed = false
          ..parked = true;
        moved = true;
      }
    }
    if (moved && _status == l10n.chatNoSignalSessionRe) _status = '';
    return moved;
  }

  // the new key taken as it is: the mark and the banner go, sending goes on
  Future<void> _acceptNewKey() async {
    final name = _nickname ?? widget.peerHaloId;
    if (!await acceptNewKeyAsked(context, widget.peerHaloId, name)) return;
    await _readKeyState();
  }

  // whether the accept's word to them was let go. a quiet session says
  // nothing of it: it sends nothing anyway
  Future<void> _readAckLost() async {
    if (_isDev) return;
    try {
      final lost = !sessionQuiet && await session.ackLost(widget.peerHaloId);
      if (mounted && lost != _ackLost) setState(() => _ackLost = lost);
    } catch (e) {
      dlog('ack line: not read (${e.runtimeType})');
    }
  }

  // the line's button: the accept's word goes again, and the line with it
  Future<void> _retryAck() async {
    HapticFeedback.selectionClick();
    setState(() => _ackLost = false);
    await appState.retryAck(widget.peerHaloId);
    await _readAckLost();
  }

  Future<void> _dismissKeyChanged() async {
    await session.setKeyChanged(widget.peerHaloId, false);
    if (mounted) setState(() => _keyChanged = false);
  }

  // request-lock state: a stranger we haven't accepted, capped at 2 sent msgs.
  bool _accepted = true; // assume ok until loaded, so normal chats don't flash
  bool _peerEngaged =
      false; // they replied, added us back or asked -> lock lifts
  int _sentCount = 0;
  int _recvCount =
      0; // messages they've sent us; >0 + unaccepted = a request TO us
  // sender-side lock: messaging a stranger who hasn't accepted, past the cap.
  // once they engage (reply/back-pair) or we accept them, it clears.
  bool get _requestPending => !_peerEngaged && _recvCount == 0;
  // ours to someone who has not accepted: the pill says so, not the route
  bool get _waitsAccept =>
      _requestPending && !_vouched && !_isDev && !widget.support;
  bool get _requestLocked =>
      _requestPending && _sentCount >= (_isDev ? kDevCap : 2) && !_vouched;
  // receiver-side: a stranger has messaged us and we haven't accepted yet.
  bool get _incomingRequest => !_accepted && _recvCount > 0 && !widget.support;
  // a reaction says this phone read it: none in a request or a block
  bool get _canReact => !_blocked && !_incomingRequest;
  // a link in a request is plain words on both sides: nothing to tap open,
  // no card under it
  bool get _plainLinks =>
      !_isDev && (_requestPending || (!_accepted && _recvCount > 0));
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
  // a request to a stranger is words alone until they accept: no photo,
  // file, voice note or gif goes from here, and their side holds any that
  // come. an introduced one, the dev chat and his support chats keep theirs
  bool get _mediaWaits =>
      _viaPhone || (_requestPending && !_vouched && !_isDev && !widget.support);
  // their side of it: what a stranger sent with a file waits, unshown,
  // until the accept. a decline shreds it
  bool _heldBack(_Msg m) =>
      _incomingRequest &&
      !_vouched &&
      !_isDev &&
      m.direction != 'out' &&
      (m.mediaPath != null || m.filePath != null || m.fileName != null);
  // said wherever media was reached for in a request still waiting
  bool _sayMediaLater() {
    if (!_mediaWaits) return false;
    if (mounted) showHaloToast(context, _mediaLaterLine);
    return true;
  }

  // what a file reached for where only words go says
  String get _mediaLaterLine =>
      _viaPhone ? l10n.chatInboxFilesFromPhone : l10n.requestSenderMediaLater;

  // an attach or camera tap where only words go
  void _sayFilesFromPhone() => _sayMediaLater();

  // what the scam shield saw on this stranger, if anything and not dismissed
  ShieldFlag? _flag;
  bool _showScrollDown = false;
  // their messages that came in while reading back, for the jump button.
  // counted as they arrive: older pages and reloads add none
  int _unseenNew = 0;
  // came in written well before the bottom, up the thread (EarlierChip)
  final _earlier = EarlierArrivals();
  String? _rippleUid;
  _Msg? _replyFlash;
  String? _note;

  // the developer chat: his header and first line, the note before the
  // first send, and the one start every kind of message asks for
  late final bool _isDev = isDevChat(widget.peerHaloId);
  DevOpening? _devOpening;
  // this chat in the session that opened it, for what is kept between visits
  late final String _memo;
  // their messages in other languages, translated on the phone
  late final ChatTranslation? _translation = switch (translationHubIfOn()) {
    final hub? => ChatTranslation(hub, widget.peerHaloId),
    null => null,
  };
  // their voice notes and ours as words, made on the phone
  late final ChatTranscripts? _transcripts = switch (voiceTranscriptsIfOn()) {
    final hub? => ChatTranscripts(
      hub,
      widget.peerHaloId,
      theirLang: () => theirWordsLang([
        for (final m in _messages.reversed)
          if (m.direction == 'in' && m.text.isNotEmpty) m.text,
      ]),
    ),
    null => null,
  };
  // its row in this session's database, for when the chat was made
  DevChatRow? _devChat;
  // the pinned key did not check out: nothing was sent
  bool _devKeyFailed = false;
  // the pinned card is too old to start a chat on: an update brings one
  bool _devCardOld = false;

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
      ? l10n.devNamelessLineShown
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
      case DevStart.needsUpdate:
        HapticFeedback.lightImpact();
        setState(() => _devCardOld = true);
        return false;
      case DevStart.none:
        return false;
    }
  }

  void _chooseDevName(bool anon) => _devOpening?.choose(anon: anon);

  // android's word that this chat was screenshotted or is recorded: one
  // quiet line here, on this phone alone
  VoidCallback? _unwatchCaptures;
  void _captured(Capture what) {
    if (!mounted || lockState.locked) return;
    // a secure window came out black: until a phone shows the callback
    // stays quiet there, nothing is said
    if (appState.windowSecure) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    showHaloToast(context, captureLine(what));
  }

  @override
  void initState() {
    super.initState();
    _unwatchCaptures = captureWatch.watch(_captured);
    _memo = session.chatKey(widget.peerHaloId);
    _tray.addListener(_trayMoved);
    chatShown(widget.peerHaloId);
    showInChat.addListener(_showAsked);
    if (onDesktop) DeskTrays.handedIn.addListener(_takeHandedIn);
    // a computer: the chat opens ready to type. the field takes it as soon
    // as it is built
    if (onDesktop) _composerFocus.requestFocus();
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
    // received notes play at this identity's speed
    unawaited(VoiceSpeed.use(session.container));
    appState.loadChatBurn(widget.peerHaloId).then((p) {
      if (mounted) {
        setState(() {
          _ghost = p.$1;
          _burnSeconds = _viaPhone && !kAnswerBurns.contains(p.$2)
              ? kAnswerBurns.first
              : p.$2;
          _ghostKnown = true;
        });
      }
    });
    appState.loadChatDisguise(widget.peerHaloId).then((d) {
      if (mounted) setState(() => _disguise = d);
    });
    // held before the first frame, from what the list knows, so the push
    // never draws the chat uncovered; the read below settles it
    if (!_isDev &&
        !widget.support &&
        appState.shotsBlocksChat(widget.peerHaloId)) {
      // and the menus are kept from the first frame on
      _shots = const ChatShots(on: true, can: 1, known: true);
      _shotsHold.want(true, now: true);
    }
    _loadShots();
    unawaited(_loadHealLines());
    unawaited(_loadPqLine());
    appState.addListener(_onAppStateChanged);
    mediaSendsTick.addListener(_mediaSendsMoved);
    fileWaits.addListener(_waitsMoved);
    lockState.addListener(_lockLifted);
    claimChat(widget.peerHaloId);
    (_openChats[widget.peerHaloId] ??= []).add(this);
    // opened under the lock: marked read once it lifts
    lockGuard.isLocked() ? _underLock = true : _markRead();
    _unreadAfterRow = _lastReadPerPeer[_memo];
    final rows = session.draftsOf(widget.peerHaloId);
    final kept = heldDraft(rows.container, widget.peerHaloId, group: false);
    _msgCtrl.text = composerWith(kept?.text ?? '', widget.initialText);
    _draftReply = kept?.replyTo;
    // after a stopped process the draft is only in its row
    if (kept == null) unawaited(_readDraft(rows));
    // kept on every keystroke, so it survives leaving the chat and the app
    _msgCtrl.addListener(_keepDraft);
    // what is typed from here on may tell them, words put back never do
    _typedWas = _msgCtrl.text;
    _msgCtrl.addListener(_typed);
    // words handed in by a share or a forward are a draft from the start;
    // after a stop, once the row they join is read
    if (kept != null && _handedIn) _keepDraft();
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
    _loadWall();
    // a new default under appearance shows here at once
    wallpaperRevision.addListener(_loadWall);
    peerXPubOf(widget.peerHaloId).then((v) {
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
    unawaited(_loadBadge());
    // request lock: are they an accepted contact, have they engaged, and how
    // many messages have we already sent while unaccepted.
    final barReads = <Future<void>>[
      blockedRead,
      session.isAccepted(widget.peerHaloId).then((v) {
        if (mounted) setState(() => _accepted = v);
      }),
      _readEngaged().then((v) {
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
      _readPhoneOnly(),
    ];
    unawaited(_readAckLost());
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
          if (onDesktop) _takeHandedIn();
          _takeSharedIn();
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
    _scrollCtrl.addListener(_lookEarlier);
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
    _find.attach(context, () {
      if (!_searching) _openSearch();
    });
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
        if (m.msgUid != null) _earlier.drop(m.msgUid!);
        _forgetTranslation(m);
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

  // the words of their last messages, what the translate bar looks at
  List<String> _theirRecent() {
    if (_translation == null) return const [];
    final out = <String>[];
    for (var i = _messages.length - 1; i >= 0 && out.length < 20; i--) {
      final m = _messages[i];
      if (m.direction != 'in' || m.welcome || m.sticker != null) continue;
      if (m.removing || m.text.trim().isEmpty) continue;
      out.add(m.text);
    }
    return out;
  }

  // its translation and its transcript go with it, not when the chat
  // closes
  void _forgetTranslation(_Msg m) {
    _translation?.forget(trKeyOf(m.msgUid, m.came), m.text);
    final uid = m.msgUid;
    if (uid == null || !isVoiceName(m.fileName)) return;
    final words = _transcripts?.of(uid).text ?? '';
    _transcripts?.forget(uid);
    if (words.isNotEmpty) _translation?.forget(txTranslateKey(uid), words);
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
      _loadShots();
      unawaited(_loadHealLines());
      unawaited(_loadPqLine());
      // their badge rides their messages: one that came now may change it
      unawaited(_loadBadge());
      // a copy of theirs to this device opens the pair: the composer comes
      if (_phoneOnly != null) unawaited(_readPhoneOnly());
    }
    _refreshRequestState();
    unawaited(_readKeyState());
    unawaited(_readAckLost());
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

  Future<void> _loadBadge() async {
    final c = await session.getContact(widget.peerHaloId);
    final b = c?['supporter_badge'] as String?;
    if (mounted && b != _peerBadge) setState(() => _peerBadge = b);
  }

  // who vouched, as we know them. only accepted contacts come back, so a
  // voucher we deleted since is no longer named.
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
    final f = ShieldFlag.fromRow(
      await session.shownShieldFor(widget.peerHaloId),
    );
    if (mounted && f != _flag) setState(() => _flag = f);
  }

  // dismissed for good: the row stays, so the check never runs on them again
  Future<void> _dismissShield() async {
    await session.dismissShield(widget.peerHaloId);
    if (mounted) setState(() => _flag = null);
  }

  // they added us back, or their hello was answered here: either way they
  // know this phone, so nothing here is a request of mine and no card waves
  Future<bool> _readEngaged() async {
    if (await session.isBackPaired(widget.peerHaloId)) return true;
    try {
      return await session.theyAsked(widget.peerHaloId);
    } catch (_) {
      return false;
    }
  }

  // a reply can land while the sender sits in the locked chat, so re-check
  // whenever something arrives
  void _refreshRequestState() {
    if (_accepted && _peerEngaged && _recvCount > 0) return;
    session.isAccepted(widget.peerHaloId).then((v) {
      if (mounted && v != _accepted) setState(() => _accepted = v);
    });
    _readEngaged().then((v) {
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
  // offline case; this covers a route that was slow or flaky.
  void _autoRetryTick() {
    if (!mounted || _sealing > 0 || _cannotSend()) return;
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

  // the sends this screen started, by row, until their verdict is drawn
  final Map<String, int> _ownSends = {};
  // rows seen held by a send this screen did not start
  final Set<String> _seenGoing = {};
  Timer? _followTimer;

  // the files still to come: a bubble draws a card or its file by them, so
  // one read after the chat was drawn draws again. a ring moving does not
  Set<String> _waitUids = fileWaits.value.keys.toSet();
  void _waitsMoved() {
    final now = fileWaits.value.keys.toSet();
    if (setEquals(now, _waitUids)) return;
    _waitUids = now;
    if (mounted) setState(() {});
  }

  // a beat after the tick, so a send that just let go has written its row
  void _mediaSendsMoved() {
    _followTimer?.cancel();
    _followTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_followMediaSends()),
    );
  }

  // a file of ours that a send took up or let go of somewhere else: the
  // outbox, or this chat left and opened again. one held shows as sending;
  // one let go reads its row, and is done, waiting or not sent
  Future<void> _followMediaSends() async {
    if (!mounted) return;
    var changed = false;
    final ended = <_Msg>[];
    for (final m in _messages) {
      final uid = m.msgUid;
      if (m.direction != 'out' ||
          uid == null ||
          (m.mediaPath == null && m.filePath == null) ||
          _ownSends.containsKey(uid)) {
        continue;
      }
      if (mediaInflight.contains(uid)) {
        _seenGoing.add(uid);
        if (!m.sending && (m.failed || m.parked) && !m.notSent) {
          m
            ..sending = true
            ..failed = false
            ..parked = false;
          changed = true;
        }
      } else if (_seenGoing.remove(uid) && m.sending) {
        ended.add(m);
      }
    }
    if (ended.isNotEmpty) {
      final backPaired = await session.isBackPaired(widget.peerHaloId);
      for (final m in ended) {
        final uid = m.msgUid!;
        final s = await session.sendState(uid);
        final held = !s.sent && await session.heldBack(uid);
        if (!mounted) return;
        // taken up again meanwhile, here or there
        if (!m.sending || mediaInflight.contains(uid)) continue;
        if (_ownSends.containsKey(uid)) continue;
        m.sending = false;
        if (!s.sent && !s.delivered) {
          m.failed = held || backPaired;
          m.parked = !held && !backPaired;
          m.notSent = held;
        } else {
          await _takeBurn(m);
        }
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
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
        await _takeBurn(m);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  // a timed message of ours that another send finished: its clock runs from
  // the row, started there if nothing started it yet
  Future<void> _takeBurn(_Msg m) async {
    if (m.burnSecs == null || m.burnAt != null || m.msgUid == null) return;
    final at = await session.lightBurn(m.msgUid!);
    if (at != null) m.burnAt = at;
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
    // one written before the pages held comes with the page it is in
    final oldest = _hasMore ? _oldestHeld() : null;
    final bottom = _messages.lastOrNull;
    if (oldest != null && bottom != null) {
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid == null || have.contains(uid) || r['direction'] == 'out') {
          continue;
        }
        final at = rowWrittenAt(r);
        final above =
            byWritten(
              at,
              (r['rowid'] as int?) ?? 0,
              oldest.when.millisecondsSinceEpoch,
              oldest.rowid,
            ) <=
            0;
        if (above && cameEarlier(at, bottom.when.millisecondsSinceEpoch)) {
          _earlier.add(uid);
        }
      }
    }
    // no new row we don't already hold means a full reload: covers edits,
    // reactions and deletes
    // a held row's place is read once, before any loop: windows' aot hoists
    // a field of a nullable above its null check, and a load through null
    // there reads unmapped memory (crash 4)
    final top = oldest == null
        ? null
        : (at: oldest.when.millisecondsSinceEpoch, rowid: oldest.rowid);
    final brandNew = rows
        .where(
          (r) =>
              (r['msg_uid'] as String?) != null &&
              !have.contains(r['msg_uid'] as String?) &&
              (top == null ||
                  byWritten(
                        rowWrittenAt(r),
                        (r['rowid'] as int?) ?? 0,
                        top.at,
                        top.rowid,
                      ) >
                      0),
        )
        .toList();
    if (brandNew.isEmpty) {
      if (_earlier.count > 0) _lookEarlierSoon();
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
        DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
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
        album: AlbumTag.ofRow(r),
        spoiler: r['spoiler'] == 1,
        delivered: (r['delivered'] as int? ?? 0) == 1,
        sending:
            (r['direction'] as String) == 'out' &&
            (r['sent'] as int? ?? 1) == 0,
      );
      m.rowid = (r['rowid'] as int?) ?? 0;
      m.cameAt = (r['sent_at'] as num?)?.toInt();
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
    // one that came late goes up the thread, where it was written: it is
    // neither followed nor counted as new below
    final last = _messages.lastOrNull;
    final end = last == null
        ? null
        : (at: last.when.millisecondsSinceEpoch, rowid: last.rowid);
    bool below(_Msg m) =>
        end == null ||
        byWritten(m.when.millisecondsSinceEpoch, m.rowid, end.at, end.rowid) >
            0;
    final theirs = fresh.where((m) => m.direction != 'out' && below(m)).length;
    final ours = fresh.any((m) => m.direction == 'out');
    final follow = (snap && fresh.any(below)) || ours;
    for (final m in fresh) {
      if (m.direction != 'out' &&
          m.msgUid != null &&
          end != null &&
          cameEarlier(m.when.millisecondsSinceEpoch, end.at)) {
        _earlier.add(m.msgUid!);
      }
    }
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
    if (mounted) sayArrivals(context, theirs);
    _lookEarlierSoon();
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
            !_heldBack(_messages[i]) &&
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
    _Msg target, {
    // an album: [target] stands for all of it, [tile] is the one held
    AlbumRun<_Msg>? album,
    int? tile,
  }) async {
    // what the album's actions land on: its first item, the one held, and
    // the one holding this phone's reaction
    final anchor = album?.anchor ?? target;
    final held = album != null && tile != null && tile < album.drawn.length
        ? album.drawn[tile]
        : null;
    final reactOn = album == null ? target : _reactOn(album);
    // a photo or video of theirs that came protected is neither saved nor
    // shared from here: what its mark promises holds on this phone
    final saveOn = _keptHere(held ?? anchor) ? null : held ?? anchor;
    final shareOn = album == null ? target : held;
    final canShare =
        shareOn != null &&
        !_keptHere(shareOn) &&
        shareOn.filePath != null &&
        !isVoiceName(shareOn.fileName);
    final going = album == null
        ? target.sending &&
              (target.mediaPath != null || target.filePath != null)
        : album.present.any((x) => x.sending);
    HapticFeedback.selectionClick();
    for (final x in album?.present ?? [target]) {
      _touched(x);
    }
    // his first line is the app's own: it is copied and nothing else
    final welcome = target.welcome;
    // theirs, in a chat that blocks: not even saved in here
    final theirsKept = _keeps(target);
    // in a chat that blocks screenshots nothing leaves, ours included
    final kept = theirsKept || _shots.blocking;
    // a row without a uid gets a local one. the peer doesn't know it, so the
    // reaction stays local.
    if (target.msgUid == null && !welcome) {
      final uid = newMsgUid();
      target.msgUid = uid;
      await session.assignUidIfMissing(widget.peerHaloId, target.came, uid);
    }
    if (!mounted) return;
    await keyboardDown(context);
    // the lock went up, or the chat started to go, while the uid was
    // written: no menu
    if (!mounted || !bubbleContext.mounted || lockGuard.isLocked()) return;
    if (ModalRoute.isCurrentOf(context) == false) return;
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final bubbleSize = box.size;
    const pickerH = 54.0;
    // theirs in a language the person does not read
    final trKey = trKeyOf(target.msgUid, target.came);
    final translation = _translation;
    final trOffer =
        translation != null &&
            !welcome &&
            target.direction == 'in' &&
            target.sticker == null
        ? translation.offer(target.text)
        : null;
    final canTranslate = translation != null && trOffer != null;
    // a voice note copies its words while they show, as a text would
    final heard = target.msgUid != null && isVoiceName(target.fileName)
        ? _transcripts?.shownText(target.msgUid!)
        : null;
    final copyWords = target.text.isEmpty ? heard ?? '' : target.text;
    // the card's height from its rows, so it is placed where it fits
    final out = target.direction == 'out';
    final media = target.mediaPath != null || target.filePath != null;
    final rows = welcome
        ? 1
        // the rows, Select among them
        : (canTranslate ? 7 : 4) +
              (target.text.isNotEmpty && target.sticker == null ? 1 : 0) +
              (target.sticker == null ? 1 : 0) +
              (target.filePath != null && !isVoiceName(target.fileName)
                  ? 1
                  : 0) +
              (out && !media && target.sticker == null ? 1 : 0) -
              (out ? 0 : 1) +
              (target.filePath != null && !isVoiceName(target.fileName)
                  ? 4
                  : 0);
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
    // a file of its own, not a voice note: it is looked at, sent on and
    // handed out from here
    // in a set of files, the one held
    final fileAt = album == null
        ? target
        : album.tag.files
        ? held
        : null;
    final fileOn =
        fileAt != null &&
        canForwardFile(fileAt.filePath, fileAt.fileName, kept: kept);
    final fileView =
        fileAt != null &&
        fileAt.filePath != null &&
        !isVoiceName(fileAt.fileName) &&
        fileViewOf(fileFactsOrName(fileAt.filePath!, fileAt.fileName)) != null;
    // pin the bar to the message's side so it never runs off the edge
    final alignRight = target.direction == 'out';
    final still = motionStill(context);

    // what the menu can do, the phone's card and the computer's menu alike.
    // [dismiss] takes the menu down first, then runs what it is given
    List<MenuAction> actionsWith(
      void Function({bool now, VoidCallback? then}) dismiss,
    ) => [
      // a file kryfo can show opens here first, before any way out
      if (fileView)
        MenuAction(
          icon: Icons.visibility_outlined,
          label: l10n.fileViewInKryfo,
          tint: HaloColors.amber,
          onTap: () {
            dismiss(now: true);
            viewInKryfo(
              context,
              fileAt.filePath!,
              fileAt.fileName,
              kept: kept,
              from: _fileFrom(fileAt),
            );
          },
        ),
      // his first line: copy, and nothing else
      if (!welcome)
        MenuAction(
          icon: target.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: target.pinned ? l10n.chatUnpin : l10n.chatPin,
          onTap: () {
            dismiss();
            _togglePin(anchor);
          },
        ),
      // in an album, the one held
      if (!welcome)
        MenuAction(
          icon: saveOn?.saved ?? false
              ? Icons.bookmark
              : Icons.bookmark_outline,
          label: saveOn?.saved ?? false ? l10n.chatUnsave : l10n.commonSave,
          tint: saveOn?.saved ?? false ? HaloColors.amber : null,
          // one saved before stays, and can be let go
          onTap: saveOn == null || (theirsKept && !saveOn.saved)
              ? null
              : () => dismiss(then: () => _toggleSaved(saveOn)),
        ),
      MenuAction(
        icon: Icons.copy_rounded,
        label: l10n.commonCopy,
        onTap: kept || copyWords.isEmpty || target.sticker != null
            ? null
            : () {
                dismiss();
                copySensitive(copyWords, kept: true);
                showHaloToast(context, l10n.commonCopied);
              },
      ),
      // more than this one: a tap on each row picks it
      if (!welcome)
        MenuAction(
          icon: Icons.check_circle_outline_rounded,
          label: l10n.selectStart,
          onTap: () {
            dismiss(now: true);
            _pick(target);
          },
        ),
      if (canTranslate)
        MenuAction(
          icon: Icons.translate_rounded,
          label: translation.shown(trKey, target.text)
              ? l10n.translateShowOriginal
              : l10n.translateAction,
          onTap: () => dismiss(
            then: () => askTranslate(context, translation, trKey, target.text),
          ),
        ),
      // the translate line's own menu, in rows of their
      // own here
      if (canTranslate)
        MenuAction(
          icon: Icons.all_inclusive_rounded,
          label: l10n.translateAlwaysChat,
          checked: translation.auto == true,
          onTap: () => dismiss(
            then: () async {
              try {
                await translation.setAuto(translation.auto != true);
              } catch (_) {}
            },
          ),
        ),
      if (canTranslate)
        MenuAction(
          icon: Icons.do_not_disturb_on_outlined,
          label: l10n.translateBarNever(langName(trOffer.seen)),
          onTap: () => dismiss(
            then: () => neverOffer(context, translation.hub, trOffer),
          ),
        ),
      // a sticker is not forwarded, copied or edited, and
      // a photo, a file or a voice note is not forwarded
      if (!welcome)
        MenuAction(
          icon: Icons.forward_rounded,
          label: l10n.chatForward,
          onTap:
              kept ||
                  !canForward(
                    text: target.text,
                    mediaPath: target.mediaPath,
                    filePath: target.filePath,
                    sticker: target.sticker != null,
                  )
              ? (fileOn
                    ? () {
                        dismiss(now: true);
                        forwardFile(context, fileAt.filePath!, fileAt.fileName);
                      }
                    : null)
              : () {
                  // a sheet takes its place: no copy over it
                  dismiss(now: true);
                  _forwardMessage(target);
                },
        ),
      MenuAction(
        icon: Icons.download_rounded,
        label: l10n.fileSaveToDevice,
        // in an album, the one held. nothing kept to this
        // chat leaves it
        onTap:
            kept ||
                shareOn == null ||
                _keptHere(shareOn) ||
                shareOn.filePath == null ||
                shareOn.fileName == null ||
                isVoiceName(shareOn.fileName)
            ? null
            : () {
                dismiss(now: true);
                saveReceivedFile(context, shareOn.filePath!, shareOn.fileName);
              },
      ),
      // a tap opens a file, so sharing it lives here. an
      // app installer is only ever saved
      if (canShareOut)
        MenuAction(
          icon: Icons.ios_share_rounded,
          label: l10n.commonShare,
          apart: true,
          onTap:
              kept ||
                  !canShare ||
                  knownInstaller(shareOn.filePath!, shareOn.fileName)
              ? null
              : () {
                  dismiss(now: true);
                  lockState.hold(
                    () =>
                        shareFileOut(shareOn.filePath!, name: shareOn.fileName),
                  );
                },
        ),
      // the way out: another app sees the file, and the note says so
      MenuAction(
        icon: Icons.open_in_new_rounded,
        label: l10n.fileOpenWith,
        apart: true,
        aside: l10n.fileOpenWithNote,
        onTap:
            kept ||
                !canShare ||
                knownInstaller(shareOn.filePath!, shareOn.fileName)
            ? null
            : () {
                dismiss(now: true);
                openFileOutside(context, shareOn.filePath!, shareOn.fileName);
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
        label: going ? l10n.chatStopSending : l10n.chatUnsend,
        onTap: target.direction != 'out'
            ? null
            : () {
                dismiss(now: true);
                // a photo or file still on its way stops here
                // and the other side drops what it has. an
                // album goes back whole
                if (album != null) {
                  going ? _stopAlbum(album) : _unsendAlbum(album);
                } else if (going) {
                  _stopSending(target);
                } else {
                  _unsendMessage(target);
                }
              },
      ),
    ];

    // a computer: the small menu at the mouse, nothing lifted or dimmed
    if (onDesktop) {
      void done({bool now = false, VoidCallback? then}) => then?.call();
      final reacts = !welcome && _canReact;
      await showDeskMenu<void>(
        bubbleContext,
        label: l10n.a11yMessageActions,
        note: theirsKept ? l10n.chatShotsMenuNote : null,
        reactions: !reacts
            ? null
            : DeskReactions(
                emojis: kQuickReactions,
                selected: target.reactions[''],
                onPick: (e) {
                  final added = reactOn.reactions[''] != e;
                  _toggleReaction(reactOn, e);
                  if (added) _flashReaction(reactOn);
                },
              ),
        groups: (_) => deskGroupsOf([
          // the phone's bar has reply beside the reactions
          if (reacts)
            MenuAction(
              icon: Icons.reply_rounded,
              label: l10n.chatReply,
              onTap: () {
                if (!lockGuard.isLocked()) _replyWith(anchor);
              },
            ),
          ...actionsWith(done),
        ]),
      );
      return;
    }

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
    late final void Function({bool now}) shut;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
      menuRemoved(shut);
      // the copy has landed on the row: the row shows again at once
      if (menuMayTouch) setState(() => _liftedUid = null);
      final run = landed;
      landed = null;
      if (menuMayTouch) run?.call();
    }

    // [then] runs once the copy is back on the row, so a change that moves
    // the row (a reaction's room, the reply bar) does not move it under
    // the copy
    void dismiss({bool now = false, VoidCallback? then}) {
      if (gone && !now) return;
      if (!gone) landed = then;
      gone = true;
      menuFolding(shut);
      unguard?.call();
      unguard = null;
      if (now || !menuMayTouch) {
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
          child: MenuScope(
            onDismiss: dismiss,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MenuCloser(
                    onDismiss: dismiss,
                    child: MenuBackdrop(closing: closing),
                  ),
                ),
                // the offset is from the left edge, in either direction
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  width: bubbleSize.width,
                  // a copy of the bubble: heard once, on the chat
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0.0,
                          end: still || closing ? 0.0 : 1.0,
                        ),
                        duration: kHouseTime,
                        curve: kHouseCurve,
                        child: Material(
                          type: MaterialType.transparency,
                          child: _Bubble(
                            msg: target,
                            newestOut: switch (_newestOut()) {
                              final n? =>
                                identical(target, n) ||
                                    (album?.present.any(
                                          (x) => identical(x, n),
                                        ) ??
                                        false),
                              null => false,
                            },
                            album: album,
                            translation: _translation,
                            transcripts: _transcripts,
                            plainLinks: _plainLinks,
                            waitsAccept: _waitsAccept,
                          ),
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
                        emojis: kQuickReactions,
                        selected: target.reactions[''],
                        onPick: (e) => dismiss(
                          then: () {
                            final added = reactOn.reactions[''] != e;
                            _toggleReaction(reactOn, e);
                            if (added) _flashReaction(reactOn);
                          },
                        ),
                        // no reply bar or keyboard over the lock
                        onReply: () => dismiss(
                          then: () {
                            if (!lockGuard.isLocked()) _replyWith(anchor);
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
                      note: theirsKept ? l10n.chatShotsMenuNote : null,
                      actions: actionsWith(dismiss),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(entry);
    shut = dismiss;
    menuOpened(shut);
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
          when: DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
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
    // up on the files service already: it comes down with the row
    await appState.takeDropBackOf(uid);
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
      line: l10n.chatItDisappearsWithNoShown,
      yes: l10n.chatUnsend,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (confirm != true) return;
    if (mounted) setState(() => m.removing = true);
    // it burns, then its row folds (LeaveFold); pulled sooner, it pops
    await Future.delayed(kLeaveGone);
    await appState.takeDropBackOf(m.msgUid!);
    await session.deleteMessage(m.msgUid!);
    if (mounted) setState(() => _messages.remove(m));
    // the home row still previews the message just unsent
    unawaited(appState.refreshContacts());
    await _sendUnsendFrame(m.msgUid!);
  }

  // theirs, photo or video, sent protected: kept to this chat
  static bool _keptHere(_Msg m) =>
      m.secure &&
      m.direction == 'in' &&
      (m.mediaPath != null || m.filePath != null);

  // an album taken back whole, ours only: each item's row and file go
  // here and each is unsent there, so a phone without albums drops them all
  Future<void> _unsendAlbum(AlbumRun<_Msg> run) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final confirm = await showConfirmSheet(
      context,
      title: l10n.albumUnsendTitle,
      line: l10n.chatAlbumItDisappearsWithNoShown,
      yes: l10n.chatUnsend,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (confirm != true) return;
    await _takeBackAlbum(run);
  }

  // stopped part way: what went is taken back with what had not. once any
  // of it reached them, that is an unsend, asked as one
  Future<void> _stopAlbum(AlbumRun<_Msg> run) async {
    if (run.present.any((x) => x.delivered)) return _unsendAlbum(run);
    await _takeBackAlbum(run);
  }

  Future<void> _takeBackAlbum(AlbumRun<_Msg> run) async {
    final ms = [
      for (final x in run.present)
        if (x.direction == 'out' && x.msgUid != null) x,
    ];
    if (ms.isEmpty) return;
    for (final x in ms) {
      if (x.sending) cancelMediaSend(x.msgUid!);
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
    for (final x in ms) {
      await appState.takeDropBackOf(x.msgUid!);
      await session.deleteMessage(x.msgUid!);
    }
    if (mounted) setState(() => _messages.removeWhere(ms.contains));
    unawaited(appState.refreshContacts());
    for (final x in ms) {
      await _sendUnsendFrame(x.msgUid!);
    }
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
      await session.assignUidIfMissing(widget.peerHaloId, m.came, uid);
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
      await session.assignUidIfMissing(widget.peerHaloId, m.came, uid);
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
      // a computer's timed answers on his phone count from now, read here
      if (!linkedRole && !lockGuard.isLocked()) {
        await appState.answersSeen(widget.peerHaloId);
      }
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
    final wantAll = _searching || _pagedOut;
    // a reload keeps the pages already scrolled in: a receipt, a reaction
    // or an edit must not drop what is being read
    final keepFrom = wantAll || !_loaded ? null : _oldestHeld();
    // opened on a message: the newest page, and the whole thread only when
    // it is further up than that
    final jumpTo = _didJump ? null : widget.jumpToUid;
    List<Map<String, Object?>> rows;
    if (wantAll) {
      rows = await session.messagesFor(widget.peerHaloId);
      _hasMore = false;
    } else if (keepFrom != null) {
      rows = List.of(
        await session.messagesFrom(
          widget.peerHaloId,
          rowid: keepFrom.rowid,
          at: keepFrom.when.millisecondsSinceEpoch,
        ),
      );
    } else {
      rows = List.of(
        await session.messagesPage(widget.peerHaloId, limit: _pageSize + 1),
      );
      _hasMore = rows.length > _pageSize;
      if (_hasMore) rows.removeAt(0);
      if (jumpTo != null && !rows.any((r) => r['msg_uid'] == jumpTo)) {
        rows = await session.messagesFor(widget.peerHaloId);
        _hasMore = false;
        _pagedOut = true;
      }
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
          DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(r)),
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
          album: AlbumTag.ofRow(r),
          spoiler: r['spoiler'] == 1,
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
      loaded.last.cameAt = (r['sent_at'] as num?)?.toInt();
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
      // the line sits over the run of rows at the end that all came since
      // the chat was left, at its first from them: everything under it is
      // new. one that came late and went up the thread is not under it
      final after = _unreadAfterRow;
      var start = loaded.length;
      while (after != null &&
          start > 0 &&
          !loaded[start - 1].welcome &&
          loaded[start - 1].rowid > after) {
        start--;
      }
      for (var i = start; i < loaded.length; i++) {
        if (loaded[i].direction != 'out') {
          _firstUnreadKey = _rowKey(loaded[i]);
          break;
        }
      }
      _unreadResolved = true;
      // what came since and went up the thread, above the newest read
      final read = start > 0 && !loaded[start - 1].welcome
          ? loaded[start - 1]
          : null;
      if (after != null && read != null) {
        try {
          await _earlierSince(after, read, loaded);
        } catch (e) {
          // the line is a help: a read that fails leaves the chat as it is
          dlog('earlier: not read (${e.runtimeType})');
        }
        if (!mounted) return;
      }
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
    unawaited(_restoreReply());
    // a stored draft that would not read is tried again
    final kept = _draftRows;
    if (_rowUnread && kept != null) unawaited(_readDraft(kept));
    // if a search is active, recompute matches against the fresh list.
    if (_searching && _query.isNotEmpty) {
      _onQueryChanged(_query);
    } else if (!_didJump && widget.jumpToUid != null) {
      _didJump = true;
      _jumpToUid(widget.jumpToUid!);
    } else if (snap) {
      _scrollToEnd(instant: true);
    }
    // a file still going from a screen left since is followed to its end
    unawaited(_followMediaSends());
    if (_earlier.count > 0) {
      await _pruneEarlier();
      _lookEarlierSoon();
    }
  }

  // what came in after row [after] and went up the thread, well above
  // [read], the newest row read: in the rows [loaded] or above them
  Future<void> _earlierSince(int after, _Msg read, List<_Msg> loaded) async {
    final bottom = read.when.millisecondsSinceEpoch;
    final first = loaded.where((m) => !m.welcome).firstOrNull;
    final rows = await session.messagesAfter(widget.peerHaloId, after);
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid == null || r['direction'] == 'out') continue;
      final at = rowWrittenAt(r);
      final id = (r['rowid'] as int?) ?? 0;
      final held = loaded.any((m) => m.msgUid == uid);
      // one held is up the thread when it sorts before the newest read
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
    if (_earlier.seenIn(_anchors) || went) setState(() {});
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
    await _jumpToPin(uid);
  }

  // the oldest row on screen that the database has, in the chat's order
  _Msg? _oldestHeld() {
    for (final m in _messages) {
      if (!m.welcome && m.rowid > 0) return m;
    }
    return null;
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
  // ---- several messages picked at once (select_parts.dart) ----

  // the rows picked, by the key of the row that draws each
  final Set<String> _picked = {};
  bool get _selecting => _picked.isNotEmpty;

  // a row picked or let go: an album or a set of files goes whole
  void _pick(_Msg m) {
    final lead = _albums.runOf(m)?.lead ?? m;
    final k = _rowKey(lead);
    setState(() => _picked.contains(k) ? _picked.remove(k) : _picked.add(k));
  }

  // what is picked, in the chat's order, every member of an album with it
  List<_Msg> get _pickedRows => [
    for (final x in _messages)
      if (_picked.contains(_rowKey(_albums.runOf(x)?.lead ?? x))) x,
  ];

  bool _leaves(_Msg x) => mayLeave(
    blocking: _shots.blocking,
    timed: x.burnSecs != null,
    marked: x.secure,
    spoiler: x.spoiler,
    hidden: session.isHidden(widget.peerHaloId),
  );

  Widget _selectBar() {
    final rows = _pickedRows;
    final all = rows.isNotEmpty && rows.every(_leaves) && !_isDev;
    final words =
        all &&
        rows.every(
          (x) =>
              x.sticker == null &&
              x.mediaPath == null &&
              x.filePath == null &&
              x.text.trim().isNotEmpty,
        );
    final files =
        all &&
        rows.every(
          (x) =>
              (x.mediaPath != null ||
                  canForwardFile(x.filePath, x.fileName, kept: false)) &&
              fileWaitOf(x.msgUid) == null,
        );
    return SelectBar(
      key: const ValueKey('select'),
      count: _picked.length,
      onClose: () => setState(_picked.clear),
      onCopy: words ? () => _copyPicked(rows) : null,
      onForward: words || files ? () => _forwardPicked(rows, words) : null,
    );
  }

  void _copyPicked(List<_Msg> rows) {
    copySensitive(rows.map((x) => x.text.trim()).join('\n\n'), kept: true);
    showHaloToast(context, l10n.commonCopied);
    setState(_picked.clear);
  }

  // words go to one chat's composer as one; photos and files go to it as
  // files, each read and never moved
  Future<void> _forwardPicked(List<_Msg> rows, bool words) async {
    final id = await pickWordsChat(
      context,
      title: l10n.chatForwardTo,
      empty: l10n.chatNoContactsToForward,
      dev: devForwardTarget,
    );
    if (id == null || !mounted) return;
    setState(_picked.clear);
    if (words) {
      final text = rows.map((x) => x.text.trim()).join('\n\n');
      if (id == widget.peerHaloId) return _takeWords(text);
      final route = await wordsRoute(id, text);
      if (route == null || !mounted) return;
      await Navigator.of(context).push(route);
      return;
    }
    await landFiles(context, id, session.container.id, [
      for (final x in rows)
        SharedCopy(
          x.mediaPath ?? x.filePath!,
          name: x.fileName ?? savedPhotoName(x.mediaPath!, x.when),
        ),
    ]);
  }

  // the shared page asked for a message of this chat: what is above the
  // chat goes, and the chat goes to it. an album's row stands for its own
  void _showAsked() {
    final v = showInChat.value;
    if (v == null || v.chat != widget.peerHaloId || !mounted) return;
    showInChat.value = null;
    final me = ModalRoute.of(context);
    Navigator.of(context).popUntil((r) => r == me || r.isFirst);
    final row = _messages.where((m) => m.msgUid == v.uid).firstOrNull;
    final lead = row == null ? null : _albums.runOf(row)?.lead;
    unawaited(_jumpToPin(lead?.msgUid ?? v.uid));
  }

  // a photo or video of the chat is one item, the oldest first: those the
  // viewer can swipe through. a marked one, a timed one and one still to
  // come stay out and open on their own
  bool _swipes(_Msg m) =>
      !m.preparing &&
      !m.secure &&
      !m.spoiler &&
      m.burnSecs == null &&
      m.sticker == null &&
      fileWaitOf(m.msgUid) == null &&
      (m.mediaPath != null ||
          (m.filePath != null &&
              !isVoiceName(m.fileName) &&
              fileShapeNow(m.filePath, m.fileName) == FileShape.video));

  // every photo and video of the chat in the viewer, from [m], with save,
  // forward and unsend where the chat lets them leave (viewer_rules.dart)
  bool _openChatMedia(BuildContext c, _Msg m, Object? tag) {
    if (!_swipes(m)) return false;
    final rows = [
      for (final x in _messages)
        if (_swipes(x)) x,
    ];
    final at = rows.indexOf(m);
    if (at < 0) return false;
    final hidden = session.isHidden(widget.peerHaloId);
    bool leaves(_Msg x) => mayLeave(
      blocking: _shots.blocking,
      timed: x.burnSecs != null,
      marked: x.secure,
      spoiler: x.spoiler,
      hidden: hidden,
    );
    openAlbum(
      c,
      [
        for (final x in rows)
          AlbumItem(
            x.mediaPath ?? x.filePath!,
            video: x.mediaPath == null,
            fileName: x.fileName,
            heroTag: identical(x, m) ? tag : null,
          ),
      ],
      start: at,
      secure: _shots.blocking,
      actions: ViewerActions(
        save: (i) {
          final x = rows[i];
          if (!leaves(x)) return null;
          final path = x.mediaPath ?? x.filePath!;
          return () => saveReceivedFile(
            context,
            path,
            x.fileName ?? savedPhotoName(path, x.when),
          );
        },
        forward: (i) {
          final x = rows[i];
          if (!leaves(x) || _isDev) return null;
          // a photo or video goes on as itself, read and never moved
          final path = x.mediaPath ?? x.filePath!;
          return () => forwardFile(
            context,
            path,
            x.fileName ?? savedPhotoName(path, x.when),
          );
        },
        unsend: (i) {
          final x = rows[i];
          if (x.direction != 'out' || x.sending || x.msgUid == null) {
            return null;
          }
          return () {
            Navigator.of(c).maybePop();
            final run = _albums.runOf(x);
            run != null ? _unsendAlbum(run) : _unsendMessage(x);
          };
        },
      ),
    );
    return true;
  }

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

  // the receiver in app/state.dart owns the engine inbox and routes every
  // message through _applyIncomingPayload. this only pulls new rows from the
  // db.
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
  Future<String> _wireText(String? uid, String cipher, int ident) =>
      wireWhenReady(
        ready: _torReadyToSend,
        kept: () async => uid == null || await session.messageExists(uid),
        send: () => _routeText(cipher, ident, uid),
      );

  // before the peer back-pairs, direct onion first so their drain runs the
  // back-pair flow, with the first-contact copy beside it (routeText)
  // [ident]: the identity the door sealed it on, and the one it goes on
  Future<String> _routeText(String cipher, int ident, [String? uid]) async {
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
        xpub ??= await peerXPubOf(widget.peerHaloId);
        if (xpub != null) _peerXPub = xpub;
        return xpub;
      },
      fc: appState.peerFcFor(widget.peerHaloId),
      pairRoute: await appState.pairRoute(
        widget.peerHaloId,
        backPaired: _backPaired,
      ),
      pairRead: await appState.pairRead(
        widget.peerHaloId,
        backPaired: _backPaired,
      ),
      viaFirst: (x, fc) => sendFirstContactNoted(ident, x, fc, cipher),
      viaRelay: (x) => Future(() => engine.nostrSend(ident, x, cipher)),
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
    if (_sealing > 0) return;
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
      // it goes again as quietly as it first went; a row that will not
      // say rings, as an older app does
      var silent = false;
      if (msg.msgUid case final u?) {
        try {
          silent = await session.sentSilent(u);
        } catch (e) {
          dlog('retry: silent not read (${e.runtimeType})');
        }
      }
      final String cipher;
      final int sealedOn;
      try {
        final wrapped = await wrapMessage(
          msg.text,
          msgUid: msg.msgUid,
          silent: silent,
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
        final sealed = await signalSeal(widget.peerHaloId, wrapped);
        cipher = sealed.cipher;
        sealedOn = sealed.ident;
      } catch (e) {
        // a linked device: its copies went from here, or its phone answers
        final out = deviceSealOutcome(e);
        if (out == 'ok' || out == 'parked') {
          // handed to the phone: it waits for the phone's copy
          await _finishTextSend(msg, out!);
          return;
        }
        if (!mounted) return;
        // waiting on their card: still going, as the first send has it
        if (e is StartingAfresh || e is KeyHeld) return;
        if (out != null) unawaited(_readPhoneOnly());
        setState(() {
          msg.sending = false;
          msg.failed = true;
          if (devKeyFailed(e)) _devKeyFailed = true;
        });
        return;
      }
      if (_devKeyFailed && mounted) setState(() => _devKeyFailed = false);
      handed = true;
      await Future<String>(() => _wireText(uid, cipher, sealedOn))
          .whenComplete(() {
            if (own) appState.releaseSend(uid);
          })
          .then((result) => _finishTextSend(msg, result));
    } finally {
      if (!handed && own) appState.releaseSend(uid);
    }
  }

  // the flame: a tap picks how long, and while one is set "Off" is on top.
  // the choice stays until it is changed here
  Future<void> _pickBurnDuration() async {
    final picked = await showBurnSheet(
      context,
      on: _ghost,
      secs: _burnSeconds,
      // an answer the phone sends lives an hour at least
      short: !_viaPhone,
    );
    if (picked == null || !mounted) return;
    final on = picked != kBurnOff;
    setState(() {
      if (on) _burnSeconds = picked;
      _ghost = on;
    });
    // kept with this chat alone
    unawaited(appState.saveChatBurn(widget.peerHaloId, on, _burnSeconds));
    // the draft takes the chat's new clock
    _keepDraft(clock: true);
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
      album: msg.album,
      spoiler: msg.spoiler,
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
      voice: isVoiceName(msg.fileName),
      voiceDisguised: msg.voiceDisguised,
      burnSeconds: msg.burnSecs,
      secure: msg.secure,
      replyTo: msg.replyTo,
      album: msg.album,
      spoiler: msg.spoiler,
      writtenAt: msg.when.millisecondsSinceEpoch,
    ).then((result) => _finishMediaSend(msg, result));
  }

  Future<void> _showStickers() async {
    // a sticker is no answer a computer hands the phone
    if (_viaPhone) {
      _sayMediaLater();
      return;
    }
    final pick = await showStickerSheet(
      context,
      container: session.container,
      // a gif goes as a photo: none in a request still waiting
      gifs: _mediaWaits ? null : appGifTabs(),
    );
    // the sheet hands focus back to the composer; the keyboard stays down
    FocusManager.instance.primaryFocus?.unfocus();
    if (pick == null || !mounted) return;
    // a found gif goes the way a gif from the phone goes: inside the
    // message, cleaned, never fetched again by anyone
    if (pick is GifPick || pick is PhoneGifPick) {
      if (_sayMediaLater()) return;
    }
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
  // what goes into the chat, in one sheet: the gallery, the phone's
  // files, and files already in this container's chats
  Future<void> _showAttachSheet() async {
    final most = await appState.fileLimitFor(widget.peerHaloId);
    final spoilers = await appState.spoilersFor(widget.peerHaloId);
    if (!mounted) return;
    final r = await showSendSheet(
      context,
      most: most,
      spoilers: spoilers,
      to: _isDev ? l10n.devName : _nickname ?? widget.peerHaloId,
      pickGallery: galleryPicksForSheet,
      pickFiles: filePicksForSheet,
      recent: () => recentFilesIn(
        session.peerDb(widget.peerHaloId),
        homeOf: sessionHomeOf,
      ),
      galleryLabel: l10n.chatGalleryShown,
      shortcuts: [
        // a computer has no camera to open
        if (!onDesktop)
          SendShortcut(
            (c) => Icon(Icons.photo_camera_outlined, color: c),
            l10n.chatCamera,
            HaloColors.amber,
            _openCamera,
          ),
        SendShortcut(
          (c) => Icon(Icons.videocam_outlined, color: c),
          l10n.chatVideo,
          HaloColors.rose,
          _pickAndSendVideo,
        ),
        SendShortcut(
          (c) => Icon(Icons.gif_box_outlined, color: c),
          l10n.chatGifFromPhoneShown,
          HaloColors.violet,
          _pickAndSendGif,
        ),
      ],
    );
    if (r == null) return;
    await _sendFromSheet(r);
  }

  // the sheet's picks, in the order chosen: photos and videos through the
  // preview, unless they go as files; files each as the file tile sends
  // one, the caption on the first. the pickers' copies go once done
  Future<void> _sendFromSheet(SendSheetResult r) async {
    try {
      if (!mounted || _requestLocked || _sayMediaLater()) return;
      // the sheet is the preview: one send, one caption, in the order
      // picked, with no second screen
      var caption = r.caption;
      for (final run in r.runs) {
        if (!mounted || lockState.locked) break;
        if (run.media) {
          if (_mediaWaits || _roomLeft <= 0) {
            showHaloToast(
              context,
              _mediaWaits
                  ? l10n.requestSenderMediaLater
                  : l10n.chatWaitingForThemTo,
            );
            break;
          }
          final items = await readGalleryPicks([
            for (final m in run.picks) m.source as XFile? ?? XFile(m.path),
          ], spoilers: r.spoilers);
          try {
            if (items.isEmpty || !mounted || !await _askBig(items)) break;
            await _sendPicked(MediaSendResult(items: items, caption: caption));
          } finally {
            await shredPickedImages([for (final m in items) ?m.video]);
          }
        } else {
          await _sendFileSet(
            [
              for (final f in run.picks)
                (
                  f.path,
                  f.media && f.from == SendTab.gallery
                      ? madeName(f.name, fallbackExt: f.video ? 'mp4' : 'jpg')
                      : f.name,
                ),
            ],
            caption,
            spoilers: r.spoilers,
          );
        }
        caption = '';
      }
    } finally {
      await r.release();
      await shredPicked(const []);
    }
  }

  // remembered in the container that holds the chat
  Future<void> _setDisguise(bool on) async {
    setState(() => _disguise = on);
    await appState.saveChatDisguise(widget.peerHaloId, on);
  }

  Future<void> _sendVoice(VoiceTake take) async {
    final srcPath = take.path;
    final making = take.making;
    // the note is not going: its take, and a disguise of it made or still
    // being made, shredded
    Future<void> drop([String? masked]) async {
      making?.cancel();
      await dropTake(srcPath, masked ?? take.masked);
    }

    // the chat went while the note was made: the raw voice goes, unsent
    if (!mounted || _requestLocked || _sayMediaLater()) {
      // one that will not go is swept at the next start
      drop().ignore();
      return;
    }
    if (!await File(srcPath).exists()) return drop();
    if (!mounted) return drop();
    if (_isDev && !await _ensureDevStarted()) return drop();
    final peer = widget.peerHaloId;
    // where the chat is as the note leaves: one hidden, brought back or
    // deleted while it is made keeps none of it
    final home = session.chatKey(peer);
    final bool wasAccepted;
    try {
      wasAccepted = await session.isAccepted(peer);
    } catch (e) {
      dlog('voice: chat not read (${e.runtimeType})');
      return drop();
    }
    // said wherever the person is once the lock is down, and only where
    // the chat is still there to see
    void say(String line) =>
        showHaloToastAnywhere(line, still: () => session.chatKey(peer) == home);
    // read after the start: an anonymous chat is disguised whatever the
    // note says
    final disguise = take.disguise || _devAnon;
    final msgUid = newMsgUid();
    final replyToUid = _takeQuote();
    // sent is sent: leaving the chat does not stop it. the lock does, and
    // nothing of it outlives the lock
    var locked = false;
    final unguard = lockGuard.closeOnLock(() {
      locked = true;
      making?.cancel();
    });
    _Msg? pending;
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

    try {
      var masked = take.masked;
      if (making != null) {
        // its bubble shows at once, waiting for its disguise
        final m = pending = _Msg(
          'out',
          '',
          DateTime.now(),
          sending: true,
          msgUid: msgUid,
          replyTo: replyToUid,
          fileName: kVoiceWav,
          voiceDisguised: true,
          burnSecs: _ghost ? _burnSeconds : null,
        )..making = making.progress;
        setState(() {
          _messages.add(m);
          _normaliseMessages();
          _status = '';
          _replyTo = null;
        });
        // the quote is answered: the kept draft lets it go too
        _keepDraft();
        _scrollToEnd();
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
      final String filePath;
      try {
        if (session.chatKey(peer) != home) throw StateError('moved');
        final mediaDir = await session.mediaDirOf(peer);
        filePath = '${mediaDir.path}/vn_$msgUid.wav';
      } catch (e) {
        dlog('voice: no media folder (${e.runtimeType})');
        unpend();
        await dropTake(srcPath, masked);
        return;
      }
      // the recorder's own file is the voice before any disguise: it is the
      // copy kept with the message, or it goes once the disguise is there
      final placed = await placeVoice(
        srcPath,
        filePath,
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
      if (locked) return lockedOut(null, placed: filePath);
      if (_requestPending && mounted) setState(() => _sentCount++);
      final msg =
          pending ??
          _Msg(
            'out',
            '',
            DateTime.now(),
            sending: true,
            msgUid: msgUid,
            replyTo: replyToUid,
            fileName: kVoiceWav,
            voiceDisguised: disguise,
            burnSecs: _ghost ? _burnSeconds : null,
            burnAt: null,
          );
      msg
        ..filePath = filePath
        ..making = null;
      if (mounted) {
        setState(() {
          if (!_messages.contains(msg)) _messages.add(msg);
          _normaliseMessages();
          _status = '';
          _replyTo = null;
        });
        // the quote is answered: the kept draft lets it go too
        _keepDraft();
        _scrollToEnd();
        HapticFeedback.lightImpact();
      }
      // from here a lock takes it off the screen as one still being made
      pending = msg;
      await _answerSupport();
      // what goes: opus to a phone that plays it, else the wav. the bubble
      // shows the wav until the opus copy is there, then that
      if (locked) return lockedOut(null, placed: filePath);
      // a lock under way stops the encode, and both files go
      final (wirePath, wireName) = await voiceForWire(
        filePath,
        opus: await appState.opusFor(peer),
        stop: () => locked,
      );
      if (wirePath != filePath) {
        voicePeaksSame(filePath, wirePath);
        final ms = await voiceFileMs(wirePath);
        if (ms != null) voiceLengthKnown(wirePath, ms);
        msg
          ..filePath = wirePath
          ..fileName = wireName;
        if (mounted) setState(() {});
        unawaited(voiceFileFree(filePath).then((_) => shredFile(filePath)));
      }
      if (locked) return lockedOut(null, placed: wirePath);
      // the bubble, the row and the wire all say when it was begun
      final writtenAt = msg.when.millisecondsSinceEpoch;
      var kept = false;
      try {
        kept = await appState.keepOwn(peer, () async {
          // a lock while it waited for a move: nothing is written
          if (locked) return false;
          return session.saveInChat(
            peer,
            home: home,
            msgUid: msgUid,
            wasAccepted: wasAccepted,
            writtenAt: writtenAt,
            replyTo: replyToUid,
            filePath: wirePath,
            fileName: wireName,
            voiceDisguised: disguise,
            burnAt: msg.burnAt,
            burnSecs: msg.burnSecs,
            sent: 0,
          );
        });
      } catch (e) {
        dlog('voice: row not kept (${e.runtimeType})');
      }
      if (!kept && locked) return lockedOut(null, placed: wirePath);
      if (!kept) {
        if (mounted) setState(() => _messages.remove(msg));
        await shredFile(wirePath);
        say(l10n.voiceNotSent);
        return;
      }
      // the home row moves up on what you sent too
      unawaited(appState.refreshContacts());
      // left while it was made: the screen showing the chat now hears of it
      if (!mounted) appState.chatChanged(peer);
      _sendChunkedMedia(
        path: wirePath,
        msgUid: msgUid,
        fileName: wireName,
        voice: true,
        voiceDisguised: disguise,
        burnSeconds: msg.burnSecs,
        replyTo: replyToUid,
        writtenAt: writtenAt,
      ).then((result) => _finishMediaSend(msg, result));
    } finally {
      unguard();
    }
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
  // straight out: a dialog on a 40kb photo is noise.
  // [asItIs]: a kind the send lane does not clean, which it says
  Future<bool> _confirmBigSend(int bytes, {bool asItIs = false}) async {
    final big = bytes >= 512 * 1024;
    if (!big) return true;
    if (!mounted) return false;
    final ok = await showConfirmSheet(
      context,
      title: l10n.chatSendThis,
      figure: appState.sendMode == 'private'
          ? l10n.chatOverTor(_humanBytes(bytes), _wireEstimate(bytes))
          : _humanBytes(bytes),
      line: asItIs
          ? '${l10n.chatBigFilesGoOut}\n\n${l10n.fileGoesAsItIs}'
          : l10n.chatBigFilesGoOut,
      yes: l10n.chatSendIt,
      keep: l10n.commonCancel,
      rose: false,
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    return ok;
  }

  // the in-app camera: a stripped photo or a clip goes through the send
  // preview as a pick does; the clip's private copy is shredded once it is
  // done with, sent or not
  Future<void> _openCamera() async {
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

  // src is a file this app can read: the picker's copy or a camera clip.
  // it is copied into the media folder, never read into memory.
  // true when it went. [caption]: the words under it
  Future<bool> _sendFileFrom(
    String src,
    String picked, {
    String caption = '',
  }) async {
    if (_requestLocked || _sayMediaLater()) return false;
    final ready = await _readyFile(src, picked);
    if (ready == null) return false;
    await _sendReady(ready, caption);
    return true;
  }

  // files picked together go as one bubble (file_stack.dart): each made
  // ready first, so a set never names a place nothing fills, then sent in
  // sets of up to kAlbumMax with the caption on the first. to someone who
  // has not accepted yet each goes alone
  Future<void> _sendFileSet(
    List<(String, String)> files,
    String caption, {
    // the photos among them marked as spoilers, by their path
    Set<String> spoilers = const {},
  }) async {
    if (files.isEmpty || _requestLocked || _sayMediaLater()) return;
    // one alone goes as a file always went
    if (files.length == 1) {
      await _sendFileFrom(files.first.$1, files.first.$2, caption: caption);
      return;
    }
    final ready = <_Ready>[];
    for (final (path, name) in files) {
      if (!mounted || lockState.locked) break;
      if (await _readyFile(path, name) case final r?) {
        ready.add(
          spoilers.contains(path)
              ? _Ready(r.uid, r.path, fileName: r.fileName, spoiler: true)
              : r,
        );
      }
    }
    // the lock came while they were made ready: none of it goes
    if (!mounted || lockState.locked) {
      for (final r in ready) {
        await shredFile(r.path);
      }
      return;
    }
    for (final x in albumPlan(
      ready,
      caption,
      alone: _requestPending,
      files: true,
    )) {
      if (!mounted) break;
      await _sendReady(x.item, x.caption, album: x.album);
    }
  }

  // a file made ready to go: checked, copied into the media folder under
  // its own uid and cleaned there. nothing shows or leaves yet; null when
  // it will not go, and the toast has said why
  Future<_Ready?> _readyFile(
    String src,
    String picked, {
    // its bubble's, when it shows before it is ready
    String? uid,
    // the big file's question was asked in the preview
    bool asked = false,
  }) async {
    final name = sentFileName(picked);
    final int size;
    try {
      size = await File(src).length();
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return null;
    }
    // an empty file would read as sent with nothing gone
    if (size == 0) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return null;
    }
    final most = await appState.fileLimitFor(widget.peerHaloId);
    if (!fileFits(size, most)) {
      if (mounted) showHaloToast(context, fileTooBigLine(size, most));
      return null;
    }
    final raw = (await readFileFactsFresh(src, name))?.raw ?? false;
    if (!asked &&
        !await _confirmBigSend(
          size,
          asItIs: !await sendLaneCleans(src, name),
        )) {
      return null;
    }
    final msgUid = uid ?? newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.peerHaloId);
    // its type only: the name it was given lives in the database
    final dest = File('${mediaDir.path}/f_$msgUid${typeLeaf(name)}');
    // a gallery video carries where, on what and when, like a photo, and a
    // picture sent as a file is cleaned like one sent as a photo. both are
    // told by their bytes and cleaned on our own copy by the one cleaner;
    // one that cannot be read through, or still reads as anything after,
    // is not sent. a raw picture is never walked as a video. the copy is
    // made and cleaned out of the media folder and only moved in clean. a
    // picture it cannot clean is drawn again as a clean jpeg, or goes as it
    // is, never asked about (copyForSend)
    final done = await copyForSend(src, dest.path, name: name, raw: raw);
    final at = done.path;
    if (at == null) {
      if (mounted) {
        showHaloToast(
          context,
          done.video ? l10n.chatCouldNotCleanThat : l10n.chatCouldNotReadThat,
        );
      }
      return null;
    }
    makeBlurSoon(at);
    // its glance ready before its bubble draws: no stand-in on our side
    if (mounted) await warmSentPreview(context, at, done.name);
    return _Ready(msgUid, at, fileName: done.name);
  }

  // a photo made ready the same way: cleaned of what the gallery's
  // re-encode copied across, and written under its own uid
  Future<_Ready?> _readyPhoto(Uint8List raw, {String? uid}) async {
    final bytes = await photoToSendOffUi(raw);
    if (bytes == null) {
      if (mounted) showHaloToast(context, l10n.cameraCouldNotStripThat);
      return null;
    }
    // the chat went while it was cleaned: nothing is written
    if (!mounted) return null;
    final msgUid = uid ?? newMsgUid();
    final mediaDir = await session.mediaDirOf(widget.peerHaloId);
    // a png, gif, webp or heic keeps its own kind, and its name says so
    final mediaFile = File('${mediaDir.path}/$msgUid.${pictureExt(bytes)}');
    if (!await writeMadeCopy(mediaFile, bytes)) {
      if (mounted) showHaloToast(context, l10n.cleanFreeSomeSpaceAnd);
      return null;
    }
    makeBlurSoon(mediaFile.path);
    // its glance ready before its bubble draws: no stand-in on our side
    if (mounted) await warmSentPreview(context, mediaFile.path, null);
    return _Ready(msgUid, mediaFile.path);
  }

  // a ready photo or file shown and sent. none to a stranger before they
  // accept (their side holds it), and to the dev chat a slot is taken
  // before any await so a second send cannot slip past
  Future<void> _sendReady(
    _Ready ready,
    String caption, {
    bool? secure,
    AlbumTag? album,
    // its bubble, shown on send while it was made ready
    _Msg? shown,
  }) async {
    void drop() {
      if (shown != null && mounted) {
        setState(() => _messages.remove(shown));
      }
    }

    if (_isDev && !await _ensureDevStarted()) {
      await shredFile(ready.path);
      drop();
      return;
    }
    if (_requestLocked || _sayMediaLater()) {
      await shredFile(ready.path);
      drop();
      return;
    }
    if (_requestPending) setState(() => _sentCount++);
    final isFile = ready.fileName != null;
    final msgUid = ready.uid;
    // read it once: the toggle is cleared below and the save reads it after.
    // a file goes protected only when asked for in the preview
    final wantSecure = shown?.secure ?? secure ?? (!isFile && _secureNext);
    // a few photos at once: the first one answers
    final replyToUid = shown == null ? _takeQuote() : shown.replyTo;
    final msg =
        shown ??
        _Msg(
          'out',
          caption,
          DateTime.now(),
          sending: true,
          msgUid: msgUid,
          replyTo: replyToUid,
          burnSecs: _ghost ? _burnSeconds : null,
          burnAt: null,
          secure: wantSecure,
          album: album,
          spoiler: ready.spoiler,
        );
    setState(() {
      msg
        ..mediaPath = isFile ? null : ready.path
        ..filePath = isFile ? ready.path : null
        ..fileName = ready.fileName
        ..preparing = false;
      if (!_messages.contains(msg)) _messages.add(msg);
      _normaliseMessages();
      _status = '';
      if (shown == null) _replyTo = null;
    });
    // the quote is answered: the kept draft lets it go too
    if (shown == null) _keepDraft();
    if (shown == null) _scrollToEnd();
    HapticFeedback.lightImpact();
    await _answerSupport();
    await session.saveMessage(
      widget.peerHaloId,
      'out',
      msg.text,
      msgUid: msgUid,
      replyTo: replyToUid,
      mediaPath: msg.mediaPath,
      filePath: msg.filePath,
      fileName: msg.fileName,
      burnAt: msg.burnAt,
      burnSecs: msg.burnSecs,
      sent: 0,
      secure: wantSecure,
      album: msg.album,
      spoiler: msg.spoiler,
      // the time its bubble shows, kept by a resend after a restart
      writtenAt: msg.when.millisecondsSinceEpoch,
    );
    unawaited(appState.refreshContacts());
    if (wantSecure && mounted) setState(() => _secureNext = false);
    unawaited(
      _sendChunkedMedia(
        path: ready.path,
        msgUid: msgUid,
        caption: msg.text,
        fileName: ready.fileName,
        burnSeconds: msg.burnSecs,
        secure: wantSecure,
        replyTo: replyToUid,
        album: msg.album,
        spoiler: msg.spoiler,
        writtenAt: msg.when.millisecondsSinceEpoch,
      ).then((r) => _finishMediaSend(msg, r)),
    );
  }

  // what the send preview gave back. its bubbles show at once, waiting,
  // as albums of up to kAlbumMax with the caption on the first; then each
  // item is made ready in its order. one that will not go is taken out and
  // the rest counted again before anything is saved or sent, so an album
  // never names a place nothing fills. to someone who has not accepted yet
  // each goes on its own, as the slots they may hold count
  Future<void> _sendPicked(MediaSendResult r) async {
    if (r.items.isEmpty || !mounted) return;
    // his chat starts before anything of it shows
    if (_isDev && !await _ensureDevStarted()) return;
    if (!mounted) return;
    final alone = _requestPending;
    final plan = albumPlan(r.items, r.caption, alone: alone);
    final reply = _takeQuote();
    final now = DateTime.now().millisecondsSinceEpoch;
    final waiting = [
      for (final (k, go) in plan.indexed)
        _Msg(
          'out',
          go.caption,
          // a millisecond apart, so they keep their order
          DateTime.fromMillisecondsSinceEpoch(now + k),
          sending: true,
          msgUid: newMsgUid(),
          replyTo: k == 0 ? reply : null,
          burnSecs: _ghost ? _burnSeconds : null,
          secure: r.secure,
          album: go.album,
          spoiler: go.item.spoiler,
        )..preparing = true,
    ];
    setState(() {
      _messages.addAll(waiting);
      _normaliseMessages();
      _status = '';
      _replyTo = null;
    });
    // the quote is answered: the kept draft lets it go too
    _keepDraft();
    _scrollToEnd();
    final ready = <(_Msg, _Ready)>[];
    for (final (k, go) in plan.indexed) {
      if (!mounted) break;
      final m = waiting[k];
      final v = go.item.video;
      final one = v != null
          ? await _readyFile(
              v.path,
              madeVideoName(v.name),
              uid: m.msgUid,
              asked: true,
            )
          : await _readyPhoto(go.item.photo!, uid: m.msgUid);
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
      final again = albumPlan(
        [for (final (m, _) in ready) m],
        r.caption,
        alone: alone,
      );
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
      await _sendReady(x, m.text, shown: m);
    }
  }

  // the slots the dev chat has left before his first word: kDevCap in all.
  // a stranger's request takes none (_mediaWaits)
  int get _roomLeft =>
      _requestPending && !_vouched && _isDev ? kDevCap - _sentCount : kPickMax;

  // a big file's question, asked over the preview before it closes
  Future<bool> _askBig(List<PickedMedia> items) async {
    var bytes = 0;
    for (final m in items) {
      final v = m.video;
      if (v == null) continue;
      try {
        bytes += await File(v.path).length();
      } catch (_) {
        // one that cannot be read is told so when it is made ready
      }
    }
    return _confirmBigSend(bytes);
  }

  // the send preview: null when the person backed out. what it was handed
  // goes at once when it closes with nothing sent: a lock or a session
  // switch that takes it never leaves a video copy for the boot sweep
  Future<MediaSendResult?> _preview(
    List<PickedMedia> items, [
    Future<List<PickedMedia>> Function()? more,
  ]) async {
    if (!mounted) return null;
    final room = _roomLeft;
    if (_mediaWaits || room <= 0) {
      for (final m in items) {
        if (m.video case final v?) unawaited(shredPickedImages([v]));
      }
      showHaloToast(
        context,
        _mediaWaits ? l10n.requestSenderMediaLater : l10n.chatWaitingForThemTo,
      );
      return null;
    }
    // a phone before spoilers would show one plain: no choice then
    final spoilers = await appState.spoilersFor(widget.peerHaloId);
    if (!mounted) return null;
    return Navigator.of(context).push<MediaSendResult?>(
      haloRoute<MediaSendResult?>(
        // holdSecure stays false here: the chat's own screenshot block
        // (ChatShots.blocking) is wired in at the merge with the
        // screenshots branch
        MediaSendScreen(
          items: items,
          addMore: more,
          spoilers: spoilers,
          secure: _secureNext,
          max: room,
          beforeSend: _askBig,
          onGone: (videos) => unawaited(shredPickedImages(videos)),
        ),
      ),
    );
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
    AlbumTag? album,
    bool spoiler = false,
    // when its row was written
    required int writtenAt,
  }) async {
    // a quiet session keeps it here: it waits, and nothing leaves
    if (sessionQuiet || appState.everydayHeld) return 'parked';
    // its verdict is _finishMediaSend's, which lets go of the count; a send
    // that throws lets go of it here
    _ownSends[msgUid] = (_ownSends[msgUid] ?? 0) + 1;
    try {
      return await sendChunkedMediaTo(
        peerId: widget.peerHaloId,
        peerOnion: widget.peerOnion,
        peerXPub:
            _peerXPub ?? (widget.peerXPub.isEmpty ? null : widget.peerXPub),
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
        album: album,
        spoiler: spoiler,
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
    } catch (e) {
      _ownSendDone(msgUid);
      rethrow;
    }
  }

  void _ownSendDone(String? uid) {
    final n = uid == null ? null : _ownSends[uid];
    if (n != null && n > 1) {
      _ownSends[uid!] = n - 1;
    } else if (n != null) {
      _ownSends.remove(uid);
    }
  }

  Future<void> _finishMediaSend(_Msg msg, String result) async {
    try {
      await _drawMediaVerdict(msg, result);
    } finally {
      final uid = msg.msgUid;
      _ownSendDone(uid);
      // another send may have it by now, the outbox's or one it lost to:
      // followed like one this screen did not start
      if (result != 'ok' && uid != null) unawaited(_followMediaSends());
    }
  }

  Future<void> _drawMediaVerdict(_Msg msg, String result) async {
    // another sender already has this one; its verdict comes later. a
    // cancelled one has no row left to finish.
    if (result == 'busy' || result == 'cancelled') return;
    if (msg.msgUid != null) _seenGoing.remove(msg.msgUid);
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
      // an album's item takes the clock the album already has
      msg.burnAt = await session.setMsgBurnAt(msg.msgUid!, ba);
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
    final later = dropTryLater(result) || dropDayDone(result);
    if (dropTryLater(result)) showHaloToast(context, l10n.fileServerTryLater);
    if (dropDayDone(result)) showHaloToast(context, l10n.fileDayLimit);
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
          !held &&
          !later) {
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
    // send raw through the image path: Image.memory animates gifs by the bytes,
    // the name follows the bytes.
    await _sendOneImage(clean, '');
  }

  Future<void> _sendOneImage(Uint8List raw, String caption) async {
    // first, so a photo that is dropped spends no request slot
    if (_requestLocked || _sayMediaLater()) return;
    final ready = await _readyPhoto(raw);
    if (ready != null) await _sendReady(ready, caption);
  }

  // its own tile as well: without android's photo picker the gallery is
  // photos only, as a mixed pick there is the file browser. the clip goes
  // the file way, which strips it and copies it out of the picker's cache.
  Future<void> _pickAndSendVideo() async {
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
    // held for their answer (an accept) is no wait on tor
    return valveWaitFrom(
      oldest,
      awaitsAnswer: signalSession.awaitsAnswer(widget.peerHaloId),
      answeredAtMs: signalSession.answeredAt(widget.peerHaloId),
    );
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
    if (url == null ||
        _previewBusy ||
        sessionQuiet ||
        appState.everydayHeld ||
        _plainLinks) {
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

  // [silent]: held send, the far side posts it without sound
  Future<void> _send({bool silent = false}) async {
    if (onDesktop && !_tray.isEmpty && !(_devOpening?.busy ?? false)) {
      _composerFocus.requestFocus();
      return _sendTray();
    }
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || (_devOpening?.busy ?? false)) return;
    // a computer: the next words go straight on, the send button's click
    // took the field's focus
    if (onDesktop) _composerFocus.requestFocus();
    await _sendBody(text, silent: silent);
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
    bool silent = false,
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
    final before = _sendTurn;
    final turn = Completer<void>();
    _sendTurn = turn.future;
    var handed = false;
    try {
      final replyToUid = _takeQuote();
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
      void sealing(bool on) => _sealing += on ? 1 : -1;

      setState(() {
        _messages.add(msg);
        _normaliseMessages();
        sealing(true);
        _status = '';
        _replyTo = null;
        if (typed) _pendingPreview = null;
      });
      if (typed) _msgCtrl.clear();
      // the quote is answered: the kept draft lets it go too
      _keepDraft();
      _scrollToEnd();
      // the sheet or the card already fired it
      if (typed) HapticFeedback.lightImpact();

      try {
        // inside, so a throw here settles the row and the count too
        await _answerSupport();
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
        // its retries go as quietly
        if (silent) await session.markSilent(msgUid);
      } catch (e) {
        // a throw must not leave it counted: that holds the auto retry
        // until the chat is reopened
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
      final int sealedOn;
      try {
        // a fresh session is an opener whatever the history: the far side
        // may have let us go and its gate asks again
        final fresh = !await hasSessionWith(widget.peerHaloId);
        // an answer the phone sends carries none: his never do
        if (!_viaPhone && (_recvCount == 0 || fresh)) {
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
          silent: silent,
        );
        // an opener goes again as these very words (sendOpenersAgain)
        if (!_backPaired) {
          await session.keepOpenerWire(msgUid, wrapped).catchError((Object e) {
            dlog('send: opener not kept (${e.runtimeType})');
          });
        }
        await before;
        final prev = _encryptGate;
        final gate = Completer<void>();
        _encryptGate = gate.future;
        try {
          await prev;
          final sealed = await signalSeal(widget.peerHaloId, wrapped);
          cipher = sealed.cipher;
          sealedOn = sealed.ident;
        } finally {
          gate.complete();
        }
      } catch (e) {
        // a linked device: its copies went from here, or its phone answers
        final out = deviceSealOutcome(e);
        if (out == 'ok' || out == 'parked') {
          mounted ? setState(() => sealing(false)) : sealing(false);
          await _finishTextSend(msg, out!);
          return;
        }
        // no session yet, and a hello of mine waits for their answer: it
        // waits with it, no failed send. the outbox sends it once they answer
        final wait = out == null && e is! StartingAfresh && e is! KeyHeld
            ? await appState.helloWaitOf(widget.peerHaloId)
            : kNoHelloWait;
        if (!mounted) return;
        if (out != null) unawaited(_readPhoneOnly());
        setState(() {
          sealing(false);
          // one waiting on their card after a restore is no broken session
          // and no failed send: it stays going, and the outbox sends it
          // once their card is here
          if (e is StartingAfresh || e is KeyHeld) return;
          if (wait.waits) {
            msg.sending = false;
            msg.parked = true;
            _helloWait = wait;
            return;
          }
          msg.sending = false;
          msg.failed = true;
          if (slot) _sentCount--;
          if (devKeyFailed(e)) {
            _devKeyFailed = true;
          } else if (out == null) {
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
      Future<String>(() => _wireText(msgUid, cipher, sealedOn))
          .whenComplete(() => appState.releaseSend(msgUid))
          .then((result) => _finishTextSend(msg, result));
    } finally {
      if (!handed) appState.releaseSend(msgUid);
      // one that ended early still lets the next go only after the one
      // before it
      unawaited(before.whenComplete(turn.complete));
    }
  }

  // the keyboard needs no scroll: the reversed list keeps its bottom edge,
  // so a reader keeps their place

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
    final rows = _draftRows;
    if (rows != null && !_rowUnread) {
      final d = heldDraft(rows.container, widget.peerHaloId, group: false);
      if (d == null && _msgCtrl.text.trim().isNotEmpty) {
        // sent from a copy over it, or its timer ran out while a page was
        // on top: gone here too, its row with it
        _timedDraftGone();
        unawaited(dropDraft(rows, widget.peerHaloId, group: false));
      } else {
        final draft = d?.text ?? '';
        if (draft.trim() != _msgCtrl.text.trim()) _takeDraft(draft);
      }
    }
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
    // the flag comes off here and not only in dispose: a screen deactivated
    // and never disposed would keep the whole app from screenshots
    _shotsHold.release();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _shotsHold.want(_shots.blocking, now: true);
  }

  // theirs, in a chat that blocks: not copied, forwarded, shared, saved
  // or opened elsewhere (shotsKeeps)
  bool _keeps(_Msg m) =>
      shotsKeeps(blocking: _shots.blocking, mine: m.direction == 'out');

  Future<void> _loadShots() async {
    if (_isDev || widget.support) return;
    final ChatShots s;
    try {
      s = await session.peerDb(widget.peerHaloId).shotsOf(widget.peerHaloId);
    } catch (e) {
      dlog('shots: not read (${e.runtimeType})');
      return;
    }
    if (!mounted) return;
    // their changes are paced: a phone flipping fast cannot flash this one
    _shotsHold.want(s.blocking);
    final was = _shots;
    if (s.on == was.on &&
        s.can == was.can &&
        s.by == was.by &&
        s.when == was.when &&
        s.blocked == was.blocked) {
      return;
    }
    setState(() => _shots = s);
  }

  Future<void> _loadPqLine() async {
    if (_isDev || widget.support || _pqAt != null) return;
    final at = await appState.pqLineAt(widget.peerHaloId);
    if (!mounted || at == null) return;
    setState(() => _pqAt = at);
  }

  // the line where this chat went over to post-quantum, placed as the
  // screenshot line is
  Widget? _pqLineAt(int ix, {required bool below}) {
    final when = _pqAt;
    if (when == null || when <= 0 || _messages.isEmpty) return null;
    if (!_lineHere(ix, DateTime.fromMillisecondsSinceEpoch(when), below)) {
      return null;
    }
    return ShotsLine(
      key: const ValueKey('pq-line'),
      on: true,
      icon: Icons.enhanced_encryption_outlined,
      text: l10n.chatNowPostQuantum,
    );
  }

  Future<void> _flipShots() async {
    if (!_shots.peerCan) return;
    final on = !_shots.on;
    // the switch moves on the tap; the line and the flag follow the write
    setState(
      () => _shots = ChatShots(
        on: on,
        at: _shots.at,
        can: _shots.can,
        by: kShotsByMe,
        when: DateTime.now().millisecondsSinceEpoch,
        blocked: _shots.blocked,
        quiet: _shots.quiet,
        known: _shots.known,
      ),
    );
    _shotsHold.want(_shots.blocking, now: true);
    await appState.setChatShots(widget.peerHaloId, on);
    await _loadShots();
  }

  // where the block last changed: over the first row since, or under the
  // newest one when nothing came after it. an album's member is drawn by
  // its lead, so the line goes with the lead's row
  Widget? _shotsLineAt(int ix, {required bool below}) {
    final s = _shots;
    if (s.by == kShotsByNone || s.when <= 0 || _messages.isEmpty) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(s.when);
    if (!_lineHere(ix, at, below)) return null;
    return ShotsLine(
      key: const ValueKey('shots-line'),
      on: s.on,
      text: shotsLineText(
        on: s.on,
        mine: s.by == kShotsByMe,
        name: _nickname ?? widget.peerHaloId,
      ),
    );
  }

  // whether a line at [at] falls by row [ix]: an album's member is drawn by
  // its lead, so the line goes with the lead's row
  bool _lineHere(int ix, DateTime at, bool below) {
    final run = _albums.runOf(_messages[ix]);
    return run == null
        ? _shotsLineBy(ix, at, below: below)
        : run.present.any(
            (x) => _shotsLineBy(
              _messages.lastIndexWhere((m) => identical(m, x)),
              at,
              below: below,
            ),
          );
  }

  // where a heal rebuilt their session, or their verified device list
  // moved: a quiet line where it happened, as the screenshot line falls.
  // under the newest row, the wait for their update after a restore here
  List<Widget> _healLinesAt(int ix, {required bool below}) {
    if (_messages.isEmpty) return const [];
    final name = _nickname ?? widget.peerHaloId;
    return [
      for (final l in _healLines)
        if (_lineHere(ix, DateTime.fromMillisecondsSinceEpoch(l.at), below))
          ShotsLine(
            key: ValueKey('heal-line-${l.at}'),
            on: true,
            icon: isDeviceLine(l.kind)
                ? Icons.devices_outlined
                : Icons.verified_user_outlined,
            text: switch (l.kind) {
              kHealLineRestored => l10n.chatHealRestored(name),
              kDeviceLineLinked => l10n.chatDeviceLinked(name),
              kDeviceLineRemoved => l10n.chatDeviceRemoved(name),
              kDeviceLineUnchecked => l10n.chatDeviceListUnchecked(name),
              _ => l10n.chatHealNewSession(name),
            },
          ),
      if (below && _pausedForUpdate && ix == _messages.length - 1)
        ShotsLine(
          key: const ValueKey('heal-paused'),
          on: true,
          icon: Icons.system_update_outlined,
          text: l10n.chatNeedsUpdateToChat(name),
        ),
    ];
  }

  // whether the line falls over row [ix], or under it
  bool _shotsLineBy(int ix, DateTime at, {required bool below}) {
    if (ix < 0) return false;
    final m = _messages[ix];
    if (below) return ix == _messages.length - 1 && m.when.isBefore(at);
    if (m.when.isBefore(at)) return false;
    return ix == 0 ? !_hasMore : _messages[ix - 1].when.isBefore(at);
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

  // the thread's albums, read again each time the thread is drawn
  AlbumIndex<_Msg> _albums = _indexAlbums(const []);

  static AlbumIndex<_Msg> _indexAlbums(Iterable<_Msg> rows) => AlbumIndex<_Msg>(
    rows,
    tag: (m) => m.album,
    written: (m) => m.when.millisecondsSinceEpoch,
    owner: (m) => m.direction,
    // a photo or a video; one of theirs whose file could not be kept
    // still holds its place
    media: (m) =>
        m.sticker == null &&
        (m.preparing ||
            m.mediaPath != null ||
            (m.filePath != null &&
                !isVoiceName(m.fileName) &&
                fileShapeNow(m.filePath, m.fileName) == FileShape.video) ||
            (m.direction == 'in' && m.filePath == null)),
    file: _inFileSet,
  );

  // a row a set of files holds: a file, never a voice note, a sticker or
  // words alone
  static bool _inFileSet(_Msg m) =>
      m.sticker == null && m.fileName != null && !isVoiceName(m.fileName);

  // one row standing for a whole album: the caption of its first item, the
  // send state of all of it, its reactions, and the earliest clock
  static _Msg _albumFace(AlbumRun<_Msg> run) {
    final ms = run.present;
    final a = run.anchor;
    final media = a.mediaPath ?? a.filePath ?? '';
    String? replyTo;
    for (final x in ms) {
      replyTo ??= x.replyTo;
    }
    // a set of files is no picture: its rows draw each file
    final files = run.tag.files;
    final face = _Msg(
      a.direction,
      run.caption((x) => x.text),
      a.when,
      msgUid: a.msgUid,
      replyTo: replyTo,
      secure: ms.any((x) => x.secure),
      sending: ms.any((x) => x.sending),
      pinned: ms.any((x) => x.pinned),
      mediaPath: files ? null : media,
      filePath: files ? a.filePath : null,
      fileName: files ? a.fileName : null,
      saved: ms.any((x) => x.saved),
      delivered: ms.every((x) => x.delivered),
      viaDev: a.viaDev,
      album: a.album,
      reactions: albumReactions([for (final x in ms) x.reactions]),
    );
    face
      ..cameAt = a.cameAt
      ..rowid = a.rowid
      ..failed = ms.any((x) => x.failed)
      ..parked = ms.any((x) => x.parked)
      ..notSent = ms.any((x) => x.notSent)
      ..gaveUp = ms.any((x) => x.gaveUp)
      ..removing = ms.any((x) => x.removing)
      ..burnedAway = ms.any((x) => x.burnedAway)
      ..fresh = ms.any((x) => x.fresh)
      ..burnSecs = a.burnSecs
      ..burnUnseen = ms.any((x) => x.burnUnseen)
      ..burnAt = albumBurnAt([for (final x in ms) x.burnAt]);
    return face;
  }

  // the member a reaction from this phone goes on: the one already holding
  // it, or the album's first
  static _Msg _reactOn(AlbumRun<_Msg> run) {
    for (final x in run.present) {
      if (x.reactions.containsKey('')) return x;
    }
    return run.anchor;
  }

  // the newest of ours still in the thread: the one bubble that spells
  // Delivered. found from the end, so it is near
  _Msg? _newestOut() {
    for (var j = _messages.length - 1; j >= 0; j--) {
      final x = _messages[j];
      if (x.direction == 'out' && !x.removing && !x.welcome) return x;
    }
    return null;
  }

  Widget _buildRow(BuildContext c, int i, bool searchActive) {
    final ix = _messages.length - 1 - i;
    final row = _messages[ix];
    // one alone still made ready shows as a waiting tile of its own
    final run =
        _albums.runOf(row) ??
        (row.preparing
            ? (AlbumRun<_Msg>('', const AlbumTag('', 1, 0), row, 0)
                ..slots[0] = row)
            : null);
    // drawn by its album's first row
    if (run != null && !identical(run.lead, row)) {
      return const SizedBox.shrink();
    }
    final m = run == null ? row : _albumFace(run);
    // an empty control message that leaked through would be a blank bubble.
    // a sticker this version does not have may have no text at all. a voice
    // note still being disguised has no file yet
    if (run == null &&
        m.text.isEmpty &&
        m.sticker == null &&
        m.mediaPath == null &&
        m.filePath == null &&
        m.making == null &&
        m.preview == null) {
      return const SizedBox.shrink();
    }
    final members = run?.present ?? [row];
    final making = members.any((x) => x.preparing);
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
        } else if (_heldBack(original)) {
          // a stranger's file, its name and caption too, waits for the accept
          quoted = l10n.requestReceiverMediaLater;
        } else if (original.sticker != null) {
          quoted = l10n.stickerLabel;
          quotedSticker = original.sticker;
        } else if (original.text.isNotEmpty) {
          quoted = original.text;
        } else if (_albums.runOf(original) != null) {
          quoted = l10n.albumQuoted;
        } else if (original.mediaPath != null) {
          quoted = l10n.chatQuotedPhoto;
        } else if (isVoiceName(original.fileName)) {
          quoted = l10n.chatVoiceMessage;
        } else if (original.fileName != null) {
          quoted = original.fileName;
        } else {
          quoted = l10n.chatMessageUnavailable;
          quotedAuthor = null;
        }
      }
    }
    // an album is a hit when its caption is
    final rowsAt = run == null
        ? [ix]
        : [for (final x in members) _messages.indexOf(x)];
    final hitAt = searchActive
        ? rowsAt.where(_matchSet.contains).firstOrNull
        : null;
    final isMatch = hitAt != null;
    final isCurrent =
        searchActive &&
        _matches.isNotEmpty &&
        rowsAt.contains(_matches[_matchPos]);
    final dimmed = searchActive && !isMatch;
    final showDate = ix == 0 || !_sameDay(_messages[ix - 1].when, m.when);
    // the rows around it as drawn: an album's other rows are not
    _Msg? near(int step) {
      for (var j = ix + step; j >= 0 && j < _messages.length; j += step) {
        final o = _messages[j];
        final r = _albums.runOf(o);
        if (r == null) return o;
        if (identical(r, run)) continue;
        if (identical(r.lead, o)) return o;
      }
      return null;
    }

    final prevMsg = near(-1);
    final nextMsg = near(1);
    bool sameRun(_Msg? o) =>
        o != null &&
        o.direction == m.direction &&
        !o.removing &&
        _sameDay(o.when, m.when) &&
        (m.when.difference(o.when).inSeconds).abs() < 120;
    final firstUnread = members.any((x) => _rowKey(x) == _firstUnreadKey);
    final firstInGroup = !sameRun(prevMsg) || firstUnread;
    final lastInGroup = !sameRun(nextMsg);
    final lifted = members.any((x) => _rowKey(x) == _liftedUid);
    final react = run == null ? row : _reactOn(run);
    final bubble = SizedBox(
      width: double.infinity,
      child: AnimatedOpacity(
        opacity: lifted ? 0.0 : 1.0,
        // back with no fade: the menu's copy has just landed right on it
        duration: lifted ? const Duration(milliseconds: 300) : Duration.zero,
        child: _Bubble(
          key: isMatch ? _matchKeys[hitAt] : null,
          msg: m,
          openMedia: _openChatMedia,
          newestOut: switch (_newestOut()) {
            final n? => members.any((x) => identical(x, n)),
            null => false,
          },
          translation: _translation,
          transcripts: _transcripts,
          album: run,
          stickers: _stickers,
          stickerOrder: i,
          landing: m.msgUid == null ? null : _landings[m.msgUid],
          quotedSticker: quotedSticker,
          linkTitle: _linkPreview(m)?['title'],
          linkBySender: _linkPreview(m)?['by'] == 'sender',
          plainLinks: _plainLinks,
          waitsAccept: _waitsAccept,
          firstInGroup: firstInGroup,
          lastInGroup: lastInGroup,
          revealed: m.msgUid != null && m.msgUid == _revealedUid,
          onReveal: m.msgUid == null
              ? null
              : () => setState(
                  () =>
                      _revealedUid = _revealedUid == m.msgUid ? null : m.msgUid,
                ),
          onStop: _stopSending,
          fromName: _fileFrom(m),
          soundsAfter: _soundsAfter,
          voiceAfter: _voiceAfter,
          // a set of files retries the row tapped; an album all of it
          onRetry: run == null || run.tag.files
              ? _tapRetry
              : (_) {
                  for (final x in members) {
                    if (x.failed || x.parked) _tapRetry(x);
                  }
                },
          // nothing to act on while it is still made ready
          onLongPress: making
              ? null
              : (ctx) =>
                    _showEmojiPickerAt(ctx, run == null ? row : m, album: run),
          onLongPressTile: run == null || making
              ? null
              : (ctx, tile) =>
                    _showEmojiPickerAt(ctx, m, album: run, tile: tile),
          onAct: () {
            for (final x in members) {
              _touched(x);
            }
          },
          onReact: m.welcome || !_canReact
              ? null
              : (e) {
                  final added = react.reactions[''] != e;
                  _toggleReaction(react, e);
                  if (added) _flashReaction(react);
                },
          onDoubleReact: m.welcome || !_canReact || making
              ? null
              : () {
                  if (lockGuard.isLocked()) return false;
                  final e = kDoubleTapReaction;
                  final added = react.reactions[''] != e;
                  _toggleReaction(react, e);
                  if (added) _flashReaction(react);
                  return added;
                },
          secure: m.secure,
          kept: _keeps(m),
          // the db's answer can come after the first frame: until then
          // only a contact the app already holds counts as known
          known: pdfPeerKnown(
            widget.peerHaloId,
            appState.contacts,
            accepted: _accepted,
            blocked: _blocked,
          ),
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
          ripple: members.any(
            (x) =>
                x.msgUid != null &&
                (x.msgUid == _rippleUid || identical(x, _replyFlash)),
          ),
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
    // its other rows are read, and landed on, where the album is
    Widget anchored(RowAnchors at, Widget child) {
      var w = child;
      for (final x in members) {
        if (!identical(x, row)) {
          w = RowAnchor(anchors: at, id: _rowKey(x), child: w);
        }
      }
      return w;
    }

    final answer = run == null ? row : run.anchor;
    // picking: a tap picks the row, its own taps wait
    final shown = _selecting && !m.welcome
        ? SelectRow(
            on: _picked.contains(_rowKey(row)),
            onTap: () => _pick(row),
            child: bubble,
          )
        : null;
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDate) _dateDivider(m.when, row.msgUid ?? 'r${row.rowid}'),
          ?_shotsLineAt(ix, below: false),
          ?_pqLineAt(ix, below: false),
          ..._healLinesAt(ix, below: false),
          if (firstUnread) _newMessagesDivider(),
          // the bubble alone: what says it has been read
          RowAnchor(
            anchors: _readAnchors,
            id: _rowKey(row),
            child: anchored(
              _readAnchors,
              anchored(
                _anchors,
                LeaveFold(
                  leaving: m.removing,
                  // a timed bubble has burned already; any other burns now
                  after: m.burnedAway ? Duration.zero : kBurnDissolve,
                  // his first line takes no reply
                  child:
                      shown ??
                      (m.welcome
                          ? bubble
                          : SwipeToReply(
                              onReply: () {
                                HapticFeedback.selectionClick();
                                _replyWith(answer);
                              },
                              child: bubble,
                            )),
                ),
              ),
            ),
          ),
          ?_shotsLineAt(ix, below: true),
          ?_pqLineAt(ix, below: true),
          ..._healLinesAt(ix, below: true),
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
    _keepDraft();
    _composerFocus.requestFocus();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && identical(_replyFlash, m)) {
        setState(() => _replyFlash = null);
      }
    });
  }

  @override
  void dispose() {
    // a sound of this chat stops with it
    final playing = SoundPlayer.instance.item?.path;
    if (playing != null && _messages.any((m) => m.filePath == playing)) {
      SoundPlayer.instance.stop();
    }
    if (_sharedHeld.isNotEmpty) {
      unawaited(SharedInbox.release(_sharedHeld.toList()));
    }
    _find.detach();
    _helloWaitTimer?.cancel();
    _unwatchCaptures?.call();
    // the row stays with the chat for its next opening
    _tray.removeListener(_trayMoved);
    chatGone(widget.peerHaloId);
    showInChat.removeListener(_showAsked);
    DeskTrays.handedIn.removeListener(_takeHandedIn);
    for (final land in List.of(_flights)) {
      land();
    }
    _timers.dispose();
    _reads.dispose();
    releaseChat(widget.peerHaloId);
    _shotsHold.release();
    final open = _openChats[widget.peerHaloId]?..remove(this);
    if (open != null && open.isEmpty) _openChats.remove(widget.peerHaloId);
    lockState.removeListener(_lockLifted);
    appState.removeListener(_onAppStateChanged);
    mediaSendsTick.removeListener(_mediaSendsMoved);
    fileWaits.removeListener(_waitsMoved);
    _followTimer?.cancel();
    wallpaperRevision.removeListener(_loadWall);
    _devOpening
      ?..removeListener(_onDevOpening)
      ..dispose();
    _translation?.dispose();
    _transcripts?.dispose();
    _lastReadPerPeer[_memo] = _messages.fold(
      0,
      (a, m) => m.rowid > a ? m.rowid : a,
    );
    // left: what the composer holds is written now, not after the wait
    _msgCtrl.removeListener(_keepDraft);
    _msgCtrl.removeListener(_typed);
    _keepDraft();
    final rows = _draftRows;
    if (rows != null) {
      unawaited(writeDraftNow(rows, widget.peerHaloId, group: false));
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

  Future<void> _openMediaGallery() => openShared(
    context,
    chatId: widget.peerHaloId,
    title: _isDev ? l10n.devName : _nickname ?? widget.peerHaloId,
    blocking: _shots.blocking,
  );

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
                  label: l10n.groupInfoSharedMedia,
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
          onShots: () async {
            final flip = _flipShots();
            setSheet(() {});
            await flip;
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
    required VoidCallback onShots,
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
              label: l10n.groupInfoSharedMedia,
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
            // both phones or neither: off, with the reason, until theirs
            // knows the block. someone blocked is not offered
            if (!_blocked && !widget.support && !_isDev)
              MenuSheetRow(
                icon: Icons.phonelink_lock_outlined,
                label: l10n.chatBlockScreenshots,
                sub: !_accepted
                    ? l10n.chatAcceptThemFirst
                    : !_shots.peerCan
                    ? l10n.chatShotsWhenTheyUpdateShown
                    : l10n.chatShotsBlocksBoth,
                toggled: _shots.blocking,
                onTap: _accepted && _shots.peerCan ? onShots : null,
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
  bool _contactOpening = false;
  Future<void> _openContact() async {
    if (_isDev) return showDevAboutSheet(context);
    // read first, so the page opens drawn; a second tap meanwhile is one
    if (_contactOpening) return;
    _contactOpening = true;
    try {
      await warmContactInfo(widget.peerHaloId);
    } finally {
      _contactOpening = false;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      haloRoute(
        ContactScreen(
          haloId: widget.peerHaloId,
          avatarSeed: widget.avatarSeed,
          peerXPub: widget.peerXPub,
          face: _peerFace,
          nickname: _nickname,
          support: widget.support,
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

  void _loadWall() {
    chatWall(widget.peerHaloId).then((w) {
      if (mounted && !w.sameAs(_wall)) setState(() => _wall = w);
    });
  }

  // the sheet previews live: each swatch changes the room behind it, and
  // backing out puts the old one back
  Future<void> _pickAtmosphere() async {
    final id = widget.peerHaloId;
    final before = _wall;
    final follows = await followsDefault(id);
    final byDefault = follows ? before : await defaultWall();
    if (!mounted) return;
    final picked = await showWallpaperSheet(
      context,
      before.atmo,
      allowPhoto: true,
      allowDefault: true,
      followsDefault: follows,
      hasPhoto: !follows && before.photo != null,
      photo: before.photo,
      defaultPhoto: byDefault.photo,
      onPreview: (a) {
        if (mounted) setState(() => _wall = ChatWall(a));
      },
      onPreviewDefault: () => defaultWall().then((w) {
        if (mounted) setState(() => _wall = w);
      }),
    );
    if (!mounted) return;
    if (picked is WallpaperFromPhotos) {
      setState(() => _wall = before);
      final r = await pickWallpaperPhoto(
        context,
        save: (at, photo) => at.setChatPhoto(id, photo),
        failed: (r) {
          if (!mounted) return;
          showHaloToast(
            context,
            r == Picked.missed
                ? l10n.wallpaperNotSet
                : l10n.cameraCouldNotStripThat,
          );
        },
      );
      if (r != Picked.kept) return;
    } else if (picked is WallpaperDefault) {
      await session.setChatAtmosphere(id, null);
    } else if (picked is Atmo) {
      await session.setChatAtmosphere(id, picked.name);
    } else {
      setState(() => _wall = before);
      return;
    }
    HapticFeedback.selectionClick();
    _loadWall();
  }

  Future<void> _clearConversation() async {
    final confirm = await showConfirmSheet(
      context,
      title: l10n.chatClearThisConversation,
      line: ownClearLine(group: false),
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
    if (!mounted) return;
    // a heal's hold ends once the number was looked at
    if (_healHold != null) {
      await appState.releaseHealHold(widget.peerHaloId);
    }
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
      line: ownBlockLine(chat: true),
      yes: l10n.commonBlock,
      keep: l10n.commonCancel,
    );
    if (confirm != true) return;
    await appState.block(widget.peerHaloId);
    if (mounted) setState(() => _blocked = true);
    // someone blocked holds nothing on this screen
    await _loadShots();
  }

  Future<void> _unblockContact() async {
    await appState.unblock(widget.peerHaloId);
    if (mounted) setState(() => _blocked = false);
    await _loadShots();
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
    final steps = TraceSteps('accept tap');
    await session.acceptRequest(widget.peerHaloId);
    steps.step('row written');
    await appState.afterAccept(widget.peerHaloId);
    steps.step('accepted');
    if (mounted) {
      setState(() {
        _accepted = true;
        // they asked: they know this phone, whatever has come from them
        _peerEngaged = true;
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

  // the sounds and voice notes under [m], in the order they came: what
  // the player plays after it
  List<SoundItem> _soundsAfter(_Msg m) {
    final at = _messages.indexOf(m);
    if (at < 0) return const [];
    return [
      for (final x in _messages.skip(at + 1))
        if (x.filePath != null &&
            (isVoiceName(x.fileName) ||
                fileViewOf(fileFactsOrName(x.filePath!, x.fileName)) ==
                    FileView.audio))
          SoundItem(
            x.filePath!,
            name: x.fileName,
            from: _fileFrom(x),
            when: x.when,
            voice: isVoiceName(x.fileName),
            kept: _keeps(x),
          ),
    ];
  }

  // the voice note after [m] in the chat, by its bubble's key: it plays on.
  // a timed one or one still on its way is passed over: a timer starts only
  // with a tap
  String? _voiceAfter(_Msg m) {
    final at = _messages.indexOf(m);
    if (at < 0) return null;
    for (final x in _messages.skip(at + 1)) {
      if (x.making != null || !isVoiceName(x.fileName) || x.filePath == null) {
        continue;
      }
      if (x.burnAt != null || x.burnSecs != null) continue;
      if (fileWaitOf(x.msgUid) != null) continue;
      return _voiceKeyOf(x);
    }
    return null;
  }

  // who sent a file, for its viewer's head: theirs only
  String? _fileFrom(_Msg m) => m.direction == 'out'
      ? null
      : _isDev
      ? l10n.devName
      : _nickname ?? widget.peerHaloId;

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
    _byApp = true;
    try {
      _msgCtrl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    } finally {
      _byApp = false;
    }
  }

  // the composer's words as the last change left them, and whether the
  // app is the one changing them now
  String _typedWas = '';
  bool _byApp = false;

  // a keystroke or a paste in the focused composer: their phone may show
  // that this one is typing (typing.dart). the app's own changes, a draft
  // put back or words handed in, say nothing
  void _typed() {
    final t = _msgCtrl.text;
    final e = composerEdit(
      _typedWas,
      t,
      byApp: _byApp,
      focused: _composerFocus.hasFocus,
    );
    _typedWas = t;
    if (e == null || _isDev || widget.support) return;
    unawaited(
      appState.typingEdit(
        widget.peerHaloId,
        userEdit: e.userEdit,
        nonEmpty: e.nonEmpty,
      ),
    );
  }

  // where this chat's draft is kept, while the session still holds the
  // chat where it did when the chat opened: a chat left behind by a lock
  // or a hide writes nothing
  DraftRows? get _draftRows {
    final rows = session.draftsOf(widget.peerHaloId);
    return rows.container.chatKey(widget.peerHaloId) == _memo ? rows : null;
  }

  // [clock]: the person changed the timer, the draft takes it
  void _keepDraft({bool clock = false}) {
    final rows = _draftRows;
    if (rows == null || _rowUnread) return;
    typedDraft(
      rows,
      widget.peerHaloId,
      Draft(
        _msgCtrl.text,
        replyTo: _replyTo?.msgUid ?? _draftReply,
        at: DateTime.now().millisecondsSinceEpoch,
        // a timed chat's draft goes as its messages would
        burnSecs: _ghost ? _burnSeconds : null,
      ),
      group: false,
      clock: clock,
      timedKnown: _ghostKnown,
    );
  }

  // the kept draft read back, unless something was typed meanwhile
  Future<void> _readDraft(DraftRows rows) async {
    final before = _msgCtrl.text;
    final r = await readKeptDraft(rows, widget.peerHaloId, group: false);
    if (!mounted) return;
    // not read, with words handed in: they stay aside, nothing is written
    // over the row, and the next load reads it again
    if (!r.read) {
      if (_handedIn) _rowUnread = true;
      return;
    }
    final again = _rowUnread;
    _rowUnread = false;
    final d = r.draft;
    if (d == null) {
      final left = _msgCtrl.text.trim().isNotEmpty;
      if (left && (again || (_handedIn && _msgCtrl.text == before))) {
        _keepDraft();
      }
      return;
    }
    if (!again && _msgCtrl.text != before) return;
    _draftReply = d.replyTo;
    // read late: the row's words first, then what was put in meanwhile
    _takeDraft(
      composerWith(d.text, again ? _msgCtrl.text : widget.initialText),
    );
    unawaited(_restoreReply());
  }

  // the stored draft could not be read under handed-in words: nothing is
  // written until it is, so they never take its place
  bool _rowUnread = false;

  // the quote a kept draft had, once the messages are here: from the pages
  // held, else from its own row, as it may be older than them. only one
  // gone from the chat is let go; until then the draft keeps its uid
  Future<void> _restoreReply() async {
    final uid = _draftReply;
    if (uid == null || !_loaded || !mounted || _quoteLookup) return;
    if (_replyTo != null) {
      _draftReply = null;
      return;
    }
    for (final m in _messages) {
      if (m.msgUid == uid) {
        _draftReply = null;
        setState(() => _replyTo = m);
        return;
      }
    }
    Map<String, Object?>? row;
    _quoteLookup = true;
    try {
      row = await session.messageIn(widget.peerHaloId, uid);
    } catch (e) {
      // not read: the uid stays, and the next load tries again
      dlog('draft quote: not read (${e.runtimeType})');
      return;
    } finally {
      _quoteLookup = false;
    }
    if (!mounted || _draftReply != uid) return;
    _draftReply = null;
    if (row == null || _replyTo != null) return;
    final m = _Msg(
      row['direction'] as String,
      row['plaintext'] as String? ?? '',
      DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(row)),
      sticker: StickerWire.parse(row['sticker']),
      msgUid: uid,
      mediaPath: row['media_path'] as String?,
      fileName: row['file_name'] as String?,
    );
    setState(() => _replyTo = m);
  }

  bool _quoteLookup = false;

  bool get _handedIn => (widget.initialText ?? '').trim().isNotEmpty;

  // what a send answers: the quote up, or a kept one still being looked
  // up, which the send then takes so the lookup does not put it back
  String? _takeQuote() {
    final uid = _replyTo?.msgUid ?? _draftReply;
    _draftReply = null;
    return uid;
  }

  // its timed draft went with the chat's timer: words and quote both
  void _timedDraftGone() {
    _draftReply = null;
    if (_replyTo != null) setState(() => _replyTo = null);
    _msgCtrl.clear();
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
            : _devCardOld
            ? NoticeBanner(
                key: const ValueKey('dev-old'),
                glyph: NoticeGlyph.clock,
                text: l10n.devUpdateToWrite,
                color: HaloColors.violet,
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
  Widget build(BuildContext context) => menuBack(
    child: PopScope(
      canPop: !_escHolds && !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // back first lets go of what is picked
        if (_selecting) {
          setState(_picked.clear);
          return;
        }
        _escOne();
      },
      child: DragInZone(
        enabled: _composerShown,
        stage: _stage,
        couldNotRead: () => l10n.chatCouldNotReadThat,
        child: _page(context),
      ),
    ),
  );

  // this chat's row of staged files on a computer, kept by chat and
  // container so it can never go to anyone else
  late final AttachTray _tray = DeskTrays.of(_trayKey);
  late final String _trayKey = '${session.container.id}|${widget.peerHaloId}';

  // photos, videos and files shared from another app wait for this chat
  // in front, once the bar is known
  void _takeSharedIn() {
    if (!mounted || !_barKnown) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final got = SharedInbox.take(_trayKey);
    _sharedHeld.addAll(got);
    if (got.isNotEmpty) unawaited(_sendSharedIn(got));
  }

  // shared copies this chat holds while its preview or question is up: a
  // chat that goes first shreds them
  final _sharedHeld = <SharedCopy>{};

  // the photos and videos through the send preview as a gallery pick, then
  // the files once asked about, each as the file tile sends one. a back out
  // anywhere sends nothing more of it; the copies go once done with
  Future<void> _sendSharedIn(List<SharedCopy> got) async {
    try {
      if (!_composerShown) {
        if (_requestLocked) showHaloToast(context, l10n.chatWaitingForThemTo);
        return;
      }
      if (_sayMediaLater()) return;
      final media = [
        for (final c in got)
          if (c.kind != SharedKind.file)
            XFile(c.path, name: c.name, mimeType: c.mime),
      ];
      final files = [
        for (final c in got)
          if (c.kind == SharedKind.file) c,
      ];
      if (media.isNotEmpty) {
        var sent = false;
        final most = await appState.fileLimitFor(widget.peerHaloId);
        if (!mounted) return;
        await sendGalleryPicks(
          media,
          pickMore: () => lockState.hold(pickGallery),
          // a photo is shrunk as a gallery pick is; one still over the
          // chat's limit stays out, and says so
          preview: (items, more) {
            final (:fit, :over) = photosWithin(items, most);
            if (over != null) {
              showHaloToast(
                context,
                l10n.sharePhotoOverLimit(
                  humanFileSize(over),
                  humanFileSize(most),
                ),
              );
            }
            if (fit.isEmpty) return Future.value(null);
            return _preview(fit, more);
          },
          send: (r) {
            sent = true;
            return _sendPicked(r);
          },
        );
        if (!sent) return;
      }
      if (files.isEmpty || !mounted || lockState.locked) return;
      if (!await askSendSharedFiles(context, files)) return;
      for (final f in files) {
        if (!mounted || lockState.locked) break;
        final ready = await _readyFile(f.path, f.name);
        if (ready != null) await _sendReady(ready, '');
      }
    } finally {
      _sharedHeld.removeAll(got);
      await SharedInbox.release(got);
    }
  }

  // what a tool sent here ("Send to a chat") waits for this row and goes in
  // by a drop's rules, once the bar is known
  void _takeHandedIn() {
    if (!mounted || !_barKnown) return;
    final got = DeskTrays.takeHandedOff(_trayKey);
    if (got.isNotEmpty) unawaited(_stageHanded(got));
  }

  Future<void> _stageHanded(List<TrayHandoff> got) async {
    for (final h in got) {
      if (!mounted || !_composerShown || _mediaWaits) {
        if (mounted && _composerShown) {
          _tray.say(l10n.requestSenderMediaLater);
        }
        h.drop();
        continue;
      }
      final f = h.path, b = h.bytes;
      if (f != null) {
        await _tray.add([
          f,
        ], most: () => appState.fileLimitFor(widget.peerHaloId));
        // too big or a full row: the line says so, the tool's file goes
        if (!_tray.items.any((x) => x.path == f)) DeskTrays.released(f);
      } else if (b != null) {
        await _tray.addPicture(
          b,
          most: () => appState.fileLimitFor(widget.peerHaloId),
          name: h.name,
        );
      }
    }
  }

  void _trayMoved() {
    if (mounted) setState(() {});
  }

  // dropped or pasted files wait above the composer. a request to a
  // stranger is words alone: the row says so and keeps nothing
  void _stage(List<String> files) {
    if (!_composerShown) return;
    if (_mediaWaits) {
      _tray.say(_mediaLaterLine);
      return;
    }
    unawaited(
      _tray.add(files, most: () => appState.fileLimitFor(widget.peerHaloId)),
    );
  }

  // a picture pasted from the clipboard waits there too, in memory only
  void _stagePicture(Uint8List png) {
    if (!_composerShown) return;
    if (_mediaWaits) {
      _tray.say(_mediaLaterLine);
      return;
    }
    unawaited(
      _tray.addPicture(
        png,
        most: () => appState.fileLimitFor(widget.peerHaloId),
      ),
    );
  }

  // enter with files staged: the photos and videos as albums with the
  // caption on the first, the phone's way, then each file after it. a file
  // alone takes the caption itself
  Future<void> _sendTray() async {
    if (_requestLocked || _sayMediaLater()) return;
    if (_requestPending && _tray.items.length > _roomLeft) {
      showHaloToast(context, l10n.chatWaitingForThemTo);
      return;
    }
    // a second enter while the first reads finds the row taken
    if (_trayBusy) return;
    _trayBusy = true;
    try {
      await _sendTrayNow();
    } finally {
      _trayBusy = false;
    }
  }

  bool _trayBusy = false;

  Future<void> _sendTrayNow() async {
    final caption = _msgCtrl.text.trim();
    final plan = trayPlan(_tray.items, caption);
    final picks = <PickedMedia>[];
    for (final x in plan.media) {
      if (x.kind == TrayKind.video) {
        picks.add(PickedMedia.video(XFile(x.path, name: x.name)));
        continue;
      }
      try {
        picks.add(PickedMedia.photo(await trayBytes(x)));
      } catch (_) {
        if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      }
    }
    // a big video is asked about as the preview asks
    if (!mounted || !await _askBig(picks) || !mounted) return;
    // a lock while it read took the row: nothing goes
    if (lockState.locked) return;
    final sent = _tray.take();
    _msgCtrl.clear();
    _keepDraft();
    try {
      if (picks.isNotEmpty) {
        await _sendPicked(
          MediaSendResult(items: picks, caption: caption, secure: _secureNext),
        );
      }
      await _sendFileSet([
        for (final (f, _) in plan.files) (f.path, f.name),
      ], plan.files.isEmpty ? '' : plan.files.first.$2);
    } finally {
      AttachTray.sent(sent);
    }
  }

  // esc on a computer lets go of the staged files, then the quote, then
  // the search, and only then closes the chat. a menu open over it goes
  // first, as its own page
  bool get _escHolds =>
      onDesktop &&
      (_tray.shown || (_replyTo != null && !_blocked) || _searching);

  void _escOne() {
    if (_tray.shown) {
      _tray.clear();
    } else if (_replyTo != null && !_blocked) {
      setState(() => _replyTo = null);
      _keepDraft();
    } else if (_searching) {
      _closeSearch();
    }
    if (onDesktop) _composerFocus.requestFocus();
  }

  // the bar under the thread is the composer: a drop goes as a pick would
  bool get _composerShown =>
      _barKnown &&
      !_blocked &&
      _devStop == null &&
      !_incomingRequest &&
      !_requestLocked &&
      !(_keyHeld && !_isDev);

  Widget _page(BuildContext context) {
    // the albums as the thread stands now: a row of one is drawn by its lead
    _albums = _indexAlbums(_messages);
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
              child: _selecting
                  ? _selectBar()
                  : _searching
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
                      supporterBadge: _peerBadge,
                      shotsBlocked: _shots.blocking,
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
            ...readLines([
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
                      // their messages in another language: the whole chat
                      // translated with one tap. never in the decoy
                      TranslateBarSlot(
                        chat: _translation,
                        theirs: _theirRecent(),
                        allowed: !_isDev && !sessionQuiet && !_searching,
                      ),
                      _Fold(
                        // his chat is no request: its lock line says the rest
                        (_flag != null && !_accepted) || _isDev
                            ? const SizedBox(
                                key: ValueKey('top-none'),
                                width: 0,
                              )
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
                                mediaLater: _mediaWaits,
                              )
                            : const SizedBox(
                                key: ValueKey('top-none'),
                                width: 0,
                              ),
                      ),
                      // his key moved on: this chat still reads and writes
                      _Fold(
                        _devShown?.status == DevKeyStatus.previous
                            ? NoticeBanner(
                                key: const ValueKey('dev-moved'),
                                glyph: NoticeGlyph.shield,
                                text: l10n.devNewKey,
                                color: HaloColors.warn,
                                textColor: HaloColors.warnText,
                                margin: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  14,
                                  2,
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('dev-moved-none'),
                                width: 0,
                              ),
                      ),
                      // added by a v3 card: its owner may need the new Kryfo
                      // before the chat can start. stays until they answer
                      _Fold(
                        _helloWait.update && !_blocked && !_isDev
                            ? NoticeBanner(
                                key: const ValueKey('hello-old'),
                                glyph: NoticeGlyph.clock,
                                text: l10n.helloSentOld,
                                color: HaloColors.warn,
                                textColor: HaloColors.warnText,
                                margin: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  14,
                                  2,
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('hello-old-none'),
                                width: 0,
                              ),
                      ),
                      _Fold(
                        _ackLost && !_blocked && !_isDev
                            ? _AckLostLine(
                                key: const ValueKey('ack-lost'),
                                onRetry: _retryAck,
                              )
                            : const SizedBox(
                                key: ValueKey('ack-lost-none'),
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
                            : const SizedBox(
                                key: ValueKey('key-none'),
                                width: 0,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AtmoScope(
                  atmo: _wall.atmo,
                  photo: _wall.photo != null,
                  child: Stack(
                    key: _listKey,
                    children: [
                      Positioned.fill(child: ChatBackdrop(_wall, chat: _memo)),
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
                            : NotificationListener<ScrollMetricsNotification>(
                                key: const ValueKey('list'),
                                onNotification: _threadResized,
                                // the newest bubble's time rests above the line
                                child: EarlierRoom(
                                  shown: _earlier.count > 0,
                                  controller: _scrollCtrl,
                                  reversed: true,
                                  builder: (_, room) => ReadWidth(
                                    builder: (_, side) => ListView.builder(
                                      controller: _scrollCtrl,
                                      reverse: true,
                                      padding: EdgeInsets.fromLTRB(
                                        16 + side,
                                        12,
                                        16 + side,
                                        12 + room,
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
                                          final row =
                                              _messages[_messages.length -
                                                  1 -
                                                  i];
                                          final id = _rowKey(row);
                                          // drawn, and landed on, in its album.
                                          // a stranger's file waits unshown
                                          if (_albums.hidden(row) ||
                                              _heldBack(row)) {
                                            return SizedBox.shrink(
                                              key: ValueKey(id),
                                            );
                                          }
                                          return RowAnchor(
                                            key: ValueKey(id),
                                            anchors: _anchors,
                                            id: id,
                                            child: _buildRow(
                                              c,
                                              i,
                                              searchActive,
                                            ),
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
                                                color: HaloColors.text,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
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
              // answers handed to the phone, not sent by it yet
              _Fold(
                _viaPhone && _answersWait
                    ? Padding(
                        key: const ValueKey('answers-wait'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text(
                          l10n.chatInboxSendsWhenPhoneOnline,
                          textAlign: TextAlign.center,
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.amberText,
                          ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('answers-wait-none'),
                        width: 0,
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
                              color: HaloColors.amberText,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('status-none'), width: 0),
              ),
              // the route not up: messages typed now are queued. the pill's
              // reading, its grace and its words; the long words only while tor
              // is still coming up. not on a phone whose identity has moved,
              // where tor is off on purpose.
              LinkViewBuilder(
                builder: (_, link) => _Fold(
                  appState.sendMode == 'private' &&
                          link.chatLine != null &&
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
                                  link.chatLine!,
                                  style: HaloType.sans(
                                    size: 10.5,
                                    color: HaloColors.text,
                                  ).copyWith(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(key: ValueKey('tor-none'), width: 0),
                ),
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
                // a request with no red flag shows nothing at all
                _flag != null && !_accepted && !_blocked
                    ? ShieldNote(
                        key: const ValueKey('shield-flag'),
                        flag: _flag!,
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        onDismiss: _dismissShield,
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
                // the quote is part of the composer the blocked bar replaces
                child: _replyTo != null && !_blocked
                    ? _ReplyQuoteBar(
                        target: _replyTo!,
                        onCancel: () {
                          setState(() => _replyTo = null);
                          _keepDraft();
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              IncomingMediaBanner(
                chatKey: _memo,
                onPause: appState.pauseDownload,
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
                        : _phoneOnly != null
                        ? 'bar_phone_only'
                        : _keyHeld && !_isDev
                        // a heal's card and a new key's card cross
                        ? 'bar_held_${_healHold ?? 'key'}'
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
                          introducer: _vouched
                              ? vouchNames(_voucherNames)
                              : null,
                          onAccept: _acceptRequestPeer,
                          onDecline: _declineRequestPeer,
                          onBlock: _blockRequestPeer,
                        )
                      : _requestLocked
                      ? _RequestLockBar(line: _isDev ? l10n.devLockLine : null)
                      : _phoneOnly != null
                      ? _RequestLockBar(
                          line: _phoneOnly,
                          icon: Icons.smartphone_outlined,
                        )
                      : _keyHeld && !_isDev
                      ? KeyHeldCard(
                          peerName: _nickname ?? widget.peerHaloId,
                          healKind: _healHold,
                          onCheck: _openKeyVerification,
                          onAccept: _healHold != null
                              ? _keepChatting
                              : _acceptNewKey,
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
                                url:
                                    _accepted &&
                                        !_plainLinks &&
                                        !sessionQuiet &&
                                        _torUp
                                    ? firstUrl(v.text)
                                    : null,
                                pending: _pendingPreview,
                                busy: _previewBusy,
                                onAdd: _addPreview,
                                onDrop: () =>
                                    setState(() => _pendingPreview = null),
                              ),
                            ),
                            TrayStrip(tray: _tray),
                            PasteFiles(
                              onFiles: _stage,
                              onPicture: _stagePicture,
                              child: _Composer(
                                // a computer answering through the phone
                                // shows them, and says files go from there
                                media: !_mediaWaits || _viaPhone,
                                voice: !_viaPhone,
                                staged: !_tray.isEmpty,
                                onAttach: _viaPhone
                                    ? _sayFilesFromPhone
                                    : _showAttachSheet,
                                onStickers: _showStickers,
                                onCamera: _viaPhone
                                    ? _sayFilesFromPhone
                                    : _openCamera,
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
                                onToggleGhost: _pickBurnDuration,
                                onPickBurn: _pickBurnDuration,
                                burnSeconds: _burnSeconds,
                                controller: _msgCtrl,
                                focusNode: _composerFocus,
                                onSend: _send,
                                // a request waits for their accept: nothing
                                // to make quiet yet
                                onSendSilent: _requestLocked
                                    ? null
                                    : () => _send(silent: true),
                                disguise: _voiceDisguise,
                                disguiseLocked: _devAnon,
                                onVoice: _sendVoice,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ]),
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
              color: HaloColors.text,
              height: 1.5,
            ),
          ),
          // a stranger's photos and files wait for the accept
          if (introducer == null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.requestReceiverMediaLater,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text,
                height: 1.5,
              ),
            ),
          ],
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
              color: HaloColors.text,
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
  // photos and files wait for their accept: said under the line
  final bool mediaLater;
  const _RequestBanner({
    super.key,
    this.compact = false,
    this.mediaLater = false,
  });

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
              color: HaloColors.text,
              height: 1.5,
            ),
          ),
          if (mediaLater && !compact) ...[
            const SizedBox(height: 4),
            Text(
              l10n.requestSenderMediaLater,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text,
                height: 1.5,
              ),
            ),
          ],
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
                  style: HaloType.sans(size: 13, color: HaloColors.text),
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
                color: HaloColors.text,
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
                color: HaloColors.amberText,
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
  // the chat blocks screenshots on both phones
  final bool shotsBlocked;
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
    this.note,
    this.supporterBadge,
    this.shotsBlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    // the palette swaps in place: depending on the theme repaints the
    // header when it switches under an open chat
    Theme.of(context);
    final fast = appState.sendMode != 'private';
    return Container(
      // a computer's header stands a little roomier, a phone's as it was
      padding: onDesktop
          ? const EdgeInsetsDirectional.fromSTEB(8, 10, 12, 14)
          : const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          PaneBack(
            child: IconButton(
              tooltip: l10n.commonBack,
              icon: Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
              onPressed: onBack,
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: l10n.chatViewContact,
            child: GestureDetector(
              onTap: onBlock, // avatar opens the contact page
              behavior: HitTestBehavior.opaque,
              // the same face flies in from the list row
              child: HaloHero(
                tag: 'face-$avatarSeed',
                child: KryfoAvatar(
                  seed: avatarSeed,
                  size: onDesktop ? 40 : 36,
                  choice: face,
                ),
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
                              size: onDesktop ? 15.5 : 14,
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
                            l10n.chatSupporter,
                            style: HaloType.mono(
                              size: 7.5,
                              color: HaloColors.amberText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (nickname != null)
                    Text(
                      haloId,
                      style: HaloType.mono(size: 10, color: HaloColors.text),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    // the line swaps to "Typing" while they type, in one
                    // line either way, so the header keeps its height
                    child: TypingSwap(
                      showing: appState.typing.board.of(
                        appState.typingKey(haloId),
                      ),
                      style: typingStyle(size: 10, mono: true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 10,
                            // fast and tor told apart by their own colours,
                            // never by the accent
                            color: fast
                                ? HaloColors.greenText
                                : HaloColors.violet,
                          ),
                          const SizedBox(width: 4),
                          // a longer language at a big font size would run
                          // past the header's buttons, so it ends in …
                          Flexible(
                            child: Text(
                              fast
                                  ? l10n.chatEncryptedDirect
                                  : l10n.chatEncryptedOverTor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.mono(
                                size: 10,
                                color: fast
                                    ? HaloColors.greenText
                                    : HaloColors.text,
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: Duration(
                              milliseconds: motionStill(context) ? 0 : 220,
                            ),
                            child: shotsBlocked
                                ? Padding(
                                    key: const ValueKey('shots'),
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 6,
                                    ),
                                    child: Semantics(
                                      label: l10n.chatShotsBlockedHere,
                                      child: Icon(
                                        Icons.phonelink_lock_outlined,
                                        size: 11,
                                        color: HaloColors.text2,
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    key: ValueKey('no-shots'),
                                    width: 0,
                                  ),
                          ),
                        ],
                      ),
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
                                color: HaloColors.amberText,
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
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
    },
    child: _head(context),
  );

  Widget _head(BuildContext context) {
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
                            builder: (dir) => ShiftTapGuard(
                              controller: widget.controller,
                              child: TextField(
                                textDirection: dir,
                                inputFormatters: const [UnmarkedInput()],
                                controller: widget.controller,
                                enableIMEPersonalizedLearning: false,
                                focusNode: _focus,
                                onChanged: widget.onChanged,
                                // enter goes to the next match on a
                                // computer, as a browser's find does
                                onSubmitted: onDesktop
                                    ? (_) {
                                        widget.onNext();
                                        _focus.requestFocus();
                                      }
                                    : null,
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
                      // the arrows' 48 boxes make the row's top gap
                      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 0, 0),
                      child: Row(
                        children: [
                          Text.rich(
                            TextSpan(
                              style: HaloType.mono(
                                size: 10,
                                color: HaloColors.text,
                              ),
                              children: widget.matchCount == 0
                                  ? [
                                      TextSpan(
                                        text: l10n.chatNoMatches,
                                        style: HaloType.mono(
                                          size: 10,
                                          color: HaloColors.text,
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
                                        color: HaloColors.amberText,
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
      // a 48 box to tap, the 24 square drawn in its middle
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
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
        ),
      ),
    );
  }
}

// a voice note's bubble, by its message: the key play-on finds it by
String _voiceKeyOf(_Msg m) => 'vb_${m.msgUid ?? m.filePath}';

class _Bubble extends StatelessWidget {
  // uids whose entrance animation already played, so a list rebuild doesn't
  // replay it
  static final Set<String> _entered = {};
  final _Msg msg;
  final void Function(_Msg)? onRetry;
  // a file's ring: stops it on its way
  final void Function(_Msg)? onStop;
  // who they are, for a file viewer's head
  final String? fromName;
  // a sound file: the sounds below it, which play after it
  final List<SoundItem> Function(_Msg)? soundsAfter;
  // a voice note: the key of the one after it, which plays on
  final String? Function(_Msg)? voiceAfter;
  final void Function(BuildContext)? onLongPress;
  // its photo, video or file opened, or its voice note played
  final VoidCallback? onAct;
  // a tap on a reaction chip: the same emoji from this phone, on or off
  final void Function(String emoji)? onReact;
  // a double tap: the first quick reaction on or off, true when it went on
  final bool Function()? onDoubleReact;
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
  // a request's links: shown as the words they are, never tappable
  final bool plainLinks;
  // a request they have not accepted: the pill waits, nothing turns
  final bool waitsAccept;
  // a sticker row: the chat's budget, its place in it, and its flight
  final StickerBudget? stickers;
  final int stickerOrder;
  final StickerLanding? landing;
  // the quoted message is a sticker
  final StickerWire? quotedSticker;
  // sent, with no receipt yet, to someone who has not added us back
  final bool unconfirmed;
  // theirs, in a chat that blocks: opened in no other app
  final bool kept;
  // from someone this phone accepted: a pdf's first page may be drawn
  final bool known;
  // an album: [msg] stands for all of it, and its grid is drawn
  final AlbumRun<_Msg>? album;
  // a photo or a video opened in the viewer with the rest of the chat's,
  // under [tag]: false when it opens on its own
  final bool Function(BuildContext, _Msg, Object? tag)? openMedia;
  // a tile of the album held: the bubble's context and the tile
  final void Function(BuildContext, int)? onLongPressTile;
  // the chat's translations: theirs in another language offer one
  final ChatTranslation? translation;
  // the chat's voice note transcripts
  final ChatTranscripts? transcripts;
  // the newest of ours: the only one that spells Delivered
  final bool newestOut;
  const _Bubble({
    super.key,
    required this.msg,
    this.newestOut = false,
    this.translation,
    this.transcripts,
    this.album,
    this.openMedia,
    this.onLongPressTile,
    this.stickers,
    this.stickerOrder = 0,
    this.landing,
    this.quotedSticker,
    this.onRetry,
    this.onStop,
    this.fromName,
    this.soundsAfter,
    this.voiceAfter,
    this.onLongPress,
    this.onAct,
    this.onReact,
    this.onDoubleReact,
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
    this.plainLinks = false,
    this.waitsAccept = false,
    this.firstInGroup = true,
    this.lastInGroup = true,
    this.unconfirmed = false,
    this.kept = false,
    this.known = false,
  });

  // builds the message body, underlining query matches in amber. plain
  // Text when there's no active query.
  Widget _body(bool isOut, {bool image = false, String? words}) {
    // a caption is the words of a text bubble; under a photo there is no
    // amber behind them
    final base = HaloType.message(onAmber: isOut && !image);
    if (query.isEmpty && plainLinks) {
      final t = words ?? msg.text;
      return Text(t, style: base, textDirection: writtenDir(t));
    }
    if (query.isEmpty) {
      return KryfoLinkText(
        text: words ?? msg.text,
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

  // a file is drawn by what its bytes are once they are read, so a bubble
  // drawn by the name alone is drawn again then
  @override
  Widget build(BuildContext context) =>
      msg.filePath == null || isVoiceName(msg.fileName)
      ? _build(context)
      : ValueListenableBuilder<int>(
          valueListenable: fileFactsRead,
          builder: (context, _, _) => _build(context),
        );

  Widget _build(BuildContext context) {
    final isOut = msg.direction == 'out';
    final isImage = msg.mediaPath != null;
    // a photo or an album with a caption is one card: flatter corners, the
    // picture's top ones the same so the edges meet
    final corner =
        (isImage || (album != null && !album!.tag.files)) && msg.text.isNotEmpty
        ? kCaptionCorner
        : 14.0;
    final shape = fileShapeNow(msg.filePath, msg.fileName);
    // a video with no caption sits on the chat like a photo: no bubble
    // around it, its time and tick in its corner
    final isVideo =
        album == null &&
        msg.filePath != null &&
        msg.text.isEmpty &&
        !isVoiceName(msg.fileName) &&
        shape == FileShape.video;
    final frameless = isImage || isVideo;
    // a file's preview reaches the bubble's edges, as a photo does
    final fileBleed =
        !frameless &&
        msg.making == null &&
        !isVoiceName(msg.fileName) &&
        ((album?.tag.files ?? false) ||
            (album == null && msg.mediaPath == null && msg.filePath != null));
    final failedShown = _sendLooksFailed(msg);
    final parked = msg.parked && !msg.sending && !msg.failed;
    final pending = msg.sending || (msg.failed && !failedShown);
    // a finished media send means every slice was accepted somewhere, not
    // that it arrived: a relay taking the bytes is not the peer reading
    // them. so media shows its time and a clock until the receipt lands,
    // never a tick, then Delivered.
    final isMedia = msg.mediaPath != null || msg.filePath != null;
    final waitsAck = isMedia && !msg.delivered;
    final showMeta = isOut && !pending && !failedShown && !parked;
    // a photo, a video, a file or a voice note that came in says when, as
    // ours do: there is no text of it to place it by
    // a text of theirs says when on the last bubble of a run, as ours do
    final showTime = showMeta || (!isOut && (isMedia || lastInGroup));
    // the time is drawn on a run's last bubble; the ones above it keep
    // their tick. a file, a timer or an edit keeps its own
    final timeHere =
        lastInGroup ||
        isMedia ||
        msg.burnAt != null ||
        msg.edited ||
        parked ||
        unconfirmed;
    // ours kept until it can go says so in its bubble: its time and a clock
    final showStamp = (showTime || (isOut && parked)) && !frameless;
    // a set of files shows each row's own ring: no pill under it
    final showPill = isOut && pending && !(album?.tag.files ?? false);
    final reacted = msg.reactions.isNotEmpty;
    final roomTime = motionStill(context) ? Duration.zero : kHouseTime;
    // full ink for 4.5:1 on every accent: the small mono size keeps it
    // behind the message
    final metaColor = (isOut && !frameless)
        ? HaloColors.onAmber
        : HaloColors.text;
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
      // insertion ordered, so drop the oldest and it never grows unbounded
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
    // a computer: tab reaches it, the menu key opens its menu
    return DeskMenuFocus(
      onMenu: onLongPress == null ? null : () => onLongPress!(context),
      child: AnimatedOpacity(
        duration: Duration(milliseconds: isExpiring ? 440 : 250),
        curve: Curves.easeOut,
        opacity: dimmed ? 0.4 : 1.0,
        child: ReactTaps(
          behavior: HitTestBehavior.opaque,
          onTap: (failedShown || parked) && onRetry != null
              ? () => onRetry!(msg)
              : onReveal,
          // a failed bubble's retry is at once, and takes no reaction
          onReact: (failedShown || parked) && onRetry != null
              ? null
              : onDoubleReact,
          onLongPress: onLongPress == null ? null : () => onLongPress!(context),
          // a right click on a computer opens the same menu
          onSecondaryTap: !onDesktop || onLongPress == null
              ? null
              : () => onLongPress!(context),
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
                        padding: EdgeInsets.only(
                          bottom: reacted ? kChipRoom : 0,
                        ),
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
                                    topStart: Radius.circular(corner),
                                    topEnd: Radius.circular(corner),
                                    bottomStart: Radius.circular(
                                      isOut
                                          ? corner
                                          : (lastInGroup ? 4 : corner),
                                    ),
                                    bottomEnd: Radius.circular(
                                      isOut
                                          ? (lastInGroup ? 4 : corner)
                                          : corner,
                                    ),
                                  ),
                                  border: searchRing(isCurrentMatch),
                                  boxShadow: searchGlow(isCurrentMatch),
                                ),
                                clipBehavior: frameless || fileBleed
                                    ? Clip.antiAlias
                                    : Clip.none,
                                child: fileBubbleFrame(
                                  context,
                                  on: fileBleed,
                                  top: quotedText == null,
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
                                                    ? HaloColors.onAmber
                                                          .withValues(
                                                            alpha: 0.1,
                                                          )
                                                    : HaloColors.amber
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                              child: IntrinsicHeight(
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  mainAxisSize:
                                                      MainAxisSize.max,
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
                                                                style:
                                                                    _quoteStyle(
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
                                                                style:
                                                                    _quoteStyle(
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
                                        // here before its file: a card that
                                        // brings it, in place of the file
                                        if (album == null &&
                                            !isOut &&
                                            fileWaitOf(msg.msgUid) != null)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: FileWaitOr(
                                              uid: msg.msgUid,
                                              fileName: msg.fileName,
                                              onGet: appState.downloadNow,
                                              onPause: appState.pauseDownload,
                                              child: () =>
                                                  const SizedBox.shrink(),
                                            ),
                                          )
                                        else if (album case final run?
                                            when run.tag.files)
                                          _fileStack(context, run)
                                        else if (album case final run?)
                                          SpoilerCover(
                                            uid: run.anchor.msgUid,
                                            on: run.present.any(
                                              (x) => x.spoiler,
                                            ),
                                            radius: BorderRadius.circular(
                                              corner,
                                            ),
                                            child: _grid(
                                              context,
                                              run,
                                              stamp: _mediaCorner(
                                                msg,
                                                showMeta: showTime,
                                                failedShown: failedShown,
                                                parked: parked,
                                                word: newestOut,
                                              ),
                                              corner: corner,
                                            ),
                                          )
                                        else if (msg.making != null)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: VoiceMakingBubble(
                                              progress: msg.making!,
                                              isOut: isOut,
                                            ),
                                          )
                                        else if (isVoiceName(msg.fileName) &&
                                            msg.filePath != null)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                VoiceBubble(
                                                  key: ValueKey(
                                                    _voiceKeyOf(msg),
                                                  ),
                                                  path: msg.filePath!,
                                                  isOut: isOut,
                                                  disguised: msg.voiceDisguised,
                                                  onPlay: onAct,
                                                  playKey: _voiceKeyOf(msg),
                                                  next: voiceAfter == null
                                                      ? null
                                                      : () => voiceAfter!(msg),
                                                ),
                                                VoiceTranscript(
                                                  chat: transcripts,
                                                  uid: msg.msgUid,
                                                  path: msg.filePath!,
                                                  isOut: isOut,
                                                  translation: translation,
                                                ),
                                              ],
                                            ),
                                          )
                                        else if (msg.filePath != null &&
                                            shape == FileShape.video)
                                          VideoBubble(
                                            key: ValueKey(
                                              'vid_${msg.filePath}',
                                            ),
                                            path: msg.filePath!,
                                            fileName: msg.fileName!,
                                            width:
                                                (MediaQuery.of(
                                                          context,
                                                        ).size.width *
                                                        0.66)
                                                    .clamp(180.0, 300.0),
                                            onOpen: () {
                                              onAct?.call();
                                              openVideo(
                                                context,
                                                path: msg.filePath!,
                                                fileName: msg.fileName,
                                                kept: kept,
                                              );
                                            },
                                            stamp: _mediaCorner(
                                              msg,
                                              showMeta: showTime,
                                              failedShown: failedShown,
                                              parked: parked,
                                              word: newestOut,
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
                                                  kept: kept,
                                                  from: fromName,
                                                  heroTag: fileHeroTag(
                                                    msg.filePath!,
                                                    'chat',
                                                  ),
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                              child: fileCard(
                                                msg.filePath,
                                                msg.fileName,
                                                isOut,
                                                shape: shape,
                                                sendingUid: isOut && msg.sending
                                                    ? msg.msgUid
                                                    : null,
                                                heroTag: msg.filePath == null
                                                    ? null
                                                    : fileHeroTag(
                                                        msg.filePath!,
                                                        'chat',
                                                      ),
                                                from: fromName,
                                                kept: kept,
                                                glance: known,
                                                failed: msg.failed,
                                                when: msg.when,
                                                upNext: soundsAfter == null
                                                    ? null
                                                    : () => soundsAfter!(msg),
                                                onCancel: onStop == null
                                                    ? null
                                                    : () => onStop!(msg),
                                              ),
                                            ),
                                          ),
                                        if (album == null &&
                                            msg.mediaPath != null &&
                                            (isOut ||
                                                fileWaitOf(msg.msgUid) == null))
                                          SpoilerCover(
                                            uid: msg.msgUid,
                                            on: msg.spoiler,
                                            radius: BorderRadius.circular(
                                              corner,
                                            ),
                                            child: PressScale(
                                              scale: 0.97,
                                              haptic: false,
                                              onTap: () {
                                                onAct?.call();
                                                final tag = photoHeroTag(
                                                  msg.mediaPath!,
                                                  'chat',
                                                );
                                                if (openMedia?.call(
                                                      context,
                                                      msg,
                                                      tag,
                                                    ) ??
                                                    false) {
                                                  return;
                                                }
                                                _openFullImage(
                                                  context,
                                                  msg.mediaPath!,
                                                  secure: msg.secure,
                                                  tag: tag,
                                                  radius: corner,
                                                );
                                              },
                                              // said as a photo from the start,
                                              // before the picture has faded up
                                              child: Semantics(
                                                image: true,
                                                label: l10n.appPhoto,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      msg.text.isNotEmpty
                                                      ? BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            corner,
                                                          ),
                                                        )
                                                      : BorderRadius.circular(
                                                          14,
                                                        ),
                                                  child: Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      // the photo's own shape, its blur
                                                      // the same, before the file decodes
                                                      PhotoShape(
                                                        path: msg.mediaPath!,
                                                        image: mediaImage(
                                                          msg.mediaPath!,
                                                          screenPx(
                                                            context,
                                                            times: 0.78,
                                                          ),
                                                        ),
                                                        maxWidth: photoMaxWidth(
                                                          context,
                                                        ),
                                                        child: HaloHero(
                                                          tag: photoHeroTag(
                                                            msg.mediaPath!,
                                                            'chat',
                                                          ),
                                                          child: ChatPicture(
                                                            path:
                                                                msg.mediaPath!,
                                                            // its blur at once,
                                                            // the photo fading up
                                                            // over it once decoded
                                                            child: SealedPicture(
                                                              path: msg
                                                                  .mediaPath!,
                                                              shaped: false,
                                                              decodeWidth:
                                                                  screenPx(
                                                                    context,
                                                                    times: 0.78,
                                                                  ),
                                                              image: mediaImage(
                                                                msg.mediaPath!,
                                                                screenPx(
                                                                  context,
                                                                  times: 0.78,
                                                                ),
                                                              ),
                                                              errorBuilder: (_, e, _) {
                                                                dlog(
                                                                  'image failed: '
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
                                                                        size:
                                                                            22,
                                                                        color: HaloColors
                                                                            .text2,
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            6,
                                                                      ),
                                                                      Text(
                                                                        l10n.chatPhotoUnavailable,
                                                                        style: HaloType.mono(
                                                                          size:
                                                                              11,
                                                                          color:
                                                                              HaloColors.text2,
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
                                                      // ours on its way: a ring
                                                      // that fills with the bytes
                                                      if (isOut &&
                                                          msg.sending &&
                                                          msg.msgUid != null)
                                                        Positioned.fill(
                                                          child: MediaSendRing(
                                                            uid: msg.msgUid!,
                                                          ),
                                                        ),
                                                      PositionedDirectional(
                                                        end: 8,
                                                        bottom: 8,
                                                        child: _mediaCorner(
                                                          msg,
                                                          showMeta: showTime,
                                                          failedShown:
                                                              failedShown,
                                                          parked: parked,
                                                          word: newestOut,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        PhotoLedWidth(
                                          // a caption wraps at its photo's width
                                          on:
                                              msg.mediaPath != null &&
                                              album == null,
                                          child: Padding(
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
                                                  (msg.mediaPath != null ||
                                                      (album?.tag.files ??
                                                          false))
                                                  ? CrossAxisAlignment.start
                                                  : CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // the time and tick sit at the end of the
                                                // last line when they fit, else under it.
                                                // they grow in as the sending pill folds
                                                MetaFlow(
                                                  textDirection: writtenDir(
                                                    msg.text,
                                                  ),
                                                  body: Column(
                                                    crossAxisAlignment:
                                                        (msg.mediaPath !=
                                                                null ||
                                                            (album?.tag.files ??
                                                                false))
                                                        ? CrossAxisAlignment
                                                              .start
                                                        : CrossAxisAlignment
                                                              .end,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (msg.text.isNotEmpty)
                                                        MetaAnchor(
                                                          child: DeskSelectable(
                                                            // a click on these words is the bubble's while it retries
                                                            enabled:
                                                                !((failedShown ||
                                                                        parked) &&
                                                                    onRetry !=
                                                                        null),
                                                            onMenu:
                                                                onLongPress ==
                                                                    null
                                                                ? null
                                                                : () =>
                                                                      onLongPress!(
                                                                        context,
                                                                      ),
                                                            onTap: onReveal,
                                                            child: writtenStart(
                                                              msg.text,
                                                              TranslatedBody(
                                                                chat:
                                                                    translation,
                                                                msgKey: trKeyOf(
                                                                  msg.msgUid,
                                                                  msg.came,
                                                                ),
                                                                came: msg.came,
                                                                text: msg.text,
                                                                enabled:
                                                                    !isOut &&
                                                                    query
                                                                        .isEmpty &&
                                                                    msg.sticker ==
                                                                        null &&
                                                                    !msg.welcome,
                                                                original: _body(
                                                                  isOut,
                                                                  image:
                                                                      msg.mediaPath !=
                                                                      null,
                                                                ),
                                                                translated:
                                                                    (
                                                                      t,
                                                                    ) => _body(
                                                                      isOut,
                                                                      image:
                                                                          msg.mediaPath !=
                                                                          null,
                                                                      words: t,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      if (msg.url case final u?
                                                          when !plainLinks) ...[
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        LinkStub(
                                                          url: u,
                                                          isOut: isOut,
                                                          title: linkTitle,
                                                          bySender:
                                                              linkBySender,
                                                        ),
                                                      ],
                                                      if (msg.place
                                                          case final p?
                                                          when !plainLinks) ...[
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        PlaceStub(
                                                          place: p,
                                                          isOut: isOut,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  meta: GrowSwap(
                                                    child: !showStamp
                                                        ? const SizedBox.shrink(
                                                            key: ValueKey(
                                                              'no-meta',
                                                            ),
                                                          )
                                                        : KeyedSubtree(
                                                            key: const ValueKey(
                                                              'meta',
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                if (msg
                                                                    .secure) ...[
                                                                  Icon(
                                                                    Icons
                                                                        .shield_rounded,
                                                                    size: 10,
                                                                    color:
                                                                        metaColor,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                ],
                                                                if (!timeHere)
                                                                  // read out on every bubble, drawn on a run's last
                                                                  Semantics(
                                                                    label: _fmtTime(
                                                                      msg.when,
                                                                    ),
                                                                    child:
                                                                        const SizedBox.shrink(),
                                                                  )
                                                                else
                                                                  Text(
                                                                    _fmtTime(
                                                                      msg.when,
                                                                    ),
                                                                    style: TextStyle(
                                                                      fontFamily:
                                                                          HaloType
                                                                              .monoFamily,
                                                                      fontFamilyFallback:
                                                                          HaloType
                                                                              .monoFallbackNow,
                                                                      fontSize:
                                                                          9,
                                                                      color:
                                                                          metaColor,
                                                                      letterSpacing:
                                                                          track(
                                                                            0.4,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                if (isOut &&
                                                                    msg.edited) ...[
                                                                  const SizedBox(
                                                                    width: 5,
                                                                  ),
                                                                  Text(
                                                                    l10n.chatEdited,
                                                                    style: TextStyle(
                                                                      fontFamily:
                                                                          HaloType
                                                                              .monoFamily,
                                                                      fontFamilyFallback:
                                                                          HaloType
                                                                              .monoFallbackNow,
                                                                      fontSize:
                                                                          9,
                                                                      color:
                                                                          metaColor,
                                                                      fontStyle:
                                                                          slant(),
                                                                      letterSpacing:
                                                                          track(
                                                                            0.4,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ],
                                                                if (isOut) ...[
                                                                  if (timeHere ||
                                                                      msg.edited ||
                                                                      msg.secure)
                                                                    const SizedBox(
                                                                      width: 3,
                                                                    ),
                                                                  _outMark(
                                                                    context,
                                                                    msg,
                                                                    unconfirmed:
                                                                        unconfirmed ||
                                                                        waitsAck,
                                                                    waits:
                                                                        parked,
                                                                    color:
                                                                        metaColor,
                                                                    word:
                                                                        newestOut,
                                                                  ),
                                                                ],
                                                                // theirs keep the countdown on its own line
                                                                if (isOut &&
                                                                    msg.burnAt !=
                                                                        null) ...[
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  Icon(
                                                                    Icons
                                                                        .local_fire_department_outlined,
                                                                    size: 11,
                                                                    color:
                                                                        metaColor,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 2,
                                                                  ),
                                                                  Text(
                                                                    _fmtBurn(
                                                                      msg.burnAt!,
                                                                    ),
                                                                    style: HaloType.mono(
                                                                      size: 9.5,
                                                                      color:
                                                                          metaColor,
                                                                      weight: FontWeight
                                                                          .w600,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
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
                                                      fontFamily:
                                                          HaloType.monoFamily,
                                                      fontFamilyFallback:
                                                          HaloType
                                                              .monoFallbackNow,
                                                      fontSize: 9,
                                                      color:
                                                          HaloColors.amberText,
                                                      fontStyle: slant(),
                                                      letterSpacing: track(0.4),
                                                    ),
                                                  ),
                                                ],

                                                // a sent photo has no meta row, so its
                                                // countdown lives here like an incoming one.
                                                // one not read yet shows its whole window
                                                if (msg.burnLabel
                                                    case final burn?
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
                                                    l10n.chatFailedTapToRetryShown,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          HaloType.monoFamily,
                                                      fontFamilyFallback:
                                                          HaloType
                                                              .monoFallbackNow,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                        ),
                                      ],
                                    ),
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
                                                  topStart: Radius.circular(
                                                    corner,
                                                  ),
                                                  topEnd: Radius.circular(
                                                    corner,
                                                  ),
                                                  bottomStart: Radius.circular(
                                                    isOut
                                                        ? corner
                                                        : (lastInGroup
                                                              ? 4
                                                              : corner),
                                                  ),
                                                  bottomEnd: Radius.circular(
                                                    isOut
                                                        ? (lastInGroup
                                                              ? 4
                                                              : corner)
                                                        : corner,
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
                              color: HaloColors.text,
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
                                // an album's tiles show their own
                                // a file card shows its own in its ring, a voice
                                // note has none
                                if (album == null &&
                                    msg.msgUid != null &&
                                    (msg.mediaPath != null ||
                                        (msg.filePath != null &&
                                            (shape != FileShape.card ||
                                                isVoiceName(
                                                  msg.fileName,
                                                ))))) ...[
                                  SendProgressLabel(msgUid: msg.msgUid!),
                                  const SizedBox(width: 6),
                                ],
                                SendPill(
                                  mode: _pmFrom(appState.sendMode),
                                  waiting: waitsAccept,
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
    );
  }

  // files sent together: a row each, as each would draw alone
  Widget _fileStack(BuildContext context, AlbumRun<_Msg> run) {
    final isOut = msg.direction == 'out';
    final hold = onLongPressTile;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: FileStack(
        isOut: isOut,
        onGet: appState.downloadNow,
        onPause: appState.pauseDownload,
        rows: [
          for (final (i, x) in run.drawn.indexed)
            if (x != null)
              _stackRow(
                context,
                x,
                hold == null ? null : () => hold(context, i),
              ),
        ],
      ),
    );
  }

  FileStackRow _stackRow(BuildContext context, _Msg x, VoidCallback? hold) {
    final isOut = x.direction == 'out';
    final path = x.filePath;
    final shape = fileShapeNow(path, x.fileName);
    return FileStackRow(
      id: x.msgUid ?? 'r${x.rowid}',
      name: x.fileName,
      waitUid: isOut ? null : x.msgUid,
      until: x.when.add(kFileKeptFor),
      failed: isOut && _sendLooksFailed(x),
      onRetry: onRetry == null ? null : () => onRetry!(x),
      onLongPress: hold,
      spoiler: x.spoiler,
      ready: () => path != null && shape == FileShape.video && !x.sending
          ? VideoBubble(
              key: ValueKey('vid_$path'),
              path: path,
              fileName: x.fileName!,
              width: kFilePreviewWidth,
              onOpen: () {
                onAct?.call();
                openVideo(
                  context,
                  path: path,
                  fileName: x.fileName,
                  kept: kept,
                );
              },
            )
          : PressScale(
              scale: 0.97,
              haptic: false,
              onTap: () {
                onAct?.call();
                if (path != null) {
                  openReceivedFile(
                    context,
                    path,
                    x.fileName,
                    kept: kept,
                    from: fromName,
                    heroTag: fileHeroTag(path, 'chat'),
                  );
                }
              },
              child: fileCard(
                path,
                x.fileName,
                isOut,
                shape: shape,
                sendingUid: isOut && x.sending ? x.msgUid : null,
                heroTag: path == null ? null : fileHeroTag(path, 'chat'),
                from: fromName,
                kept: kept,
                glance: known,
                queued: true,
                failed: x.failed,
                when: x.when,
                upNext: soundsAfter == null ? null : () => soundsAfter!(x),
                onCancel: onStop == null ? null : () => onStop!(x),
              ),
            ),
    );
  }

  // the album's grid: a tile a place, each opening the viewer at itself
  Widget _grid(
    BuildContext context,
    AlbumRun<_Msg> run, {
    required Widget stamp,
    required double corner,
  }) {
    final shown = run.drawn;
    final w = (MediaQuery.sizeOf(context).width * 0.72).clamp(200.0, 340.0);
    final hold = onLongPressTile;
    return AlbumGrid(
      tiles: [for (final x in shown) x == null ? null : _tileOf(x)],
      width: w,
      captioned: msg.text.isNotEmpty,
      radius: corner,
      stamp: stamp,
      onOpen: (i) {
        onAct?.call();
        final x = i < shown.length ? shown[i] : null;
        if (x != null && (openMedia?.call(context, x, null) ?? false)) return;
        _openAlbumAt(context, shown, i);
      },
      onGet: appState.downloadNow,
      onPause: appState.pauseDownload,
      onLongPress: hold == null ? null : (i) => hold(context, i),
    );
  }

  static AlbumTile _tileOf(_Msg x) => AlbumTile(
    path: x.mediaPath ?? x.filePath,
    video: x.mediaPath == null && x.filePath != null,
    lost: !x.preparing && x.mediaPath == null && x.filePath == null,
    sendingUid: x.direction == 'out' && x.sending ? x.msgUid : null,
    waitUid: x.direction == 'in' && fileWaitOf(x.msgUid) != null
        ? x.msgUid
        : null,
  );

  TextStyle _quoteStyle(bool isOut) => HaloType.sans(
    size: 12.5,
    color: isOut ? HaloColors.onAmber : HaloColors.text,
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
    // a computer: tab reaches it, the menu key opens its menu
    return DeskMenuFocus(
      onMenu: onLongPress == null ? null : () => onLongPress!(context),
      child: AnimatedOpacity(
        duration: Duration(milliseconds: isExpiring ? 440 : 250),
        curve: Curves.easeOut,
        opacity: dimmed ? 0.4 : 1.0,
        child: ReactTaps(
          behavior: HitTestBehavior.opaque,
          onReact: retry != null ? null : onDoubleReact,
          onLongPress: onLongPress == null ? null : () => onLongPress!(context),
          // a right click on a computer opens the same menu
          onSecondaryTap: !onDesktop || onLongPress == null
              ? null
              : () => onLongPress!(context),
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
                                      word: newestOut,
                                      burn: burn,
                                      burnWaits: msg.burnWaits,
                                      alert: failedShown
                                          ? l10n.chatFailedTapToRetryShown
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
                                          borderRadius: BorderRadius.circular(
                                            28,
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
                            child: SendPill(
                              mode: _pmFrom(appState.sendMode),
                              waiting: waitsAccept,
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
              color: HaloColors.amberText,
              letterSpacing: track(0.4),
            ),
          ),
        ),
      ],
    );
  }
}

// the corners of a photo or an album sent with a caption, flatter than a
// text bubble's
@visibleForTesting
const kCaptionCorner = 10.0;

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
                    color: HaloColors.amberText,
                    letter: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                if (target.sticker case final st?)
                  StickerLine(
                    st,
                    style: HaloType.sans(
                      size: 13,
                      color: HaloColors.text,
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
                      color: HaloColors.text,
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
  const _EmptyConversation({super.key});
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
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: HaloColors.amber,
                  size: 25,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.chatSayHi,
                textAlign: TextAlign.center,
                style: HaloType.serif(
                  size: 24,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              ...[
                const SizedBox(height: 8),
                Text(
                  l10n.chatJustTheTwoOf,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text,
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
  final VoidCallback onSend;
  // held send: the same words, posted without sound on their side
  final VoidCallback? onSendSilent;
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
  // photos, files, the camera and voice notes: off in a request to a
  // stranger until they accept
  final bool media;
  // the voice note's mic, where media is on
  final bool voice;
  // files wait in the row above: send shows with nothing typed
  final bool staged;

  const _Composer({
    this.media = true,
    this.staged = false,
    required this.controller,
    this.focusNode,
    required this.onSend,
    this.onSendSilent,
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
    this.voice = true,
  });

  @override
  Widget build(BuildContext context) {
    // a phone whose identity has moved has no engine running: a message
    // typed here would sit in the outbox for good. nowhere to type it.
    if (appState.movedAway) return const MovedStrip();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: onDesktop
          ? const EdgeInsets.fromLTRB(20, 12, 20, 16)
          : const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                                    color: HaloColors.amberText,
                                    italic: true,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' · ${l10n.chatMessagesBurnAfter(_humanBurn(burnSeconds))}',
                                  style: HaloType.mono(
                                    size: 10.5,
                                    color: HaloColors.text,
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
                label: ghost
                    ? '${l10n.chatTimedMessages}, ${burnShort(burnSeconds)}'
                    : l10n.chatTimedMessages,
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
              // how long, beside the flame while it is on
              FlameTime(on: ghost, secs: burnSeconds),
              // the shield toggle stays hidden until it is verified end to
              // end. the flag, the wire and the viewer are all in place.
              const SizedBox(width: 1),
              // the camera that keeps its photos inside kryfo. each icon
              // sits in a finger-sized box, so a tap between them lands
              if (!onDesktop && media)
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
              if (media)
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
                )
              else
                const SizedBox(width: 8),
              const SizedBox(width: 1),
              Expanded(
                child: WrittenDir(
                  controller: controller,
                  builder: (dir) => EnterSends(
                    controller: controller,
                    onSend: onSend,
                    child: ShiftTapGuard(
                      controller: controller,
                      child: TextField(
                        controller: controller,
                        enableIMEPersonalizedLearning: false,
                        focusNode: focusNode,
                        textDirection: dir,
                        inputFormatters: const [UnmarkedInput()],
                        cursorColor: HaloColors.amber,
                        style: HaloType.sans(size: 14),
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hint: ComposerHint(l10n.chatMessage),
                          // stickers sit inside the field: no width taken from the row
                          suffixIcon: StickerButton(onTap: onStickers),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 36,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: onDesktop ? 16 : 14,
                            vertical: onDesktop ? 13 : 10,
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
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final still = motionStill(context);
                  final hasText = value.text.trim().isNotEmpty || staged;
                  // a send still grinding takes the next one behind it
                  final canSend = hasText;
                  // mic and send trade places with a small pop instead of a cut
                  final Widget end = !hasText && media && voice
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
                          // held: "Send without sound"
                          child: SendHold(
                            onSilent: canSend ? onSendSilent : null,
                            child: PressScale(
                              label: l10n.commonSend,
                              onTap: canSend ? onSend : null,
                              scale: 0.86,
                              haptic:
                                  false, // _send already fires its own impact
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
                                              color: HaloColors.amber
                                                  .withValues(alpha: 0.35),
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
                          ),
                        );
                  // with reduced motion, a crossfade and nothing that grows
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

// the saved mode string as the pill's enum. private is full tor, 3 hops.
PrivacyMode _pmFrom(String m) =>
    m == 'private' ? PrivacyMode.private : PrivacyMode.fast;

/// whose pdf a bubble may draw a first page of unasked: an accepted
/// contact this phone holds, or the developer's chat, not blocked, even
/// before the chat's own reads answered
@visibleForTesting
bool pdfPeerKnown(
  String peer,
  Iterable<ContactPreview> contacts, {
  required bool accepted,
  required bool blocked,
}) =>
    !blocked &&
    // the developer's chat on a user's phone is no stranger's; his inbox
    // chats on his own phone are, and keep the tile
    (isDevChat(peer) ||
        accepted && contacts.any((c) => c.haloId == peer && !c.blocked));

// shown at the top of a chat when a known contact's identity key changed.
// a reinstall looks the same as an attack, so we prompt to verify instead
// of alarming. ok dismisses until the key changes again.
// the accept's word to them was tried as long as it is and never got
// through: a plain line, and a way to send it again
class _AckLostLine extends StatelessWidget {
  final VoidCallback onRetry;
  const _AckLostLine({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.chatTheyMayNotKnow,
              style: HaloType.sans(
                size: 12.5,
                weight: FontWeight.w500,
                color: HaloColors.text,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            child: _ScaleTap(
              onTap: onRetry,
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  l10n.commonTryAgain,
                  maxLines: 1,
                  style: HaloType.sans(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: HaloColors.onAmber,
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
              color: HaloColors.text,
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
