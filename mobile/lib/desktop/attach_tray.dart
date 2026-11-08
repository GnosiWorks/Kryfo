// SPDX-License-Identifier: GPL-3.0-or-later
// files dropped or pasted on a chat on a computer wait in a row above the
// composer until enter sends them with what is typed. each chat has its
// own row, so nothing staged in one can go to another. nothing is copied
// while it waits: a row holds paths and, for a photo, a small decoded
// thumb in memory, and a lock lets go of all of it. the copy into the
// sealed media folder is made on send, the way a pick's is. note to self
// has its row too (DeskTrays.of('<container>|notes')): enter keeps each
// staged file as a note. a pasted picture has no path: its bytes wait in
// memory, never on disk, and go the photo's way
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../lock_state.dart' show lockState;
import '../open_file.dart' show nameSaysVideo;
import '../shred.dart' show shredTree;
import '../theme.dart';
import '../widgets/media_bubbles.dart' show fileTooBigLine, humanFileSize;
import '../widgets/motion.dart' show motionStill;
import 'desktop_mode.dart' show onDesktop;
import 'clip_picture.dart' show clipboardPicture;
import 'desktop_run.dart' show runChannel;
import 'drag_in.dart' show draggedFiles, kDragInMost;

/// what a staged item goes as: photos and videos in an album, as the
/// phone's gallery sends them, and the rest as files after
enum TrayKind { photo, video, file }

const _photoExts = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'};

TrayKind trayKindOf(String name) {
  final ext = p.extension(name).toLowerCase();
  if (_photoExts.contains(ext)) return TrayKind.photo;
  if (nameSaysVideo(name)) return TrayKind.video;
  return TrayKind.file;
}

class TrayItem {
  TrayItem(this.path, this.size)
    : name = p.basename(path),
      kind = trayKindOf(path),
      bytes = null;

  /// a picture pasted from the clipboard, a png in memory. its path is a
  /// name for the row alone: nothing is at it
  TrayItem.picture(Uint8List this.bytes, {String? name})
    : path = 'pasted:${_pasted++}',
      name = name ?? l10n.trayPastedPicture,
      size = bytes.length,
      kind = TrayKind.photo;

  static var _pasted = 0;

  final String path;
  final String name;
  final int size;
  final TrayKind kind;

  /// a pasted picture's bytes; null for a file, read from its path
  final Uint8List? bytes;

  /// a photo's small picture, decoded here and dropped with the row
  ui.Image? thumb;

  bool get media => kind != TrayKind.file;
}

/// how a row goes on enter, as the phone's picks go: photos and videos
/// as albums with the caption on the first (albumPlan), then each file in
/// the order staged. with no photo or video the first file takes it
({List<TrayItem> media, List<(TrayItem, String)> files}) trayPlan(
  List<TrayItem> items,
  String caption,
) {
  final media = [
    for (final x in items)
      if (x.media) x,
  ];
  final files = [
    for (final x in items)
      if (!x.media) x,
  ];
  return (
    media: media,
    files: [
      for (final (k, x) in files.indexed)
        (x, media.isEmpty && k == 0 ? caption : ''),
    ],
  );
}

/// what a staged photo is: a pasted one's bytes, or its file's
Future<Uint8List> trayBytes(TrayItem x) async =>
    x.bytes ?? await File(x.path).readAsBytes();

/// a photo's thumb, a small decode of its bytes. null for one that will
/// not decode, which then shows as a file does
Future<ui.Image?> decodeTrayThumb(String path) async {
  try {
    return await decodeTrayBytes(await File(path).readAsBytes());
  } catch (_) {
    return null;
  }
}

Future<ui.Image?> decodeTrayBytes(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 160);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// files copied in explorer or a file manager, as paths, read off the
/// clipboard by the runner. none where the runner has no such call.
/// a copied picture's own data comes with clipboardPicture
Future<List<String>> clipboardFiles() async {
  try {
    return await runChannel.invokeListMethod<String>('clipFiles') ?? const [];
  } catch (_) {
    return const [];
  }
}

