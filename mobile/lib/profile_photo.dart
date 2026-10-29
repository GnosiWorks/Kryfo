// SPDX-License-Identifier: GPL-3.0-or-later
// profile photos. one you set for a contact stays on this phone. your own
// goes, sealed, only to accepted contacts who added you back and whose
// phone understands it ('pp' in their capability list), in a few slices
// over the existing session. a take-back makes their app show your face
// again. everything lives in the container's encrypted database, never in
// a file. the decoy sends nothing and takes nothing in
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'image_strip.dart' show PictureKind, photoToSend, pictureKind;

/// the envelope's word for a photo frame
const kPhotoWire = 'pp';

/// the side every own photo is drawn at
const kPhotoSide = 512;

/// raw bytes per slice: base64 of it, with the frame around it, fills the
/// seal size a media slice fills
const kPhotoSliceBytes = 12 * 1024;

/// at most this many slices, and so this many bytes, for one photo
const kPhotoSlicesMost = 8;
const kPhotoBytesMost = kPhotoSliceBytes * kPhotoSlicesMost;

/// a version written further ahead of this clock is not taken
const kPhotoAheadMost = Duration(days: 1);

/// a photo half in waits this long for its other slices
const kPhotoPartsKeep = Duration(days: 14);

/// a changed photo goes to each contact at a random time in this window,
/// so one change is no burst on the wire
const kPhotoSpreadFrom = Duration(seconds: 30);
const kPhotoSpreadTo = Duration(minutes: 5);

/// how long a failed send waits, step by step
const kPhotoBackoff = [
  Duration(minutes: 2),
  Duration(minutes: 10),
  Duration(minutes: 30),
  Duration(hours: 2),
  Duration(hours: 6),
];

/// the decoy offers the same rows; a photo picked there stays in its own
/// database and is never sent
const decoyOwnPhoto = true;

/// adding a photo needs the phone's encoder
bool photoAddOffered({required bool desktop}) => !desktop;

/// a slice of a photo, or a take-back when [drop]
@immutable
class PhotoFrame {
  const PhotoFrame.slice({
    required this.version,
    required this.index,
    required this.total,
    required Uint8List this.bytes,
  }) : drop = false;
  const PhotoFrame.drop(this.version)
    : drop = true,
      index = 0,
      total = 0,
      bytes = null;

  // when it was set or taken back, ms by the sender's clock
  final int version;
  final bool drop;
  final int index;
  final int total;
  final Uint8List? bytes;

  Map<String, Object> toWire() => drop
      ? {'v': version, 'x': 1}
      : {'v': version, 'i': index, 'n': total, 'd': base64Encode(bytes!)};

  /// null when it is no frame this version would take
  static PhotoFrame? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final v = raw['v'];
    if (v is! int || v <= 0) return null;
    if (raw['x'] == 1) return PhotoFrame.drop(v);
    final i = raw['i'];
    final n = raw['n'];
    final d = raw['d'];
    if (i is! int || n is! int || d is! String) return null;
    if (n < 1 || n > kPhotoSlicesMost || i < 0 || i >= n) return null;
    // base64 of a slice is a third longer, and nothing more
    if (d.length > (kPhotoSliceBytes + 2) ~/ 3 * 4) return null;
    final Uint8List b;
    try {
      b = base64Decode(d);
    } catch (_) {
      return null;
    }
    if (b.isEmpty || b.length > kPhotoSliceBytes) return null;
    return PhotoFrame.slice(version: v, index: i, total: n, bytes: b);
  }
}

/// a photo frame as it goes: no text, no uid, no sender fields. the seal
/// adds 'ss' and 'cp' and fills it to its size
String wrapPhotoFrame(PhotoFrame f, {required int writtenAt}) =>
    'halo/1:${jsonEncode({kPhotoWire: f.toWire(), 'w': writtenAt})}';

/// [photo] in the slices it goes in
List<PhotoFrame> photoSlices(Uint8List photo, int version) {
  final n = (photo.length + kPhotoSliceBytes - 1) ~/ kPhotoSliceBytes;
  if (n < 1 || n > kPhotoSlicesMost) return const [];
  return [
    for (var i = 0; i < n; i++)
      PhotoFrame.slice(
        version: version,
        index: i,
        total: n,
        bytes: Uint8List.sublistView(
          photo,
          i * kPhotoSliceBytes,
          min(photo.length, (i + 1) * kPhotoSliceBytes),
        ),
      ),
  ];
}

