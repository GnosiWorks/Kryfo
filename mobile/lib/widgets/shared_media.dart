// SPDX-License-Identifier: GPL-3.0-or-later
// what a chat shared. on the contact and group pages: the first four photos,
// the last of them saying how many more, and a row each for files, voice
// messages and links. a tap opens the shared page on that tab: photos in a
// grid, the rest in lists by month. until the rows are read the section
// holds four quiet tiles, so nothing wrong is ever on screen. everything is
// read from the container that holds the chat, so a hidden chat's files
// show only inside the vault

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../l10n/dates.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../link_preview.dart' show domainOf, firstUrl;
import '../main.dart' show AppStateFiles, appState, session;
import '../open_file.dart' show nameSaysVideo;
import '../open_outside.dart';
import '../read_burn.dart' show burnWaitsRow;
import '../sound_player.dart';
import '../theme.dart';
import '../transfers.dart';
import '../voice_format.dart' show isVoiceName;
import '../wide/read_width.dart' show kDeskTile;
import 'album_grid.dart' show VideoFace, VideoMarks;
import 'ease_size.dart';
import 'file_badge.dart';
import 'file_viewer_parts.dart' show fileHeroTag;
import 'halo_hero.dart';
import 'halo_rows.dart';
import 'motion.dart' show haloRoute, kHouseCurve, motionStill;
import 'page_head.dart';
import 'photo_viewer.dart' show openPhoto, photoHeroTag;
import 'pill_tabs.dart';
import 'press_scale.dart';
import 'sealed_picture.dart';
import 'shots_line.dart' show KeptIn;
import 'shared_files.dart';
import 'spoiler_cover.dart';
import '../voice_length.dart' show voiceClock, voiceFileMs;
import 'confirm_sheet.dart' show showConfirmSheet;
import 'file_actions.dart' show canForwardFile, forwardFile;
import '../file_save.dart' show saveReceivedFile;
import '../show_in_chat.dart' show askShowInChat, chatOpenUnder;
import '../viewer_rules.dart' show mayLeave, maySaveOut;
import 'sound_views.dart' show openSoundPlayer, soundsKept;
import 'swap.dart';
import 'video_bubble.dart' show openReceivedFile;
import 'video_viewer.dart' show openVideo, videoFlight, videoHeroTag;

enum SharedTab { media, files, voice, links }

String sharedTabLabel(SharedTab t) => switch (t) {
  SharedTab.media => l10n.sharedTabMedia,
  SharedTab.files => l10n.sharedTabFiles,
  SharedTab.voice => l10n.sharedTabVoice,
  SharedTab.links => l10n.sharedTabLinks,
};

/// one thing a chat shared
class SharedItem {
  // the photo, the file or the voice note; null for a link, and for a file
  // still to come
  final String? path;
  final String? name;
  final String? uid;
  final bool mine;
  // the sender marked it
  final bool secure;
  final DateTime when;
  // who sent it, in a group
  final String? peer;
  final String? url;
  final String? title;
  // a video among the media, drawn and opened as one
  final bool video;
  // timed (read or ours) and marked a spoiler: neither leaves the chat
  final bool timed;
  final bool spoiler;
  const SharedItem({
    this.path,
    this.name,
    this.uid,
    this.mine = false,
    this.secure = false,
    required this.when,
    this.peer,
    this.url,
    this.title,
    this.video = false,
    this.timed = false,
    this.spoiler = false,
  });
}

class SharedLists {
  final List<SharedItem> media;
  final List<SharedItem> files;
  final List<SharedItem> voice;
  final List<SharedItem> links;
  const SharedLists({
    this.media = const [],
    this.files = const [],
    this.voice = const [],
    this.links = const [],
  });

  List<SharedItem> of(SharedTab t) => switch (t) {
    SharedTab.media => media,
    SharedTab.files => files,
    SharedTab.voice => voice,
    SharedTab.links => links,
  };

