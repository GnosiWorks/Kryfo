// SPDX-License-Identifier: GPL-3.0-or-later
// the speech models on the dart side: the engine downloads them over tor
// into the app's own storage and checks them against its pins; this asks
// it to and polls. one copy for the phone, whoever reads.

import 'dart:convert';

/// one downloadable model as the engine pins it
class VoiceModelInfo {
  const VoiceModelInfo(this.id, this.file, this.size);
  final String id;
  final String file;
  final int size;
}

/// a download as the engine reports it. kind is "hash" for a file that
/// did not match its pin, "net" for what a retry may get past
class VoiceModelStatus {
  const VoiceModelStatus(this.state, this.done, this.total, this.kind);
  final String state;
  final int done;
  final int total;
  final String kind;

  static const idle = VoiceModelStatus('idle', 0, 0, '');

  bool get running => state == 'running';
  bool get finished => state == 'done';
  bool get failed => state == 'failed';

  static VoiceModelStatus parse(String s) {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return VoiceModelStatus(
        m['state'] as String? ?? 'idle',
        (m['done'] as num?)?.toInt() ?? 0,
        (m['total'] as num?)?.toInt() ?? 0,
        m['kind'] as String? ?? '',
      );
    } catch (_) {
      return const VoiceModelStatus('failed', 0, 0, 'net');
    }
  }
}

/// an engine call by symbol with string arguments, off the ui isolate
typedef VoiceEngineCall =
    Future<String> Function(String symbol, List<String> args);

class VoiceModels {
  VoiceModels({required this.call, required this.dir, required this.quiet});

  final VoiceEngineCall call;

  /// the models' directory in the app's own storage
  final Future<String> Function() dir;

  /// a quiet session (the decoy) downloads nothing and sees no model, as
  /// the translation packs do. the engine holds to it too: it refuses a
  /// download while a decoy is open and stops one when a decoy opens
  final bool Function() quiet;

  Future<List<VoiceModelInfo>> models() async {
    final out = await call('HaloVoiceModels', const []);
    if (out.startsWith('error')) return const [];
    try {
      final m = jsonDecode(out) as Map<String, dynamic>;
      return [
        for (final e in (m['models'] as List? ?? const []))
          VoiceModelInfo(
            e['id'] as String,
            e['file'] as String,
            (e['size'] as num).toInt(),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// starts fetching [id] from the mirror the engine pins; nothing here
  /// names a host. false when it could not start
  Future<bool> fetch(String id) async => await start(id) == 'ok';

  /// the same, with the engine's answer: "ok", or "error: ..." ("error:
  /// tor: ..." when tor is not up)
  Future<String> start(String id) async {
    if (quiet()) return 'error: decoy';
    return call('HaloVoiceFetch', [id, await dir()]);
  }

  Future<VoiceModelStatus> progress(String id) async {
    if (quiet()) return VoiceModelStatus.idle;
    return VoiceModelStatus.parse(await call('HaloVoiceProgress', [id]));
  }

  Future<void> cancel(String id) => call('HaloVoiceCancel', [id]);

  /// whether [id] is on the phone and matches its pin. a file that does not
  /// is deleted by the engine
  Future<bool> installed(String id) async {
    if (quiet()) return false;
    return await call('HaloVoiceCheck', [id, await dir()]) == 'yes';
  }

  /// the model's path for the transcriber, null unless it is installed
  Future<String?> pathOf(String id) async {
    if (!await installed(id)) return null;
    for (final m in await models()) {
      if (m.id == id) return '${await dir()}/${m.file}';
    }
    return null;
  }

  /// where [id] is kept once on the phone, there or not; null for a model
  /// the engine does not pin
  Future<String?> fileOf(String id) async {
    for (final m in await models()) {
      if (m.id == id) return '${await dir()}/${m.file}';
    }
    return null;
  }

  /// takes [id] off the phone; the transcripts already made stay
  Future<bool> remove(String id) async {
    if (quiet()) return false;
    return await call('HaloVoiceRemove', [id, await dir()]) == 'ok';
  }
}
