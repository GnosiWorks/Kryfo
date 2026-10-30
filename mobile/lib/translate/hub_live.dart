// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's translation hub: settings in the identity's database, packs
// in the app's own storage, downloads by the engine over tor, bergamot when
// the build has it.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../lock_state.dart' show lockState;
import '../main.dart' show appState, session, sessionQuiet;
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

// off until the translation library is in the build
const kOfflineTranslation = false;

// the hub while translation is on, or one a test set. null: no screen
// shows translation and nothing of it is built
TranslationHub? translationHubIfOn() =>
    TranslationHub.instance ?? (kOfflineTranslation ? translationHub() : null);

TranslationHub _live() {
  final engine = FfiTranslateEngine();
  final catalog = engine.catalog() ?? builtInCatalog;
  late final TranslationHub hub;
  final downloads = ModelDownloads(
    backend: EngineModelBackend(engine, modelsDir, () => catalog),
    onWifi: _onWifi,
    wifiOnly: () => hub.settings.wifiOnly,
    quiet: () => sessionQuiet,
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
      open: () async => [
        await session.settingsDb(),
        if (session.vault case final v? when v.isOpen) await v.open(),
      ],
    ),
    engine: engine,
    catalog: catalog,
    translator: translator,
    downloads: downloads,
    scope: () => session.container.id,
  );
  // a hidden chat's switch is not kept once its vault shuts
  hub.followSessions(appState, () => appState.sessionRev);
  // nothing translated or guessed is kept behind the lock
  hub.followLock(lockState, () => lockState.locked);
  WidgetsBinding.instance.addObserver(TranslateAway(hub));
  return hub;
}