/// one chat's staged files
class AttachTray extends ChangeNotifier {
  /// set by tests
  static Future<ui.Image?> Function(String path) decode = decodeTrayThumb;
  static Future<ui.Image?> Function(Uint8List bytes) decodePicture =
      decodeTrayBytes;

  final List<TrayItem> _items = [];
  String? _line;
  bool _warn = false;

  List<TrayItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  /// a line under the row: too big, too many, or what waits for an accept
  String? get line => _line;

  /// the line says something did not go in: too big, too many
  bool get warns => _warn;

  /// something shows: items or a line
  bool get shown => _items.isNotEmpty || _line != null;

  /// [paths] staged in the order given. one over [most] bytes, or past
  /// the count a send takes, stays out and the line says why
  Future<void> add(
    List<String> paths, {
    required Future<int> Function() most,
  }) async {
    if (lockState.locked) return;
    final files = draggedFiles(paths);
    if (files.isEmpty) return;
    final limit = await most();
    if (lockState.locked) return;
    String? line;
    final added = <TrayItem>[];
    for (final f in files) {
      if (_items.any((x) => x.path == f) || added.any((x) => x.path == f)) {
        continue;
      }
      if (_items.length + added.length >= kDragInMost) {
        line = l10n.mediaSendUpTo(whole(kDragInMost));
        break;
      }
      final int size;
      try {
        size = File(f).lengthSync();
      } catch (_) {
        continue;
      }
      if (size == 0) continue;
      if (size > limit) {
        line = fileTooBigLine(size, limit);
        continue;
      }
      added.add(TrayItem(f, size));
    }
    _items.addAll(added);
    _line = line;
    _warn = line != null;
    notifyListeners();
    for (final x in added) {
      if (x.kind == TrayKind.photo) unawaited(_thumb(x));
    }
  }

  /// a picture pasted, as png [bytes], staged as a photo. one over [most]
  /// bytes, or past the count a send takes, stays out and the line says
  /// why. nothing goes in while the app is locked
  Future<void> addPicture(
    Uint8List bytes, {
    required Future<int> Function() most,
    String? name,
  }) async {
    if (lockState.locked || bytes.isEmpty) return;
    final limit = await most();
    if (lockState.locked) return;
    if (_items.length >= kDragInMost) {
      _line = l10n.mediaSendUpTo(whole(kDragInMost));
      _warn = true;
      notifyListeners();
      return;
    }
    if (bytes.length > limit) {
      _line = fileTooBigLine(bytes.length, limit);
      _warn = true;
      notifyListeners();
      return;
    }
    final x = TrayItem.picture(bytes, name: name);
    _items.add(x);
    _line = null;
    _warn = false;
    notifyListeners();
    unawaited(_thumb(x));
  }

  Future<void> _thumb(TrayItem x) async {
    final pasted = x.bytes;
    final img = pasted != null
        ? await decodePicture(pasted)
        : await decode(x.path);
    if (img == null) return;
    // gone while it decoded: a lock, a remove, a send
    if (!_items.contains(x)) {
      img.dispose();
      return;
    }
    x.thumb = img;
    notifyListeners();
  }

  /// a line alone, with nothing staged: a request still waiting
  void say(String line) {
    _line = line;
    _warn = false;
    notifyListeners();
  }

  void remove(TrayItem x) {
    if (!_items.remove(x)) return;
    _forget(x);
    DeskTrays._release(x.path);
    _line = null;
    notifyListeners();
  }

  /// what is staged, handed over for the send; the row is empty after.
  /// a file a tool made goes once [sent] says the send read it
  List<TrayItem> take() {
    final out = List<TrayItem>.of(_items);
    clear(sending: true);
    return out;
  }

