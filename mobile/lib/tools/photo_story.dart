// SPDX-License-Identifier: GPL-3.0-or-later

import '../meta/meta_reader.dart';
import 'geo.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/numbers.dart';

enum StoryRowKind { place, hidden, device, time, more }

class StoryRow {
  final StoryRowKind kind;
  final String title;
  final String? sub;
  final String? mono;
  const StoryRow(this.kind, this.title, {this.sub, this.mono});
}

class PhotoStory {
  final String head;
  final String tail;
  final List<StoryRow> rows;
  final List<String> everything;
  final bool canClean;
  const PhotoStory({
    required this.head,
    required this.tail,
    required this.rows,
    required this.everything,
    required this.canClean,
  });
}

String _metres(double m) {
  if (m >= 1000) return l10n.photoStoryKm(whole((m / 1000).round()));
  if (m >= 10) return l10n.photoStory1Metre((m / 5).round() * 5);
  final r = m.round();
  return l10n.photoStory1Metre(r <= 1 ? 1 : r);
}

String placeLine(GpsFix fix, GeoWorld? world, GeoPlaces? places) {
  final near = places?.nearest(fix.lat, fix.lon);
  final country =
      world?.at(fix.lat, fix.lon)?.country.name ??
      (near == null ? null : world?.nameOf(near.place.country));
  if (near == null) return country ?? l10n.photoStoryFarFromAnyTown;
  final where = country == null || country == near.place.name
      ? near.place.name
      : '${near.place.name}, $country';
  if (near.km <= 25) return l10n.photoStoryNear(where);
  return l10n.photoStoryAboutKmFrom(whole((near.km / 5).round() * 5), where);
}

String deviceName(String? make, String? model) {
  var mk = (make ?? '').trim(), md = (model ?? '').trim();
  if (mk.isNotEmpty && md.toLowerCase().startsWith(mk.toLowerCase())) mk = '';
  if (mk.isNotEmpty && mk == mk.toLowerCase()) {
    mk = mk[0].toUpperCase() + mk.substring(1);
  }
  return [mk, md].where((x) => x.isNotEmpty).join(' ');
}

DateTime? _taken(String? raw) {
  if (raw == null) return null;
  final m = RegExp(
    r'^(\d{4})[:\-](\d{2})[:\-](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(raw);
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.tryParse(m.group(i) ?? '0') ?? 0];
  if (v[1] < 1 ||
      v[1] > 12 ||
      v[2] < 1 ||
      v[2] > 31 ||
      v[3] > 23 ||
      v[4] > 59) {
    return null;
  }
  return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
}

String _shutter(double s) {
  if (s >= 1) {
    return l10n.photoStoryS(decimal(s, s == s.roundToDouble() ? 0 : 1));
  }
  return l10n.photoStory1S(whole((1 / s).round()));
}