  bool get isEmpty =>
      media.isEmpty && files.isEmpty && voice.isEmpty && links.isEmpty;

  /// the photos sent as spoilers
  Set<String> get spoilers => {
    for (final m in media)
      if (m.spoiler) m.path!,
  };

  /// the media that are videos
  Set<String> get videos => {
    for (final m in media)
      if (m.video) m.path!,
  };
}

/// [rows] newest first into the four lists. a timed one not read yet and
/// a blocked member's are left out, as in the chat. a file still to come
/// is listed with its wait; a photo or a voice note still to come is not
bool _waits(String? uid) => uid != null && fileWaits.value.containsKey(uid);

SharedLists sortShared(
  Iterable<Map<String, Object?>> rows, {
  Set<String> blocked = const {},
  bool Function(String? uid) waiting = _waits,
}) {
  final media = <SharedItem>[];
  final files = <SharedItem>[];
  final voice = <SharedItem>[];
  final links = <SharedItem>[];
  String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
  for (final r in rows) {
    final peer = r['peer_id'] as String?;
    if (peer != null && blocked.contains(peer)) continue;
    if (burnWaitsRow(r)) continue;
    final mine = r['direction'] == 'out';
    final uid = r['msg_uid'] as String?;
    final at = (r['sent_at'] as num?)?.toInt() ?? 0;
    final when = DateTime.fromMillisecondsSinceEpoch(at);
    final secure = (r['secure'] as int? ?? 0) == 1;
    final mediaPath = text(r['media_path']);
    final filePath = text(r['file_path']);
    final name = text(r['file_name']);
    final coming = !mine && waiting(uid);
    SharedItem item(String? path, {bool video = false}) => SharedItem(
      path: path,
      name: name,
      uid: uid,
      mine: mine,
      secure: secure,
      when: when,
      peer: peer,
      video: video,
      timed: r['burn_secs'] != null || r['burn_at'] != null,
      spoiler: r['spoiler'] == 1,
    );
    if (mediaPath != null) {
      if (!coming) media.add(item(mediaPath));
    } else if (name != null && isVoiceName(name)) {
      if (filePath != null && !coming) voice.add(item(filePath));
    } else if (name != null &&
        filePath != null &&
        !coming &&
        nameSaysVideo(name)) {
      // a video is drawn as one in the chat, so it is media here too. one
      // still to come stays with the files, where its wait shows
      media.add(item(filePath, video: true));
    } else if (name != null) {
      if (coming) {
        files.add(item(null));
      } else if (filePath != null) {
        files.add(item(filePath));
      }
    }
    final words = r['plaintext'];
    final url = words is String && words.contains('://')
        ? firstUrl(words)
        : null;
    if (url != null) {
      links.add(
        SharedItem(
          uid: uid,
          mine: mine,
          when: when,
          peer: peer,
          url: url,
          title: _previewTitle(r['preview'], url),
        ),
      );
    }
  }
  return SharedLists(media: media, files: files, voice: voice, links: links);
}

// the title the sender fetched for [url], if it shipped one
String? _previewTitle(Object? raw, String url) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final d = jsonDecode(raw) as Map<String, dynamic>;
    final t = d['title']?.toString().trim();
    if (d['url']?.toString() != url || t == null || t.isEmpty) return null;
    return t;
  } catch (_) {
    return null;
  }
}

/// what [chatId] shared, from the container that holds it
Future<SharedLists> loadShared(String chatId, {bool group = false}) async {
  if (!group) return sortShared(await session.mediaFor(chatId));
  final both = await Future.wait([
    session.loadGroupMessages(chatId),
    session.blockedIds(),
  ]);
  final rows = both[0] as List<Map<String, Object?>>;
  return sortShared(rows.reversed, blocked: both[1] as Set<String>);
}

// ---- the section on the contact and group pages ----

