// SPDX-License-Identifier: GPL-3.0-or-later
// photos, videos and files shared from another app, as home takes them:
// the lock first, then a choice for one photo or video (send it to a chat,
// or check it), then the chat picker, a copy in, and that chat's own send
// preview. nothing goes without its send, and what is not used is let go
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/l10n.dart';
import '../lock_guard.dart';
import '../lock_state.dart';
import '../main.dart' show AppStateFiles, appState, session;
import '../share_files.dart';
import '../share_targets.dart';
import '../share_text.dart';
import '../theme.dart';
import '../tools/tools_bridge.dart';
import '../voice_live.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/media_bubbles.dart'
    show fileGlyph, fileTooBigLine, humanFileSize;
import '../file_kind.dart' show kindOfName;
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/tool_parts.dart' show ToolWideButton;
import 'chat_screen.dart' show landFilesInOpenChat;
import 'dev_about_sheet.dart' show devForwardTarget;
import 'forward_sheet.dart';

enum ShareWay { chat, check }

/// how long a copy in may go without moving before it is stopped
@visibleForTesting
Duration copyIdleLimit = const Duration(seconds: 45);

/// how long android is given to say what was shared
@visibleForTesting
Duration sharePeekLimit = const Duration(seconds: 10);

class ShareFiles {
  ShareFiles({
    required this.onCheck,
    LockGuard? guard,
    String Function()? where,
  }) : gate = ShareGate(guard: guard ?? lockGuard, where: where ?? _where),
       _whereNow = where ?? _where;

  /// one photo or video to the photo checker
  final void Function(PickedFile f) onCheck;
  final ShareGate gate;
  final String Function() _whereNow;

  static String _where() =>
      shareSessionTag(decoy: lockState.inDecoy, vault: lockState.inVault);

  // what this process is done with, as for shared words
  static final _done = <String>{};

  bool _busy = false;
  BuildContext? _sheet;
  bool _newer = false;
  final _gone = Completer<void>();

  ToolsBridge get _bridge => ToolsBridge.instance;

  Timer? _peekTimer;

  void dispose() {
    _peekTimer?.cancel();
    if (!_gone.isCompleted) _gone.complete();
  }

  Future<T> _whileHere<T>(Future<T> f, T orElse) =>
      Future.any([f, _gone.future.then((_) => orElse)]);

  void _popSheet() {
    final s = _sheet;
    if (s != null && s.mounted && (ModalRoute.of(s)?.isCurrent ?? false)) {
      Navigator.of(s).pop();
    }
  }

