// SPDX-License-Identifier: GPL-3.0-or-later
// the tools on a computer: each tool screen keeps its phone code and only
// its way in and out changes. in: the open dialog, a drop, ctrl and v. out:
// the save dialog straight to the place picked, "Send to a chat" into a
// chat's row, "Copy picture". the person's own file is only read, where it
// is. what a tool makes lives in memory, or sealed in kryfo's tmp, until it
// is saved or staged (a locked file is age's ciphertext in kryfo's tmp);
// nothing plain is written anywhere else
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../desktop/attach_tray.dart' show DeskTrays, TrayHandoff;
import '../desktop/desktop_mode.dart' show bulkTempDir, engineDir, onDesktop;
import '../desktop/desktop_save.dart' show deskSaver;
import '../desktop/drag_in.dart' show DragInZone;
import '../l10n/l10n.dart';
import '../lock_guard.dart' show LockDropped;
import '../lock_state.dart';
import '../main.dart' show appState, session;
import '../meta/file_source.dart';
import '../meta/meta_reader.dart';
import '../screens/forward_sheet.dart' show pickWordsChat, wordsRoute;
import '../shred.dart' show shredTree;
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/tool_parts.dart' show ToolWideButton;
import 'tools_bridge.dart';

/// which tool a file opens in
enum DeskToolFor { picture, video, locked, other }

const _ageHead = 'age-encryption.org/';
const _ageArmor = '-----BEGIN AGE ENCRYPTED FILE-----';

/// [path] by its first bytes: a picture or a video the cleaner reads, an
/// age file, or anything else
DeskToolFor deskToolFor(String path) {
  try {
    final f = File(path).openSync();
    final List<int> head;
    try {
      head = f.readSync(64);
    } finally {
      f.closeSync();
    }
    final text = String.fromCharCodes(head);
    if (text.startsWith(_ageHead) || text.startsWith(_ageArmor)) {
      return DeskToolFor.locked;
    }
    final src = FileSource.open(path);
    try {
      return switch (metaKindOf(src)) {
        MetaKind.unknown =>
          p.extension(path).toLowerCase() == '.age'
              ? DeskToolFor.locked
              : DeskToolFor.other,
        MetaKind.mp4 => DeskToolFor.video,
        _ => DeskToolFor.picture,
      };
    } finally {
      src.close();
    }
  } catch (_) {
    return DeskToolFor.other;
  }
}

/// a file of the person's, as the open dialog gives it
PickedFile? deskPicked(String path) {
  try {
    return PickedFile(
      uri: path,
      name: p.basename(path),
      size: File(path).lengthSync(),
      inPlace: true,
    );
  } on FileSystemException {
    return null;
  }
}

String _tag() {
  final rnd = Random.secure();
  return List.generate(
    8,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// a folder of its own in kryfo's tmp: in memory on linux, sealed under
/// this run's key on windows. the tools' copies and results live there
Future<Directory> toolsFolder(String what) async {
  final d = Directory(
    p.join((await getTemporaryDirectory()).path, what, _tag()),
  );
  await d.create(recursive: true);
  return d;
}

/// where the engine writes a locked file a tool made. only age's ciphertext
/// is ever there. on windows the engine's own folder, on the disk. on linux
/// the disk's tmp too: the memory folder holds about a tenth of the ram,
/// and a large file would not fit
Future<Directory> engineToolsFolder() async {
  final bulk = bulkTempDir;
  final base = Platform.isLinux && bulk != null
      ? await bulk()
      : engineDir((await getApplicationDocumentsDirectory()).path);
  final d = Directory(p.join(base, 'tools_out', _tag()));
  await d.create(recursive: true);
  return d;
}

/// a pasted picture (png bytes) as a file the cleaner reads: kryfo's own
/// copy in its tmp, never a plain one on the disk, shred once read
Future<PickedFile?> pastedPicture(Uint8List png) async {
  try {
    final name = '${l10n.trayPastedPicture}.png';
    final d = await toolsFolder('tools_in');
    final f = File(p.join(d.path, name));
    await f.writeAsBytes(png, flush: true);
    return PickedFile(uri: f.path, name: name, size: png.length);
  } on FileSystemException {
    return null;
  }
}

/// [bytes] saved with the save dialog, straight to the place picked:
/// 'saved', 'kept' when it was closed or the app locked meanwhile, 'failed'
Future<String> deskSaveBytes(Uint8List bytes, String name) async {
  try {
    return await lockState.hold(() => deskSaver.saveBytes(bytes, name));
  } on LockDropped {
    return 'kept';
  }
}

/// [what] staged in the row of a chat picked from this session's own, and
/// that chat opened: nothing goes until enter, as with a drop. a held chat
/// is asked about first, a blocked one is not listed, and a lock or a
/// session change on the way takes it back
Future<void> sendToChat(BuildContext context, TrayHandoff what) async {
  final container = session.container.id;
  final String? id;
  try {
    id = await pickWordsChat(
      context,
      title: l10n.shareChooseChat,
      empty: appState.contacts.isEmpty ? l10n.shareNoChats : l10n.shareNoOne,
    );
  } catch (_) {
    what.drop();
    return;
  }
  if (id == null ||
      !context.mounted ||
      lockState.locked ||
      session.container.id != container) {
    what.drop();
    return;
  }
  final route = await wordsRoute(id, '');
  if (route == null ||
      !context.mounted ||
      lockState.locked ||
      session.container.id != container) {
    what.drop();
    return;
  }
  DeskTrays.handOff('$container|$id', what);
  // over the tool, which stays: back is the tool again
  unawaited(Navigator.of(context).push(route));
}

/// a tool's page on a computer goes when the app locks: its result, its
/// typed password and its job with it (each screen's dispose)
mixin DeskToolLock<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    if (onDesktop) lockState.addListener(_deskLocked);
  }

  void _deskLocked() {
    if (!lockState.locked || !mounted) return;
    final r = ModalRoute.of(context);
    if (r != null && r.isActive) r.navigator?.removeRoute(r);
  }

  @override
  void dispose() {
    lockState.removeListener(_deskLocked);
    super.dispose();
  }
}

