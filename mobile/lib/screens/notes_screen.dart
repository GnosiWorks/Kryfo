// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../album.dart' show kPickMax;
import '../desktop/attach_tray.dart';
import '../desktop/drag_in.dart' show kDragInMost;
import '../file_save.dart' show saveReceivedFile;
import '../lock_guard.dart' show LockDropped;
import '../lock_state.dart' show lockState;
import '../msg_order.dart' show rowWrittenAt;
import '../notes_add.dart';
import '../picked.dart';
import '../sent_name.dart' show madeVideoName;
import '../widgets/attach_grid.dart';
import '../widgets/note_media.dart';
import '../widgets/photo_shape.dart' show PhotoLedWidth, photoMaxWidth;
import '../widgets/voice_mic.dart' show HoldToTalkMic, VoiceTake;
import '../gifs/gif_engine.dart' show appGifTabs;
import '../stickers/sticker_pack.dart' show StickerLibrary;
import '../stickers/sticker_sheet.dart'
    show GifPick, PhoneGifPick, StickerButton, StickerPick, showStickerSheet;
import '../stickers/sticker_wire.dart' show StickerWire;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'camera_screen.dart';
import 'media_send_screen.dart';
import '../widgets/desk_menu.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/chat_parts.dart' show DayChip;
import '../widgets/confirm_sheet.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/message_menu.dart' show MenuSheet, MenuSheetRow;
import '../widgets/motion.dart' show haloRoute, motionStill;
import '../widgets/page_head.dart' show PageBar;
import '../widgets/stagger_in.dart';
import '../widgets/breathing_ring.dart';
import '../widgets/press_scale.dart';
import '../widgets/row_motion.dart' show GrowIn;
import '../widgets/swap.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../widgets/written_field.dart';
import '../widgets/ease_size.dart';
import '../bidi_safe.dart';
import '../widgets/shift_tap_guard.dart';
import '../widgets/enter_sends.dart';
import '../desktop/desktop_mode.dart' show onDesktop;
import '../desktop/drag_in.dart' show DragInZone, draggedFiles;
import '../dlog.dart';
import 'notes_export_screen.dart';
import '../wide/read_width.dart' show DeskPage;

const String kNotesPeerId = '_notes_self_';