  void _onSheet(BuildContext c) {
    _sheet = c;
    if (_newer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _popSheet());
    }
  }

  /// a share came in: a sheet up for an older one gives way
  void arrived(BuildContext context, bool Function() alive) {
    if (_busy) {
      _newer = true;
      _popSheet();
    }
    take(context, alive);
  }

  Future<void> take(BuildContext context, bool Function() alive) async {
    if (_busy) return;
    _busy = true;
    // a lock that went up and came down while a sheet was up is gone by the
    // time the sheet answers: seen here, it takes the sheet and the share
    var lockedSince = false;
    void onLock() {
      if (!lockState.locked) return;
      lockedSince = true;
      _popSheet();
    }

    lockState.addListener(onLock);
    try {
      while (alive()) {
        final s = await _peek();
        if (s == null) return;
        if (_done.contains(s.id)) {
          await _bridge.dropSharedFiles(s.id);
          return;
        }
        final clear = await _whileHere(gate.clearSeen(s.seenIn), false);
        if (!alive()) return;
        if (!clear) {
          await _finish(s.id);
          continue;
        }
        await _whileHere(voiceNotesDone(), null);
        await WidgetsBinding.instance.endOfFrame;
        if (!alive() || !context.mounted) return;
        _newer = false;
        final now = await _peek();
        if (now?.id != s.id) continue;
        final where = _whereNow();
        final container = session.container.id;
        lockedSince = lockState.locked;
        await _bridge.sawSharedFiles(s.id, where);
        if (!context.mounted) return;
        // a lock, or an unlock into another session, while a sheet was up
        // ends it there
        bool still() =>
            context.mounted &&
            !lockedSince &&
            !lockState.locked &&
            _whereNow() == where &&
            session.container.id == container;
        // a chat picked in the share menu goes straight there, when it
        // still may: no check offered, no picker
        final menu = await shareTargets.chatFor(s.chat);
        if (!context.mounted) return;
        // one photo or video may be checked instead; files only go
        final one = s.items.length == 1 ? s.items.single : null;
        final kind = one == null ? null : kindOfPicked(one);
        var way = ShareWay.chat;
        if (menu == null && one != null && kind != SharedKind.file) {
          final w = await _whileHere(
            askShareWay(
              context,
              video: kind == SharedKind.video,
              onSheet: _onSheet,
            ),
            null,
          );
          _sheet = null;
          if (!alive()) return;
          if (_newer) continue;
          if (w == null || !still()) {
            await _finish(s.id);
            continue;
          }
          way = w;
        }
        if (way == ShareWay.check) {
          await _finish(s.id);
          onCheck(one!);
          continue;
        }
        if (!context.mounted) return;
        final id =
            menu ??
            await _whileHere(
              pickWordsChat(
                context,
                title: l10n.shareChooseChat,
                empty: appState.contacts.isEmpty
                    ? l10n.shareNoChats
                    : l10n.shareNoOne,
                // a screenshot for a bug report goes to him
                dev: devForwardTarget,
                onSheet: _onSheet,
              ),
              null,
            );
        _sheet = null;
        if (!alive()) return;
        if (_newer) continue;
        if (id == null || !still()) {
          await _finish(s.id);
          continue;
        }
        if (!context.mounted) return;
        final copies = await _copyAll(context, s.items, id);
        // copied in: the uris are let go
        await _finish(s.id);
        if (copies.isEmpty) continue;
        if (!still()) {
          await shredCopies(copies);
          continue;
        }
        if (!context.mounted) return;
        await landFiles(context, id, container, copies);
      }
    } finally {
      lockState.removeListener(onLock);
      _busy = false;
    }
  }

  // a provider that never answers ends the look, not every share after it
  // its timer goes with the home, so none outlives it
  Future<SharedFiles?> _peek() {
    final late = Completer<SharedFiles?>();
    _peekTimer?.cancel();
    _peekTimer = Timer(sharePeekLimit, () {
      if (!late.isCompleted) late.complete(null);
    });
    return Future.any([
      _bridge.peekSharedFiles(),
      late.future,
      _gone.future.then((_) => null),
    ]).whenComplete(() => _peekTimer?.cancel());
  }

  Future<void> _finish(String id) async {
    _done.add(id);
    await _bridge.dropSharedFiles(id);
  }

  // each item copied in, the chat's limit first. one over it is said and
  // left out; a lock or a cancel on the way keeps none
  Future<List<SharedCopy>> _copyAll(
    BuildContext context,
    List<PickedFile> items,
    String id,
  ) async {
    final most = await appState.fileLimitFor(id);
    if (!context.mounted) return const [];
    final sorted = sortBySize(items, most);
    final over = sorted.over;
    if (over != null) {
      showHaloToast(
        context,
        kindOfPicked(over) == SharedKind.photo
            ? l10n.sharePhotoTooBig(
                humanFileSize(over.size),
                humanFileSize(kSharedPhotoMost),
              )
            : fileTooBigLine(over.size, most),
      );
    }
    if (sorted.fit.isEmpty) return const [];
    final out = <SharedCopy>[];
    // a cancel, a lock or a copy that stopped moving ends the wait at once,
    // whatever the provider still does
    final stopped = Completer<void>();
    String? said;
    final total = sorted.fit.fold<int>(
      0,
      (n, f) => n + (f.size > 0 ? f.size : 0),
    );
    var before = 0;
    final shown = ValueNotifier<double?>(null);
    Timer? idle;
    void stop() {
      if (stopped.isCompleted) return;
      stopped.complete();
      _bridge.cancelCopy();
    }

    // stopped because nothing moved: said, unlike a cancel or a lock
    var stuck = false;
    void moved() {
      idle?.cancel();
      idle = Timer(copyIdleLimit, () {
        stuck = !stopped.isCompleted;
        stop();
      });
    }

    final sub = _bridge.progress.listen((c) {
      moved();
      if (total > 0) shown.value = ((before + c.done) / total).clamp(0.0, 1.0);
    });

    void onLock() {
      if (lockState.locked) stop();
    }

    lockState.addListener(onLock);
    BuildContext? sheet;
    var asked = false;
    // a quick copy shows nothing; a slow one a bar that can be stopped
    final slow = Timer(const Duration(milliseconds: 400), () {
      if (!context.mounted || stopped.isCompleted) return;
      asked = true;
      showHaloSheet<void>(
        context,
        dismissible: false,
        builder: (c) {
          sheet = c;
          return _CopySheet(progress: shown, onStop: stop);
        },
      );
    });
    try {
      for (final f in sorted.fit) {
        if (stopped.isCompleted) break;
        moved();
        final copy = _bridge.copyIn(f.uri, most: copyMostOf(f, most));
        final String path;
        try {
          final got = await Future.any<String?>([
            copy,
            stopped.future.then((_) => null),
          ]);
          if (got == null) {
            // one that ends after all the wait is let go of on its own
            copy.then(
              (late) => shredCopies([SharedCopy(late, name: '')]),
              onError: (_) {},
            );
            break;
          }
          path = got;
        } on ToolsFailure catch (e) {
          if (e.code == 'cancelled') {
            stop();
            break;
          }
          said ??= switch (e.code) {
            'big' => l10n.shareFileOverLimit(
              humanFileSize(copyMostOf(f, most)),
            ),
            'full' => l10n.cleanFreeSomeSpaceAnd,
            _ => l10n.chatCouldNotReadThat,
          };
          before += f.size > 0 ? f.size : 0;
          continue;
        }
        out.add(
          SharedCopy(path, name: f.name ?? p.basename(path), mime: f.mime),
        );
        before += f.size > 0 ? f.size : 0;
      }
    } finally {
      slow.cancel();
      idle?.cancel();
      await sub.cancel();
      lockState.removeListener(onLock);
      // stopped: the copies go before anything waits on a frame, which
      // never comes while the app is away under the lock
      if (stopped.isCompleted) {
        await shredCopies(List.of(out));
        out.clear();
      }
      // asked for but not built yet: it is, a frame on
      if (asked && sheet == null) await WidgetsBinding.instance.endOfFrame;
      final s = sheet;
      final r = s != null && s.mounted ? ModalRoute.of(s) : null;
      // its own route, wherever it sits now: never whatever is on top
      if (r != null && r.isActive) r.navigator?.removeRoute(r);
    }
    if (stopped.isCompleted) {
      if (stuck && context.mounted) {
        showHaloToast(context, l10n.chatCouldNotReadThat);
      }
      return const [];
    }
    final line = said;
    if (line != null && context.mounted) showHaloToast(context, line);
    return out;
  }
}