/// a file that is no photo, video or locked file: one clear choice, so a
/// stray drop does nothing
Future<bool> askLockThisFile(BuildContext context, String name) async =>
    await showHaloSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: 14),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 21, color: HaloColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.toolsLockThisFileLine,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13.5,
                  height: 1.5,
                  color: HaloColors.warm,
                ),
              ),
              const SizedBox(height: 18),
              ToolWideButton(
                label: l10n.toolsLockThisFile,
                filled: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    ) ==
    true;

/// the tools tab and a tool's page on a computer: a file dropped there
/// opens in its tool. one at a time
class DeskToolsIn extends StatefulWidget {
  const DeskToolsIn({
    super.key,
    required this.onFile,
    this.page = false,
    required this.child,
  });

  final void Function(String path) onFile;

  /// a tool's own page, not the tab
  final bool page;
  final Widget child;

  /// what a page opened from [context] takes a drop with: the page it
  /// replaces keeps the same way in
  static Widget wrap(BuildContext context, Widget page) {
    final at = context.findAncestorWidgetOfExactType<DeskToolsIn>();
    if (at == null) return page;
    return DeskToolsIn(onFile: at.onFile, page: true, child: page);
  }

  /// a tool's page is the one in front: ctrl and v there opens what was
  /// copied in its place
  static bool pageInFront() => _DeskToolsInState._pages.any(
    (s) => s.mounted && (ModalRoute.of(s.context)?.isCurrent ?? false),
  );

  @override
  State<DeskToolsIn> createState() => _DeskToolsInState();
}

class _DeskToolsInState extends State<DeskToolsIn> {
  static final _pages = <_DeskToolsInState>{};

  @override
  void initState() {
    super.initState();
    if (widget.page) _pages.add(this);
  }

  @override
  void dispose() {
    _pages.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!onDesktop) return widget.child;
    return DragInZone(
      enabled: true,
      stage: (files) {
        if (files.length > 1) {
          showHaloToast(context, l10n.toolsOneFileAtATime);
          return;
        }
        widget.onFile(files.single);
      },
      couldNotRead: () => l10n.chatCouldNotReadThat,
      line: () => l10n.toolsDropHere,
      child: widget.child,
    );
  }
}

/// a text field has the keys: its own ctrl and v pastes words there
bool typingInAField() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText ||
      ctx.findAncestorStateOfType<EditableTextState>() != null;
}

/// ctrl and v, or shift and insert
bool isPasteKey(KeyEvent e) {
  if (e is! KeyDownEvent) return false;
  final keys = HardwareKeyboard.instance;
  final k = e.logicalKey;
  if (k == LogicalKeyboardKey.keyV) {
    return keys.isControlPressed && !keys.isAltPressed && !keys.isShiftPressed;
  }
  return k == LogicalKeyboardKey.insert && keys.isShiftPressed;
}

/// a tool's own folder, shred: what it made goes with it
void dropToolsFolder(String path) =>
    unawaited(shredTree(p.dirname(path)).catchError((_) {}));
