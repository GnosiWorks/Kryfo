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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../file_kind.dart';
import '../l10n/dates.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../link_preview.dart' show domainOf, firstUrl;
import '../main.dart' show AppStateFiles, appState, session;
import '../open_outside.dart';
import '../read_burn.dart' show burnWaitsRow;
import '../sound_player.dart';
import '../theme.dart';
import '../transfers.dart';
import '../voice_format.dart' show isVoiceName;
import '../wide/read_width.dart' show kDeskTile;
import 'ease_size.dart';
import 'file_badge.dart';
import 'file_bubble.dart' show fileNameDir;
import 'file_viewer_parts.dart' show fileHeroTag;
import 'file_wait.dart' show FileWaitMark, fileWaitLine;
import 'halo_hero.dart';
import 'halo_rows.dart';
import 'media_bubbles.dart' show humanFileSize, splitFileName;
import 'motion.dart' show haloRoute, kHouseCurve, motionStill;
import 'page_head.dart';
import 'photo_viewer.dart' show openPhoto, photoHeroTag;
import 'pill_tabs.dart';
import 'press_scale.dart';
import 'sealed_picture.dart';
import 'shots_line.dart' show KeptIn;
import 'sound_views.dart' show openSoundPlayer;
import 'swap.dart';
import 'video_bubble.dart' show openReceivedFile;

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
    SharedItem item(String? path) => SharedItem(
      path: path,
      name: name,
      uid: uid,
      mine: mine,
      secure: secure,
      when: when,
      peer: peer,
    );
    if (mediaPath != null) {
      if (!coming) media.add(item(mediaPath));
    } else if (name != null && isVoiceName(name)) {
      if (filePath != null && !coming) voice.add(item(filePath));
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
  // shown over the last tile: how many more there are
  final int more;
  const _Tile({required this.path, required this.side, this.more = 0});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // its blur, the photo fading up over it as it decodes
          SealedPicture(
            path: path,
            image: mediaImage(
              path,
              (side * MediaQuery.devicePixelRatioOf(context)).round(),
            ),
            // a black square would read as a broken app, not a photo whose
            // file is gone
            errorBuilder: (_, _, _) => MissingTile(size: side),
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
  String? Function(String? peer)? nameOf,
}) => Navigator.of(context).push(
  haloRoute(
    SharedScreen(
      chatId: chatId,
      title: title,
      group: group,
      start: start,
      blocking: blocking,
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
  final String? Function(String? peer)? nameOf;
  // tests hand the lists in
  final Future<SharedLists> Function()? load;
  const SharedScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.group = false,
    this.start = SharedTab.media,
    this.blocking = false,
    this.nameOf,
    this.load,
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
      securePaths: {
        for (final m in media)
          if (m.secure) m.path!,
      },
    );
  }

  Widget _listPage(SharedTab tab, List<SharedItem> items) {
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
          _ => _FileRow(item: it, onTap: () => _openFile(it)),
        };
      },
    );
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
      kept: widget.blocking && !it.mine,
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
    );
    final p = SoundPlayer.instance;
    if (!p.isOn(it.path!)) {
      unawaited(
        p.play(
          sound(it),
          next: [for (final x in all.take(at).toList().reversed) sound(x)],
        ),
      );
    }
    await openSoundPlayer(context, heroTag: fileHeroTag(it.path!, 'shared'));
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

class _FileRow extends StatefulWidget {
  final SharedItem item;
  final VoidCallback onTap;
  const _FileRow({required this.item, required this.onTap});

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  // read once the row is built, not for the whole list up front
  int? _size;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  @override
  void didUpdateWidget(_FileRow old) {
    super.didUpdateWidget(old);
    if (old.item.path != widget.item.path) _readSize();
  }

  Future<void> _readSize() async {
    final p = widget.item.path;
    if (p == null) return;
    try {
      final n = await File(p).length();
      if (mounted) setState(() => _size = n);
    } catch (_) {
      // gone: the row says nothing of its size
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final facts = FileFacts(kindOfName(it.name), extOf(safeFileName(it.name)));
    final shown = safeFileName(it.name, facts: facts);
    final (stem, ext) = splitFileName(shown);
    // a left to right name still sits at the start of a right to left row
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: fileNameDir(stem),
      children: [
        Flexible(
          child: Text(
            stem,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: fileNameDir(stem),
            style: _nameStyle,
          ),
        ),
        if (ext.isNotEmpty)
          Text(
            ext,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: _nameStyle,
          ),
      ],
    );
    final path = it.path;
    if (path == null) {
      // still to come: its ring follows it, a tap brings or pauses it
      return ValueListenableBuilder<Map<String, FileWait>>(
        valueListenable: fileWaits,
        builder: (context, waits, _) {
          final w = waits[it.uid];
          if (w == null) return const SizedBox.shrink();
          final line = fileWaitLine(
            w,
            unmetered: true,
            left: it.uid == null ? null : fileWaitLeft(it.uid!),
          );
          return _Row(
            lead: FileWaitMark(wait: w),
            text: _RowText(title: title, sub: line),
            label: '$shown, $line',
            hint: switch (w.state) {
              WaitState.coming => l10n.transferPauseDownload,
              WaitState.paused => l10n.transferResume,
              WaitState.asks => l10n.transferDownload,
            },
            onTap: widget.onTap,
          );
        },
      );
    }
    final sub = [
      if (_size != null) humanFileSize(_size!),
      dayMonthMaybeYear(it.when),
    ].join(' · ');
    return _Row(
      lead: HaloHero(
        tag: fileHeroTag(path, 'shared'),
        child: FileBadge(facts: facts, size: 42),
      ),
      text: _RowText(title: title, sub: sub),
      label: '$shown, $sub',
      onTap: widget.onTap,
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final who = item.mine ? l10n.chatYou : (from ?? l10n.sharedTabVoice);
    final sub = '${dayMonthMaybeYear(item.when)} · ${hourMinute(item.when)}';
    final tone = fileToneColor(FileTone.audio);
    final ink = onFileTone(FileTone.audio);
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
  const SharedPhotoGrid({
    super.key,
    required this.paths,
    this.securePaths = const {},
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
        final tag = photoHeroTag(path, 'gallery');
        return PressScale(
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
        );
      },
    );
  }
}