class SharedMediaSection extends StatelessWidget {
  final List<String> paths;
  // which of [paths] are videos
  final Set<String> videos;
  // which of [paths] are spoilers: blurred here, as in the chat
  final Set<String> spoilers;
  final int count;
  // false while the rows are still being read
  final bool loaded;
  final VoidCallback? onOpen;
  // how many files, voice messages and links, each a row that opens its tab
  final int files;
  final int voice;
  final int links;
  final ValueChanged<SharedTab>? onOpenTab;
  const SharedMediaSection({
    super.key,
    required this.paths,
    this.videos = const {},
    this.spoilers = const {},
    required this.count,
    this.loaded = true,
    this.onOpen,
    this.files = 0,
    this.voice = 0,
    this.links = 0,
    this.onOpenTab,
  });

  @override
  Widget build(BuildContext context) {
    final Widget body;
    final rest = [
      if (files > 0) (SharedTab.files, files, Icons.description_outlined),
      if (voice > 0) (SharedTab.voice, voice, Icons.mic_none_rounded),
      if (links > 0) (SharedTab.links, links, Icons.link_rounded),
    ];
    if (!loaded) {
      body = KeyedSubtree(
        key: const ValueKey('media-waiting'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageSection(l10n.groupInfoSharedMedia),
            _row((_, _) => const _BlankTile()),
            // the rows that most often follow, held quiet, so the page does
            // not jump down under a finger when they are read
            const SizedBox(height: 12),
            HaloGroup(
              children: [
                for (final (label, icon) in [
                  (l10n.sharedTabFiles, Icons.description_outlined),
                  (l10n.sharedTabVoice, Icons.mic_none_rounded),
                  (l10n.sharedTabLinks, Icons.link_rounded),
                ])
                  HaloRow(icon: icon, label: label, pending: true),
              ],
            ),
          ],
        ),
      );
    } else if (count == 0 && rest.isEmpty) {
      body = Padding(
        key: const ValueKey('media-none'),
        padding: const EdgeInsets.only(top: 18),
        child: HaloGroup(
          children: [
            HaloRow(
              icon: Icons.photo_library_outlined,
              label: l10n.contactNothingSharedYet,
            ),
          ],
        ),
      );
    } else {
      final shown = paths.take(4).toList();
      final more = count - 3;
      body = Column(
        key: const ValueKey('media-some'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageSection(
            count > 0
                ? l10n.contactSharedMedia(whole(count))
                : l10n.groupInfoSharedMedia,
          ),
          if (count > 0)
            PressScale(
              onTap: onOpen,
              scale: 0.98,
              label: l10n.contactSharedMedia(whole(count)),
              child: _row(
                (i, side) => i >= shown.length
                    ? const SizedBox.shrink()
                    : _Tile(
                        path: shown[i],
                        side: side,
                        video: videos.contains(shown[i]),
                        spoiler: spoilers.contains(shown[i]),
                        more: i == 3 && count > 4 ? more : 0,
                      ),
              ),
            ),
          if (rest.isNotEmpty) ...[
            if (count > 0) const SizedBox(height: 12),
            HaloGroup(
              children: [
                for (final (tab, n, icon) in rest)
                  HaloRow(
                    icon: icon,
                    label: sharedTabLabel(tab),
                    value: whole(n),
                    onTap: onOpenTab == null ? null : () => onOpenTab!(tab),
                  ),
              ],
            ),
          ],
        ],
      );
    }
    // the space eases to what came, and the new state fades over the old
    return EaseSize(child: FadeSwap(child: body));
  }

  Widget _row(Widget Function(int i, double side) tile) => LayoutBuilder(
    builder: (context, box) {
      const gap = 6.0;
      final side = (box.maxWidth - gap * 3) / 4;
      return Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            SizedBox.square(dimension: side, child: tile(i, side)),
          ],
        ],
      );
    },
  );
}

