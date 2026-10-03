// SPDX-License-Identifier: GPL-3.0-or-later
// debug builds only: times search on a scratch encrypted database (never
// the real one) filled with 50,000 messages, through the app's own index
// code and query. started by `run-as app.kryfo touch app_flutter/search_bench`;
// the marker and the scratch database are gone afterwards.
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'dlog.dart';
import 'main.dart' show searchTables, indexSearchRowIn, runSearchQuery;
import 'search.dart';

Future<void> maybeRunSearchBench() async {
  final dir = await getApplicationDocumentsDirectory();
  final marker = File(p.join(dir.path, 'search_bench'));
  if (!await marker.exists()) return;
  await marker.delete();
  final path = p.join(dir.path, 'search_bench.db');
  try {
    await _bench(path);
  } catch (e) {
    dlog('SEARCHBENCH failed: $e');
  } finally {
    await deleteDatabase(path);
  }
}

const _words = {
  'en':
      'the meeting tomorrow pizza tonight train station coffee late sorry '
      'photo birthday party weekend doctor keys window rain cinema office '
      'garden bread market friday lunch table music bike river',
  'de':
      'morgen treffen bahnhof kaffee später danke wochenende arzt schlüssel '
      'fenster regen kino büro garten brot markt freitag mittagessen straße',
  'ru':
      'привет завтра встреча вокзал кофе позже спасибо выходные врач ключи '
      'окно дождь кино офис сад хлеб рынок пятница обед идём',
  'fa':
      'سلام فردا جلسه ایستگاه قهوه بعدا ممنون آخرهفته دکتر کلید پنجره باران '
      'سینما دفتر باغ نان بازار جمعه ناهار کتاب می‌خواهم',
  'ar':
      'مرحبا غدا اجتماع محطة قهوة لاحقا شكرا عطلة طبيب مفاتيح نافذة مطر '
      'سينما مكتب حديقة خبز سوق الجمعة غداء كتاب',
  'vi':
      'xin chào ngày mai cuộc họp nhà ga cà phê muộn cảm ơn cuối tuần bác sĩ '
      'chìa khóa cửa sổ mưa rạp phim văn phòng tiếng việt',
};

const _zh = '我们今天明天晚上去吃饭开会火车站咖啡谢谢周末医生钥匙窗户下雨电影办公室花园面包市场星期五午饭音乐';

String _line(Random r) {
  final lang = r.nextInt(8);
  if (lang >= 6) {
    final n = 6 + r.nextInt(14);
    final b = StringBuffer();
    for (var i = 0; i < n; i++) {
      b.write(_zh[r.nextInt(_zh.length)]);
    }
    return b.toString();
  }
  final list = _words.values.elementAt(lang).split(' ');
  final n = 3 + r.nextInt(14);
  return [for (var i = 0; i < n; i++) list[r.nextInt(list.length)]].join(' ');
}

Future<void> _bench(String path) async {
  await deleteDatabase(path);
  final db = await openDatabase(
    path,
    password: 'bench-${DateTime.now().microsecondsSinceEpoch}',
    version: 1,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          peer_id TEXT NOT NULL,
          direction TEXT NOT NULL,
          plaintext TEXT NOT NULL,
          sent_at INTEGER NOT NULL,
          msg_uid TEXT,
          group_id TEXT,
          media_path TEXT,
          file_path TEXT,
          file_name TEXT,
          preview TEXT,
          poll TEXT,
          burn_at INTEGER,
          burn_secs INTEGER,
          burn_unseen INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, '
        'blocked INTEGER NOT NULL DEFAULT 0, '
        'accepted INTEGER NOT NULL DEFAULT 1)',
      );
      await searchTables(db, fresh: true);
    },
  );
  final r = Random(7);
  const total = 50000;
  final fill = Stopwatch()..start();
  for (var c = 0; c < 40; c++) {
    await db.insert('contacts', {'halo_id': 'peer-$c'});
  }
  var t0 = DateTime(2024).millisecondsSinceEpoch;
  for (var start = 0; start < total; start += 1000) {
    final rows = <Map<String, Object?>>[];
    for (var i = start; i < start + 1000; i++) {
      t0 += 30000 + r.nextInt(600000);
      final group = r.nextInt(3) == 0 ? 'group-${r.nextInt(12)}' : null;
      final kind = r.nextInt(40);
      var text = _line(r);
      if (kind == 0) text = '$text https://example.org/${r.nextInt(999)}';
      rows.add({
        'peer_id': group != null && r.nextBool()
            ? 'me'
            : 'peer-${r.nextInt(40)}',
        'direction': r.nextBool() ? 'in' : 'out',
        'plaintext': kind == 1 ? '' : text,
        'sent_at': t0,
        'msg_uid': 'u$i',
        'group_id': group,
        'media_path': kind == 1 ? '/nope/p$i.jpg' : null,
        'file_path': kind == 2 ? '/nope/f$i' : null,
        'file_name': kind == 2 ? 'report-$i.pdf' : null,
      });
    }
    // written the way the app's fill writes: batches, one trip each
    final ins = db.batch();
    for (final row in rows) {
      ins.insert('messages', row);
    }
    final ids = await ins.commit();
    final idx = db.batch();
    for (var k = 0; k < rows.length; k++) {
      indexSearchRowIn(idx, ids[k] as int, rows[k]);
    }
    await idx.commit(noResult: true);
  }
  fill.stop();
  dlog('SEARCHBENCH filled $total rows in ${fill.elapsedMilliseconds} ms');
  final cases = <(String, String?, SearchKind)>[
    ('one word', 'pizza', SearchKind.all),
    ('two words', 'meeting tomorrow', SearchKind.all),
    ('prefix', 'wee', SearchKind.all),
    ('very common', 'the', SearchKind.all),
    ('none', 'xylophone', SearchKind.all),
    ('german', 'straße', SearchKind.all),
    ('russian', 'идем', SearchKind.all),
    ('chinese', '吃饭', SearchKind.all),
    ('persian', 'میخواهم', SearchKind.all),
    ('arabic', 'مرحبا', SearchKind.all),
    ('vietnamese', 'tieng viet', SearchKind.all),
    ('all photos', null, SearchKind.photos),
    ('all files', null, SearchKind.files),
    ('all links', null, SearchKind.links),
    ('word in links', 'coffee', SearchKind.links),
  ];
  var worst = 0;
  for (final (name, q, kind) in cases) {
    final match = q == null ? null : ftsMatch(q);
    final times = <int>[];
    var n = 0;
    for (var run = 0; run < 5; run++) {
      final sw = Stopwatch()..start();
      final rows = await runSearchQuery(db, match, kind);
      sw.stop();
      times.add(sw.elapsedMilliseconds);
      n = rows.length;
    }
    times.sort();
    if (times.last > worst) worst = times.last;
    dlog(
      'SEARCHBENCH $name: median ${times[2]} ms, worst ${times.last} ms, '
      '$n rows',
    );
  }
  dlog('SEARCHBENCH worst of all: $worst ms');
  await db.close();
}
