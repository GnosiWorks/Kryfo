// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: which phones play opus voice notes (voice_format.dart)

part of '../main.dart';

extension AppStateVoice on AppState {
  // what a message kept here says of the sender's phone, in the container
  // its chat is in: on an accepted contact's row, or on the member row of
  // the group or room it came in. called past the stranger gate only, and
  // never for the developer's chat
  Future<void> _takeOpus(String peer, UnwrappedMessage env, HaloDb db) async {
    if (isDevId(peer)) return;
    try {
      final d = await db.open();
      final counts = AppState._dataFrame(env) && env.msgUid != null;
      final g = env.groupId;
      if (g != null) {
        await takeMemberOpus(
          d,
          g,
          peer,
          carried: env.playsOpus,
          counts: counts,
          written: env.writtenAt,
        );
      } else {
        await takePeerOpus(
          d,
          peer,
          carried: env.playsOpus,
          counts: counts,
          written: env.writtenAt,
        );
      }
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
      return await groupPlaysOpus(
        await session.chatDb(groupId),
        groupId,
        sessionId,
      );
    } catch (e) {
      dlog('voice: group opus not read (${e.runtimeType})');
      return false;
    }
  }
}
