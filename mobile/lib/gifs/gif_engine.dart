// SPDX-License-Identifier: GPL-3.0-or-later
// the app's gif source: the engine's services lane, the route people search
// takes. a quiet session gets nothing from it
import '../main.dart' show appState, engine, session, sessionQuiet;
import '../stickers/sticker_sheet.dart' show GifTabs;
import 'gif_panel.dart' show gifRouteOf;
import 'gif_source.dart';

class _EngineWire implements GifWire {
  const _EngineWire();

  @override
  Future<String> post(String url, String body) => engine.torPost(url, body);

  @override
  Future<String> get(String url) => engine.torGetJson(url);

  @override
  Future<String> getFile(String url, String path) =>
      engine.torGetFile(url, path);
}

final appGifSource = RelayGifSource(
  const _EngineWire(),
  quiet: () => sessionQuiet,
);

/// the picker's gif tabs for the open session
GifTabs appGifTabs() => GifTabs(
  source: sessionQuiet ? null : appGifSource,
  route: gifRouteOf(appState.sendMode),
  loadOn: () => loadGifSearchOn(session.container),
  saveOn: (on) => saveGifSearchOn(on, session.container),
);
