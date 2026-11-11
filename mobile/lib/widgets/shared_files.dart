// SPDX-License-Identifier: GPL-3.0-or-later
// the files tab of the shared page: search by name with the match lit,
// filters for the kind, who sent it (in a group), the order, and only what
// is on this phone. each row says who sent it in a group, how big it is and
// when, or until when one still waiting can be got. a hold opens a small
// menu that grows out of the row: open, forward, save, show in chat, and
// remove download. nothing ever comes without a tap
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_kind.dart';
import '../l10n/dates.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../theme.dart';
import '../transfers.dart';
import 'confirm_sheet.dart';
import 'file_badge.dart';
import 'file_bubble.dart' show fileNameDir;
import 'file_stack.dart' show fileWaitRowLine, kFileKeptFor;
import 'file_viewer_parts.dart' show fileHeroTag;
import 'file_wait.dart' show FileWaitMark;
import 'halo_hero.dart';
import 'media_bubbles.dart' show humanFileSize, splitFileName;
import 'motion.dart' show kHouseCurve, motionStill;
import 'press_scale.dart';

/// what kinds the type filter offers
enum FileKindFilter { all, docs, code, audio, video, archives, other }

enum FileOrder { newest, oldest, largest }

String fileKindFilterName(FileKindFilter k) => switch (k) {
  FileKindFilter.all => l10n.filesAllTypes,
  FileKindFilter.docs => l10n.filesTypeDocs,
  FileKindFilter.code => l10n.filesTypeCode,
  FileKindFilter.audio => l10n.filesTypeAudio,
  FileKindFilter.video => l10n.filesTypeVideo,
  FileKindFilter.archives => l10n.filesTypeArchives,
  FileKindFilter.other => l10n.filesTypeOther,
};

String fileOrderName(FileOrder o) => switch (o) {
  FileOrder.newest => l10n.filesNewest,
  FileOrder.oldest => l10n.filesOldest,
  FileOrder.largest => l10n.filesLargest,
};

/// the filter a file of [name] falls under
FileKindFilter fileKindFilterOf(String? name) {
  final tone = fileToneOf(FileFacts(kindOfName(name), extOf(name)));
  return switch (tone) {
    FileTone.pdf || FileTone.doc || FileTone.sheet => FileKindFilter.docs,
    FileTone.code => FileKindFilter.code,
    FileTone.audio => FileKindFilter.audio,
    FileTone.video => FileKindFilter.video,
    FileTone.zip => FileKindFilter.archives,
    FileTone.picture || FileTone.other => FileKindFilter.other,
  };
}

/// one file of the list, with what the filters read
class FileEntry {
  // the file here, or null while it waits
  final String? path;
  final String? name;
  final String? uid;
  final bool mine;
  // who sent it, for the "from" filter: null for ours
  final String? peer;
  final DateTime when;
  const FileEntry({
    required this.path,
    required this.name,
    required this.uid,
    required this.mine,
    required this.peer,
    required this.when,
  });
}

/// the filters as they stand
class FileFilters {
  final String query;
  final FileKindFilter kind;
  // a member's id, '' for ours, null for anyone
  final String? from;
  final FileOrder order;
  final bool here;
  const FileFilters({
    this.query = '',
    this.kind = FileKindFilter.all,
    this.from,
    this.order = FileOrder.newest,
    this.here = false,
  });

  bool get any =>
      query.trim().isNotEmpty ||
      kind != FileKindFilter.all ||
      from != null ||
      order != FileOrder.newest ||
      here;

  FileFilters copy({
    String? query,
    FileKindFilter? kind,
    String? Function()? from,
    FileOrder? order,
    bool? here,
  }) => FileFilters(
    query: query ?? this.query,
    kind: kind ?? this.kind,
    from: from == null ? this.from : from(),
    order: order ?? this.order,
    here: here ?? this.here,
  );
}

