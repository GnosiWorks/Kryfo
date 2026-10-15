// SPDX-License-Identifier: GPL-3.0-or-later
// the app's gif source: the engine's gif lane, the route people search
// takes. a quiet session shows the tab and gets nothing from it
import '../main.dart' show appState, engine, session, sessionQuiet;
import '../stickers/sticker_sheet.dart' show GifTabs;
import 'gif_panel.dart' show gifRouteOf;
import 'gif_source.dart';

class _EngineWire implements GifWire {
  const _EngineWire();

  @override
  Future<String> post(String url, String body) => engine.gifPost(url, body);

  @override
  Future<String> get(String url) => engine.gifGet(url);

  @override
  Future<String> getFile(String url, String path) =>
      engine.gifGetFile(url, path);
}

final appGifSource = RelayGifSource(
  const _EngineWire(),
  quiet: () => sessionQuiet,
  overTor: () => appState.sendMode == 'private',
);

/// the picker's gif tabs for the open session, its own switch included
GifTabs appGifTabs() => GifTabs(
  source: appGifSource,
  route: gifRouteOf(appState.sendMode),
  loadOn: () => loadGifSearchOn(session.container),
  saveOn: (on) => saveGifSearchOn(on, session.container),
  loadAsked: () => loadGifAsked(session.container),
  markAsked: () => markGifAsked(session.container),
);
