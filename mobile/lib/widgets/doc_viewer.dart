// SPDX-License-Identifier: GPL-3.0-or-later
// a word document read inside kryfo: its headings, paragraphs, lists and
// tables, with bold, italic and underline, never run, linked or fetched.
// read off the ui isolate with caps (doc_read.dart), dropped as the lock
// goes up and read again once it lifts. "Open with…" stays in its bar
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/material.dart';

import '../doc_read.dart';
import '../file_kind.dart';
import '../file_save.dart';
import '../l10n/l10n.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'file_actions.dart';
import 'file_viewer_parts.dart';
import 'media_bubbles.dart' show humanFileSize;
import 'motion.dart' show motionStill;

/// the extensions the document reader opens
const kDocViewExts = {'docx'};

/// how long a document may take to read before the page says it cannot
const kDocReadMost = Duration(seconds: 8);

Future<void> openDocFile(
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
  (_) => DocViewer(
    path: path,
    name: name,
    facts: facts,
    kept: kept,
    from: from,
    heroTag: heroTag,
  ),
);

DocRead? _readApart(Uint8List bytes) => readDocx(bytes);

/// [path] read as a document, off the ui isolate; null when it cannot be.
/// tests put their own in
Future<DocRead?> Function(String path) readDocFile = (path) async {
  final f = File(path);
  if (await f.length() > kDocMostBytes) return null;
  final b = await f.readAsBytes();
  try {
    return await compute(_readApart, b).timeout(kDocReadMost);
  } catch (_) {
    return null;
  } finally {
    b.fillRange(0, b.length, 0);
  }
};

class DocViewer extends StatefulWidget {
  final String path;
  final String? name;
  final FileFacts facts;
  final bool kept;
  final String? from;
  final Object? heroTag;
  const DocViewer({
    super.key,
    required this.path,
    required this.name,
    required this.facts,
    this.kept = false,
    this.from,
    this.heroTag,
  });

  @override
  State<DocViewer> createState() => DocViewerState();
}

class DocViewerState extends State<DocViewer> {
  DocRead? _doc;
  bool _failed = false;
  int? _size;

  @visibleForTesting
  DocRead? get doc => _doc;

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
      if (mounted) setState(() => _doc = null);
    } else {
      _read();
    }
  }

  Future<void> _read() async {
    int? size;
    DocRead? d;
    try {
      size = await File(widget.path).length();
      d = await readDocFile(widget.path);
    } catch (_) {
      d = null;
    }
    if (!mounted || picturesShut.value) return;
    setState(() {
      _size = size;
      _doc = d;
      _failed = d == null;
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
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.fileDocUnreadable,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 14, color: HaloColors.text),
          ),
        ),
      );
    }
    final d = _doc;
    final still = motionStill(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 200),
      child: d == null
          ? const SizedBox.expand(key: ValueKey('none'))
          : _Paper(key: const ValueKey('doc'), doc: d),
    );
  }
}

// the document as a page: light paper with dark words, as it was written
class _Paper extends StatelessWidget {
  final DocRead doc;
  const _Paper({super.key, required this.doc});

  static const _ink = Color(0xFF1F1A15);
  static const _paper = Color(0xFFFBF8F3);

  @override
  Widget build(BuildContext context) {
    final blocks = doc.blocks;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: blocks.length + 1,
      itemBuilder: (context, i) {
        final first = i == 0;
        final last = i == blocks.length;
        final Widget child = last
            ? (doc.cut
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        l10n.fileDocCut,
                        style: HaloType.sans(size: 13, color: _ink),
                      ),
                    )
                  : const SizedBox(height: 8))
            : _block(blocks[i]);
        return Container(
          decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(first ? 6 : 0),
              bottom: Radius.circular(last ? 6 : 0),
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, first ? 20 : 0, 20, last ? 16 : 0),
          child: child,
        );
      },
    );
  }

  Widget _block(DocBlock b) => switch (b) {
    DocPara p => _para(p),
    DocTable t => _table(t),
  };

  Widget _para(DocPara p) {
    final size = switch (p.heading) {
      4 => 24.0,
      1 => 21.0,
      2 => 18.0,
      3 => 16.0,
      _ => 15.0,
    };
    final base =
        (p.heading > 0
                ? HaloType.serif(size: size, color: _ink)
                : HaloType.sans(size: size, color: _ink))
            .copyWith(height: 1.45);
    final words = Text.rich(
      TextSpan(
        children: [
          for (final r in p.runs)
            TextSpan(
              text: r.text,
              style: base.copyWith(
                fontWeight: r.bold || p.heading > 0
                    ? FontWeight.w700
                    : FontWeight.w400,
                fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
                decoration: r.underline ? TextDecoration.underline : null,
              ),
            ),
        ],
      ),
      // each paragraph runs the way its own first letters do
      textDirection: _dirOf(p.text),
    );
    final top = p.heading > 0 ? 14.0 : 0.0;
    final list = p.list;
    if (list == null) {
      return Padding(
        padding: EdgeInsets.only(top: top, bottom: 8),
        child: SizedBox(width: double.infinity, child: words),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 16.0 * list, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: base),
          Expanded(child: words),
        ],
      ),
    );
  }

  Widget _table(DocTable t) {
    final cols = t.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final style = HaloType.sans(size: 13, color: _ink).copyWith(height: 1.35);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: const Color(0xFFCFC6BA)),
          children: [
            for (final r in t.rows)
              TableRow(
                children: [
                  for (var c = 0; c < cols; c++)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          c < r.length ? r[c] : '',
                          style: style,
                          textDirection: _dirOf(c < r.length ? r[c] : ''),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

final _rtlStart = RegExp('^[^A-Za-z]*[֐-ࣿיִ-﷿ﹰ-﻿]');

TextDirection _dirOf(String s) =>
    _rtlStart.hasMatch(s) ? TextDirection.rtl : TextDirection.ltr;
