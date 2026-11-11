// SPDX-License-Identifier: GPL-3.0-or-later
// a file in a chat: its kind as a coloured tile, its name with the real
// extension always in view, its size, and a glance at what is inside (a
// code file's first lines, a pdf's first page). while it goes out a ring
// fills where the tile was, with a cross that stops it. the kind is read
// from the bytes, so a renamed app installer still shows as one, with a
// line about it; its tap saves instead of opening
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_kind.dart';
import '../file_peek.dart';
import '../pdf_pages.dart';
import '../file_save.dart' show savingFiles;
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show percent, whole;
import '../media_progress.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'file_actions.dart' show fileViewOf, pdfViewHere;
import 'ease_size.dart';
import 'file_badge.dart';
import 'halo_hero.dart';
import 'motion.dart' show kHouseCurve, motionStill;
import 'swap.dart';
import 'media_bubbles.dart' show humanFileSize, splitFileName;

final _rtlStart = RegExp(
  '^[^A-Za-z]*[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
);

/// the way a file's name runs: by its own first letters, so a latin name
/// keeps its extension at its end in a right to left app
TextDirection fileNameDir(String stem) =>
    _rtlStart.hasMatch(stem) ? TextDirection.rtl : TextDirection.ltr;

/// the preview box's width: fixed, so the bubble's intrinsic pass needs no
/// layout of its own
const kFilePreviewWidth = 236.0;

/// the line under the name: the size, after the extension when the tile
/// shows a glyph instead of it
String fileMetaLine(FileFacts facts, int? size) {
  final kind = facts.ext.isEmpty
      ? l10n.mediaBubblesFile
      : facts.ext.toUpperCase();
  final glyph =
      facts.installer ||
      facts.ext.isEmpty ||
      fileToneOf(facts) == FileTone.audio ||
      fileToneOf(facts) == FileTone.video;
  if (size == null) return glyph ? kind : '';
  return glyph ? '$kind · ${humanFileSize(size)}' : humanFileSize(size);
}

