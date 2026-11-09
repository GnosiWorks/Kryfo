// SPDX-License-Identifier: GPL-3.0-or-later
// a text or code file read inside kryfo: its words in a monospace face,
// line by line, never run, drawn or linked. read through the seal into
// memory, dropped as the lock goes up and read again once it lifts
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../file_kind.dart';
import '../file_peek.dart' show looksLikeText, visibleText;
import '../file_save.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'file_actions.dart';
import 'file_viewer_parts.dart';
import 'media_bubbles.dart' show humanFileSize;
import 'motion.dart' show motionStill;

/// the most of a file the reader takes in. a longer one says where it stops
const kTextViewMost = 2 << 20;

/// the extensions read as prose, each line in the way its own letters run;
/// everything else is code, left to right
const _proseExts = {'txt', 'md', 'srt', 'vtt', 'log', 'csv', 'tsv'};

Future<void> openTextFile(
  BuildContext context, {
  required String path,
  required String? name,
  required FileFacts facts,
  bool kept = false,
  String? from,
  Object? heroTag,
}) => openFileViewer(
  context,
  secure: kept,
  (_) => TextViewer(
    path: path,
    name: name,
    facts: facts,
    kept: kept,
    from: from,
    heroTag: heroTag,
  ),
);

/// the lines of [bytes] as the reader shows them, and whether some were
/// left out at the end
@visibleForTesting
({List<String> lines, bool cut}) textLinesOf(List<int> bytes, {int? whole}) {
  final cut = whole != null && whole > bytes.length;
  final text = utf8.decode(bytes, allowMalformed: true);
  final lines = const LineSplitter().convert(text).map(visibleText).toList();
  return (lines: lines, cut: cut);
}

/// the longest piece of a line one row draws: a minified file is one line
/// of megabytes, and one text of it would be laid out whole
const kTextRowMost = 4000;

/// [lines] as the reader's rows: a long line goes on in rows of its own
/// with no number of their own
@visibleForTesting
List<(int?, String)> textRowsOf(List<String> lines, {int most = kTextRowMost}) {
  final rows = <(int?, String)>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.length <= most) {
      rows.add((i + 1, l));
      continue;
    }
    for (var at = 0; at < l.length; at += most) {
      var end = at + most < l.length ? at + most : l.length;
      // never between the two halves of a surrogate pair
      if (end < l.length && (l.codeUnitAt(end) & 0xFC00) == 0xDC00) end--;
      rows.add((at == 0 ? i + 1 : null, l.substring(at, end)));
      at = end - most;
    }
  }
  return rows;
}

class TextViewer extends StatefulWidget {
  final String path;
  final String? name;
  final FileFacts facts;
  final bool kept;
  final String? from;
  final Object? heroTag;
  const TextViewer({
    super.key,
    required this.path,
    required this.name,
    required this.facts,
    this.kept = false,
    this.from,
    this.heroTag,
  });

  @override
  State<TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<TextViewer> {
  List<String>? _lines;
  bool _cut = false;
  bool _binary = false;
  int? _size;

  @override
  void initState() {
    super.initState();
    picturesShut.addListener(_lock);
    _read();
  }

  @override
  void dispose() {
    picturesShut.removeListener(_lock);
    super.dispose();
  }

  void _lock() {
    if (picturesShut.value) {
      if (mounted) setState(() => _lines = null);
    } else {
      _read();
    }
  }

  Future<void> _read() async {
    final b = <int>[];
    int? size;
    try {
      size = await File(widget.path).length();
      await for (final c in File(widget.path).openRead(0, kTextViewMost)) {
        b.addAll(c);
      }
    } catch (_) {
      // gone: the page says it cannot be read
    }
    if (!mounted || picturesShut.value) return;
    if (!looksLikeText(b.take(8192).toList())) {
      setState(() {
        _binary = true;
        _size = size;
      });
      return;
    }
    final r = textLinesOf(b, whole: size);
    b.fillRange(0, b.length, 0);
    setState(() {
      _lines = r.lines;
      _cut = r.cut;
      _size = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final facts = widget.facts;
    final shown = safeFileName(widget.name, facts: facts);
    final size = _size;
    final sub = [
      if (widget.from != null) l10n.fileFrom(widget.from!),
      if (size != null) humanFileSize(size),
      if (_lines != null) l10n.fileLines(_lines!.length, whole(_lines!.length)),
    ].join(' · ');
    final kept = widget.kept;
    return ColoredBox(
      color: HaloColors.ink,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FileViewerHead(
              shown: shown,
              facts: facts,
              sub: sub,
              heroTag: widget.heroTag,
            ),
            Expanded(child: _body(context)),
            FileViewerBar(
              onForward: canForwardFile(widget.path, widget.name, kept: kept)
                  ? () => forwardFile(context, widget.path, widget.name)
                  : null,
              onSave: kept
                  ? null
                  : () => saveReceivedFile(context, widget.path, widget.name),
              onOpenWith: kept
                  ? null
                  : () => openFileOutside(context, widget.path, widget.name),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_binary) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.fileNotWords,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 14, color: HaloColors.text),
          ),
        ),
      );
    }
    final lines = _lines;
    final still = motionStill(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 200),
      child: lines == null
          ? const SizedBox.expand(key: ValueKey('none'))
          : _Lines(
              key: const ValueKey('lines'),
              lines: lines,
              cut: _cut,
              prose: _proseExts.contains(widget.facts.ext),
            ),
    );
  }
}

class _Lines extends StatefulWidget {
  final List<String> lines;
  final bool cut;
  final bool prose;
  const _Lines({
    super.key,
    required this.lines,
    required this.cut,
    required this.prose,
  });

  @override
  State<_Lines> createState() => _LinesState();
}

class _LinesState extends State<_Lines> {
  late var _rows = textRowsOf(widget.lines);

  @override
  void didUpdateWidget(_Lines old) {
    super.didUpdateWidget(old);
    if (old.lines != widget.lines) _rows = textRowsOf(widget.lines);
  }

  @override
  Widget build(BuildContext context) {
    final style = HaloType.mono(
      size: 12.5,
      color: HaloColors.text,
      weight: FontWeight.w400,
    ).copyWith(height: 1.5);
    final gutter = HaloType.mono(
      size: 11,
      color: HaloColors.text,
      weight: FontWeight.w400,
    ).copyWith(height: 1.65);
    final lines = widget.lines;
    final rows = _rows;
    final cut = widget.cut;
    final prose = widget.prose;
    final digits = whole(lines.length).length;
    final scaler = MediaQuery.textScalerOf(context);
    final gutterW = scaler.scale(11) * 0.62 * digits + 16;
    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 10, 14, 24),
        itemCount: rows.length + (cut ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == rows.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                l10n.fileShowsFirst(humanFileSize(kTextViewMost)),
                style: HaloType.sans(size: 12.5, color: HaloColors.text),
              ),
            );
          }
          final (n, l) = rows[i];
          return Directionality(
            // code runs left to right in every language
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: gutterW,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        n == null ? '' : whole(n),
                        textAlign: TextAlign.right,
                        style: gutter,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    l.isEmpty ? ' ' : l,
                    style: style,
                    textDirection: prose
                        ? (writtenDir(l) ?? TextDirection.ltr)
                        : TextDirection.ltr,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