/// the slices joined, or null while one is missing
Uint8List? joinPhotoSlices(Map<int, Uint8List> parts, int total) {
  if (parts.length != total) return null;
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < total; i++) {
    final p = parts[i];
    if (p == null) return null;
    out.add(p);
  }
  return out.takeBytes();
}

/// a photo as it may be kept or shown: a picture kind every phone draws,
/// small enough, and clean as the photo lane reads it. null: dropped
Uint8List? photoFit(Uint8List b) {
  if (b.isEmpty || b.length > kPhotoBytesMost) return null;
  final kind = pictureKind(b);
  if (kind != PictureKind.jpeg &&
      kind != PictureKind.png &&
      kind != PictureKind.webp) {
    return null;
  }
  return photoToSend(b);
}

/// a version from [sender] is taken when it is newer than the one held and
/// not written past tomorrow by their clock
bool photoVersionTakes(int version, int held, {int? now}) {
  final clock = now ?? DateTime.now().millisecondsSinceEpoch;
  if (version > clock + kPhotoAheadMost.inMilliseconds) return false;
  return version > held;
}

/// what a photo frame to a contact needs, every one of it
@immutable
class PhotoSendFacts {
  const PhotoSendFacts({
    required this.quiet,
    required this.held,
    required this.dev,
    required this.accepted,
    required this.backPaired,
    required this.blocked,
    required this.peerCan,
  });

  // a decoy session, or a decoy container
  final bool quiet;
  // the everyday identity is held, or being wiped
  final bool held;
  final bool dev;
  final bool accepted;
  final bool backPaired;
  final bool blocked;
  // their phone said 'pp'
  final bool peerCan;
}

/// whether [f]'s contact should hold our photo now
bool photoOwedTo(PhotoSendFacts f) =>
    !f.dev && f.accepted && f.backPaired && !f.blocked && f.peerCan;

/// whether anything may go to them at all now. a take-back still goes to
/// someone blocked or deleted: it only withdraws
bool photoMaySend(PhotoSendFacts f) => !f.quiet && !f.held && !f.dev;

/// what a contact should hold of ours: our version, or 0 for none. null
/// when nothing is owed
int? photoTarget({required int sent, required int mine, required bool owed}) {
  final want = owed ? mine : 0;
  return sent == want ? null : want;
}

/// when a change first goes to a contact
int photoFirstAt(int now, Random r) {
  final from = kPhotoSpreadFrom.inMilliseconds;
  final span = kPhotoSpreadTo.inMilliseconds - from;
  return now + from + r.nextInt(span);
}

/// when a failed send goes again
int photoRetryAt(int now, int tries, Random r) {
  final step = kPhotoBackoff[min(tries, kPhotoBackoff.length - 1)];
  // a tenth either way, so two phones' retries drift apart
  final jitter = step.inMilliseconds ~/ 10;
  return now + step.inMilliseconds - jitter + r.nextInt(2 * jitter + 1);
}

/// the photos this session shows, by kryfo id: yours for a contact over
/// theirs, and your own under your id. a decoy's book holds only its own
final photoBook = PhotoBook();

class PhotoBook extends ChangeNotifier {
  Map<String, Uint8List> _photos = const {};

  Uint8List? of(String id) => _photos[id];
  bool has(String id) => _photos.containsKey(id);
  int get length => _photos.length;

  /// the whole book at once. the same bytes keep their object, so a
  /// picture on screen is not decoded again
  void put(Map<String, Uint8List> next) {
    final kept = <String, Uint8List>{};
    var moved = next.length != _photos.length;
    for (final MapEntry(key: id, value: b) in next.entries) {
      final was = _photos[id];
      if (was != null && (identical(was, b) || listEquals(was, b))) {
        kept[id] = was;
      } else {
        kept[id] = b;
        moved = true;
      }
    }
    _photos = kept;
    if (moved) notifyListeners();
  }

  void clear() => put(const {});
}