  /// [items] taken for a send are read: what a tool made for them goes
  static void sent(List<TrayItem> items) {
    for (final x in items) {
      DeskTrays._release(x.path);
    }
  }

  void clear({bool sending = false}) {
    if (!shown) return;
    for (final x in _items) {
      _forget(x);
      if (!sending) DeskTrays._release(x.path);
    }
    _items.clear();
    _line = null;
    notifyListeners();
  }

  void _forget(TrayItem x) {
    x.thumb?.dispose();
    x.thumb = null;
  }
}

/// every chat's row, by chat. a lock empties them all
class DeskTrays {
  DeskTrays._();

  static final _trays = <String, AttachTray>{};
  static bool _watching = false;

  /// the row of the chat [key] names: its container and its peer or group
  static AttachTray of(String key) {
    if (!_watching) {
      _watching = true;
      lockState.addListener(_lockMoved);
    }
    return _trays.putIfAbsent(key, AttachTray.new);
  }

  static void _lockMoved() {
    if (lockState.locked) clearAll();
  }

  static void clearAll() {
    for (final t in _trays.values) {
      t.clear();
    }
    _waiting.clear();
    handedIn.value++;
    for (final f in List.of(_owned)) {
      _release(f);
    }
  }

  // what a tool handed to a chat that has not taken it yet, by row
  static final _waiting = <String, List<TrayHandoff>>{};

  /// files a tool made (a locked file), shredded once they leave a row,
  /// are sent, or the app locks
  static final _owned = <String>{};

  /// says a chat may have something waiting for its row
  static final handedIn = ValueNotifier<int>(0);

  /// [what] waits for the row of [key] until that chat takes it. a locked
  /// app takes nothing
  static void handOff(String key, TrayHandoff what) {
    if (lockState.locked) {
      what.drop();
      return;
    }
    if (!_watching) of(key);
    final f = what.path;
    if (what.owned && f != null) _owned.add(f);
    (_waiting[key] ??= []).add(what);
    handedIn.value++;
  }

  /// what waits for [key]'s row, taken
  static List<TrayHandoff> takeHandedOff(String key) =>
      _waiting.remove(key) ?? const [];

  static void _release(String path) {
    if (!_owned.remove(path)) return;
    unawaited(shredTree(p.dirname(path)).catchError((_) {}));
  }

  /// a handed file the chat could not keep (a stranger's chat, a full row)
  static void released(String path) => _release(path);
}

/// one result a tool sends to a chat: a file at [path], or a picture's
/// [bytes] under [name]. an [owned] file is the tool's own, in its folder,
/// and goes with that folder once read
class TrayHandoff {
  const TrayHandoff.file(String this.path, {this.owned = false})
    : bytes = null,
      name = null;
  const TrayHandoff.picture(Uint8List this.bytes, {required this.name})
    : path = null,
      owned = false;

  final String? path;
  final Uint8List? bytes;
  final String? name;
  final bool owned;

  /// not taken: what the tool made goes
  void drop() {
    final f = path;
    if (owned && f != null) {
      DeskTrays._owned.add(f);
      DeskTrays._release(f);
    }
  }
}

/// ctrl and v, or shift and insert, in a composer on a computer: files
/// copied in explorer go to [onFiles], a copied picture (a screenshot, a
/// browser's copy image) to [onPicture] as png bytes. words on the
/// clipboard paste as they always have, unless they are only a link
/// beside a picture (firefox's copy image): then the picture goes and the
/// link stays out. a locked app takes nothing
class PasteFiles extends StatelessWidget {
  const PasteFiles({
    super.key,
    required this.onFiles,
    this.onPicture,
    required this.child,
  });

  final void Function(List<String> paths) onFiles;
  final void Function(Uint8List png)? onPicture;
  final Widget child;

  /// set by tests
  static Future<List<String>> Function() clip = clipboardFiles;
  static Future<Uint8List?> Function() picture = clipboardPicture;