/// the files a paste names: each line a path or a file link to a file that
/// is there, as a computer's file manager copies them. none when any line
/// is something else, so words paste as words
@visibleForTesting
List<String> pastedFiles(String? text) {
  final lines = [
    for (final l in (text ?? '').split(RegExp(r'[\r\n]+')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (lines.isEmpty || lines.length > kDragInMost) return const [];
  final paths = <String>[];
  for (final l in lines) {
    String path = l;
    if (l.startsWith('file://')) {
      try {
        path = Uri.parse(l).toFilePath();
      } catch (_) {
        return const [];
      }
    }
    if (!File(path).isAbsolute) return const [];
    paths.add(path);
  }
  final files = draggedFiles(paths);
  return files.length == paths.length ? files : const [];
}

/// the clock the notes are sorted under their headings by
@visibleForTesting
DateTime Function() notesNow = DateTime.now;

/// the heading a note written [at] sits under, seen [now]: 'today',
/// 'yesterday', 'week' for earlier this week (from the language's first
/// day of it, or [weekStart]), else its month as 'year-month'. days are
/// the calendar's, so a clock change or midnight moves nothing early
String noteSection(DateTime at, DateTime now, {int? weekStart}) {
  int day(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  final that = day(at), today = day(now);
  if (that >= today) return 'today';
  if (that == today - 1) return 'yesterday';
  final first = weekStart ?? weekStartDay();
  if (that >= today - (now.weekday - first) % 7) return 'week';
  return '${at.year}-${at.month}';
}

/// the words of a heading from [noteSection]
String noteSectionLabel(String section) => switch (section) {
  'today' => l10n.chatToday,
  'yesterday' => l10n.chatYesterday,
  'week' => l10n.notesThisWeek,
  _ => monthYear(
    DateTime(
      int.parse(section.split('-').first),
      int.parse(section.split('-').last),
    ),
  ),
};

// the time under a note: its day too once the heading does not say it
String _noteTime(DateTime at, String section) => switch (section) {
  'today' || 'yesterday' => hourMinute(at),
  'week' => weekdayTime(at),
  _ => dayMonthTime(at),
};

// note to self: stored as messages under the reserved kNotesPeerId, words
// and what a chat can hold besides (notes_add.dart). with devices of mine
// linked it is on each of them (notes_own_app.dart), else on this phone
// alone. the newest sits on the bar, as in a chat, and a new one grows up
// from it
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _input = TextEditingController();
  List<Map<String, Object?>> _notes = [];
  // nothing is drawn until the first load: the empty page is for no notes,
  // not for notes still on their way
  bool _loaded = false;
  // the notes on screen before the last load: any other one is new
  Set<Object>? _had;
  // deleted notes fold away before the list reloads
  final Set<Object> _leaving = {};
  // how far the notes run up under the bar, for its hairline
  final _under = ValueNotifier<double>(0);
  // a note can be held: said under the notes until the first hold, in each
  // identity's own notes
  static const _kHoldTold = 'notes_hold_told';
  late final String _holdKey = session.container.key(_kHoldTold);
  bool _holdTold = true;
  // long notes opened past their fold, by note. in memory only
  final Set<Object> _open = {};
  // the heading held at the top of the list and how far the next one has
  // pushed it up
  final _pin = ValueNotifier<(String?, double)>((null, 0));
  // what the pin is worked out from: the list, the held chip, the rows
  // built, and per note its heading
  BuildContext? _listCtx;
  BuildContext? _pinCtx;
  final Map<Object, BuildContext> _rows = {};
  Map<Object, int> _indexOf = {};
  List<String> _sections = [];
  bool _pinQueued = false;
  // my other devices have these notes too: the lines say so
  bool _shared = false;
  // an item being made ready: the bar takes no other until it is in
  bool _adding = false;
  // files dropped or pasted on a computer wait in a row above the bar
  // until enter keeps them, as in a chat. the row is this container's
  late final AttachTray _tray = DeskTrays.of('${session.container.id}|notes');

  @override
  void initState() {
    super.initState();
    _load();
    notesMoved.addListener(_load);
    _tray.addListener(_trayMoved);
    _readShared();
    SharedPreferences.getInstance().then((p) {
      if (mounted && p.getBool(_holdKey) != true) {
        setState(() => _holdTold = false);
      }
    });
  }

  Future<void> _readShared() async {
    if (ownSync == null) return;
    final on = await notesApp.ownNotesShared();
    if (mounted && on != _shared) setState(() => _shared = on);
  }

  void _heldOnce() {
    if (_holdTold) return;
    setState(() => _holdTold = true);
    SharedPreferences.getInstance().then((p) => p.setBool(_holdKey, true));
  }

  // every note at once, asked first, folding away together
  Future<void> _deleteAll() async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.notesDeleteAllTitle,
      line: !_shared
          ? l10n.notesDeleteAllLineShown
          // a linked device's clear stays on it, as a chat's does
          : linkedRole
          ? l10n.notesDeleteAllHereOnly
          : l10n.notesDeleteAllEverywhere,
      yes: l10n.notesDeleteAllYes,
    );
    if (!ok || !mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _leaving.addAll(_notes.map(_key)));
    await deleteAllNotes();
    await Future.delayed(FadeFold.gone);
    if (!mounted) return;
    _leaving.clear();
    await _load();
  }

  void _pageMenu() {
    showHaloSheet<String>(
      context,
      scroll: true,
      builder: (ctx) => SingleChildScrollView(
        child: MenuSheet(
          groups: [
            if (notesExportHere())
              [
                MenuSheetRow(
                  icon: Icons.ios_share_rounded,
                  label: l10n.notesExportNotes,
                  onTap: () => Navigator.pop(ctx, 'export'),
                ),
              ],
            [
              MenuSheetRow(
                icon: Icons.delete_sweep_outlined,
                label: l10n.notesDeleteAll,
                danger: true,
                onTap: () => Navigator.pop(ctx, 'all'),
              ),
            ],
          ],
        ),
      ),
    ).then((a) {
      if (!mounted) return;
      if (a == 'all') _deleteAll();
      // asked again: the session may have changed under the sheet
      if (a == 'export' && notesExportHere()) {
        Navigator.of(context).push(haloRoute(const NotesExportScreen()));
      }
    });
  }

  @override
  void dispose() {
    notesMoved.removeListener(_load);
    // the row stays with the notes for their next opening
    _tray.removeListener(_trayMoved);
    _input.dispose();
    _under.dispose();
    _pin.dispose();
    super.dispose();
  }

  // the list starts at the bottom, so what is above the bar is the extent
  // after, not the offset
  bool _track(Notification n) {
    final m = switch (n) {
      ScrollNotification(depth: 0, :final metrics) => metrics,
      ScrollMetricsNotification(depth: 0, :final metrics) => metrics,
      _ => null,
    };
    if (m != null) {
      _under.value = m.extentAfter;
      _queuePin();
    }
    return false;
  }

  // the rows have their places once the frame is laid out
  void _queuePin() {
    if (_pinQueued) return;
    _pinQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pinQueued = false;
      if (mounted) _placePin();
    });
  }

  // the inline heading's room above its chip, and where the held chip sits
  static const _headPad = 8.0;
  static const _pinTop = 8.0;

  // the heading of the row under the top of the list is held there, and
  // the next heading up from below pushes it out
  void _placePin() {
    final list = _listCtx?.findRenderObject();
    if (list is! RenderBox || !list.attached || !list.hasSize) return;
    final top = list.localToGlobal(Offset.zero).dy;
    String? held;
    var best = double.negativeInfinity;
    double? next;
    _rows.forEach((id, ctx) {
      final i = _indexOf[id];
      final box = ctx.findRenderObject();
      if (i == null || box is! RenderBox || !box.attached || !box.hasSize) {
        return;
      }
      final head = i == 0 || _sections[i - 1] != _sections[i];
      final y = box.localToGlobal(Offset.zero).dy - top;
      final start = head ? y + _headPad : y;
      if (start <= _pinTop + 0.5) {
        if (start > best) {
          best = start;
          held = _sections[i];
        }
      } else if (head && (next == null || start < next!)) {
        next = start;
      }
    });
    final chip = _pinCtx?.findRenderObject();
    final h = chip is RenderBox && chip.hasSize ? chip.size.height : 0.0;
    final n = next;
    final push = held == null || n == null
        ? 0.0
        : math.min(0.0, n - (_pinTop + h + 6));
    _pin.value = (held, push);
    // the chip's height is known once it is drawn
    if (held != null && h == 0) _queuePin();
  }

  void _toggle(Object id) {
    setState(() {
      if (!_open.remove(id)) _open.add(id);
    });
  }

  static Object _key(Map<String, Object?> n) =>
      n['rowid'] ?? n['msg_uid'] ?? identityHashCode(n);

  Future<void> _load() async {
    final rows = await session.messagesFor(kNotesPeerId);
    if (!mounted) return;
    setState(() {
      _had = _notes.isEmpty && _had == null ? null : _notes.map(_key).toSet();
      _notes = rows;
      _loaded = true;
      final ids = rows.map(_key).toSet();
      _open.retainWhere(ids.contains);
    });
    if (rows.isEmpty) _under.value = 0;
  }

  Future<void> _save() async {
    if (onDesktop && !_tray.isEmpty) return _keepTray();
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // a uid, so the note can be found again to delete
    await keepNoteWords(text);
    _input.clear();
    await _load();
  }

  // ---- what a note holds besides words ----

  // one item made ready and kept, or the line why not. the bar waits for
  // it, and a lock that came meanwhile keeps nothing
  Future<void> _add(
    Future<NoteReady> Function() ready, {
    String caption = '',
  }) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final r = await ready();
      final item = r.item;
      if (item == null) {
        final line = r.line;
        if (line != null && mounted) showHaloToast(context, line);
        return;
      }
      if (lockState.locked || !mounted) {
        await shredFile(item.path);
        return;
      }
      await keepNoteItem(item, caption: caption);
      HapticFeedback.lightImpact();
      await _load();
    } catch (e) {
      dlog('notes: an item not added (${e.runtimeType})');
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _attach() {
    HapticFeedback.selectionClick();
    showHaloSheet<void>(
      context,
      builder: (sheetCtx) => AttachGrid(
        note: l10n.chatNoExifNeverSaved,
        items: [
          // a computer has no camera to open
          if (!onDesktop)
            AttachItem(
              icon: (c) => Icon(Icons.photo_camera_outlined, color: c),
              tint: HaloColors.amber,
              label: l10n.chatCamera,
              onTap: _camera,
            ),
          AttachItem(
            icon: (c) => Icon(Icons.photo_library_outlined, color: c),
            tint: HaloColors.violet,
            label: l10n.chatGalleryShown,
            onTap: _gallery,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.videocam_outlined, color: c),
            tint: HaloColors.rose,
            label: l10n.chatVideo,
            onTap: _video,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.gif_box_outlined, color: c),
            tint: HaloColors.violet,
            label: l10n.chatGifFromPhoneShown,
            onTap: _gif,
          ),
          AttachItem(
            icon: (c) => Icon(Icons.attach_file, color: c),
            tint: HaloColors.amber,
            label: l10n.chatFile2,
            onTap: _file,
          ),
        ],
      ),
    );
  }

  // the in-app camera: a stripped photo, or a clip cleaned as a file
  Future<void> _camera() async {
    final r = await Navigator.of(
      context,
    ).push<CaptureResult>(haloRoute<CaptureResult>(const CameraScreen()));
    if (r == null || !mounted) return;
    final photo = r.photo;
    if (photo != null) return _add(() => readyNotePhoto(photo));
    final path = r.videoPath;
    if (path == null) return;
    try {
      await _add(() => readyNoteFile(path, madeVideoName()));
    } finally {
      await shredCapture(path);
    }
  }

  // photos and videos through the send preview, its caption on the first
  Future<void> _gallery() async {
    final picked = await lockState.hold(pickGallery);
    if (picked.isEmpty || !mounted) return;
    await sendGalleryPicks(
      picked,
      pickMore: () => lockState.hold(pickGallery),
      preview: _preview,
      send: _keepPicked,
    );
  }

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
          max: kPickMax,
          onGone: (videos) => unawaited(shredPickedImages(videos)),
        ),
      ),
    );
  }

  Future<void> _keepPicked(MediaSendResult r) async {
    for (final (i, m) in r.items.indexed) {
      if (!mounted || lockState.locked) return;
      final caption = i == 0 ? r.caption : '';
      final v = m.video;
      final photo = m.photo;
      if (v != null) {
        await _add(
          () => readyNoteFile(v.path, madeVideoName(v.name)),
          caption: caption,
        );
      } else if (photo != null) {
        await _add(() => readyNotePhoto(photo), caption: caption);
      }
    }
  }

  // its own tile, as in a chat: without android's photo picker the
  // gallery is photos only
  Future<void> _video() async {
    final x = await lockState.hold(
      () => ImagePicker().pickVideo(source: ImageSource.gallery),
    );
    if (x == null) return;
    try {
      if (!mounted) return;
      await sendGalleryPicks(
        [x],
        videos: true,
        pickMore: () => lockState.hold(pickGallery),
        preview: _preview,
        send: _keepPicked,
      );
    } finally {
      await shredPickedImages([x]);
    }
  }

  // the chat's sheet: a sticker, a found gif, or a gif from this device
  Future<void> _stickers() async {
    final pick = await showStickerSheet(
      context,
      container: session.container,
      gifs: appGifTabs(),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (pick == null || !mounted) return;
    if (pick is GifPick) return _add(() => readyNoteGif(pick.bytes));
    if (pick is PhoneGifPick) return _gif();
    if (pick is! StickerPick) return;
    try {
      final lib = StickerLibrary.ready ?? await StickerLibrary.load();
      final pack = lib.pack(pick.ref.pack);
      final st = pack?.sticker(pick.ref.id);
      if (pack == null || st == null || !mounted) return;
      await keepNoteSticker(StickerWire.of(pack, st), st.emoji);
      HapticFeedback.lightImpact();
      await _load();
    } catch (e) {
      dlog('notes: a sticker not kept (${e.runtimeType})');
    }
  }

  Future<void> _gif() async {
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
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    if (res == null) return;
    final path = res.path;
    try {
      final data = path == null ? null : await File(path).readAsBytes();
      if (data != null) await _add(() => readyNoteGif(data));
    } finally {
      await shredPicked([res]);
    }
  }

  // any file: copied in from the picker's copy, never read whole
  Future<void> _file() async {
    final PlatformFile? res;
    try {
      res = await lockState.hold(() => FilePicker.pickFile(type: FileType.any));
    } on LockDropped {
      return;
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    if (res == null) return;
    final path = res.path;
    try {
      if (path != null) await _add(() => readyNoteFile(path, res!.name));
    } finally {
      await shredPicked([res]);
    }
  }

  void _trayMoved() {
    if (mounted) setState(() {});
  }

  // files dropped on the page, or pasted: they wait in the row, only read,
  // never moved
  void _stage(List<String> files) {
    unawaited(_tray.add(files, most: () async => kNoteFileMost));
  }

  // enter with files waiting: each kept as its own note in the order
  // staged, a photo as a photo and a gif as a gif, the words with the first
  Future<void> _keepTray() async {
    if (_adding) return;
    final caption = _input.text.trim();
    final items = _tray.take();
    _input.clear();
    for (final (i, x) in items.indexed) {
      if (!mounted || lockState.locked) return;
      await _add(() => _readyStaged(x), caption: i == 0 ? caption : '');
    }
  }

  Future<NoteReady> _readyStaged(TrayItem x) async {
    final gif = x.name.toLowerCase().endsWith('.gif');
    if (x.kind != TrayKind.photo && !gif) {
      return readyNoteFile(x.path, x.name);
    }
    final Uint8List bytes;
    try {
      bytes = await File(x.path).readAsBytes();
    } catch (_) {
      return (item: null, line: l10n.chatCouldNotReadThat);
    }
    return gif ? readyNoteGif(bytes) : readyNotePhoto(bytes);
  }

  // a paste that names files on this computer keeps them; anything else
  // pastes as words
  Future<bool> _pasteFiles() async {
    if (!onDesktop) return false;
    final ClipboardData? clip;
    try {
      clip = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      return false;
    }
    final files = pastedFiles(clip?.text);
    if (files.isEmpty) return false;
    if (mounted && !lockState.locked) _stage(files);
    return true;
  }

  // a picture or a gif a phone's keyboard pastes or inserts
  Future<void> _inserted(KeyboardInsertedContent c) async {
    final data = c.data;
    if (data == null || data.isEmpty) {
      if (mounted) showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    await _add(
      () =>
          c.mimeType == 'image/gif' ? readyNoteGif(data) : readyNotePhoto(data),
    );
  }

  Future<void> _voice(VoiceTake take) async {
    if (!mounted || lockState.locked) {
      await dropTake(take.path, take.masked);
      return;
    }
    await _add(() => readyNoteVoice(take.path, masked: take.masked));
  }

  void _menu(Map<String, Object?> n) {
    _heldOnce();
    final text = n['plaintext'] as String? ?? '';
    final path = (n['file_path'] ?? n['media_path']) as String?;
    showMenuSheet<String>(
      context,
      label: l10n.a11yMessageActions,
      groups: (ctx) {
        void pick(String a) => Navigator.pop(ctx, a);
        return [
          [
            MenuSheetRow(
              icon: Icons.copy_rounded,
              label: l10n.commonCopy,
              onTap: text.isEmpty ? null : () => pick('copy'),
            ),
            if (path != null)
              MenuSheetRow(
                icon: Icons.download_outlined,
                label: l10n.fileSaveToDevice,
                onTap: () => pick('save'),
              ),
          ],
          [
            MenuSheetRow(
              icon: Icons.delete_outline,
              label: l10n.commonDelete,
              danger: true,
              onTap: () => pick('delete'),
            ),
          ],
        ];
      },
    ).then((a) {
      if (!mounted || a == null) return;
      switch (a) {
        case 'copy':
          copySensitive(text, kept: true);
          showHaloToast(context, l10n.commonCopied);
        case 'save':
          if (path != null) {
            saveReceivedFile(context, path, n['file_name'] as String?);
          }
        case 'delete':
          _delete(n);
      }
    });
  }

  Future<void> _delete(Map<String, Object?> n) async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.notesDeleteThisNote,
      line: _shared
          ? l10n.notesGoneEverywhere
          : l10n.notesGoneFromThisPhoneShown,
      yes: l10n.commonDelete,
    );
    final key = _key(n);
    if (!ok || !mounted || !_leaving.add(key)) return;
    HapticFeedback.heavyImpact();
    setState(() {});
    // notes kept before they had a uid are given one now, by their time
    var uid = n['msg_uid'] as String?;
    if (uid == null) {
      uid = newMsgUid();
      await session.assignUidIfMissing(
        kNotesPeerId,
        n['sent_at'] as int? ?? 0,
        uid,
      );
    }
    await deleteNote(uid);
    await Future.delayed(FadeFold.gone);
    await _load();
    _leaving.remove(key);
  }

  Widget _head(String section) => ValueListenableBuilder<(String?, double)>(
    valueListenable: _pin,
    // under the held chip it is the held chip
    builder: (_, p, child) => Opacity(
      opacity: p.$1 == section ? 0 : 1,
      alwaysIncludeSemantics: true,
      child: child,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, _headPad, 0, 14),
      child: Center(
        child: Semantics(
          header: true,
          child: DayChip(noteSectionLabel(section)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final now = notesNow();
    final weekStart = weekStartDay();
    _sections = [
      for (final n in _notes)
        noteSection(
          DateTime.fromMillisecondsSinceEpoch(rowWrittenAt(n)),
          now,
          weekStart: weekStart,
        ),
    ];
    _indexOf = {for (var i = 0; i < _notes.length; i++) _key(_notes[i]): i};
    if (_notes.isNotEmpty) _queuePin();
    // a file dropped here is kept, as one picked with the paperclip
    return DragInZone(
      enabled: true,
      stage: _stage,
      couldNotRead: () => l10n.chatCouldNotReadThat,
      line: () => l10n.notesDropToKeep,
      child: Scaffold(
        backgroundColor: HaloColors.surface,
        body: DeskPage(
          child: SafeArea(
            child: Column(
              children: [
                PageBar(
                  under: _under,
                  title: l10n.notesNoteToSelf,
                  sub: Text(
                    _shared
                        ? l10n.notesOnAllDevices
                        : l10n.notesOnlyOnThisPhoneShown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(size: 10, color: HaloColors.text2),
                  ),
                  actions: [
                    if (_notes.isNotEmpty)
                      IconButton(
                        tooltip: l10n.notesMenu,
                        icon: Icon(
                          Icons.more_horiz,
                          color: HaloColors.text2,
                          size: 22,
                        ),
                        onPressed: _pageMenu,
                      ),
                  ],
                ),
                Expanded(
                  // the first note fades the empty page away
                  child: !_loaded
                      ? const SizedBox.shrink()
                      : NotificationListener<Notification>(
                          onNotification: _track,
                          child: FadeSwap(
                            child: _notes.isEmpty
                                ? KeyedSubtree(
                                    key: const ValueKey('none'),
                                    child: _empty(),
                                  )
                                : _Seen(
                                    key: const ValueKey('notes'),
                                    onMount: (c) => _listCtx = c,
                                    onGone: (c) {
                                      if (identical(_listCtx, c)) {
                                        _listCtx = null;
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        _list(),
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          child: _held(),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                ),
                EaseSize(
                  child: !_holdTold && _notes.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            18,
                            6,
                            18,
                            8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                onDesktop
                                    ? Icons.mouse_outlined
                                    : Icons.touch_app_outlined,
                                size: 15,
                                color: HaloColors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.notesHoldHintShown,
                                  style: HaloType.sans(
                                    size: 12.5,
                                    color: HaloColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                TrayStrip(tray: _tray),
                PasteFiles(onFiles: _stage, child: _inputBar()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list() => ListView.builder(
    // newest at the bottom, on the bar: the list starts there and a new
    // note pushes the rest up
    reverse: true,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    itemCount: _notes.length,
    itemBuilder: (_, k) {
      final i = _notes.length - 1 - k;
      final n = _notes[i];
      final id = _key(n);
      final text = n['plaintext'] as String? ?? '';
      final ts = rowWrittenAt(n);
      final section = _sections[i];
      final head = i == 0 || _sections[i - 1] != section;
      // fade older notes so the newest read brightest
      final fresh = i >= _notes.length - 2;
      final had = _had;
      return GrowIn(
        key: ValueKey(id),
        active: had != null && !had.contains(id),
        child: StaggerIn(
          index: k,
          child: FadeFold(
            leaving: _leaving.contains(id),
            child: _Seen(
              onMount: (c) => _rows[id] = c,
              onGone: (c) {
                if (identical(_rows[id], c)) _rows.remove(id);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (head) _head(section),
                  _NoteBubble(
                    media: noteHasMedia(n)
                        ? NoteMedia(
                            key: ValueKey('note-media-$id'),
                            note: n,
                            maxWidth: photoMaxWidth(context),
                          )
                        : null,
                    // a sticker says its emoji alone, never under it
                    text: StickerWire.parse(n['sticker']) == null ? text : '',
                    time: ts == 0
                        ? ''
                        : _noteTime(
                            DateTime.fromMillisecondsSinceEpoch(ts),
                            section,
                          ),
                    fresh: fresh,
                    open: _open.contains(id),
                    onToggle: () => _toggle(id),
                    onLongPress: () => _menu(n),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  // the heading held at the top while its notes run under it
  Widget _held() => IgnorePointer(
    child: ExcludeSemantics(
      child: ValueListenableBuilder<(String?, double)>(
        valueListenable: _pin,
        builder: (_, p, _) {
          final section = p.$1;
          if (section == null) return const SizedBox.shrink();
          return Transform.translate(
            offset: Offset(0, _pinTop + p.$2),
            child: Center(
              key: const ValueKey('notes-held'),
              child: _Seen(
                onMount: (c) => _pinCtx = c,
                onGone: (c) {
                  if (identical(_pinCtx, c)) _pinCtx = null;
                },
                child: DayChip(noteSectionLabel(section)),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _empty() {
    return Center(
      child: StaggerIn(
        index: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BreathingRing(
                size: 98,
                core: 66,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: HaloColors.amberSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: HaloColors.amber,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.notesAQuietPlace,
                style: HaloType.serif(size: 24, color: HaloColors.text),
              ),
              const SizedBox(height: 10),
              Text(
                _shared
                    ? l10n.notesKeepAnything
                    : l10n.notesJotAnythingDownItShown,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // the paperclip: a photo, a gif or a file. while one is made
          // ready it turns, and takes no other
          PressScale(
            label: l10n.notesAddItem,
            onTap: _adding ? null : _attach,
            scale: 0.86,
            child: SizedBox(
              width: 40,
              height: 42,
              child: Center(
                child: _Pop(
                  child: _adding
                      ? SizedBox(
                          key: const ValueKey('adding'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HaloColors.amber,
                          ),
                        )
                      : Icon(
                          key: const ValueKey('attach'),
                          Icons.attach_file_rounded,
                          size: 22,
                          color: HaloColors.text2,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HaloColors.line, width: 0.5),
              ),
              child: WrittenDir(
                controller: _input,
                builder: (dir) => EnterSends(
                  controller: _input,
                  onSend: _save,
                  child: ShiftTapGuard(
                    controller: _input,
                    // a paste of files from a computer's file manager
                    // keeps them; words paste as words
                    child: Actions(
                      actions: {PasteTextIntent: _PasteFiles(_pasteFiles)},
                      child: TextField(
                        textDirection: dir,
                        inputFormatters: const [UnmarkedInput()],
                        controller: _input,
                        enableIMEPersonalizedLearning: false,
                        // a picture or a gif from the keyboard
                        contentInsertionConfiguration:
                            ContentInsertionConfiguration(
                              allowedMimeTypes: const [
                                'image/png',
                                'image/jpeg',
                                'image/gif',
                                'image/webp',
                              ],
                              onContentInserted: _inserted,
                            ),
                        maxLines: 5,
                        minLines: 1,
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                        decoration: InputDecoration(
                          hintText: l10n.notesJotSomethingDown,
                          hintStyle: HaloType.sans(
                            size: 13,
                            color: HaloColors.text3,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          // stickers and gifs, inside the field as in a chat
                          suffixIcon: StickerButton(onTap: _stickers),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // lit while there is something to keep; with nothing written the
          // mic takes its place, as in a chat
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (_, v, _) {
              final some = v.text.trim().isNotEmpty || !_tray.isEmpty;
              return _Pop(
                child: !some
                    ? KeyedSubtree(
                        key: const ValueKey('mic'),
                        child: SizedBox(
                          height: 42,
                          child: HoldToTalkMic(
                            disguise: false,
                            onSend: _voice,
                            mayRecord: () => !_adding && !lockState.locked,
                          ),
                        ),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('save'),
                        child: PressScale(
                          label: l10n.commonSave,
                          onTap: _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: some
                                  ? HaloColors.amber
                                  : HaloColors.surface3,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: HaloColors.amber.withValues(
                                    alpha: some ? 0.25 : 0,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: some
                                  ? HaloColors.onAmber
                                  : HaloColors.text3,
                              size: 21,
                            ),
                          ),
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

// two things trading places with a small pop; with reduced motion a
// crossfade and nothing that grows, as the chat's send and mic do
class _Pop extends StatelessWidget {
  const _Pop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
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
      child: child,
    );
  }
}

// the field's paste: files a computer copied are taken, anything else is
// the field's own paste, as it always was
class _PasteFiles extends ContextAction<PasteTextIntent> {
  _PasteFiles(this.take);
  final Future<bool> Function() take;

  @override
  Object? invoke(PasteTextIntent intent, [BuildContext? context]) {
    final own = callingAction;
    unawaited(() async {
      if (await take()) return;
      own?.invoke(intent);
    }());
    return null;
  }
}

// tells the screen where a part of it was built, so it can be measured
class _Seen extends StatefulWidget {
  final ValueChanged<BuildContext> onMount;
  final ValueChanged<BuildContext> onGone;
  final Widget child;
  const _Seen({
    super.key,
    required this.onMount,
    required this.onGone,
    required this.child,
  });
  @override
  State<_Seen> createState() => _SeenState();
}

class _SeenState extends State<_Seen> {
  @override
  void initState() {
    super.initState();
    widget.onMount(context);
  }

  @override
  void didUpdateWidget(_Seen old) {
    super.didUpdateWidget(old);
    widget.onMount(context);
  }

  @override
  void dispose() {
    widget.onGone(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// past this many lines a note folds to [_foldTo] of them
const _foldPast = 8;
const _foldTo = 6;

class _NoteBubble extends StatelessWidget {
  // a photo, a file or a voice note, over its words
  final Widget? media;
  final String text;
  final String time;
  final bool fresh;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  const _NoteBubble({
    this.media,
    required this.text,
    required this.time,
    required this.onToggle,
    required this.onLongPress,
    this.fresh = true,
    this.open = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      HaloType.sans(
        size: 14.5,
        color: fresh ? HaloColors.text : HaloColors.text2,
        height: 1.5,
      ),
    );
    final m = media;
    if (m != null) return _withMedia(context, m, style);
    // in the direction it was written, as in a chat. digits alone have no
    // direction, and the fold measure needs one
    final dir = writtenDir(text) ?? Directionality.of(context);
    final still = motionStill(context);
    final content = LayoutBuilder(
      builder: (context, c) {
        TextPainter painter(int? lines) => TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: dir,
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: lines,
        )..layout(maxWidth: c.maxWidth);
        final probe = painter(_foldPast);
        final long = probe.didExceedMaxLines;
        probe.dispose();
        final words = Text(
          text,
          textDirection: dir,
          textAlign: startOf(context),
          style: style,
        );
        Widget body = words;
        if (long) {
          final f = painter(_foldTo), a = painter(null);
          final folded = f.height, full = a.height;
          f.dispose();
          a.dispose();
          body = still
              ? _fold(words, folded, full, open ? 1 : 0)
              : TweenAnimationBuilder<double>(
                  tween: Tween(end: open ? 1 : 0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => _fold(words, folded, full, v),
                );
          // a folded note opens on a tap anywhere on its words. the same
          // tree either way, or the fold would lose its place mid-motion
          body = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: open ? null : onToggle,
            child: body,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            body,
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(size: 9, color: HaloColors.text2),
                  ),
                ),
                // large text in a long language: the toggle never takes
                // the whole row
                if (long)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: c.maxWidth * 0.75),
                    child: _toggle(still),
                  ),
              ],
            ),
          ],
        );
      },
    );
    // held, it dips with a haptic and opens its menu
    return PressScale(
      scale: 0.98,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                decoration: BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HaloColors.line2, width: 0.5),
                ),
                child: content,
              ),
            ),
            _edge(),
          ],
        ),
      ),
    );
  }

  // the amber edge at the start, as tall as the note
  Widget _edge() => PositionedDirectional(
    start: 0,
    top: 0,
    bottom: 0,
    width: 3,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HaloColors.amber.withValues(alpha: fresh ? 1 : 0.4),
            HaloColors.amber.withValues(alpha: fresh ? 0.35 : 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  // a photo, a file or a voice note: the card as wide as what it holds,
  // its words wrapping at the photo's width, the time under them
  Widget _withMedia(BuildContext context, Widget media, TextStyle style) {
    final caption = text.trim();
    return PressScale(
      scale: 0.98,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HaloColors.line2, width: 0.5),
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        media,
                        if (caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(7, 8, 7, 0),
                            child: PhotoLedWidth(
                              child: Text(
                                caption,
                                textDirection:
                                    writtenDir(caption) ??
                                    Directionality.of(context),
                                textAlign: startOf(context),
                                style: style,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            7,
                            7,
                            7,
                            0,
                          ),
                          child: Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.mono(
                              size: 9,
                              color: HaloColors.text2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _edge(),
            ],
          ),
        ),
      ),
    );
  }

  // the words cut at [v] of the way from folded to full, the last line
  // fading out while it is cut
  Widget _fold(Widget words, double folded, double full, double v) {
    final t = v.clamp(0.0, 1.0);
    final h = lerpDouble(folded, full, t)!;
    final clipped = ClipRect(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        heightFactor: full == 0 ? 1 : h / full,
        child: words,
      ),
    );
    if (t >= 1) return clipped;
    final line = folded / _foldTo;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFFFFF),
          const Color(0xFFFFFFFF).withValues(alpha: t),
        ],
        stops: [r.height <= 0 ? 0 : math.max(0, 1 - line / r.height), 1],
      ).createShader(r),
      child: clipped,
    );
  }

  Widget _toggle(bool still) {
    final label = open ? l10n.notesShowLess : l10n.notesShowMore;
    return PressScale(
      label: label,
      scale: 0.94,
      onTap: onToggle,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 12,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                    size: 12.5,
                    color: HaloColors.amberText,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: HaloColors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
