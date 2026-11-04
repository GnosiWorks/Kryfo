// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's media folders sealed at rest: real photos, videos, voice notes
// and a large file sealed in place, a stop at every step of the sealing and
// of the renaming losing nothing, and code outside dart reading sealed files
// through memory. with the host engine the crypto is the app's own
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/sealed_file.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/media_names.dart';
import 'package:kryfo/phone_seal.dart';
import 'package:kryfo/voice_opus.dart';
import 'package:path/path.dart' as p;

import 'desktop/sealed_file_test.dart' show ToyCrypto;
import 'host_engine.dart';
import 'sqlite_ffi.dart';

const _corpus = '/home/mario/kryfo-notes/cleaner-corpus/samsung';
const _voices = '/home/mario/kryfo-notes/voice-samples';
const _trailers = '/home/mario/kryfo-notes/trailers';

// a dart-only stand-in that fails on its [n]th seal: a stop part way
class _FailingCrypto implements ChunkCrypto {
  _FailingCrypto(this.inner, this.n);
  final ChunkCrypto inner;
  int n;
  @override
  Uint8List seal(Uint8List key, Uint8List plain) {
    if (--n == 0) throw const FileSystemException('stopped');
    return inner.seal(key, plain);
  }

  @override
  Uint8List? open(Uint8List key, Uint8List sealed) => inner.open(key, sealed);
}

Uint8List _raw(String path) =>
    rawFileAccess(() => File(path).readAsBytesSync());

String _sum(List<int> b) => sha256.convert(b).toString();

// whether any 64 bytes of [plain] (from a few places) are in [hay]
bool _leaks(Uint8List hay, Uint8List plain) {
  if (plain.length < 4096) return holds(hay, String.fromCharCodes(plain));
  for (final at in [1000, plain.length ~/ 2, plain.length - 200]) {
    final needle = String.fromCharCodes(plain.sublist(at, at + 64));
    if (holds(hay, needle)) return true;
  }
  return false;
}

