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
import '../doc_read.dart' show DocPara;
import 'decode_px.dart' show screenPx;
import 'doc_viewer.dart' show kDocViewExts, readDocFile;
import 'file_actions.dart' show fileFactsOrName, fileViewOf, pdfViewHere;
import 'sealed_picture.dart' show mediaImage;
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
  // one of several going one after the other: an empty ring while it waits
  final bool queued;
  // the send did not go: no fill and no tick when its ring goes
  final bool failed;
  const FileCard({
    super.key,
    required this.path,
    required this.name,
    required this.isOut,
    this.sendingUid,
    this.onCancel,
    this.heroTag,
    this.glance = false,
    this.queued = false,
    this.failed = false,
  });

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  FileFacts? _facts;
  int? _size;
  // the last share its ring showed, and a tick for a moment once it is up
  bool _ticked = false;
  // done: the ring runs to full before the tick
  bool _filling = false;
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
    // the send is done: the ring fills the rest of the way, however little
    // it showed (a small file goes in one step), then a tick, then the tile
    if (old.sendingUid != null && widget.sendingUid == null && !widget.failed) {
      _filling = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
      _tickTimer?.cancel();
      // as long as the ring takes to reach full (FileSendRing's tween)
      _tickTimer = Timer(Duration(milliseconds: _filling ? 460 : 0), () {
        if (!mounted) return;
        HapticFeedback.lightImpact();
        setState(() {
          _filling = false;
          _ticked = true;
        });
        _tickTimer = Timer(const Duration(milliseconds: 1100), () {
          if (mounted) setState(() => _ticked = false);
        });
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
    // the same tree sending or not: the glance and the tick keep their
    // state when the send ends, nothing is drawn again
    return ValueListenableBuilder<int>(
      valueListenable: mediaProgressTick,
      builder: (context, _, _) {
        final uid = widget.sendingUid;
        if (uid == null) return _card(context, null);
        final v = mediaSendProgress[uid];
        if (mediaQuiet(uid)) return _card(context, null);
        // one of a set waiting its turn: its ring is there, empty, so the
        // row does not change shape when it starts
        if (v == null) {
          return widget.queued
              ? _card(context, (uid, -1))
              : _card(context, null);
        }
        return _card(context, (uid, v));
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
    // theirs whose download was removed: the message stays, the file not
    final gone = widget.path == null && !isOut && widget.name != null;
    final meta = going != null
        ? _goingLine(going.$1, going.$2)
        : gone
        ? l10n.fileNotHere
        : fileMetaLine(facts, size);
    final still = motionStill(context);
    final nameStyle = HaloType.sans(
      size: 14,
      color: fg,
      weight: FontWeight.w600,
    );
    final path = widget.path;
    // drawn while it goes too: the page or the lines never pop in after
    final preview = path != null && !installer
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
            : _filling && going == null
            ? FileSendRing(
                key: const ValueKey('going'),
                share: 1,
                onAccent: isOut,
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
                    // the tick pops in a little; everything else, the
                    // tile after it too, only cross-fades
                    AnimatedSwitcher(
                      duration: still
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      switchInCurve: kHouseCurve,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: c.key == const ValueKey('tick')
                            ? ScaleTransition(
                                scale: Tween(begin: 0.8, end: 1.0).animate(a),
                                child: c,
                              )
                            : c,
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
    if (v < 0) return l10n.chatWaitsToSend;
    // preparing until a byte goes, then sending: never "0 b" first
    if (mediaPreparing.contains(uid) || v == 0) {
      return l10n.mediaProgressPreparingNow;
    }
    final d = transferDetail(uid, v);
    return d == null ? percent(v) : '$d · ${percent(v)}';
  }

  Widget? _previewFor(String path, FileFacts facts) {
    // a photo among files: the picture itself above its row
    if (widget.queued && facts.kind == FileKind.picture) {
      return SetPicture(path: path);
    }
    if (textViewable(facts.ext)) {
      return FileTextPreview(path: path, isOut: widget.isOut);
    }
    if (kDocViewExts.contains(facts.ext)) {
      return FileTextPreview(path: path, isOut: widget.isOut, doc: true);
    }
    if (facts.kind == FileKind.pdf &&
        pdfViewHere &&
        (widget.glance || pdfOpenedByHand.contains(path))) {
      return PdfFirstPage(path: path);
    }
    return null;
  }
}

/// the width a photo in a file set is decoded at, made ready at the same
/// size before its bubble shows
int setPicturePx(BuildContext context) =>
    (kFilePreviewWidth * MediaQuery.devicePixelRatioOf(context)).round();

/// a photo in a set of files, at the row's width. ours is on this phone and
/// made ready first, so it is there sharp from the first frame; theirs
/// fades up once read
class SetPicture extends StatelessWidget {
  final String path;
  const SetPicture({super.key, required this.path});

  static const height = 150.0;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: kFilePreviewWidth,
        height: height,
        child: Image(
          image: mediaImage(path, setPicturePx(context)),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
          frameBuilder: (_, child, frame, sync) => sync || still
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                ),
        ),
      ),
    );
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
  // a word document: its first paragraphs, read as its reader reads it
  final bool doc;
  const FileTextPreview({
    super.key,
    required this.path,
    required this.isOut,
    this.doc = false,
  });

  @override
  State<FileTextPreview> createState() => _FileTextPreviewState();
}

class _FileTextPreviewState extends State<FileTextPreview> {
  late List<String>? _lines = widget.doc ? null : firstLinesNow(widget.path);
  // a word document's first paragraphs, its headings marked
  late List<DocLine>? _paras = widget.doc ? _docLines[widget.path] : null;
  // there on the first frame: drawn at once, never faded in again
  late final bool _hadIt = _lines != null || _paras != null;

  @override
  void initState() {
    super.initState();
    picturesShut.addListener(_lock);
    if (_lines == null && _paras == null) _read();
  }

  @override
  void didUpdateWidget(FileTextPreview old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _lines = widget.doc ? null : firstLinesNow(widget.path);
      _paras = widget.doc ? _docLines[widget.path] : null;
      if (_lines == null && _paras == null) _read();
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
      forgetDocLines();
      if (mounted) {
        setState(() {
          _lines = null;
          _paras = null;
        });
      }
    } else {
      _read();
    }
  }

  Future<void> _read() async {
    final p = widget.path;
    if (widget.doc) {
      final d = await docFirstLines(p);
      if (!mounted || p != widget.path || picturesShut.value) return;
      if (d != null) setState(() => _paras = d);
      return;
    }
    final l = await firstLinesOf(p);
    if (!mounted || p != widget.path || picturesShut.value) return;
    if (l != null) setState(() => _lines = l);
  }

  // a word document as its reader sets it: headings bold, words wrapped,
  // about four lines, ending on a whole line that fades when more follows.
  // on the bubble's own ground, no box around it
  Widget _docGlance(BuildContext context, List<DocLine> paras) {
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final fg = widget.isOut ? HaloColors.onAmber : HaloColors.text;
    final body = HaloType.sans(size: 12, color: fg, height: 1.35);
    final head = HaloType.sans(
      size: 13,
      color: fg,
      weight: FontWeight.w700,
      height: 1.3,
    );
    return Container(
      width: kFilePreviewWidth,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      // a fixed width: the bubble measures it in its intrinsic pass
      child: Builder(
        builder: (context) {
          final dir = Directionality.of(context);
          var left = kDocGlanceLines;
          var more = false;
          final kids = <Widget>[];
          for (final (i, l) in paras.indexed) {
            if (left <= 0) {
              more = true;
              break;
            }
            final style = l.head ? head : body;
            final tp = TextPainter(
              text: TextSpan(text: l.text, style: style),
              textDirection: dir,
              textScaler: scaler,
              maxLines: left,
            )..layout(maxWidth: kFilePreviewWidth - 22);
            final n = tp.computeLineMetrics().length;
            final over = tp.didExceedMaxLines;
            tp.dispose();
            kids.add(
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
                child: Text(
                  l.text,
                  maxLines: left,
                  // whole lines only: the last one ends where it ends
                  overflow: TextOverflow.clip,
                  textScaler: scaler,
                  style: style,
                ),
              ),
            );
            left -= n;
            if (over) {
              more = true;
              break;
            }
          }
          if (kids.length < paras.length) more = true;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: kids,
          );
          if (!more) return text;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x26FFFFFF)],
              stops: [0, 0.72, 1],
            ).createShader(r),
            child: text,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paras = _paras;
    if (widget.doc && paras != null) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: motionStill(context) || _hadIt ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 220),
        builder: (_, v, c) => Opacity(opacity: v, child: c),
        child: _docGlance(context, paras),
      );
    }
    final lines = _lines;
    // a glance, not the reader: it grows with the text size, only so far
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final style = HaloType.mono(
      size: 10.5,
      color: HaloColors.text,
    ).copyWith(height: 1.45);
    // the room four lines take is kept while they are read, so the bubble
    // does not jump when they fade in
    final kept = widget.doc
        ? docGlanceHeight(scaler)
        : scaler.scale(10.5) * 1.45 * 4 + 18;
    return EaseSize(
      duration: const Duration(milliseconds: 220),
      alignment: AlignmentDirectional.topStart,
      child: lines == null
          ? Container(
              width: kFilePreviewWidth,
              height: kept,
              decoration: BoxDecoration(
                color: widget.doc
                    ? (widget.isOut ? HaloColors.onAmber : HaloColors.text)
                          .withValues(alpha: 0.06)
                    : HaloColors.ink.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(
                begin: motionStill(context) || _hadIt ? 1 : 0,
                end: 1,
              ),
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

/// how many pages a pdf has, on its first page in the bubble
class PdfPagesPill extends StatelessWidget {
  final int pages;
  const PdfPagesPill({super.key, required this.pages});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xD112100D),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      l10n.filePages(pages, whole(pages)),
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      style: HaloType.mono(size: 9.5, color: const Color(0xFFF5F1EA)),
    ),
  );
}

