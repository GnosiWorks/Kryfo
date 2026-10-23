// SPDX-License-Identifier: GPL-3.0-or-later
// the dart side of the model download: what it asks the engine, in which
// directory, and that a quiet session asks nothing at all
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/voice_models.dart';

class _Engine {
  final calls = <String>[];
  final answers = <String, String>{};

  Future<String> call(String symbol, List<String> args) async {
    calls.add('$symbol(${args.join(',')})');
    return answers[symbol] ?? 'error: none';
  }
}

void main() {
  late _Engine e;
  var quiet = false;
  late VoiceModels models;

  setUp(() {
    e = _Engine();
    quiet = false;
    models = VoiceModels(
      call: e.call,
      dir: () async => '/data/user/0/app.kryfo/files/voice',
      quiet: () => quiet,
    );
  });

  test('lists the pinned models', () async {
    e.answers['HaloVoiceModels'] =
        '{"base":"http://x.onion/voice/","models":[{"id":"base","file":"ggml-base-q5_1.bin","size":59707625}]}';
    final m = await models.models();
    expect(m.single.id, 'base');
    expect(m.single.size, 59707625);
    e.answers['HaloVoiceModels'] = 'error: broken';
    expect(await models.models(), isEmpty);
    e.answers['HaloVoiceModels'] = '{not json';
    expect(await models.models(), isEmpty);
  });

  test('fetches into the app storage dir', () async {
    e.answers['HaloVoiceFetch'] = 'ok';
    expect(await models.fetch('base'), isTrue);
    // the id and the dir, and no host: the engine pins where it fetches
    expect(
      e.calls.single,
      'HaloVoiceFetch(base,/data/user/0/app.kryfo/files/voice)',
    );
    e.answers['HaloVoiceFetch'] = 'error: tor: not started';
    expect(await models.fetch('base'), isFalse);
  });

  test('progress', () async {
    e.answers['HaloVoiceProgress'] = '{"state":"running","done":5,"total":10}';
    final s = await models.progress('base');
    expect(s.running, isTrue);
    expect((s.done, s.total), (5, 10));
    e.answers['HaloVoiceProgress'] =
        '{"state":"failed","kind":"hash","err":"x"}';
    expect((await models.progress('base')).kind, 'hash');
    e.answers['HaloVoiceProgress'] = 'garbage';
    expect((await models.progress('base')).failed, isTrue);
  });

  test('installed and the path', () async {
    e.answers['HaloVoiceModels'] =
        '{"models":[{"id":"base","file":"ggml-base-q5_1.bin","size":1}]}';
    e.answers['HaloVoiceCheck'] = 'no';
    expect(await models.pathOf('base'), isNull);
    e.answers['HaloVoiceCheck'] = 'yes';
    expect(
      await models.pathOf('base'),
      '/data/user/0/app.kryfo/files/voice/ggml-base-q5_1.bin',
    );
    expect(await models.pathOf('small'), isNull);
    e.answers['HaloVoiceCheck'] = 'error: dir';
    expect(await models.installed('base'), isFalse);
  });

  test('remove and cancel', () async {
    e.answers['HaloVoiceRemove'] = 'ok';
    expect(await models.remove('base'), isTrue);
    e.answers['HaloVoiceRemove'] = 'error: downloading';
    expect(await models.remove('base'), isFalse);
    await models.cancel('base');
    expect(e.calls.last, 'HaloVoiceCancel(base)');
  });

  test('a quiet session asks the engine nothing', () async {
    quiet = true;
    e.answers['HaloVoiceFetch'] = 'ok';
    e.answers['HaloVoiceCheck'] = 'yes';
    e.answers['HaloVoiceRemove'] = 'ok';
    e.answers['HaloVoiceProgress'] = '{"state":"running","done":5,"total":10}';
    expect(await models.fetch('base'), isFalse);
    expect(await models.installed('base'), isFalse);
    expect(await models.pathOf('base'), isNull);
    expect(await models.remove('base'), isFalse);
    expect((await models.progress('base')).state, 'idle');
    expect(e.calls, isEmpty);
  });
}