class FileCard extends StatefulWidget {
  final String? path;
  final String? name;
  final bool isOut;
  // ours on its way: its share fills a ring in place of the tile
  final String? sendingUid;
  // the ring's cross: stops the send
  final VoidCallback? onCancel;
  // the tile flies to the viewer's head under this tag
  final Object? heroTag;
  // a pdf's first page is drawn only for a file from someone known (ours,
  // a contact's) or one the person opened by hand: a stranger's pdf that
  // came on its own is not handed to the phone's renderer unasked
  final bool glance;
  const FileCard({
    super.key,
    required this.path,
    required this.name,
    required this.isOut,
    this.sendingUid,
    this.onCancel,
    this.heroTag,
    this.glance = false,
  });

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  FileFacts? _facts;
  int? _size;
  // the last share its ring showed, and a tick for a moment once it is up
  double _lastShare = 0;
  bool _ticked = false;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(FileCard old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.name != widget.name) _start();
    // the ring filled and the send is done: a tick, then the tile
    if (old.sendingUid != null &&
        widget.sendingUid == null &&
        _lastShare >= 0.99) {
      _lastShare = 0;
      HapticFeedback.lightImpact();
      _ticked = true;
      _tickTimer?.cancel();
      _tickTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _ticked = false);
      });
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _start() {
    final p = widget.path;
    _facts = p == null ? null : fileFactsNow(p, widget.name);
    _size = null;
    if (p != null) _read(p, widget.name);
  }

  Future<void> _read(String p, String? name) async {
    final facts = await readFileFacts(p, name);
    int? size;
    try {
      size = await File(p).length();
    } catch (_) {
      // gone or unreadable: the card shows no size
    }
    if (!mounted || p != widget.path || name != widget.name) return;
    setState(() {
      _facts = facts;
      _size = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.sendingUid;
    if (uid == null) return _card(context, null);
    return ValueListenableBuilder<int>(
      valueListenable: mediaProgressTick,
      builder: (context, _, _) {
        final v = mediaSendProgress[uid];
        if (v != null) _lastShare = v;
        return _card(context, v == null || mediaQuiet(uid) ? null : (uid, v));
      },
    );
  }

  Widget _card(BuildContext context, (String, double)? going) {
    final isOut = widget.isOut;
    final facts =
        _facts ??
        FileFacts(kindOfName(widget.name), extOf(safeFileName(widget.name)));
    final installer = facts.installer;
    final fg = isOut ? HaloColors.onAmber : HaloColors.text;
    // the name it is saved and handed on under: what is seen is what is
    // saved
    final shown = safeFileName(widget.name, facts: facts);
    final (stem, ext) = splitFileName(shown);
    final nameDir = fileNameDir(stem);
    final kind = facts.ext.isEmpty
        ? l10n.mediaBubblesFile
        : facts.ext.toUpperCase();
    final size = _size;
    final meta = going == null
        ? fileMetaLine(facts, size)
        : _goingLine(going.$1, going.$2);
    final still = motionStill(context);
    final nameStyle = HaloType.sans(
      size: 14,
      color: fg,
      weight: FontWeight.w600,
    );
    final path = widget.path;
    final preview = path != null && !installer && going == null
        ? _previewFor(path, facts)
        : null;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: savingFiles,
      builder: (context, saving, _) {
        final busy = path != null && saving.contains(path);
        final Widget mark = busy
            ? SizedBox(
                key: const ValueKey('saving'),
                width: 38,
                height: 38,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isOut ? HaloColors.onAmber : HaloColors.amber,
                  ),
                ),
              )
            : _ticked && going == null && !still
            ? Container(
                key: const ValueKey('tick'),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isOut ? HaloColors.onAmber : HaloColors.amber)
                      .withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: isOut ? HaloColors.onAmber : HaloColors.amber,
                ),
              )
            : going != null
            ? FileSendRing(
                key: const ValueKey('going'),
                share: going.$2,
                onAccent: isOut,
                onCancel: widget.onCancel,
              )
            : installer
            ? Container(
                key: const ValueKey('save'),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isOut
                      ? HaloColors.onAmber.withValues(alpha: 0.16)
                      : HaloColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.download_rounded,
                  size: 20,
                  color: isOut ? HaloColors.onAmber : HaloColors.amber,
                ),
              )
            : _hero(
                FileBadge(
                  key: ValueKey(facts.ext),
                  facts: facts,
                  onAccent: isOut,
                ),
              );
        return Semantics(
          container: true,
          button: path != null,
          label: [
            shown,
            installer ? l10n.fileAppInstaller : kind,
            if (going != null)
              _goingLine(going.$1, going.$2)
            else if (size != null)
              humanFileSize(size),
            if (installer) l10n.fileInstallerLine,
          ].join(', '),
          hint: path == null
              ? null
              : installer
              ? l10n.fileSaveToDevice
              : going != null
              ? null
              // a pdf, a text or a sound opens in kryfo's own viewer
              : fileViewOf(facts) != null
              ? l10n.fileViewInKryfo
              : l10n.fileOpenHint,
          excludeSemantics: going == null || widget.onCancel == null,
          child: ConstrainedBox(
            // large text gets a little more room, never past the bubble's
            constraints: BoxConstraints(
              maxWidth: MediaQuery.textScalerOf(context).scale(10) > 12
                  ? 320
                  : 260,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (preview != null) ...[
                  ExcludeSemantics(child: preview),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: still
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      switchInCurve: kHouseCurve,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.6, end: 1.0).animate(a),
                          child: c,
                        ),
                      ),
                      child: mark,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // the extension stays in view however long the
                          // name, so photo.jpg.apk never reads as a photo
                          ExcludeSemantics(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: nameDir,
                              children: [
                                Flexible(
                                  child: Text(
                                    stem,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: nameDir,
                                    // as wide as what is drawn, so the
                                    // extension sits right after the dots
                                    textWidthBasis: TextWidthBasis.longestLine,
                                    style: nameStyle,
                                  ),
                                ),
                                if (ext.isNotEmpty)
                                  Text(
                                    ext,
                                    maxLines: 1,
                                    textDirection: TextDirection.ltr,
                                    style: nameStyle,
                                  ),
                              ],
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            ExcludeSemantics(
                              child: RiseSwap(
                                child: Text(
                                  meta,
                                  key: ValueKey(going == null ? meta : 'going'),
                                  // wraps at large sizes: nothing is cut
                                  maxLines: 3,
                                  style: HaloType.mono(size: 10, color: fg),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (installer)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: ExcludeSemantics(
                            child: Text(
                              l10n.fileInstallerLine,
                              style: HaloType.sans(
                                size: 12,
                                color: fg,
                                height: 1.35,
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
      },
    );
  }

  Widget _hero(Widget badge) {
    final tag = widget.heroTag;
    return tag == null
        ? badge
        : HaloHero(key: badge.key, tag: tag, child: badge);
  }

  String _goingLine(String uid, double v) {
    if (mediaPreparing.contains(uid)) return l10n.mediaProgressPreparing;
    final d = transferDetail(uid, v);
    return d == null ? percent(v) : '$d · ${percent(v)}';
  }

  Widget? _previewFor(String path, FileFacts facts) {
    if (textViewable(facts.ext)) {
      return FileTextPreview(path: path, isOut: widget.isOut);
    }
    if (facts.kind == FileKind.pdf &&
        pdfViewHere &&
        (widget.glance || pdfOpenedByHand.contains(path))) {
      return PdfFirstPage(path: path);
    }
    return null;
  }
}

/// the ring of a file on its way, filling as it goes, with a cross that
/// stops it. no cross when nothing can stop it
class FileSendRing extends StatelessWidget {
  final double share;
  final bool onAccent;
  final VoidCallback? onCancel;
  final double size;
  const FileSendRing({
    super.key,
    required this.share,
    this.onAccent = false,
    this.onCancel,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final ink = onAccent ? HaloColors.onAmber : HaloColors.amber;
    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: 0.12),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: share.clamp(0.03, 1.0)),
            duration: still ? Duration.zero : const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => SizedBox(
              width: size - 2,
              height: size - 2,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 2.6,
                strokeCap: StrokeCap.round,
                color: ink,
                backgroundColor: ink.withValues(alpha: 0.18),
              ),
            ),
          ),
          if (onCancel != null)
            Icon(Icons.close_rounded, size: size * 0.4, color: ink),
        ],
      ),
    );
    final stop = onCancel;
    if (stop == null) return ring;
    return Semantics(
      button: true,
      label: l10n.chatStopSending,
      excludeSemantics: true,
      onTap: stop,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          stop();
        },
        child: ring,
      ),
    );
  }
}