class _BlankTile extends StatelessWidget {
  const _BlankTile();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String path;
  final double side;
  final bool video;
  final bool spoiler;
  // shown over the last tile: how many more there are
  final int more;
  const _Tile({
    required this.path,
    required this.side,
    this.video = false,
    this.spoiler = false,
    this.more = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video) ...[
            VideoFace(path: path, width: side),
            if (more == 0) VideoMarks(path: path),
          ] else
            // a spoiler stays blurred here: it is seen in the chat
            ImageFiltered(
              enabled: spoiler,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 14,
                sigmaY: 14,
                tileMode: TileMode.decal,
              ),
              // its blur, the photo fading up over it as it decodes
              child: SealedPicture(
                path: path,
                image: mediaImage(
                  path,
                  (side * MediaQuery.devicePixelRatioOf(context)).round(),
                ),
                // a black square would read as a broken app, not a photo
                // whose file is gone
                errorBuilder: (_, _, _) => MissingTile(size: side),
              ),
            ),
          if (more > 0)
            ColoredBox(
              color: HaloColors.ink.withValues(alpha: 0.62),
              child: Center(
                child: Text(
                  '+${whole(more)}',
                  style: HaloType.mono(
                    size: 15,
                    color: HaloColors.amberText,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// a photo whose file has gone, drawn so it does not look like a failed load
class MissingTile extends StatelessWidget {
  final double size;
  const MissingTile({super.key, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: HaloColors.surface2,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size * 0.32,
        color: HaloColors.text3,
      ),
    );
  }
}

// ---- the shared page ----

/// the shared page of a chat, on [start]. [blocking]: the chat blocks
/// screenshots, so the other side's files open in no other app.
/// [nameOf]: who sent a file, for the viewer's head
Future<void> openShared(
  BuildContext context, {
  required String chatId,
  required String title,
  bool group = false,
  SharedTab start = SharedTab.media,
  bool blocking = false,
  // a burner room: nothing of it leaves
  bool room = false,
  String? Function(String? peer)? nameOf,
}) => Navigator.of(context).push(
  haloRoute(
    SharedScreen(
      chatId: chatId,
      title: title,
      group: group,
      start: start,
      blocking: blocking,
      room: room,
      nameOf: nameOf,
    ),
  ),
);

class SharedScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final bool group;
  final SharedTab start;
  final bool blocking;
  final bool room;
  final String? Function(String? peer)? nameOf;
  // tests hand the lists in
  final Future<SharedLists> Function()? load;
  // tests take a file from this phone here
  final Future<void> Function(String uid)? removeHere;
  // a hidden chat's: read from the session unless a test says
  final bool? hidden;
  const SharedScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.group = false,
    this.start = SharedTab.media,
    this.blocking = false,
    this.room = false,
    this.nameOf,
    this.load,
    this.removeHere,
    this.hidden,
  });

  @override
  State<SharedScreen> createState() => SharedScreenState();
}

class SharedScreenState extends State<SharedScreen> {
  late var _tab = widget.start;
  late final _pages = PageController(initialPage: widget.start.index);
  SharedLists? _lists;
  // files listed as still to come: once one is in, the lists are read again
  Set<String> _coming = const {};
  int _gen = 0;

  SharedTab get tab => _tab;

  @override
  void initState() {
    super.initState();
    fileWaits.addListener(_waitsMoved);
    _load();
  }

  @override
  void dispose() {
    fileWaits.removeListener(_waitsMoved);
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_gen;
    final got =
        await (widget.load?.call() ??
            loadShared(widget.chatId, group: widget.group));
    if (!mounted || gen != _gen) return;
    setState(() {
      _lists = got;
      _coming = {
        for (final f in got.files)
          if (f.path == null && f.uid != null) f.uid!,
      };
    });
  }

  void _waitsMoved() {
    if (_coming.any((u) => !fileWaits.value.containsKey(u))) _load();
  }

  // a tap's slide passes the pages between: they do not take the tab
  bool _sliding = false;