/// [all] narrowed and put in order. [sizeOf] is what each weighs, null
/// while it is read; [waits]: one of theirs still to come
List<FileEntry> filterFiles(
  List<FileEntry> all,
  FileFilters f, {
  required int? Function(FileEntry) sizeOf,
  required bool Function(FileEntry) waits,
}) {
  final q = f.query.trim().toLowerCase();
  final out = [
    for (final e in all)
      if ((q.isEmpty || (e.name ?? '').toLowerCase().contains(q)) &&
          (f.kind == FileKindFilter.all ||
              fileKindFilterOf(e.name) == f.kind) &&
          (f.from == null ||
              (f.from == '' ? e.mine : !e.mine && e.peer == f.from)) &&
          (!f.here || (e.path != null && !waits(e))))
        e,
  ];
  switch (f.order) {
    case FileOrder.newest:
      out.sort((a, b) => b.when.compareTo(a.when));
    case FileOrder.oldest:
      out.sort((a, b) => a.when.compareTo(b.when));
    case FileOrder.largest:
      out.sort((a, b) => (sizeOf(b) ?? -1).compareTo(sizeOf(a) ?? -1));
  }
  return out;
}

/// [text] with every place [query] stands in it lit in amber
List<TextSpan> litName(String text, String query, TextStyle base) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [TextSpan(text: text, style: base)];
  final low = text.toLowerCase();
  final out = <TextSpan>[];
  var at = 0;
  while (true) {
    final i = low.indexOf(q, at);
    // a lower-case form that changed the length is not lit, only listed
    if (i < 0 || low.length != text.length) break;
    if (i > at) out.add(TextSpan(text: text.substring(at, i), style: base));
    out.add(
      TextSpan(
        text: text.substring(i, i + q.length),
        style: base.copyWith(color: HaloColors.amberText),
      ),
    );
    at = i + q.length;
  }
  if (at < text.length) {
    out.add(TextSpan(text: text.substring(at), style: base));
  }
  return out;
}

/// what a hold on a row can do. null leaves the action out
class FileRowActions {
  final VoidCallback? open;
  final VoidCallback? forward;
  final VoidCallback? save;
  final VoidCallback? showInChat;
  final VoidCallback? remove;
  const FileRowActions({
    this.open,
    this.forward,
    this.save,
    this.showInChat,
    this.remove,
  });
}

class SharedFilesPage extends StatefulWidget {
  final List<FileEntry> files;
  final bool group;
  // who a member is; null for one this phone has no name for
  final String? Function(String? peer) nameOf;
  final void Function(FileEntry) onTap;
  final FileRowActions Function(FileEntry) actions;
  // tests hand the sizes in
  final Future<int?> Function(String path)? sizeOfPath;
  const SharedFilesPage({
    super.key,
    required this.files,
    required this.group,
    required this.nameOf,
    required this.onTap,
    required this.actions,
    this.sizeOfPath,
  });

  @override
  State<SharedFilesPage> createState() => SharedFilesPageState();
}

class SharedFilesPageState extends State<SharedFilesPage> {
  var _f = const FileFilters();
  final _search = TextEditingController();
  final Map<String, int> _sizes = {};

  @visibleForTesting
  FileFilters get filters => _f;

  @override
  void initState() {
    super.initState();
    _readSizes();
  }