class FileTextPreview extends StatefulWidget {
  final String path;
  final bool isOut;
  const FileTextPreview({super.key, required this.path, required this.isOut});

  @override
  State<FileTextPreview> createState() => _FileTextPreviewState();
}

class _FileTextPreviewState extends State<FileTextPreview> {
  late List<String>? _lines = firstLinesNow(widget.path);

  @override
  void initState() {
    super.initState();
    picturesShut.addListener(_lock);
    if (_lines == null) _read();
  }

  @override
  void didUpdateWidget(FileTextPreview old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _lines = firstLinesNow(widget.path);
      if (_lines == null) _read();
    }
  }

  @override
  void dispose() {
    picturesShut.removeListener(_lock);
    super.dispose();
  }

  void _lock() {
    if (picturesShut.value) {
      forgetFirstLines();
      if (mounted) setState(() => _lines = null);
    } else {
      _read();
    }
  }

  Future<void> _read() async {
    final p = widget.path;
    final l = await firstLinesOf(p);
    if (!mounted || p != widget.path || picturesShut.value) return;
    if (l != null) setState(() => _lines = l);
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    // a glance, not the reader: it grows with the text size, only so far
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final style = HaloType.mono(
      size: 10.5,
      color: HaloColors.text,
    ).copyWith(height: 1.45);
    // the room four lines take is kept while they are read, so the bubble
    // does not jump when they fade in
    final kept = scaler.scale(10.5) * 1.45 * 4 + 18;
    return EaseSize(
      duration: const Duration(milliseconds: 220),
      alignment: AlignmentDirectional.topStart,
      child: lines == null
          ? Container(
              width: kFilePreviewWidth,
              height: kept,
              decoration: BoxDecoration(
                color: HaloColors.ink.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: motionStill(context) ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 220),
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: Container(
                width: kFilePreviewWidth,
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                decoration: BoxDecoration(
                  color: HaloColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  // code starts at the left whatever the app's language
                  textDirection: TextDirection.ltr,
                  children: [
                    for (final l in lines)
                      Text(
                        l.isEmpty ? ' ' : l,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        // code reads left to right whatever the app's language
                        textDirection: TextDirection.ltr,
                        textScaler: scaler,
                        style: style,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// a pdf's first page on paper, its top in view, with how many pages it
/// has. lines stand in for it while it is drawn; nothing when it cannot be
class PdfFirstPage extends StatefulWidget {
  final String path;
  const PdfFirstPage({super.key, required this.path});

  @override
  State<PdfFirstPage> createState() => _PdfFirstPageState();
}

class _PdfFirstPageState extends State<PdfFirstPage> {
  ui.Image? _image;
  int? _pages;
  bool _failed = false;

  static const _height = 120.0;

  @override
  void initState() {
    super.initState();
    pdfGlancesGone.addListener(_gone);
    picturesShut.addListener(_lock);
    _take(pdfGlanceNow(widget.path));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_image == null && !_failed) _ask();
  }

  @override
  void dispose() {
    pdfGlancesGone.removeListener(_gone);
    picturesShut.removeListener(_lock);
    _image?.dispose();
    super.dispose();
  }

  void _take(PdfGlance? g) {
    if (g == null) return;
    _image?.dispose();
    _image = g.image.clone();
    _pages = g.pages;
  }

  void _gone() {
    if (!mounted) return;
    setState(() {
      _image?.dispose();
      _image = null;
    });
  }

  void _lock() {
    if (!picturesShut.value && mounted) _ask();
  }

  Future<void> _ask() async {
    if (picturesShut.value) return;
    final px = (kFilePreviewWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    final g = await pdfGlance(widget.path, px);
    if (!mounted || picturesShut.value) return;
    setState(() {
      if (g == null) {
        _failed = true;
      } else {
        _take(g);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final img = _image;
    final still = motionStill(context);
    final pages = _pages;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: kFilePreviewWidth,
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFFFFFFF)),
            AnimatedOpacity(
              opacity: img == null ? 1 : 0,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: const _PaperLines(),
            ),
            if (img != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: still ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 240),
                builder: (_, v, c) => Opacity(opacity: v, child: c),
                child: RawImage(
                  image: img,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            if (pages != null)
              PositionedDirectional(
                end: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD112100D),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    l10n.filePages(pages, whole(pages)),
                    textScaler: MediaQuery.textScalerOf(
                      context,
                    ).clamp(maxScaleFactor: 1.3),
                    style: HaloType.mono(
                      size: 9.5,
                      color: const Color(0xFFF5F1EA),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// a page's lines before the page itself is drawn
class _PaperLines extends StatelessWidget {
  const _PaperLines();

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2F2922);
    const soft = Color(0xFFCFC6BA);
    Widget bar(double w, double h, Color c) => FractionallySizedBox(
      widthFactor: w,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(0.55, 7, ink),
          for (final w in const [0.9, 0.84, 0.88, 0.6]) ...[
            const SizedBox(height: 6),
            bar(w, 4, soft),
          ],
          const SizedBox(height: 12),
          bar(0.86, 4, soft),
        ],
      ),
    );
  }
}