  Future<void> _go(SharedTab t) async {
    // the pages are not up until the rows are read
    if (t == _tab || !_pages.hasClients) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = t);
    if (motionStill(context)) {
      _pages.jumpToPage(t.index);
      return;
    }
    _sliding = true;
    try {
      await _pages.animateToPage(
        t.index,
        duration: const Duration(milliseconds: 320),
        curve: kHouseCurve,
      );
    } finally {
      _sliding = false;
    }
  }

  /// the other side's, in a chat that blocks screenshots: it goes to no
  /// other app
  bool _keeps(SharedItem it) => widget.blocking && !it.mine;

  String? _from(SharedItem it) {
    if (it.mine) return null;
    return widget.nameOf?.call(it.peer) ?? (widget.group ? null : widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final lists = _lists;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Head(title: widget.title, group: widget.group),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: PillTabs(
                labels: [for (final t in SharedTab.values) sharedTabLabel(t)],
                at: _tab.index,
                onTap: (i) => _go(SharedTab.values[i]),
              ),
            ),
            Expanded(
              child: FadeSwap(
                child: lists == null
                    ? const SizedBox.expand(key: ValueKey('reading'))
                    : PageView(
                        key: const ValueKey('read'),
                        controller: _pages,
                        onPageChanged: (i) {
                          if (_sliding || i == _tab.index) return;
                          HapticFeedback.selectionClick();
                          setState(() => _tab = SharedTab.values[i]);
                        },
                        children: [
                          _mediaPage(lists.media),
                          _listPage(SharedTab.files, lists.files),
                          _listPage(SharedTab.voice, lists.voice),
                          _listPage(SharedTab.links, lists.links),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaPage(List<SharedItem> media) {
    if (media.isEmpty) {
      return _Empty(
        icon: Icons.photo_library_outlined,
        line: l10n.sharedNoPhotos,
      );
    }
    return SharedPhotoGrid(
      paths: [for (final m in media) m.path!],
      spoilers: {
        for (final m in media)
          if (m.spoiler) m.path!: m.uid,
      },
      securePaths: {
        for (final m in media)
          if (m.secure) m.path!,
      },
      videos: {
        for (final m in media)
          if (m.video) m.path!,
      },
      onVideo: (path) {
        final it = media.firstWhere((m) => m.path == path);
        openVideo(
          context,
          path: path,
          fileName: it.name,
          kept: _keeps(it),
          where: widget.group ? KeptIn.group : KeptIn.chat,
        );
      },
    );
  }

  Widget _listPage(SharedTab tab, List<SharedItem> items) {
    if (tab == SharedTab.files) return _filesPage(items);
    if (items.isEmpty) {
      return _Empty(
        icon: switch (tab) {
          SharedTab.voice => Icons.mic_none_rounded,
          SharedTab.links => Icons.link_rounded,
          _ => Icons.description_outlined,
        },
        line: switch (tab) {
          SharedTab.voice => l10n.sharedNoVoice,
          SharedTab.links => l10n.sharedNoLinks,
          _ => l10n.sharedNoFiles,
        },
      );
    }
    // a month's heading over its items, newest month first
    final entries = <Object>[];
    String? month;
    for (final it in items) {
      final m = monthMaybeYear(it.when);
      if (m != month) entries.add(m);
      month = m;
      entries.add(it);
    }
    return ListView.builder(
      key: PageStorageKey(tab),
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        if (e is String) return _MonthHead(e, first: i == 0);
        final it = e as SharedItem;
        return switch (tab) {
          SharedTab.voice => _VoiceRow(
            item: it,
            from: _from(it),
            onTap: () => _playVoice(it, items),
          ),
          SharedTab.links => _LinkRow(item: it),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  // the files: search, filters, and a menu on a hold
  Widget _filesPage(List<SharedItem> items) {
    final byEntry = <FileEntry, SharedItem>{
      for (final it in items)
        FileEntry(
          path: it.path,
          name: it.name,
          uid: it.uid,
          mine: it.mine,
          peer: it.peer,
          when: it.when,
        ): it,
    };
    return SharedFilesPage(
      files: byEntry.keys.toList(),
      group: widget.group,
      nameOf: (p) =>
          widget.nameOf?.call(p) ?? (widget.group ? null : widget.title),
      onTap: (e) => _openFile(byEntry[e]!),
      actions: (e) => _actionsFor(byEntry[e]!),
    );
  }

  // what a hold on a file offers. nothing kept to a chat that blocks leaves
  // it, and a hidden chat's file is never saved out or forwarded
  FileRowActions _actionsFor(SharedItem it) {
    final path = it.path;
    final hidden = widget.hidden ?? session.isHidden(widget.chatId);
    final uid = it.uid;
    // the viewer's rules: in a chat that blocks or a room nothing leaves,
    // ours included; nothing timed, marked or a spoiler; a hidden chat's
    // never goes out
    final leaves = mayLeave(
      blocking: widget.blocking,
      room: widget.room,
      timed: it.timed,
      marked: it.secure,
      spoiler: it.spoiler,
      hidden: hidden,
    );
    final saves = maySaveOut(
      blocking: widget.blocking,
      room: widget.room,
      timed: it.timed,
      marked: it.secure,
      spoiler: it.spoiler,
      hidden: hidden,
    );
    return FileRowActions(
      open: path == null ? null : () => _openFile(it),
      forward: !leaves || !canForwardFile(path, it.name, kept: false)
          ? null
          : () => forwardFile(context, path!, it.name),
      save: !saves || path == null
          ? null
          : () => saveReceivedFile(context, path, it.name),
      showInChat: uid == null || !chatOpenUnder(widget.chatId)
          ? null
          : () => askShowInChat(widget.chatId, uid),
      // a downloaded copy of theirs goes to free the space; the message
      // stays
      remove: uid == null || it.mine || path == null
          ? null
          : () => _removeDownload(it),
    );
  }

  Future<void> _removeDownload(SharedItem it) async {
    final uid = it.uid;
    if (uid == null) return;
    final yes = await showConfirmSheet(
      context,
      title: l10n.filesRemoveDownload,
      line: l10n.filesRemoveDownloadLine,
      yes: l10n.filesRemoveDownloadYes,
    );
    if (!yes || !mounted) return;
    HapticFeedback.mediumImpact();
    await (widget.removeHere?.call(uid) ?? session.removeDownload(uid));
    if (mounted) await _load();
  }

  Future<void> _openFile(SharedItem it) async {
    final uid = it.uid;
    final path = it.path;
    if (path == null) {
      final w = fileWaitOf(uid);
      if (uid == null || w == null) return;
      HapticFeedback.selectionClick();
      if (w.state == WaitState.coming) {
        await appState.pauseDownload(uid);
      } else {
        await appState.downloadNow(uid);
      }
      return;
    }
    await openReceivedFile(
      context,
      path,
      it.name,
      kept: _keeps(it),
      where: widget.group ? KeptIn.group : KeptIn.chat,
      from: _from(it),
      heroTag: fileHeroTag(path, 'shared'),
    );
  }

  // the voice messages after it in time play on, as in the chat
  Future<void> _playVoice(SharedItem it, List<SharedItem> all) async {
    final at = all.indexOf(it);
    SoundItem sound(SharedItem x) => SoundItem(
      x.path!,
      name: x.name,
      from: _from(x),
      when: x.when,
      voice: true,
      kept: _keeps(x),
    );
    final first = sound(it);
    final next = [for (final x in all.take(at).toList().reversed) sound(x)];
    final p = SoundPlayer.instance;
    if (!p.isOn(it.path!)) unawaited(p.play(first, next: next));
    await openSoundPlayer(
      context,
      heroTag: fileHeroTag(it.path!, 'shared'),
      secure: soundsKept(first, next),
    );
  }
}

// "Shared with Lena", the name in italics
class _Head extends StatelessWidget {
  final String title;
  final bool group;
  const _Head({required this.title, required this.group});

  @override
  Widget build(BuildContext context) {
    const mark = '';
    final words = group ? l10n.sharedIn(mark) : l10n.sharedWith(mark);
    final parts = words.split(mark);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonBack,
            icon: Icon(Icons.chevron_left, color: HaloColors.text, size: 26),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Semantics(
              header: true,
              label: words.replaceAll(mark, title),
              excludeSemantics: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    for (var i = 0; i < parts.length; i++) ...[
                      if (i > 0)
                        TextSpan(
                          text: title,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: HaloColors.amberText,
                          ),
                        ),
                      TextSpan(text: parts[i]),
                    ],
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HaloType.serif(size: 22, color: HaloColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHead extends StatelessWidget {
  final String label;
  final bool first;
  const _MonthHead(this.label, {required this.first});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(top: first ? 10 : 16, bottom: 6),
    child: Semantics(
      header: true,
      child: Text(
        dateCaps(label),
        style: HaloType.mono(
          size: 10,
          color: HaloColors.text,
          weight: FontWeight.w500,
          letter: 0.08,
        ),
      ),
    ),
  );
}

// the row's two lines: a name kept whole at its end, and a small line
class _RowText extends StatelessWidget {
  final Widget title;
  final String sub;
  const _RowText({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      title,
      const SizedBox(height: 3),
      Text(
        sub,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: HaloType.mono(size: 10.5, color: HaloColors.text),
      ),
    ],
  );
}

TextStyle get _nameStyle =>
    HaloType.sans(size: 14.5, weight: FontWeight.w500, color: HaloColors.text);

class _Row extends StatelessWidget {
  final Widget lead;
  final Widget text;
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  const _Row({
    required this.lead,
    required this.text,
    required this.label,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: label,
    hint: hint,
    excludeSemantics: true,
    onTap: onTap,
    child: PressScale(
      scale: 0.98,
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            lead,
            const SizedBox(width: 12),
            Expanded(child: text),
          ],
        ),
      ),
    ),
  );
}

class _VoiceRow extends StatelessWidget {
  final SharedItem item;
  final String? from;
  final VoidCallback onTap;
  const _VoiceRow({
    required this.item,
    required this.from,
    required this.onTap,
  });

  // each note's length, read once per path
  static final Map<String, Future<int?>> _lengths = {};

  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
    future: (_lengths.length > 300 ? (_lengths..clear()) : _lengths)
        .putIfAbsent(item.path!, () => voiceFileMs(item.path!)),
    builder: (context, snap) => _row(context, snap.data),
  );

  Widget _row(BuildContext context, int? ms) {
    final who = item.mine ? l10n.chatYou : (from ?? l10n.sharedTabVoice);
    final sub = [
      if (ms != null) voiceClock(ms),
      dayMonthMaybeYear(item.when),
      hourMinute(item.when),
    ].join(' · ');
    final tone = fileToneColor(FileTone.audio);
    // the disc is filled: its mark takes the ink a filled tile's would
    final ink = HaloColors.onFileBadge;
    final p = SoundPlayer.instance;
    return _Row(
      lead: HaloHero(
        tag: fileHeroTag(item.path!, 'shared'),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          // the one that plays shows it
          child: ListenableBuilder(
            listenable: p,
            builder: (context, _) {
              final on = p.isOn(item.path!) && p.playing;
              return AnimatedSwitcher(
                duration: motionStill(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(a),
                    child: c,
                  ),
                ),
                child: Icon(
                  on ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  key: ValueKey(on),
                  size: 20,
                  color: ink,
                ),
              );
            },
          ),
        ),
      ),
      text: _RowText(
        title: Text(
          who,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _nameStyle,
        ),
        sub: sub,
      ),
      label: [
        item.mine ? l10n.sharedYourVoice : l10n.soundVoiceFrom(who),
        sub,
      ].join(', '),
      onTap: onTap,
    );
  }
}

class _LinkRow extends StatelessWidget {
  final SharedItem item;
  const _LinkRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item.url!;
    final domain = domainOf(url);
    final title = item.title;
    final sub = dayMonthMaybeYear(item.when);
    return _Row(
      lead: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HaloColors.amberSoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(Icons.link_rounded, size: 20, color: HaloColors.amberText),
      ),
      text: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title ?? domain,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _nameStyle,
          ),
          const SizedBox(height: 3),
          // an address reads left to right in every language
          Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: HaloType.mono(size: 10.5, color: HaloColors.amberText),
          ),
          const SizedBox(height: 2),
          Text(sub, style: HaloType.mono(size: 10.5, color: HaloColors.text)),
        ],
      ),
      label: [title ?? domain, domain, sub].join(', '),
      hint: l10n.sharedOpensLink,
      onTap: () async {
        final u = Uri.tryParse(url);
        final ok = u != null && await openOutside(u);
        if (!ok && context.mounted) {
          showHaloToast(context, l10n.linkNoAppOpensShown);
        }
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String line;
  const _Empty({required this.icon, required this.line});

  @override
  Widget build(BuildContext context) => Center(
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
            ),
            child: Icon(icon, color: HaloColors.amberText, size: 25),
          ),
          const SizedBox(height: 18),
          Text(
            line,
            textAlign: TextAlign.center,
            style: HaloType.serif(size: 19, color: HaloColors.text),
          ),
        ],
      ),
    ),
  );
}

