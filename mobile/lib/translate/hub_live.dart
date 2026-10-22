// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's translation hub: settings in the identity's database, packs
// in the app's own storage, downloads by the engine over tor, bergamot when
// the build has it.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../main.dart' show session;
import 'bergamot_ffi.dart';
import 'catalog.dart';
import 'downloads.dart';
import 'engine_bridge.dart';
import 'hub.dart';
import 'settings.dart';

// the packs are the phone's, not an identity's: one copy whoever reads
Future<String> modelsDir() async =>
    p.join((await getApplicationSupportDirectory()).path, 'translate');

Future<bool> _onWifi() async {
  try {
    return (await Connectivity().checkConnectivity()).contains(
      ConnectivityResult.wifi,
    );
  } catch (_) {
    return false;
  }
}

TranslationHub translationHub() => TranslationHub.instance ??= _live();

TranslationHub _live() {
  final engine = FfiTranslateEngine();
  final catalog = engine.catalog() ?? builtInCatalog;
  late final TranslationHub hub;
  final downloads = ModelDownloads(
    backend: EngineModelBackend(engine, modelsDir, () => catalog),
    onWifi: _onWifi,
    wifiOnly: () => hub.settings.wifiOnly,
    host: () => hub.settings.host,
  );
  String? dir;
  modelsDir().then((d) => dir = d, onError: (Object _) => null);
  final translator = BergamotTranslator(
    installed: (f, t) =>
        downloads.installed(catalog.bundleFor(f, t)?.lang ?? ''),
    config: (f, t) => dir == null ? null : engine.config(f, t, dir!),
  );
  hub = TranslationHub(
    // read each time: the session changes with the identity
    store: DbTranslateStore(
      () => session.settingsDb(),
      chatDb: (id) => session.chatDb(id),
    ),
    engine: engine,
    catalog: catalog,
    translator: translator,
    downloads: downloads,
    scope: () => session.container.id,
  );
  return hub;
}