  @override
  void didUpdateWidget(SharedFilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.files, widget.files)) _readSizes();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // each file's size, read once: the order by size and the rows want them
  Future<void> _readSizes() async {
    for (final e in widget.files) {
      final p = e.path;
      if (p == null || _sizes.containsKey(p)) continue;
      int? n;
      try {
        n = await (widget.sizeOfPath?.call(p) ?? File(p).length());
      } catch (_) {
        // gone: no size
      }
      if (!mounted) return;
      if (n != null) setState(() => _sizes[p] = n!);
    }
  }

  bool _waits(FileEntry e) =>
      !e.mine && e.uid != null && fileWaits.value.containsKey(e.uid);

  int? _sizeOf(FileEntry e) {
    if (_waits(e)) return fileWaits.value[e.uid]?.size;
    final p = e.path;
    return p == null ? null : _sizes[p];
  }

  String _who(FileEntry e) =>
      e.mine ? l10n.chatYou : (widget.nameOf(e.peer) ?? l10n.filesSomeone);

  Future<void> _pickKind() async {
    final k = await showChoiceSheet<FileKindFilter>(
      context,
      title: l10n.filesTypeTitle,
      current: _f.kind,
      choices: [
        for (final k in FileKindFilter.values)
          SheetChoice(k, fileKindFilterName(k)),
      ],
    );
    if (k == null || !mounted) return;
    setState(() => _f = _f.copy(kind: k));
  }

  Future<void> _pickFrom() async {
    final peers = <String>{
      for (final e in widget.files)
        if (!e.mine && e.peer != null) e.peer!,
    };
    final any = l10n.filesFromAnyone;
    final picked = await showChoiceSheet<String>(
      context,
      title: l10n.filesFromTitle,
      current: _f.from ?? '\u0000',
      choices: [
        SheetChoice('\u0000', any),
        SheetChoice('', l10n.chatYou),
        for (final p in peers)
          SheetChoice(p, widget.nameOf(p) ?? l10n.filesSomeone),
      ],
    );
    if (picked == null || !mounted) return;
    setState(
      () => _f = _f.copy(from: () => picked == '\u0000' ? null : picked),
    );
  }

  Future<void> _pickOrder() async {
    final o = await showChoiceSheet<FileOrder>(
      context,
      title: l10n.filesOrderTitle,
      current: _f.order,
      choices: [
        for (final o in FileOrder.values) SheetChoice(o, fileOrderName(o)),
      ],
    );
    if (o == null || !mounted) return;
    setState(() => _f = _f.copy(order: o));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, FileWait>>(
      valueListenable: fileWaits,
      builder: (context, _, _) {
        final shown = filterFiles(
          widget.files,
          _f,
          sizeOf: _sizeOf,
          waits: _waits,
        );
        final seen = <String?>{};
        final twice = <String?>{
          for (final e in widget.files)
            if (!seen.add(e.name)) e.name,
        };
        final fromName = _f.from == null
            ? null
            : _f.from == ''
            ? l10n.chatYou
            : widget.nameOf(_f.from) ?? l10n.filesSomeone;
        return CustomScrollView(
          key: const PageStorageKey('files'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _SearchField(
                  controller: _search,
                  onChanged: (q) => setState(() => _f = _f.copy(query: q)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  children: [
                    _Chip(
                      label: fileKindFilterName(_f.kind),
                      on: _f.kind != FileKindFilter.all,
                      more: true,
                      onTap: _pickKind,
                    ),
                    if (widget.group)
                      _Chip(
                        label: fromName == null
                            ? l10n.filesFromAnyone
                            : l10n.filesFrom(fromName),
                        on: fromName != null,
                        more: true,
                        onTap: _pickFrom,
                      ),
                    _Chip(
                      label: fileOrderName(_f.order),
                      on: _f.order != FileOrder.newest,
                      more: true,
                      onTap: _pickOrder,
                    ),
                    _Chip(
                      label: l10n.filesOnPhone,
                      on: _f.here,
                      toggle: true,
                      onTap: () => setState(() => _f = _f.copy(here: !_f.here)),
                    ),
                  ],
                ),
              ),
            ),
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                  child: Text(
                    widget.files.isEmpty
                        ? l10n.sharedNoFiles
                        : l10n.filesNoMatch,
                    textAlign: TextAlign.center,
                    style: HaloType.sans(size: 14, color: HaloColors.text),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: [
                    for (final e in _withHeads(shown))
                      if (e is String)
                        _Head(e)
                      else
                        _FileRow(
                          key: ValueKey((e as FileEntry).uid ?? e.path),
                          entry: e,
                          query: _f.query,
                          // in a group always; in a chat when two share a
                          // name, so ours and theirs read apart
                          who: widget.group || twice.contains(e.name)
                              ? _who(e)
                              : null,
                          size: _sizeOf(e),
                          onTap: () => widget.onTap(e),
                          actions: () => widget.actions(e),
                        ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // a month's heading over its files while nothing is narrowed; a count
  // once anything is
  List<Object> _withHeads(List<FileEntry> shown) {
    if (_f.any) {
      return [l10n.filesCount(shown.length, whole(shown.length)), ...shown];
    }
    final out = <Object>[];
    String? month;
    for (final e in shown) {
      final m = monthMaybeYear(e.when);
      if (m != month) out.add(m);
      month = m;
      out.add(e);
    }
    return out;
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: HaloColors.surface2,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.search_rounded, size: 18, color: HaloColors.text),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            enableIMEPersonalizedLearning: false,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            cursorColor: HaloColors.amber,
            style: HaloType.sans(size: 14.5, color: HaloColors.text),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: l10n.filesSearchHint,
              hintStyle: HaloType.sans(size: 14.5, color: HaloColors.text2),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) => v.text.isEmpty
              ? const SizedBox.shrink()
              : Semantics(
                  button: true,
                  label: l10n.filesClearSearch,
                  excludeSemantics: true,
                  child: PressScale(
                    scale: 0.85,
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: HaloColors.text,
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final bool more;
  final bool toggle;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.more = false,
    this.toggle = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final ink = on ? HaloColors.amberText : HaloColors.text;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Semantics(
        button: true,
        toggled: toggle ? on : null,
        label: label,
        excludeSemantics: true,
        child: PressScale(
          scale: 0.94,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 180),
            curve: kHouseCurve,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? HaloColors.amberSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: on ? HaloColors.amber : HaloColors.line2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: HaloType.sans(
                    size: 13,
                    weight: on ? FontWeight.w600 : FontWeight.w400,
                    color: ink,
                  ),
                ),
                if (more) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, size: 16, color: ink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String label;
  const _Head(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 12, bottom: 6),
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

class _FileRow extends StatelessWidget {
  final FileEntry entry;
  final String query;
  // who sent it, in a group
  final String? who;
  final int? size;
  final VoidCallback onTap;
  final FileRowActions Function() actions;
  const _FileRow({
    super.key,
    required this.entry,
    required this.query,
    required this.who,
    required this.size,
    required this.onTap,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final facts = FileFacts(kindOfName(e.name), extOf(safeFileName(e.name)));
    final shown = safeFileName(e.name, facts: facts);
    final (stem, ext) = splitFileName(shown);
    final style = HaloType.sans(
      size: 14.5,
      weight: FontWeight.w500,
      color: HaloColors.text,
    );
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: fileNameDir(stem),
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(children: litName(stem, query, style)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: fileNameDir(stem),
          ),
        ),
        if (ext.isNotEmpty)
          Text.rich(
            TextSpan(children: litName(ext, query, style)),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          ),
      ],
    );
    final w = e.mine || e.uid == null ? null : fileWaits.value[e.uid];
    final Widget lead;
    final String sub;
    if (w != null) {
      lead = FileWaitMark(wait: w);
      sub = [
        ?who,
        fileWaitRowLine(
          w,
          until: e.when.add(kFileKeptFor),
          left: fileWaitLeft(e.uid!),
        ),
      ].join(' · ');
    } else {
      final path = e.path;
      final badge = FileBadge(facts: facts, size: 42);
      lead = path == null
          ? badge
          : HaloHero(tag: fileHeroTag(path, 'shared'), child: badge);
      sub = [
        ?who,
        if (size != null) humanFileSize(size!),
        dayMonthMaybeYear(e.when),
      ].join(' · ');
    }
    return _HoldMenu(
      entry: e,
      title: shown,
      sub: sub,
      facts: facts,
      actions: actions,
      child: Semantics(
        button: true,
        label: '$shown, $sub',
        hint: w == null
            ? null
            : switch (w.state) {
                WaitState.coming => l10n.transferPauseDownload,
                WaitState.paused => l10n.transferResume,
                WaitState.asks => l10n.transferDownload,
              },
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      title,
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HaloType.mono(
                          size: 10.5,
                          color: HaloColors.text,
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
    );
  }
}

/// a hold on a row: the menu grows out of the row and shrinks back into it
class _HoldMenu extends StatelessWidget {
  final FileEntry entry;
  final String title;
  final String sub;
  final FileFacts facts;
  final FileRowActions Function() actions;
  final Widget child;
  const _HoldMenu({
    required this.entry,
    required this.title,
    required this.sub,
    required this.facts,
    required this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onLongPress: () => showFileRowMenu(
      context,
      title: title,
      sub: sub,
      facts: facts,
      actions: actions(),
    ),
    child: child,
  );
}

/// the row's menu, from where the row is on the screen
Future<void> showFileRowMenu(
  BuildContext rowContext, {
  required String title,
  required String sub,
  required FileFacts facts,
  required FileRowActions actions,
}) async {
  final box = rowContext.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  HapticFeedback.mediumImpact();
  await showGeneralDialog<void>(
    context: rowContext,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(rowContext).modalBarrierDismissLabel,
    barrierColor: const Color(0x8C080705),
    transitionDuration: motionStill(rowContext)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => _RowMenu(
      from: rect,
      title: title,
      sub: sub,
      facts: facts,
      actions: actions,
    ),
    transitionBuilder: (ctx, a, _, child) {
      final size = MediaQuery.sizeOf(ctx);
      // it grows from the row it came out of
      final origin = Alignment(
        (rect.center.dx / size.width) * 2 - 1,
        (rect.center.dy / size.height) * 2 - 1,
      );
      final curve = CurvedAnimation(
        parent: a,
        curve: kHouseCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          alignment: origin,
          scale: Tween(begin: 0.9, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class _RowMenu extends StatelessWidget {
  final Rect from;
  final String title;
  final String sub;
  final FileFacts facts;
  final FileRowActions actions;
  const _RowMenu({
    required this.from,
    required this.title,
    required this.sub,
    required this.facts,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    void go(VoidCallback f) {
      Navigator.of(context).pop();
      f();
    }

    final rows = <(IconData, String, VoidCallback, bool)>[
      if (actions.open case final f?)
        (Icons.open_in_new_rounded, l10n.filesOpen, f, false),
      if (actions.forward case final f?)
        (Icons.forward_rounded, l10n.chatForward, f, false),
      if (actions.save case final f?)
        (Icons.download_rounded, l10n.fileSaveToDevice, f, false),
      if (actions.showInChat case final f?)
        (Icons.chat_bubble_outline_rounded, l10n.filesShowInChat, f, false),
      if (actions.remove case final f?)
        (Icons.delete_outline_rounded, l10n.filesRemoveDownload, f, true),
    ];
    // under the row when it fits, else over it
    const rowH = 46.0;
    final h = 64 + rows.length * rowH + 16;
    final below = from.bottom + 8 + h < mq.size.height - mq.padding.bottom;
    final top = below
        ? from.bottom + 8
        : (from.top - 8 - h).clamp(mq.padding.top + 8, double.infinity);
    return Stack(
      children: [
        Positioned(
          left: 16,
          right: 16,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: HaloColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: HaloColors.line2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 50,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Row(
                      children: [
                        FileBadge(facts: facts, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: fileNameDir(title),
                                style: HaloType.sans(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: HaloColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HaloType.mono(
                                  size: 10,
                                  color: HaloColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: HaloColors.line),
                  for (final (icon, label, f, danger) in rows)
                    Semantics(
                      button: true,
                      label: label,
                      excludeSemantics: true,
                      child: PressScale(
                        scale: 0.98,
                        onTap: () => go(f),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: rowH),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: danger
                                      ? HaloColors.rose
                                      : HaloColors.amber,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HaloType.sans(
                                      size: 14.5,
                                      color: danger
                                          ? HaloColors.roseText
                                          : HaloColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