/// the shared photos in a grid, newest first. a marked photo stays
/// protected wherever it is opened from
class SharedPhotoGrid extends StatelessWidget {
  final List<String> paths;
  final Set<String> securePaths;
  // which of [paths] are videos, opened in the player by [onVideo]
  final Set<String> videos;
  final ValueChanged<String>? onVideo;
  // photos sent as spoilers, path to their message: blurred until tapped,
  // as in the chat
  final Map<String, String?> spoilers;
  const SharedPhotoGrid({
    super.key,
    required this.paths,
    this.spoilers = const {},
    this.securePaths = const {},
    this.videos = const {},
    this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        2,
        0,
        2,
        2 + MediaQuery.paddingOf(context).bottom,
      ),
      // a computer's window is wide: tiles keep a thumbnail's size
      gridDelegate: onDesktop
          ? const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: kDeskTile,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            )
          : const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
      itemCount: paths.length,
      itemBuilder: (context, i) {
        final path = paths[i];
        if (videos.contains(path)) return _videoTile(context, path);
        final tag = photoHeroTag(path, 'gallery');
        return SpoilerCover(
          uid: spoilers[path],
          on: spoilers.containsKey(path),
          child: PressScale(
            scale: 0.96,
            haptic: false,
            onTap: () => openPhoto(
              context,
              path,
              secure: securePaths.contains(path),
              tag: tag,
            ),
            child: HaloHero(
              tag: tag,
              // each tile shows its blur, its photo fading up over it
              child: SealedPicture(
                path: path,
                image: mediaImage(path, 360),
                filterQuality: FilterQuality.low,
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
          ),
        );
      },
    );
  }

  Widget _videoTile(BuildContext context, String path) => LayoutBuilder(
    builder: (context, box) => Semantics(
      button: true,
      label: l10n.videoBubbleVideo,
      excludeSemantics: true,
      onTap: onVideo == null ? null : () => onVideo!(path),
      child: PressScale(
        scale: 0.96,
        haptic: false,
        onTap: onVideo == null ? null : () => onVideo!(path),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // the frame flies into the player, as from the chat
            HaloHero(
              tag: videoHeroTag(path),
              flightShuttleBuilder: (c, a, dir, from, to) =>
                  videoFlight(c, a, dir, from, to, path),
              child: VideoFace(path: path, width: box.maxWidth),
            ),
            VideoMarks(path: path),
          ],
        ),
      ),
    ),
  );
}