  static bool _isPaste(KeyEvent e) {
    final keys = HardwareKeyboard.instance;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.keyV) {
      return keys.isControlPressed &&
          !keys.isAltPressed &&
          !keys.isShiftPressed;
    }
    return k == LogicalKeyboardKey.insert && keys.isShiftPressed;
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || !_isPaste(e) || lockState.locked) {
      return KeyEventResult.ignored;
    }
    if (onPicture == null) {
      unawaited(_paste(null));
      return KeyEventResult.ignored;
    }
    // the field's own paste waits: a picture that wins keeps its link out
    unawaited(_paste(FocusManager.instance.primaryFocus));
    return KeyEventResult.handled;
  }

  Future<void> _paste(FocusNode? field) async {
    final paths = await clip();
    if (lockState.locked) return;
    if (paths.isNotEmpty) {
      onFiles(paths);
      _words(field);
      return;
    }
    final take = onPicture;
    if (take == null) return;
    final png = await picture();
    if (lockState.locked) return;
    if (png != null) {
      take(png);
      return;
    }
    _words(field);
  }

  // the paste ctrl and v would have done in the field
  static void _words(FocusNode? field) {
    final at = field?.context;
    if (at == null || !at.mounted) return;
    Actions.maybeInvoke(
      at,
      const PasteTextIntent(SelectionChangedCause.keyboard),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!onDesktop) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _key,
      child: child,
    );
  }
}

/// the row above the composer: a tile for each staged item with its
/// remove, and the line when there is one. nothing on a phone
class TrayStrip extends StatelessWidget {
  const TrayStrip({super.key, required this.tray});

  final AttachTray tray;

  @override
  Widget build(BuildContext context) {
    if (!onDesktop) return const SizedBox.shrink();
    final still = motionStill(context);
    return ListenableBuilder(
      listenable: tray,
      builder: (context, _) => AnimatedSize(
        duration: Duration(milliseconds: still ? 0 : 200),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: tray.shown
            ? _row(context)
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  Widget _row(BuildContext context) {
    final items = tray.items;
    final line = tray.line;
    return Container(
      key: const ValueKey('attach-tray'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (items.isNotEmpty)
            Semantics(
              container: true,
              label: l10n.trayReadyToSend(whole(items.length)),
              child: SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _Tile(
                    key: ValueKey(items[i].path),
                    item: items[i],
                    onRemove: () => tray.remove(items[i]),
                  ),
                ),
              ),
            ),
          if (line != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  line,
                  key: const ValueKey('attach-tray-line'),
                  style: HaloType.sans(
                    size: 12.5,
                    color: items.isEmpty
                        ? HaloColors.text
                        : HaloColors.roseText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.item, required this.onRemove});

  final TrayItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final thumb = item.thumb;
    final size = humanFileSize(item.size);
    return SizedBox(
      width: 104,
      child: Stack(
        children: [
          Semantics(
            container: true,
            label: '${item.name}, $size',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 104,
                      height: 72,
                      color: HaloColors.surface2,
                      alignment: Alignment.center,
                      child: thumb != null
                          ? RawImage(
                              image: thumb,
                              width: 104,
                              height: 72,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              switch (item.kind) {
                                TrayKind.photo => Icons.image_outlined,
                                TrayKind.video => Icons.movie_outlined,
                                TrayKind.file =>
                                  Icons.insert_drive_file_outlined,
                              },
                              size: 28,
                              color: HaloColors.amber,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.sans(size: 11.5, color: HaloColors.text),
                  ),
                  Text(
                    size,
                    maxLines: 1,
                    style: HaloType.mono(size: 10, color: HaloColors.text),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Tooltip(
              message: l10n.trayRemove(item.name),
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                label: l10n.trayRemove(item.name),
                child: Material(
                  color: HaloColors.surface3,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: ValueKey('tray-remove-${item.name}'),
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: HaloColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
