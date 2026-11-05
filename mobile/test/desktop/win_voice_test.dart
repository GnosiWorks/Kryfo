// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes on windows, on any host with fakes for the runner's wasapi:
// the take is written through the seal as the mic hands it over, so the
// disk never holds a plain sample; every buffer is zeroed once used; the
// disguise reads the sealed take while it records; a refused or missing mic
// says what to do; and a note plays from memory, sniffed and parsed here
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:kryfo/desktop/desktop_audio.dart';
import 'package:kryfo/desktop/sealed_format.dart' show isSealedHead;
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/win_audio.dart';
import 'package:kryfo/desktop/win_record.dart';
import 'package:kryfo/l10n/app_localizations_en.dart';
import 'package:kryfo/voice_length.dart' show wavMs;
import 'package:kryfo/voice_mask.dart';
import 'package:path/path.dart' as p;
import 'package:record_platform_interface/record_platform_interface.dart';

import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

const _rate = 16000;

// [secs] of a voice-like glide, 16-bit mono pcm, no head
Uint8List _pcm(double secs) {
  final n = (secs * _rate).round();
  final b = ByteData(n * 2);
  var ph = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    ph += 2 * math.pi * (140 + 40 * math.sin(2 * math.pi * 0.7 * t)) / _rate;
    var v = 0.0;
    for (var h = 1; h <= 6; h++) {
      v += math.sin(h * ph) / h;
    }
    final env = 0.5 + 0.5 * math.sin(2 * math.pi * 3 * t);
    b.setInt16(2 * i, (6000 * env * v).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

// the mic: what it hears, in pieces of [piece] bytes, then silence or a
// device gone. each buffer it is handed must come back zeroed
class _FakeMic implements MicSource {
  _FakeMic(this.heard, {this.piece = 3200, this.goneAfter, this.word});
  final Uint8List heard;
  final int piece;
  final int? goneAfter;
  final AudioWord? word;
  int at = 0;
  bool open_ = false;
  int opens = 0;
  Pointer<Uint8>? last;
  int lastN = 0;
  final dirty = <int>[];

  void _checkLast() {
    final l = last;
    if (l == null || lastN == 0) return;
    if (l.asTypedList(lastN).any((v) => v != 0)) dirty.add(lastN);
  }

  @override
  AudioWord probe() => word ?? AudioWord.ok;
  @override
  AudioWord open(int rate, int channels) {
    if (word != null) return word!;
    open_ = true;
    opens++;
    return AudioWord.ok;
  }

  @override
  int take(Pointer<Uint8> into, int cap) {
    _checkLast();
    last = into;
    lastN = 0;
    final g = goneAfter;
    if (g != null && at >= g) return -1;
    final n = math.min(math.min(piece, cap), heard.length - at);
    if (n <= 0) return 0;
    into.asTypedList(n).setRange(0, n, heard, at);
    at += n;
    lastN = n;
    return n;
  }

  @override
  void close() {
    open_ = false;
  }
}

// the speakers: what they were handed, copied as the runner copies it
class _FakeOut implements PcmOut {
  Uint8List? got;
  int? rate, channels;
  bool playing = false;
  bool gone = false;
  int pending = 0;
  @override
  AudioWord load(Pointer<Uint8> data, int n, int rate, int channels) {
    got = Uint8List.fromList(data.asTypedList(n));
    this.rate = rate;
    this.channels = channels;
    return AudioWord.ok;
  }

  @override
  void play(bool on) => playing = on;
  @override
  void seek(Duration to) {}
  @override
  void volume(double v) {}
  @override
  Duration position() => Duration.zero;
  @override
  int state() {
    final s = pending;
    pending = 0;
    return s;
  }

  @override
  void dispose() => gone = true;
}

Future<void> _until(bool Function() ok, {int ms = 10000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

bool _holds(Uint8List hay, Uint8List needle) {
  // a run of 64 samples from the middle of what was heard
  final at = needle.length ~/ 2 & ~1;
  final run = latin1.decode(needle.sublist(at, at + 128));
  return latin1.decode(hay, allowInvalid: true).contains(run);
}

void main() {
  late Directory root;
  late String docs, support, tmp;
  late SealedIO io;

  setUp(() {
    root = Directory.systemTemp.createTempSync('w7');
    docs = p.join(root.path, 'docs');
    support = p.join(root.path, 'support');
    tmp = p.join(root.path, 'tmp');
    for (final d in [docs, support, tmp]) {
      Directory(d).createSync(recursive: true);
    }
    final areas = SealedAreas(docs: docs, support: support, tmp: tmp)
      ..filesKey = _k(9)
      ..sessionKey = _k(7);
    io = SealedIO(areas, ToyCrypto());
  });
  tearDown(() {
    WinRecord.onRelease = null;
    root.deleteSync(recursive: true);
  });

  Future<T> sealed<T>(Future<T> Function() f) =>
      IOOverrides.runWithIOOverrides(f, io);
  Uint8List raw(String path) => io.rawFile(path).readAsBytesSync();

  const wav16 = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  test(
    'the take is sealed from its first sample, and whole once it stops',
    () async {
      final heard = _pcm(1.5);
      final mic = _FakeMic(heard);
      final rec = WinRecord(mic, every: const Duration(milliseconds: 2));
      final path = p.join(tmp, 'vn_1.wav');
      final released = <Uint8List>[];
      WinRecord.onRelease = (b) => released.add(Uint8List.fromList(b));
      await sealed(() async {
        await rec.start('r', wav16, path: path);
        expect(await rec.isRecording('r'), isTrue);
        // part way: what is on the disk is sealed and holds no sample
        await _until(() => mic.at > heard.length ~/ 3);
        final mid = raw(path);
        expect(isSealedHead(mid), isTrue);
        expect(_holds(mid, heard), isFalse);
        await _until(() => mic.at >= heard.length);
        expect(await rec.stop('r'), path);
      });
      expect(mic.open_, isFalse, reason: 'the mic is let go');
      final disk = raw(path);
      expect(isSealedHead(disk), isTrue);
      expect(_holds(disk, heard), isFalse);
      // through the seal: a wav with its sizes, and every sample
      final back = await sealed(() => File(path).readAsBytes());
      expect(back.length, 44 + heard.length);
      expect(back.sublist(44), heard);
      expect(wavMs(back), 1500);
      expect(
        ByteData.sublistView(back).getUint32(40, Endian.little),
        heard.length,
      );
      // nothing plain anywhere in the folder
      for (final f in Directory(root.path).listSync(recursive: true)) {
        if (f is! File) continue;
        expect(_holds(raw(f.path), heard), isFalse, reason: f.path);
      }
      // the buffer: zeroed after every write and when it was let go
      expect(mic.dirty, isEmpty);
      expect(released, hasLength(1));
      expect(released.single.every((v) => v == 0), isTrue);
    },
  );

  test('a level while it records, and one take at a time', () async {
    final mic = _FakeMic(_pcm(3), piece: 1600);
    final rec = WinRecord(mic, every: const Duration(milliseconds: 5));
    await sealed(() async {
      await rec.start('r', wav16, path: p.join(tmp, 'vn_2.wav'));
      await _until(() => mic.at > 8000);
      final a = await rec.getAmplitude('r');
      expect(a.current, inInclusiveRange(-40.0, 0.0));
      await expectLater(
        rec.start('s', wav16, path: p.join(tmp, 'vn_3.wav')),
        throwsStateError,
      );
      await rec.stop('r');
    });
    expect(mic.opens, 1);
  });

  test('cancel leaves nothing of the take', () async {
    final mic = _FakeMic(_pcm(1));
    final rec = WinRecord(mic, every: const Duration(milliseconds: 2));
    final path = p.join(tmp, 'vn_4.wav');
    await sealed(() async {
      await rec.start('r', wav16, path: path);
      await _until(() => mic.at > 4000);
      await rec.cancel('r');
    });
    expect(io.rawFile(path).existsSync(), isFalse);
  });

  test('a mic unplugged half way: the take keeps what came', () async {
    final heard = _pcm(1);
    final mic = _FakeMic(heard, goneAfter: 9600);
    final rec = WinRecord(mic, every: const Duration(milliseconds: 2));
    final path = p.join(tmp, 'vn_5.wav');
    await sealed(() async {
      await rec.start('r', wav16, path: path);
      await _until(() => mic.at >= 9600);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await rec.stop('r');
    });
    final back = await sealed(() => File(path).readAsBytes());
    expect(back.sublist(44), heard.sublist(0, 9600));
    expect(wavMs(back), 300);
  });

  group('a mic that does not open says what to do', () {
    final en = AppLocalizationsEn();
    late RecordPlatform before;
    setUp(() => before = RecordPlatform.instance);
    tearDown(() => RecordPlatform.instance = before);

    for (final (word, line) in [
      (AudioWord.blocked, en.desktopMicBlocked),
      (AudioWord.none, en.desktopMicNone),
      (AudioWord.failed, en.chatTheMicWouldNot),
    ]) {
      test(word.name, () async {
        final rec = WinRecord(_FakeMic(Uint8List(0), word: word));
        RecordPlatform.instance = rec;
        expect(await rec.hasPermission('r'), isFalse);
        expect(micRefusedLine(en), line);
        await expectLater(
          rec.start('r', wav16, path: p.join(tmp, 'vn_6.wav')),
          throwsA(isA<MicRefused>()),
        );
      });
    }

    test(
      'no audio calls in the runner: it fails, never a plain plugin',
      () async {
        final rec = WinRecord(null);
        RecordPlatform.instance = rec;
        expect(await rec.hasPermission('r'), isFalse);
        expect(micRefusedLine(en), en.chatTheMicWouldNot);
      },
    );

    test('the phone keeps its own line', () {
      expect(micRefusedLine(en), en.chatMicPermissionNeeded);
    });
  });

  test(
    'the disguise made while it records reads the sealed take, and writes sealed',
    () async {
      final heard = _pcm(4);
      final mic = _FakeMic(heard, piece: 3200);
      final rec = WinRecord(mic, every: const Duration(milliseconds: 20));
      final path = p.join(tmp, 'vn_7.wav');
      await sealed(() async {
        await rec.start('r', wav16, path: path);
        final live = (await LiveMask.start(
          path,
          seed: 21,
          every: const Duration(milliseconds: 5),
        ))!;
        var made = 0;
        live.progress.listen((m) => made = m);
        await _until(() => mic.at >= heard.length);
        await _until(() => made > 0);
        await rec.stop('r');
        final got = await live.finish();
        expect(got, maskPathOf(path));
        final take = await File(path).readAsBytes();
        final masked = await File(got!).readAsBytes();
        // the same note as the disguise of the whole take
        expect(masked, maskWav(take, seed: 21));
        expect(masked, isNot(take));
      });
      final disk = raw(maskPathOf(path));
      expect(isSealedHead(disk), isTrue);
      for (final f in Directory(tmp).listSync()) {
        expect(_holds(raw(f.path), heard), isFalse, reason: f.path);
      }
    },
  );

  test(
    'the disguise of the whole take reads and writes through the seal',
    () async {
      final heard = _pcm(1);
      final mic = _FakeMic(heard);
      final rec = WinRecord(mic, every: const Duration(milliseconds: 2));
      final path = p.join(tmp, 'vn_8.wav');
      await sealed(() async {
        await rec.start('r', wav16, path: path);
        await _until(() => mic.at >= heard.length);
        await rec.stop('r');
        final to = maskPathOf(path);
        expect(await maskWavFile(path, to, seed: 4), isTrue);
        expect(
          await File(to).readAsBytes(),
          maskWav(await File(path).readAsBytes(), seed: 4),
        );
      });
      expect(isSealedHead(raw(maskPathOf(path))), isTrue);
    },
  );

  group('playing', () {
    test('a sealed wav plays from memory', () async {
      final heard = _pcm(0.5);
      final path = p.join(tmp, 'vn_9.wav');
      await sealed(
        () => File(
          path,
        ).writeAsBytes([...wavHead(16000, 1, heard.length), ...heard]),
      );
      final out = _FakeOut();
      final pipe = WasapiPipe(out, decode: (_) async => fail('not an ogg'));
      final d = await sealed(() => pipe.load(path));
      expect(d, const Duration(milliseconds: 500));
      expect(out.got, heard);
      expect((out.rate, out.channels), (16000, 1));
      pipe.play();
      expect(out.playing, isTrue);
      out.pending = 1;
      expect(pipe.failed(), isNull);
      expect(pipe.ended(), isTrue);
      expect(pipe.ended(), isFalse);
      pipe.dispose();
      expect(out.gone, isTrue);
    });

    test(
      'an ogg goes through the engine\'s decoder, its pcm zeroed after',
      () async {
        final heard = _pcm(0.25);
        final path = p.join(tmp, 'vn_9.ogg');
        final ogg = Uint8List.fromList([
          ...ascii.encode('OggS'),
          ...List.filled(60, 1),
        ]);
        await sealed(() => File(path).writeAsBytes(ogg));
        final out = _FakeOut();
        Uint8List? made, asked;
        final pipe = WasapiPipe(
          out,
          decode: (b) async {
            asked = Uint8List.fromList(b);
            return made = Uint8List.fromList([
              ...wavHead(16000, 1, heard.length),
              ...heard,
            ]);
          },
        );
        expect(
          await sealed(() => pipe.load(path)),
          const Duration(milliseconds: 250),
        );
        expect(asked, ogg, reason: 'the decoder got the plaintext');
        expect(out.got, heard);
        expect(made!.every((v) => v == 0), isTrue);
      },
    );

    test('anything else does not play, nor a wav it cannot', () async {
      final out = _FakeOut();
      final pipe = WasapiPipe(out, decode: (_) async => null);
      for (final (name, bytes) in [
        ('a.mp3', [...ascii.encode('ID3'), ...List.filled(60, 0)]),
        ('b.wav', [...wavHead(96000, 1, 64), ...List.filled(64, 0)]),
        ('c.ogg', [...ascii.encode('OggS'), ...List.filled(60, 0)]),
      ]) {
        final path = p.join(tmp, name);
        await sealed(() => File(path).writeAsBytes(bytes));
        expect(await sealed(() => pipe.load(path)), isNull, reason: name);
      }
      expect(out.got, isNull);
    });

    test('just_audio over the pipe', () async {
      final heard = _pcm(0.2);
      final path = p.join(tmp, 'vn_10.wav');
      await sealed(
        () => File(
          path,
        ).writeAsBytes([...wavHead(16000, 1, heard.length), ...heard]),
      );
      final out = _FakeOut();
      final audio = DesktopAudio(pipe: () => WasapiPipe(out));
      final player = await audio.init(InitRequest(id: 'a'));
      final r = await sealed(
        () => player.load(
          LoadRequest(
            audioSourceMessage: ProgressiveAudioSourceMessage(
              id: 's',
              uri: Uri.file(path).toString(),
            ),
          ),
        ),
      );
      expect(r.duration, const Duration(milliseconds: 200));
      await player.play(PlayRequest());
      expect(out.playing, isTrue);
      await player.pause(PauseRequest());
      expect(out.playing, isFalse);
      await audio.disposePlayer(DisposePlayerRequest(id: 'a'));
      expect(out.gone, isTrue);
    });
  });

  test('the wav head', () {
    final h = wavHead(16000, 1, 32000);
    expect(wavMs(Uint8List.fromList([...h, ...Uint8List(32000)])), 1000);
    // while it records the sizes say nothing: the file's length counts
    expect(
      wavMs(Uint8List.fromList([...wavHead(16000, 1, 0), ...Uint8List(3200)])),
      100,
    );
  });
}