void main() {
  final engine = loadHostEngine();
  final ChunkCrypto crypto = engine ? const EngineChunkCrypto() : ToyCrypto();
  late Directory root;
  late String docs, support, cache;
  late SealedAreas areas;
  const everydayKey =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
  const vaultKey =
      "x'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100'";

  void install([ChunkCrypto? c]) {
    areas = SealedAreas(
      docs: docs,
      support: support,
      runtime: cache,
      phone: true,
    );
    installPhoneSeal(areas, c ?? crypto);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('phone_seal');
    docs = p.join(root.path, 'app_flutter');
    support = p.join(root.path, 'files');
    cache = p.join(root.path, 'cache');
    for (final d in [docs, support, cache]) {
      Directory(d).createSync(recursive: true);
    }
    install();
  });

  tearDown(() {
    uninstallPhoneSealForTest();
    root.deleteSync(recursive: true);
  });

  void openEveryday() =>
      containerOpened!(HaloContainer.everyday.id, '', everydayKey);
  void openVault() => containerOpened!(HaloContainer.vault.id, '_k3', vaultKey);

  test('every install has the same numbered folders, and a decoy or hidden '
      'chats show in no name', () {
    final names = Directory(
      docs,
    ).listSync().map((e) => p.basename(e.path)).toSet();
    expect(names, {
      'media',
      'wallpapers',
      'media_k2',
      'wallpapers_k2',
      'media_k3',
      'wallpapers_k3',
      'media_k4',
      'wallpapers_k4',
    });
    expect(HaloContainer.vault.folderSuffix, '_k3');
    expect(HaloContainer.decoyVault.oldFolderSuffix, '_dv');
    expect(HaloContainer.everyday.folderNames, ['media', 'wallpapers']);
  });

  test('only the media folders are sealed: support, the cache, the engine\'s '
      'own parts and sqlite stay as they were', () {
    openEveryday();
    for (final (path, sealed) in [
      (p.join(docs, 'media', 'in_x.jpg'), true),
      (p.join(docs, 'media_k3', 'f_abc.pdf'), true),
      (p.join(docs, 'wallpapers_k2', 'wp_1.jpg'), true),
      (p.join(docs, 'media', 'fetch', 'abc'), false),
      (p.join(docs, 'media_k3', 'held', 'abc.part'), false),
      (p.join(docs, 'media_v', 'old.jpg'), false),
      (p.join(docs, 'halo.db'), false),
      (p.join(docs, 'onion_d.key'), false),
      (p.join(support, 'backup_stage', 'x'), false),
      (p.join(cache, 'share', 'x'), false),
    ]) {
      expect(areas.sealedPlace(path), sealed, reason: path);
    }
    // a backup's stage and the cache may take a plain copy, nothing else
    expect(areas.plainOutAllowed(p.join(support, 'backup_stage', 'x')), isTrue);
    expect(areas.plainOutAllowed(p.join(cache, 'open', 'x')), isTrue);
    expect(areas.plainOutAllowed(p.join(docs, 'x')), isFalse);
  });

  test('a photo written into a hidden chat is sealed on the disk and opens '
      'only while its key is here', () {
    final photo = File(
      p.join(_corpus, '20261022_135215.jpg'),
    ).readAsBytesSync();
    openVault();
    final at = p.join(docs, 'media_k3', 'in_0123.jpg');
    File(at).writeAsBytesSync(photo);
    final disk = _raw(at);
    expect(isSealedHead(disk), isTrue);
    expect(_leaks(disk, photo), isFalse);
    expect(disk.length, storedLength(photo.length));
    expect(File(at).lengthSync(), photo.length);
    expect(_sum(File(at).readAsBytesSync()), _sum(photo));
    // the hidden chats shut: their files do not open
    containerClosed!(HaloContainer.vault.id);
    expect(() => File(at).readAsBytesSync(), throwsA(isA<SealedLocked>()));
    // the everyday key never opens them
    openEveryday();
    expect(() => File(at).readAsBytesSync(), throwsA(isA<SealedLocked>()));
  });

  group('the files of before, sealed in place', () {
    Map<String, Uint8List> realFiles() => {
      'in_${'a' * 32}.jpg': File(
        p.join(_corpus, '20261022_135238.jpg'),
      ).readAsBytesSync(),
      'f_photo1.jpg': File(
        p.join(_corpus, 'Screenshot_20261022-135445_Camera.jpg'),
      ).readAsBytesSync(),
      'in_${'b' * 32}.mp4': File(
        p.join(_corpus, '20261022_135332.mp4'),
      ).readAsBytesSync(),
      'vn_note1.wav': File(
        p.join(_voices, '1-woman-original.wav'),
      ).readAsBytesSync(),
      // a large file: three real videos one after the other, over 50 MB
      'f_big1.bin': Uint8List.fromList([
        ...File(p.join(_trailers, 'kryfo_04_missed.mp4')).readAsBytesSync(),
        ...File(p.join(_trailers, 'kryfo_03_abstract.mp4')).readAsBytesSync(),
        ...File(p.join(_trailers, 'kryfo_01_pitch.mp4')).readAsBytesSync(),
      ]),
    };

    test('real photos, a video, a voice note and a large file: sealed, the '
        'same bytes back, nothing plain left', () async {
      final files = realFiles();
      final dir = p.join(docs, 'media_k3');
      rawFileAccess(() {
        for (final e in files.entries) {
          File(p.join(dir, e.key)).writeAsBytesSync(e.value);
        }
      });
      // plain ones read as they are until the sweep
      openVault();
      expect(
        _sum(File(p.join(dir, 'f_photo1.jpg')).readAsBytesSync()),
        _sum(files['f_photo1.jpg']!),
      );
      final s = await sweepContainer(HaloContainer.vault);
      expect(s!.sealed, files.length);
      for (final e in files.entries) {
        final at = p.join(dir, e.key);
        final disk = _raw(at);
        expect(isSealedHead(disk), isTrue, reason: e.key);
        expect(_leaks(disk, e.value), isFalse, reason: e.key);
        expect(_sum(File(at).readAsBytesSync()), _sum(e.value), reason: e.key);
      }
      expect(
        rawFileAccess(() => Directory(dir).listSync().length),
        files.length,
      );
      // a second sweep finds nothing to do
      expect((await sweepContainer(HaloContainer.vault))!.sealed, 0);
    });

    test('a stop at every step of a file\'s sealing loses nothing', () async {
      final photo = File(
        p.join(_corpus, '20261022_135215.jpg'),
      ).readAsBytesSync();
      final dir = p.join(docs, 'media');
      final at = p.join(dir, 'in_${'c' * 32}.jpg');
      openEveryday();
      final key = areas.containerKeys['']!;

      Uint8List sealedCopy() {
        final tmp = p.join(root.path, 'copy');
        File(tmp).writeAsBytesSync(const []);
        final r = SealedRandomAccessFile.over(
          rawFileAccess(() => File(tmp).openSync(mode: FileMode.append)),
          tmp,
          key,
          crypto,
          writable: true,
          truncate: true,
        );
        r.writeFromSync(photo);
        r.closeSync();
        return _raw(tmp);
      }

      final whole = sealedCopy();
      final steps = <String, void Function()>{
        // the copy cut short while it was written
        'copy cut': () {
          File('$at.sealing').writeAsBytesSync(whole.sublist(0, 70000));
          File(at).writeAsBytesSync(photo);
        },
        // the copy whole, the plain one not touched yet
        'copy whole': () {
          File('$at.sealing').writeAsBytesSync(whole);
          File(at).writeAsBytesSync(photo);
        },
        // the plain one zeroed part way
        'zero cut': () {
          File('$at.sealing').writeAsBytesSync(whole);
          File(
            at,
          ).writeAsBytesSync([...Uint8List(200000), ...photo.sublist(200000)]);
        },
        // the copy took the name
        'renamed': () => File(at).writeAsBytesSync(whole),
      };
      for (final e in steps.entries) {
        rawFileAccess(() {
          for (final f in Directory(dir).listSync()) {
            f.deleteSync();
          }
          e.value();
        });
        await sweepContainer(HaloContainer.everyday);
        expect(_sum(File(at).readAsBytesSync()), _sum(photo), reason: e.key);
        expect(isSealedHead(_raw(at)), isTrue, reason: e.key);
        expect(
          rawFileAccess(() => File('$at.sealing').existsSync()),
          isFalse,
          reason: e.key,
        );
      }
    });

    test('a seal that fails part way leaves the plain file whole and no '
        'copy, and the next one finishes', () async {
      final video = File(
        p.join(_corpus, 'kryfo_corpus_rec.mp4'),
      ).readAsBytesSync();
      uninstallPhoneSealForTest();
      install(_FailingCrypto(crypto, 5));
      openEveryday();
      final at = p.join(docs, 'media', 'in_${'d' * 32}.mp4');
      rawFileAccess(() => File(at).writeAsBytesSync(video));
      await sweepContainer(HaloContainer.everyday);
      expect(_sum(_raw(at)), _sum(video));
      expect(rawFileAccess(() => File('$at.sealing').existsSync()), isFalse);
      uninstallPhoneSealForTest();
      install();
      openEveryday();
      expect((await sweepContainer(HaloContainer.everyday))!.sealed, 1);
      expect(_sum(File(at).readAsBytesSync()), _sum(video));
    });
  });

  group('names that say nothing', () {
    late SqliteMem db;

    setUp(() async {
      final d = SqliteMem.open();
      if (d == null) return;
      db = d;
      await appSchemaOn(db);
    });

    Future<void> row(String? media, String? file) => db.insert('messages', {
      'peer_id': 'bob',
      'direction': 'in',
      'plaintext': '',
      'sent_at': 0,
      'media_path': media,
      'file_path': file,
    });

    Future<List<String>> paths() async => [
      for (final r in await db.rawQuery(
        'SELECT media_path, file_path FROM messages ORDER BY id',
      ))
        (r['media_path'] ?? r['file_path']) as String,
    ];

    test('a hidden chat\'s folder goes by its number and each file under a '
        'name of its type, at every stop', () async {
      if (SqliteMem.open() == null) return markTestSkipped('no sqlite');
      final v = HaloContainer.vault;
      final old = p.join(docs, 'media_v');
      final named = 'in_${'e' * 32}_passport scan.PDF';
      final sent = 'f_abc123_my_letter.docx';
      final photo = 'in_${'f' * 32}.jpg';
      final bytes = {
        named: Uint8List.fromList(List.filled(3000, 1)),
        sent: Uint8List.fromList(List.filled(4000, 2)),
        photo: Uint8List.fromList(List.filled(5000, 3)),
      };
      rawFileAccess(() {
        Directory(old).createSync();
        for (final e in bytes.entries) {
          File(p.join(old, e.key)).writeAsBytesSync(e.value);
        }
      });
      await row(null, p.join(old, named));
      await row(null, p.join(old, sent));
      await row(p.join(old, photo), null);
      await db.insert('contacts', {
        'halo_id': 'bob',
        'onion': 'o',
        'xpub': 'x',
        'first_seen': 0,
        'last_seen': 0,
        'atmosphere': 'image:${p.join(docs, 'wallpapers_v', 'wp_1.jpg')}',
      });
      // stopped after the folder moved, before a row changed: the next open
      // finds the rows by the folder's old name and points them at the new
      rawFileAccess(() {
        Directory(p.join(docs, 'media_k3')).deleteSync();
        Directory(old).renameSync(p.join(docs, 'media_k3'));
      });
      // and stopped after one file took its new name, before its row did
      final dir = p.join(docs, 'media_k3');
      rawFileAccess(
        () => File(
          p.join(dir, named),
        ).renameSync(p.join(dir, 'in_${'e' * 32}.pdf')),
      );
      await mediaNamesAtOpen(db, v, docs);
      expect(await paths(), [
        p.join(dir, 'in_${'e' * 32}.pdf'),
        p.join(dir, 'f_abc123.docx'),
        p.join(dir, photo),
      ]);
      final atmo = await db.rawQuery('SELECT atmosphere FROM contacts');
      expect(
        atmo.single['atmosphere'],
        'image:${p.join(docs, 'wallpapers_k3', 'wp_1.jpg')}',
      );
      for (final path in await paths()) {
        expect(rawFileAccess(() => File(path).existsSync()), isTrue);
      }
      expect(rawFileAccess(() => Directory(old).existsSync()), isFalse);
      // nothing of a name anyone gave is on the disk
      final leaves = rawFileAccess(
        () => Directory(dir).listSync().map((e) => p.basename(e.path)),
      );
      expect(
        leaves.any((l) => l.contains('passport') || l.contains('letter')),
        isFalse,
      );
      // once more: nothing moves
      await mediaNamesAtOpen(db, v, docs);
      expect(await paths(), hasLength(3));
      // the bytes came along, and the sweep then seals them
      openVault();
      await sweepContainer(v);
      final ps = await paths();
      for (final (i, k) in [named, sent, photo].indexed) {
        expect(isSealedHead(_raw(ps[i])), isTrue);
        expect(File(ps[i]).readAsBytesSync(), bytes[k]);
      }
    });

    test('an old folder and a new one with files in both are merged, the '
        'rows kept', () async {
      if (SqliteMem.open() == null) return markTestSkipped('no sqlite');
      final old = p.join(docs, 'media_d');
      rawFileAccess(() {
        Directory(old).createSync();
        File(p.join(old, 'a.jpg')).writeAsBytesSync([1]);
        Directory(p.join(old, 'fetch')).createSync();
        File(p.join(old, 'fetch', 'x.part')).writeAsBytesSync([2]);
        File(p.join(docs, 'media_k2', 'b.jpg')).writeAsBytesSync([3]);
      });
      await row(p.join(old, 'a.jpg'), null);
      await mediaNamesAtOpen(db, HaloContainer.decoy, docs);
      final now = p.join(docs, 'media_k2');
      expect(await paths(), [p.join(now, 'a.jpg')]);
      expect(_raw(p.join(now, 'fetch', 'x.part')), [2]);
      expect(_raw(p.join(now, 'b.jpg')), [3]);
      expect(rawFileAccess(() => Directory(old).existsSync()), isFalse);
    });

    test('names already neutral are left as they are', () {
      expect(neutralLeaf('in_${'a' * 32}.jpg'), isNull);
      expect(neutralLeaf('f_abc123.pdf'), isNull);
      expect(neutralLeaf('vn_abc123.wav'), isNull);
      expect(neutralLeaf('abc123.jpg'), isNull);
      expect(neutralLeaf('in_${'a' * 32}_x y.Tar.GZ'), 'in_${'a' * 32}.gz');
      expect(neutralLeaf('f_abc_no type'), 'f_abc');
    });
  });

  group('code outside dart', () {
    test(
      'a sealed note reaches a reader as memory, gone when it is let go',
      () {
        final wav = File(
          p.join(_voices, '2-man-original.wav'),
        ).readAsBytesSync();
        openEveryday();
        final at = p.join(docs, 'media', 'vn_x.wav');
        File(at).writeAsBytesSync(wav);
        final v = plainViewOf(at);
        expect(v.path, startsWith('/proc/self/fd/'));
        expect(_sum(_raw(v.path)), _sum(wav));
        v.close();
        expect(() => _raw(v.path), throwsA(isA<FileSystemException>()));
        // a plain file, or one outside the folders, is handed as it is
        final out = p.join(cache, 'x.wav');
        File(out).writeAsBytesSync(wav);
        expect(plainViewOf(out).path, out);
      },
    );

    test('where memory will not reopen, a copy in the cache goes at once', () {
      memfdWorksForTest = false;
      openEveryday();
      final at = p.join(docs, 'media', 'vn_y.wav');
      File(at).writeAsBytesSync(List.filled(70000, 9));
      final v = plainViewOf(at);
      expect(p.isWithin(p.join(cache, kNativeCopies), v.path), isTrue);
      expect(_raw(v.path), List.filled(70000, 9));
      v.close();
      expect(File(v.path).existsSync(), isFalse);
    });

    test('the engine encodes a sealed note into a sealed one and reads it '
        'back, through memory', () async {
      if (!engine) return markTestSkipped('no host engine');
      final wav = File(
        p.join(_voices, '3-woman-original.wav'),
      ).readAsBytesSync();
      openEveryday();
      final at = p.join(docs, 'media', 'vn_z.wav');
      final ogg = p.join(docs, 'media', 'vn_z.ogg');
      File(at).writeAsBytesSync(wav);
      final ms = await encodeVoiceOgg(at, ogg);
      expect(ms, greaterThan(1000));
      final disk = _raw(ogg);
      expect(isSealedHead(disk), isTrue);
      expect(String.fromCharCodes(File(ogg).openSync().readSync(4)), 'OggS');
      final back = p.join(cache, 'back.wav');
      expect(await decodeVoiceWav(ogg, back), isTrue);
      expect(String.fromCharCodes(_raw(back).sublist(0, 4)), 'RIFF');
      // nothing plain was left in the cache on the way
      expect(Directory(p.join(cache, kNativeCopies)).existsSync(), isFalse);
    });

    test('a file sealed by another program opens here, and its key for the '
        'phone\'s own readers is the one they read it with', () {
      if (!engine) return markTestSkipped('no host engine');
      // android/app/src/test/resources/sealed_two_chunks.bin: see
      // SealedReaderTest.kt
      final vector = File(
        'android/app/src/test/resources/sealed_two_chunks.bin',
      ).readAsBytesSync();
      final area = Uint8List.fromList(List.generate(32, (i) => i));
      areas.containerKeys[''] = area;
      final at = p.join(docs, 'media', 'vec.bin');
      rawFileAccess(() => File(at).writeAsBytesSync(vector));
      final plain = File(at).readAsBytesSync();
      expect(plain.length, 65546);
      expect(plain, [for (var i = 0; i < 65546; i++) (i * 31 + 7) & 255]);
      expect(fileKeyOf(at), fileKey(area, vector.sublist(0, sealedHead)));
      expect(withFileKey(at, {'path': at})['key'], fileKeyOf(at));
      // a plain one has none: it is read as it is
      final plainAt = p.join(docs, 'media', 'plain.jpg');
      rawFileAccess(() => File(plainAt).writeAsBytesSync([1, 2, 3]));
      expect(withFileKey(plainAt, {'path': plainAt}).containsKey('key'), false);
    });
  });

  test('a shred overwrites the sealed bytes as they lie', () async {
    openEveryday();
    final at = p.join(docs, 'media', 'in_q.jpg');
    File(at).writeAsBytesSync(List.filled(100000, 5));
    final stored = _raw(at).length;
    var seen = 0;
    await rawFiles(() async {
      final r = await File(at).open(mode: FileMode.append);
      seen = await r.length();
      await r.close();
    });
    expect(seen, stored);
  });
}
