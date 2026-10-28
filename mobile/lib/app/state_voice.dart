// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: which phones play opus voice notes (voice_format.dart)

part of '../main.dart';

extension AppStateVoice on AppState {
  // what an envelope says of the sender's phone: 1:1 and group alike, in
  // the container its chat is in
  Future<void> _takeOpus(String peer, UnwrappedMessage env, HaloDb db) async {
    try {
      await takePeerOpus(
        await db.open(),
        peer,
        carried: env.playsOpus,
        counts: AppState._dataFrame(env) && env.msgUid != null,
        written: env.writtenAt,
      );
    } catch (e) {
      dlog('voice: opus word not taken (${e.runtimeType})');
    }
  }

  /// a note to [peer] may go as opus: their phone has said it plays it
  Future<bool> opusFor(String peer) async {
    try {
      return await peerPlaysOpus(await session.chatDb(peer), peer);
    } catch (e) {
      dlog('voice: opus not read (${e.runtimeType})');
      return false;
    }
  }

  /// a note to group [groupId] may go as opus: every other member's phone
  /// has said it plays it
  Future<bool> opusForGroup(String groupId) async {
    try {
      final me = sessionId;
      final others = [
        for (final m in await session.getGroupMembers(groupId))
          if (m != me) m,
      ];
      return await allPlayOpus(await session.chatDb(groupId), others);
    } catch (e) {
      dlog('voice: group opus not read (${e.runtimeType})');
      return false;
    }
  }
}
