// SPDX-License-Identifier: GPL-3.0-or-later
// the app's gif source: the engine's gif lane, the route people search
// takes. a quiet session shows the tab and gets nothing from it
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../main.dart'
    show appState, engine, session, sessionQuiet, AppStateRoute;
import '../stickers/sticker_sheet.dart' show GifTabs;
import '../theme.dart' show showHaloToast;
import 'gif_favs.dart';
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

/// the favourites a chat's picker shows: a hidden chat's in the vault, the
/// rest in the session's own container (the decoy's in the decoy)
GifFavStore gifFavsFor(String? chat) {
  final s = session;
  final d = chat != null && s.isHidden(chat) ? s.vault! : s.primary;
  return GifFavStore(db: d.open, folder: d.container.mediaDir);
}

/// a gif of a chat's, kept in that chat's favourites: a haptic and a word
/// when it is in
Future<void> keepGifOf(BuildContext context, String path, String chat) async {
  var ok = false;
  try {
    ok = await gifFavsFor(chat).add(await File(path).readAsBytes());
  } catch (e) {
    dlog('gif fav: not kept (${e.runtimeType})');
  }
  if (!context.mounted) return;
  if (ok) HapticFeedback.lightImpact();
  showHaloToast(context, ok ? l10n.gifFavAdded : l10n.gifFavCouldNotAdd);
}

/// the picker's gif tabs for the open session, its own switch included,
/// and the favourites of [chat]'s side
GifTabs appGifTabs({String? chat}) => GifTabs(
  source: appGifSource,
  route: gifRouteOf(appState.sendMode),
  loadOn: () => loadGifSearchOn(session.container),
  saveOn: (on) => saveGifSearchOn(on, session.container),
  loadAsked: () => loadGifAsked(session.container),
  markAsked: () => markGifAsked(session.container),
  favs: gifFavsFor(chat),
);
