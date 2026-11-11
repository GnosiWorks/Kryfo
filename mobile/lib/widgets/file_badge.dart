// SPDX-License-Identifier: GPL-3.0-or-later
// a file's kind at a glance: a small tile in the kind's colour with its
// extension on it, the same in the bubble, the menus, the viewers and the
// files tab
import 'package:flutter/material.dart';

import '../file_kind.dart';
import '../theme.dart';

enum FileTone { pdf, code, audio, sheet, video, picture, doc, zip, other }

const _codeExts = {
  'txt',
  'md',
  'log',
  'json',
  'xml',
  'html',
  'htm',
  'css',
  'js',
  'mjs',
  'ts',
  'tsx',
  'jsx',
  'py',
  'rb',
  'go',
  'rs',
  'dart',
  'kt',
  'kts',
  'java',
  'c',
  'h',
  'cc',
  'cpp',
  'hpp',
  'cs',
  'swift',
  'php',
  'sh',
  'bash',
  'zsh',
  'ps1',
  'bat',
  'sql',
  'yaml',
  'yml',
  'toml',
  'ini',
  'conf',
  'cfg',
  'env',
  'lua',
  'pl',
  'r',
  'scala',
  'tex',
  'srt',
  'vtt',
  'gradle',
  'properties',
  'diff',
  'patch',
  'vcf',
  'ics',
  'gpx',
  'kml',
  'asc',
  'pem',
  'pub',
  'gitignore',
};

const _sheetExts = {'csv', 'tsv', 'xls', 'xlsx', 'ods', 'numbers'};

/// the extensions the text viewer opens: words, never run or drawn
bool textViewable(String ext) =>
    _codeExts.contains(ext) || ext == 'csv' || ext == 'tsv';

FileTone fileToneOf(FileFacts facts) {
  final e = facts.ext;
  if (_sheetExts.contains(e)) return FileTone.sheet;
  if (_codeExts.contains(e)) return FileTone.code;
  return switch (facts.kind) {
    FileKind.pdf => FileTone.pdf,
    FileKind.audio => FileTone.audio,
    FileKind.video => FileTone.video,
    FileKind.archive => FileTone.zip,
    FileKind.document => FileTone.doc,
    FileKind.text => FileTone.code,
    // a picture that is not drawn as one: a camera's raw file, a tiff
    FileKind.picture => FileTone.picture,
    FileKind.installer || FileKind.other => FileTone.other,
  };
}

/// the kind's colour, from the theme's own tones. the light theme takes
/// their deeper word tones, so the white label keeps its contrast
Color fileToneColor(FileTone t) {
  final c = _toneBase(t);
  return HaloColors.isLight ? HaloColors.wordsIn(c) : c;
}

Color _toneBase(FileTone t) => switch (t) {
  FileTone.pdf => HaloColors.rose,
  FileTone.code => HaloColors.sky,
  FileTone.audio => HaloColors.violet,
  FileTone.sheet => HaloColors.green,
  FileTone.video || FileTone.picture => HaloColors.fileBlue,
  FileTone.doc => HaloColors.warm,
  FileTone.zip => HaloColors.yellow,
  FileTone.other => HaloColors.line2,
};

/// what is written on a kind's tile: the kind's own colour, as its outline
Color onFileTone(FileTone t) =>
    t == FileTone.other ? HaloColors.text : fileToneColor(t);

/// up to four letters of the extension, or none for a kind drawn as a glyph
String fileBadgeLabel(FileFacts facts) {
  final e = facts.ext.toUpperCase();
  if (e.isEmpty) return '';
  return e.length <= 4 ? e : e.substring(0, 4);
}

IconData? _glyphOf(FileTone t, FileFacts facts) {
  if (facts.installer) return Icons.install_mobile_outlined;
  return switch (t) {
    FileTone.audio => Icons.music_note_rounded,
    FileTone.video => Icons.play_arrow_rounded,
    FileTone.picture => Icons.image_outlined,
    _ => facts.ext.isEmpty ? Icons.insert_drive_file_outlined : null,
  };
}

class FileBadge extends StatelessWidget {
  final FileFacts facts;
  final double size;
  // on our own amber bubble the tile keeps its colour, ringed so it stands
  // off the accent
  final bool onAccent;
  const FileBadge({
    super.key,
    required this.facts,
    this.size = 38,
    this.onAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = fileToneOf(facts);
    // a thin outline and the label in the kind's colour, nothing filled. on
    // our own amber bubble both take the bubble's ink, a hairline
    final ink = onAccent ? HaloColors.onAmber : onFileTone(tone);
    final glyph = _glyphOf(tone, facts);
    final label = fileBadgeLabel(facts);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.27),
          border: Border.all(
            color: onAccent ? ink.withValues(alpha: 0.45) : ink,
            width: onAccent ? 1 : 1.4,
          ),
        ),
        child: glyph != null
            ? Icon(glyph, size: size * 0.5, color: ink)
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    maxLines: 1,
                    // the tile is a fixed size: its label never grows with
                    // the text size, the name beside it does
                    textScaler: TextScaler.noScaling,
                    textDirection: TextDirection.ltr,
                    style: HaloType.mono(
                      size: size * 0.27,
                      weight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