/// [copies] into [id]'s chat in [container]: the chat on top takes them in
/// place, else it opens over whatever is open. its send preview comes next
Future<void> landFiles(
  BuildContext context,
  String id,
  String container,
  List<SharedCopy> copies,
) async {
  await voiceNotesDone();
  bool still() =>
      context.mounted && !lockState.locked && session.container.id == container;
  if (!still()) {
    await shredCopies(copies);
    return;
  }
  final key = '$container|$id';
  SharedInbox.handOff(key, copies);
  if (landFilesInOpenChat(id)) return;
  final route = await wordsRoute(id, '');
  if (route == null || !still()) {
    await shredCopies(SharedInbox.take(key));
    return;
  }
  if (!context.mounted) return;
  unawaited(Navigator.of(context).push(route));
}

/// the files of a share, named, asked about before any of them goes
Future<bool> askSendSharedFiles(
  BuildContext context,
  List<SharedCopy> files,
) async =>
    await showHaloSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: 18),
              Text(
                l10n.shareSendFiles(files.length),
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 10),
              for (final f in files) _FileLine(f),
              const SizedBox(height: 16),
              ToolWideButton(
                label: l10n.chatSendIt,
                filled: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 10),
              ToolWideButton(
                label: l10n.commonCancel,
                filled: false,
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    ) ==
    true;

class _FileLine extends StatelessWidget {
  const _FileLine(this.file);
  final SharedCopy file;

  @override
  Widget build(BuildContext context) {
    int size;
    try {
      size = File(file.path).lengthSync();
    } on FileSystemException {
      size = -1;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            fileGlyph(kindOfName(file.name)),
            size: 20,
            color: HaloColors.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.sans(size: 14, color: HaloColors.text),
            ),
          ),
          if (size >= 0) ...[
            const SizedBox(width: 10),
            Text(
              humanFileSize(size),
              style: HaloType.sans(size: 12.5, color: HaloColors.warm),
            ),
          ],
        ],
      ),
    );
  }
}

/// what to do with one shared photo or video. null when let go
Future<ShareWay?> askShareWay(
  BuildContext context, {
  required bool video,
  void Function(BuildContext sheet)? onSheet,
}) => showHaloSheet<ShareWay>(
  context,
  builder: (ctx) {
    onSheet?.call(ctx);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
              child: Text(
                video ? l10n.photoKnowsVideo : l10n.photoKnowsPhoto,
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
            ),
            _WayRow(
              icon: Icons.send_outlined,
              title: l10n.toolsSendToAChat,
              line: l10n.shareSendCleanLine,
              onTap: () => Navigator.pop(ctx, ShareWay.chat),
            ),
            _WayRow(
              icon: Icons.manage_search_outlined,
              title: video ? l10n.shareCheckVideo : l10n.shareCheckPhoto,
              line: l10n.shareCheckLine,
              onTap: () => Navigator.pop(ctx, ShareWay.check),
            ),
          ],
        ),
      ),
    );
  },
);

class _WayRow extends StatelessWidget {
  const _WayRow({
    required this.icon,
    required this.title,
    required this.line,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: PressScale(
      scale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HaloColors.surface3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: HaloColors.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: HaloType.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: HaloType.sans(size: 12.5, color: HaloColors.warm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// a slow copy in: how far it is, and a way to stop it
class _CopySheet extends StatelessWidget {
  const _CopySheet({required this.progress, required this.onStop});

  final ValueNotifier<double?> progress;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 18),
            Text(
              l10n.photoKnowsReadingTheFile,
              style: HaloType.sans(
                size: 15,
                weight: FontWeight.w500,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: v == null && !still
                      ? LinearProgressIndicator(
                          backgroundColor: HaloColors.surface3,
                          color: HaloColors.amber,
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: v ?? 0),
                          duration: still
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          builder: (_, x, _) => LinearProgressIndicator(
                            value: x,
                            backgroundColor: HaloColors.surface3,
                            color: HaloColors.amber,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ToolWideButton(
              label: l10n.commonCancel,
              filled: false,
              onTap: onStop,
            ),
          ],
        ),
      ),
    );
  }
}