PhotoStory storyOf(MetaReport r, {GeoWorld? world, GeoPlaces? places}) {
  if (r.kind == MetaKind.unknown) {
    return PhotoStory(
      head: l10n.photoStoryNotAKindKryfo,
      tail: l10n.photoStorySoItWillNot,
      rows: [],
      everything: [],
      canClean: false,
    );
  }
  if (r.status == MetaStatus.unreadable) {
    return PhotoStory(
      head: l10n.photoStoryThisFileIsDamaged,
      tail: l10n.photoStoryKryfoCouldNotRead,
      rows: [],
      everything: [],
      canClean: false,
    );
  }
  final video = r.kind == MetaKind.mp4;
  final rows = <StoryRow>[];
  final all = <String>[];

  final fix = r.gps;
  if (fix != null) {
    rows.add(
      StoryRow(
        StoryRowKind.place,
        placeLine(fix, world, places),
        sub: video
            ? l10n.photoStoryWhereItWasRecorded
            : l10n.photoStoryWhereItWasTaken,
      ),
    );
    all.add(l10n.photoStoryLocation(coordsLine(fix.lat, fix.lon)));
    if (fix.altitude != null) {
      all.add(l10n.photoStoryHeightAboveTheSea(whole(fix.altitude!.round())));
    }
  } else if (r.gpsBlank) {
    rows.add(
      StoryRow(
        StoryRowKind.hidden,
        l10n.photoStoryLocationHiddenByAndroid,
        sub: l10n.photoStoryAndroidBlanksItWhen,
      ),
    );
    all.add(l10n.photoStoryLocationBlankedByAndroid);
  }

  final phone = deviceName(r.make, r.model);
  final optics = [
    if (r.fNumber != null) l10n.photoStoryF(decimal(r.fNumber!, 1)),
    if (r.exposure != null) _shutter(r.exposure!),
  ].join(' · ');
  if (phone.isNotEmpty) {
    rows.add(
      StoryRow(
        StoryRowKind.device,
        phone,
        sub: optics.isEmpty ? l10n.photoStoryWhatTookIt : null,
        mono: optics.isEmpty ? null : optics,
      ),
    );
    all.add(l10n.photoStoryPhoneOrCamera(phone));
  }

  final taken = _taken(r.taken) ?? r.created?.toLocal();
  if (taken != null) {
    rows.add(
      StoryRow(
        StoryRowKind.time,
        longDateTime(taken),
        sub: r.taken == null
            ? l10n.photoStoryWhenItWasRecorded
            : r.offset != null
            ? l10n.photoStoryToTheSecondWith
            : l10n.photoStoryToTheSecond,
      ),
    );
    all.add(l10n.photoStoryTime(mediumDateTime(taken)));
  }

  final named = <String>[];
  void note(bool on, String short, String long) {
    if (!on) return;
    named.add(short);
    all.add(long);
  }

  note(r.lens != null, l10n.photoStoryLens, l10n.photoStoryLens2('${r.lens}'));
  note(
    r.software != null,
    l10n.photoStorySoftware,
    l10n.photoStorySoftware2('${r.software}'),
  );
  note(
    r.serial != null,
    l10n.photoStorySerialNumber,
    l10n.photoStorySerialNumber2('${r.serial}'),
  );
  note(
    r.owner != null || r.copyright != null,
    l10n.photoStoryOwnerName,
    l10n.photoStoryOwner('${r.owner ?? r.copyright}'),
  );
  note(
    r.thumbnailBytes > 0,
    l10n.photoStoryHiddenThumbnail,
    l10n.photoStoryASmallCopyOf,
  );
  note(r.makerNote, l10n.photoStoryMakerNotes, l10n.photoStoryMakerNotesABlock);
  note(
    r.xmp,
    l10n.photoStoryEditingHistory,
    l10n.photoStoryXmpEditingHistoryAnd,
  );
  note(r.iptc, l10n.photoStoryCaptions, l10n.photoStoryIptcCaptionsAndCredits);
  note(r.comment, l10n.photoStoryComment, l10n.photoStoryAWrittenComment);
  note(
    r.credentials,
    l10n.photoStoryContentCredentials,
    l10n.photoStoryContentCredentials,
  );
  note(
    r.secondImage,
    l10n.photoStorySecondPicture,
    l10n.photoStoryASecondPictureInside,
  );
  note(
    r.embeddedVideo,
    l10n.photoStoryMotionVideo,
    l10n.photoStoryAShortVideoInside,
  );
  note(r.savedTime, l10n.photoStorySaveTime, l10n.photoStoryTheTimeItWas);
  note(
    r.stamps && r.created == null,
    l10n.photoStoryTimeStamps,
    l10n.photoStoryCreationTimeStamps,
  );
  note(
    r.trailingBytes > 0,
    l10n.photoStoryDataAfterThePicture,
    l10n.photoStoryDataAfterTheEnd(r.trailingBytes),
  );
  for (final k in r.textKeys) {
    all.add(l10n.photoStoryTextField(k));
  }
  for (final k in r.videoTags) {
    all.add(l10n.photoStoryVideoTag(k));
  }
  for (final k in r.extra) {
    all.add(l10n.photoStoryAlso(k));
  }
  if (r.otherExifTags > 0) {
    all.add(l10n.photoStoryCameraSettingsFlashFocus(r.otherExifTags));
  }
  final more =
      named.length +
      r.otherExifTags +
      r.textKeys.length +
      r.videoTags.length +
      r.extra.length;
  if (more > 0) {
    rows.add(
      StoryRow(
        StoryRowKind.more,
        l10n.photoStory1MoreField(more),
        sub: named.isEmpty
            ? l10n.photoStoryCameraSettings
            : named.take(4).join(', '),
      ),
    );
  }

  String head, tail;
  if (fix != null) {
    final acc = r.accuracyM;
    if (acc != null) {
      head = l10n.photoStoryAccurateToAbout(_metres(acc));
      tail = acc <= 30
          ? l10n.photoStoryEnoughToFindThe
          : acc <= 300
          ? l10n.photoStoryEnoughToFindTheStreet
          : l10n.photoStoryEnoughToFindTheArea;
    } else {
      head = l10n.photoStoryItKnowsWhereYou;
      tail = l10n.photoStoryDownToTheBuilding;
    }
  } else if (r.gpsBlank) {
    head = l10n.photoStoryAndroidHidTheLocation;
    tail = l10n.photoStoryTheOriginalMayStill;
  } else if (rows.isNotEmpty) {
    head = l10n.photoStoryNoLocationInThis;
    tail = l10n.photoStoryItStillSaysPlenty;
  } else {
    head = l10n.photoStoryThisOneKnowsNothing;
    tail = l10n.photoStoryNothingToRemove;
  }

  return PhotoStory(
    head: head,
    tail: tail,
    rows: rows,
    everything: all,
    canClean: rows.isNotEmpty,
  );
}