/// a pdf's first page on paper, its top in view, with how many pages it
/// has. lines stand in for it while it is drawn; nothing when it cannot be
// the first pages on screen, by file: where a viewer grows out of
final Map<String, List<BuildContext>> _glancesShown = {};

/// where [path]'s first page shows in a bubble on screen: the one inside
/// [tapped] when there is one. null when none shows
Rect? pdfGlanceRect(String path, Rect? tapped) {
  Rect? any;
  for (final c in _glancesShown[path] ?? const <BuildContext>[]) {
    final b = c.findRenderObject();
    if (b is! RenderBox || !b.attached || !b.hasSize) continue;
    final r = b.localToGlobal(Offset.zero) & b.size;
    if (tapped == null || tapped.overlaps(r)) return r;
    any ??= r;
  }
  return tapped == null ? any : null;
}

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
  // drawn from its first frame: no paper, no fade, the page as it is
  bool _hadIt = false;

  static const _height = 120.0;

  @override
  void initState() {
    super.initState();
    pdfGlancesGone.addListener(_gone);
    picturesShut.addListener(_lock);
    _take(pdfGlanceNow(widget.path));
    _hadIt = _image != null;
    (_glancesShown[widget.path] ??= []).add(context);
  }

  @override
  void didUpdateWidget(PdfFirstPage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _unshow(old.path);
      (_glancesShown[widget.path] ??= []).add(context);
    }
  }

  void _unshow(String path) {
    final l = _glancesShown[path];
    l?.remove(context);
    if (l != null && l.isEmpty) _glancesShown.remove(path);
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
    _unshow(widget.path);
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
            if (!_hadIt)
              AnimatedOpacity(
                opacity: img == null ? 1 : 0,
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: const _PaperLines(),
              ),
            if (img != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: still || _hadIt ? 1 : 0, end: 1),
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
                child: PdfPagesPill(pages: pages),
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

/// what a bubble of ours draws from its own file, made ready before the
/// bubble shows it: a pdf's first page, a text's first lines, a photo at
/// the bubble's size. the file is on this phone, so nothing of ours ever
/// shows a stand-in first. given up on after [most]
Future<void> warmSentPreview(
  BuildContext context,
  String path,
  String? name, {
  Duration most = const Duration(milliseconds: 1500),
}) async {
  try {
    if (name == null) {
      await precacheImage(
        mediaImage(path, screenPx(context, times: 0.78)),
        context,
        onError: (_, _) {},
      ).timeout(most);
      return;
    }
    final facts = fileFactsOrName(path, name);
    if (facts.kind == FileKind.picture) {
      // as a row of a set draws it
      await precacheImage(
        mediaImage(path, setPicturePx(context)),
        context,
        onError: (_, _) {},
      ).timeout(most);
    } else if (textViewable(facts.ext)) {
      await firstLinesOf(path).timeout(most);
    } else if (kDocViewExts.contains(facts.ext)) {
      await docFirstLines(path).timeout(most);
    } else if (facts.kind == FileKind.pdf && pdfViewHere) {
      final px = (kFilePreviewWidth * MediaQuery.devicePixelRatioOf(context))
          .round();
      await pdfGlance(path, px).timeout(most);
    }
  } catch (_) {
    // too slow or unreadable: the bubble draws as it would have
  }
}

// a document's first lines, kept like a text's, dropped at the lock
final Map<String, List<DocLine>> _docLines = {};

/// a paragraph of a document's glance
typedef DocLine = ({String text, bool head});

/// the glance's height: about four lines of body text, the last fading
double docGlanceHeight(TextScaler scaler) =>
    scaler.scale(12) * 1.35 * kDocGlanceLines + 18;

/// the lines a document's glance shows at most
const kDocGlanceLines = 4;

/// the first four paragraphs with words of the document at [path]
Future<List<DocLine>?> docFirstLines(String path) async {
  final kept = _docLines[path];
  if (kept != null) return kept;
  final d = await readDocFile(path);
  if (d == null) return null;
  final lines = <DocLine>[
    for (final b in d.blocks)
      if (b is DocPara && b.text.trim().isNotEmpty)
        (text: b.text.trim(), head: b.heading > 0),
  ].take(4).toList();
  if (lines.isEmpty) return null;
  if (_docLines.length > 24) _docLines.remove(_docLines.keys.first);
  return _docLines[path] = lines;
}

/// the lock lets go of every document's first lines
void forgetDocLines() => _docLines.clear();
