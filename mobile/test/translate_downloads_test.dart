// SPDX-License-Identifier: GPL-3.0-or-later
// a language pack's download as the app sees it: it starts only when asked,
// waits for wi-fi when told to, shows how far it got, stops and resumes,
// and says why it failed. the engine is a stand-in moved along by hand
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/downloads.dart';
import 'package:kryfo/translate/engine_bridge.dart';

import 'translate_fakes.dart';

Future<void> until(bool Function() ok) async {
  for (var i = 0; i < 400 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(ok(), isTrue);
}

void main() {
  late FakeBackend be;
  late ModelDownloads dl;
  var wifi = true;
  var wifiOnly = false;
  var host = '';

  setUp(() {
    be = FakeBackend();
    wifi = true;
    wifiOnly = false;
    host = '';
    dl = ModelDownloads(
      backend: be,
      onWifi: () async => wifi,
      wifiOnly: () => wifiOnly,
      host: () => host,
      poll: const Duration(milliseconds: 5),
    );
  });
  tearDown(() => dl.dispose());

  test('nothing on the phone: absent, and nothing fetched', () async {
    expect(dl.of('zh').phase, DlPhase.unknown);
    await dl.refresh('zh');
    expect(dl.of('zh').phase, DlPhase.absent);
    expect(be.started, isEmpty);
  });

  test('a pack already there reads as installed with its size', () async {
    be.finish('zh');
    await dl.refresh('zh');
    expect(dl.of('zh').phase, DlPhase.installed);
    expect(dl.of('zh').onDisk, greaterThan(0));
    expect(dl.installed('zh'), isTrue);
  });

  test('start, progress, done', () async {
    final seen = <DlPhase>[];
    dl.addListener(() => seen.add(dl.of('zh').phase));
    await dl.start('zh');
    expect(be.started, ['zh']);
    be.status = const FetchStatus('running', done: 10, total: 100);
    await until(() => dl.of('zh').done == 10);
    expect(dl.of('zh').phase, DlPhase.running);
    expect(dl.of('zh').share, closeTo(0.1, 1e-9));
    be.finish('zh');
    await until(() => dl.of('zh').phase == DlPhase.installed);
    expect(seen.first, DlPhase.starting);
    expect(dl.of('zh').onDisk, be.disk);
    // done: a second start fetches nothing
    await dl.start('zh');
    expect(be.started, ['zh']);
  });

  test('cancel pauses; a start resumes from there', () async {
    await dl.start('zh');
    be.status = const FetchStatus('running', done: 40, total: 100);
    be.disk = 40;
    await until(() => dl.of('zh').done == 40);
    dl.cancel('zh');
    expect(be.cancels, 1);
    await until(() => dl.of('zh').phase == DlPhase.paused);
    await until(() => dl.of('zh').onDisk == 40);
    expect(dl.of('zh').done, 40);
    await dl.start('zh');
    expect(be.started, ['zh', 'zh']);
    expect(dl.of('zh').busy, isTrue);
  });

  test('a cancel with nothing going does nothing', () {
    dl.cancel('zh');
    expect(be.cancels, 0);
  });

  test('wi-fi only waits for wi-fi, unless told to go now', () async {
    wifiOnly = true;
    wifi = false;
    await dl.start('zh');
    expect(dl.of('zh').phase, DlPhase.wifiNeeded);
    expect(be.started, isEmpty);
    await dl.start('zh', anyNetwork: true);
    expect(be.started, ['zh']);
    wifi = true;
  });

  test('on wi-fi, wi-fi only goes at once', () async {
    wifiOnly = true;
    await dl.start('zh');
    expect(be.started, ['zh']);
  });

  test('no tor: a failure that says so, and nothing fetched', () async {
    be.startAnswer = 'error: tor: not started';
    await dl.start('zh');
    expect(dl.of('zh').phase, DlPhase.failed);
    expect(dl.of('zh').fail, DlFail.noTor);
  });

  test('an engine without downloads says so', () async {
    be.startAnswer = 'error: engine has no downloads';
    await dl.start('zh');
    expect(dl.of('zh').fail, DlFail.noEngine);
  });

  test('a cut is a network failure; a bad hash says so', () async {
    await dl.start('zh');
    be.status = const FetchStatus('failed', kind: 'net', err: 'eof');
    await until(() => dl.of('zh').phase == DlPhase.failed);
    expect(dl.of('zh').fail, DlFail.network);
    // try again
    await dl.start('zh');
    expect(dl.of('zh').fail, isNull);
    be.status = const FetchStatus('failed', kind: 'hash');
    await until(() => dl.of('zh').phase == DlPhase.failed);
    expect(dl.of('zh').fail, DlFail.badFile);
  });

  test('the host set in settings is the one asked', () async {
    host = 'https://mirror.example/models/';
    await dl.start('zh');
    expect(be.hosts, ['https://mirror.example/models/']);
  });

  test('a part download left from before reads as paused', () async {
    be.disk = 1234;
    await dl.refresh('zh');
    expect(dl.of('zh').phase, DlPhase.paused);
    expect(dl.of('zh').onDisk, 1234);
  });

  test('remove takes it off, but not while it downloads', () async {
    be.finish('zh');
    await dl.refresh('zh');
    expect(await dl.remove('zh'), isTrue);
    expect(dl.of('zh').phase, DlPhase.absent);
    be.status = const FetchStatus('idle');
    await dl.start('zh');
    expect(await dl.remove('zh'), isFalse);
  });

  test('the engine progress answer parses, and junk is a failure', () {
    final s = FetchStatus.parse(
      '{"state":"failed","done":3,"total":9,"kind":"hash","err":"x"}',
    );
    expect(s.state, 'failed');
    expect(s.done, 3);
    expect(s.kind, 'hash');
    expect(FetchStatus.parse('error: what').state, 'failed');
  });
}
