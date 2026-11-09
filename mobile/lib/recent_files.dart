// SPDX-License-Identifier: GPL-3.0-or-later
// the files the sending sheet's recent tab offers: what came or went lately
// in the chats of the same container as the chat it sends to, so a hidden
// chat's files are offered only to hidden chats. nothing a chat that
// blocks keeps, nothing protected of theirs, no voice note, no timed one
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'chat_shots.dart' show shotsKeeps;
import 'dlog.dart';
import 'lock_guard.dart' show LockDropped;
import 'lock_state.dart';
import 'picked.dart';
import 'file_kind.dart' show knownInstaller;
import 'main.dart' show HaloDb, session;
import 'voice_format.dart' show isVoiceName;
import 'widgets/send_sheet.dart';

/// [homeOf]: the container the session reads a row's chat from. a row this
/// database still holds for a chat that lives elsewhere now (a hide cut
/// short) is not offered
Future<List<SendPick>> recentFilesIn(
  HaloDb db, {
  int most = 30,
  HaloDb Function(Map<String, Object?> row)? homeOf,
}) async {
  final rows = await db.recentFiles(limit: most);
  final blocks = <String, bool>{};
  Future<bool> keeps(Map<String, Object?> r) async {
    if (r['direction'] == 'out') return false;
    if ((r['secure'] as int? ?? 0) == 1) return true;
    final group = r['group_id'] as String?;
    final peer = r['peer_id'] as String? ?? '';
    final key = group ?? peer;
    Future<bool> groupKeeps(String g) async {
      // a room keeps everything of the others', ended or not
      final row = await db.getGroup(g);
      if (row != null && row['room_pub'] != null) return true;
      return (await db.groupShotsOf(g)).blocking;
    }

    final blocking = blocks[key] ??= group != null && group.isNotEmpty
        ? await groupKeeps(group)
        : (await db.shotsOf(peer)).blocking;
    return shotsKeeps(blocking: blocking, mine: false);
  }

  final out = <SendPick>[];
  final seen = <String>{};
  for (final r in rows) {
    final path = r['file_path'] as String;
    final name = r['file_name'] as String;
    if (!seen.add(path) || isVoiceName(name)) continue;
    if (homeOf != null && !identical(homeOf(r), db)) continue;
    if (knownInstaller(path, name)) continue;
    if (await keeps(r)) continue;
    final int size;
    try {
      size = await File(path).length();
    } catch (_) {
      // not here: still coming, or gone
      continue;
    }
    if (size <= 0) continue;
    out.add(
      SendPick(
        path: path,
        name: name,
        size: size,
        from: SendTab.recent,
        when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
      ),
    );
    if (out.length >= most) break;
  }
  return out;
}

/// the container [session] reads [row]'s chat from
HaloDb sessionHomeOf(Map<String, Object?> row) {
  final group = row['group_id'] as String?;
  return group != null && group.isNotEmpty
      ? session.groupDb(group)
      : session.peerDb(row['peer_id'] as String? ?? '');
}

/// the phone's photo picker, its picks ready for the sheet. each pick's
/// copy goes when the sheet lets it go
Future<List<SendPick>> galleryPicksForSheet() async {
  final List<XFile> got;
  try {
    got = await lockState.hold(pickGallery);
  } on LockDropped {
    return const [];
  } catch (e) {
    dlog('send sheet: gallery (${e.runtimeType})');
    return const [];
  }
  return [
    for (final x in got)
      SendPick(
        path: x.path,
        name: x.name,
        size: await _sizeOf(x.path),
        from: SendTab.gallery,
        media: true,
        video: isVideoPick(x),
        source: x,
        release: () => shredPickedImages([x]),
      ),
  ];
}

/// the phone's file browser, several at once
Future<List<SendPick>> filePicksForSheet() async {
  final List<PlatformFile> got;
  try {
    got = await lockState.hold(() => FilePicker.pickFiles(type: FileType.any));
  } on LockDropped {
    return const [];
  } catch (e) {
    dlog('send sheet: files (${e.runtimeType})');
    return const [];
  }
  return [
    for (final f in got)
      if (f.path != null)
        SendPick(
          path: f.path!,
          name: f.name,
          size: await _sizeOf(f.path!),
          from: SendTab.files,
          when: DateTime.now(),
          release: () => shredPickedOne(f),
        ),
  ];
}

Future<int> _sizeOf(String path) async {
  try {
    return await File(path).length();
  } catch (_) {
    return 0;
  }
}
