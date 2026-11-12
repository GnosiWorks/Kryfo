// SPDX-License-Identifier: GPL-3.0-or-later
// the second samsung round: chat info reads after its slide and sorts a
// long history off the ui isolate, our own file's glance is ready before
// its bubble, a picture picked as a file is a photo in the tray, and a word
// document opens in kryfo's own reader, read with caps
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/doc_read.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/file_peek.dart' show firstLinesNow;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/doc_viewer.dart';
import 'package:kryfo/widgets/file_actions.dart';
import 'package:kryfo/widgets/file_bubble.dart' show warmSentPreview;
import 'package:kryfo/widgets/send_sheet.dart';
import 'package:kryfo/widgets/shared_media.dart';

import 'source_body.dart' show sourceOf;

const _doc = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Camping permit</w:t></w:r></w:p>
<w:p><w:r><w:t xml:space="preserve">Valid for </w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>6 people</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t> &amp; dogs</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="3"/></w:numPr></w:pPr><w:r><w:t>Fires at the marked spots</w:t></w:r></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Day</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Place</w:t></w:r></w:p></w:tc></w:tr>
<w:tr><w:tc><w:p><w:r><w:t>Sat</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>North gate</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
<w:p><w:r><w:t>&#x202E;gpj.exe</w:t></w:r></w:p>
</w:body></w:document>''';

List<int> _docx(String xml, {bool store = false}) {
  final a = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', '<Types/>'))
    ..addFile(
      store
          ? (ArchiveFile.noCompress(
              'word/document.xml',
              utf8.encode(xml).length,
              utf8.encode(xml),
            ))
          : ArchiveFile.string('word/document.xml', xml),
    );
  return ZipEncoder().encode(a);
}

void main() {
  group('a word document', () {
    for (final store in [false, true]) {
      test('read: headings, runs, lists, tables, no direction controls '
          '(${store ? 'stored' : 'deflated'})', () {
        final d = readDocx(_docx(_doc, store: store))!;
        final paras = d.blocks.whereType<DocPara>().toList();
        expect(paras.first.heading, 1);
        expect(paras.first.text, 'Camping permit');
        final runs = paras[1].runs;
        expect(runs.map((r) => (r.text, r.bold, r.italic)), [
          ('Valid for ', false, false),
          ('6 people', true, false),
          (' & dogs', false, true),
        ]);
        expect(paras[2].list, 1);
        final table = d.blocks.whereType<DocTable>().single;
        expect(table.rows, [
          ['Day', 'Place'],
          ['Sat', 'North gate'],
        ]);
        expect(paras.last.text, 'gpj.exe');
        expect(d.cut, isFalse);
      });
    }

    test('what is no document, or unpacks too big, is not read', () {
      expect(readDocx(utf8.encode('not a zip at all')), isNull);
      expect(readDocx(_docx('').sublist(0, 30)), isNull);
      // a small file that unpacks past the cap is given up on as it grows
      final huge = '<w:p>${'a' * (kDocXmlMost + 1024)}</w:p>';
      expect(readDocx(_docx(huge)), isNull);
    });

    test('a tag that never closes reads in one pass', () {
      final w = Stopwatch()..start();
      docxBlocks('<a' * 200000);
      docxBlocks('<${'a' * 400000}');
      expect(w.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a word document opens in kryfo, never only outside', () {
      expect(
        fileViewOf(const FileFacts(FileKind.document, 'docx')),
        FileView.doc,
      );
    });

    testWidgets('the reader shows its words, its bar keeps Open with', (
      t,
    ) async {
      final dir = Directory.systemTemp.createTempSync('docx');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/permit.docx')..writeAsBytesSync(_docx(_doc));
      final was = readDocFile;
      readDocFile = (p) async => readDocx(File(p).readAsBytesSync());
      addTearDown(() => readDocFile = was);
      await t.pumpWidget(
        MaterialApp(
          home: DocViewer(
            path: f.path,
            name: 'permit.docx',
            facts: const FileFacts(FileKind.document, 'docx'),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Camping permit'), findsOneWidget);
      expect(find.text('North gate'), findsOneWidget);
      expect(find.text(l10n.fileOpenWith), findsOneWidget);
    });
  });

  test('a picture picked as a file is a photo in the tray', () {
    SendPick p(String n) =>
        SendPick(path: '/x/$n', name: n, size: 1, from: SendTab.files);
    expect(asPhotoPick(p('scan.JPG')).media, isTrue);
    expect(asPhotoPick(p('scan.heic')).media, isTrue);
    expect(asPhotoPick(p('plan.pdf')).media, isFalse);
    expect(asPhotoPick(p('noext')).media, isFalse);
  });

  testWidgets('our own file\'s glance is ready before its bubble draws', (
    t,
  ) async {
    final dir = Directory.systemTemp.createTempSync('warm');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/notes.txt')..writeAsStringSync('one\ntwo\n');
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => warmSentPreview(c, f.path, 'notes.txt'),
            child: const Text('go'),
          ),
        ),
      ),
    );
    expect(firstLinesNow(f.path), isNull);
    await t.tap(find.text('go'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    expect(firstLinesNow(f.path), ['one', 'two']);
  });

  group('chat info', () {
    test('reads after its slide in, and sorts a long history apart', () async {
      for (final file in [
        'lib/screens/contact_screen.dart',
        'lib/screens/group_info_screen.dart',
      ]) {
        expect(
          sourceOf(file),
          contains('await routeSettled(context);'),
          reason: file,
        );
      }
      final rows = [
        for (var i = 0; i < kSortInlineMost + 50; i++)
          {
            'id': i,
            'file_path': '/f/$i.pdf',
            'file_name': 'f$i.pdf',
            'direction': i.isEven ? 'out' : 'in',
            'msg_uid': 'u$i',
            'sent_at': i,
            'plaintext': i % 7 == 0 ? 'see https://kryfo.app/$i' : '',
          },
      ];
      final apart = await sortSharedSoon(rows);
      final here = sortShared(rows);
      expect(apart.files.map((x) => x.uid), here.files.map((x) => x.uid));
      expect(apart.links.map((x) => x.url), here.links.map((x) => x.url));
    });
  });
}
