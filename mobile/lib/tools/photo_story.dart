// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:intl/intl.dart';

import '../meta/meta_reader.dart';
import 'geo.dart';

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
  if (m >= 1000) return '${(m / 1000).round()} km';
  if (m >= 10) return '${(m / 5).round() * 5} metres';
  final r = m.round();
  return r <= 1 ? '1 metre' : '$r metres';
}

String placeLine(GpsFix fix, GeoWorld? world, GeoPlaces? places) {
  final near = places?.nearest(fix.lat, fix.lon);
  final country =
      world?.at(fix.lat, fix.lon)?.country.name ??
      (near == null ? null : world?.nameOf(near.place.country));
  if (near == null) return country ?? 'Far from any town';
  final where = country == null || country == near.place.name
      ? near.place.name
      : '${near.place.name}, $country';
  if (near.km <= 25) return 'Near $where';
  return 'About ${(near.km / 5).round() * 5} km from $where';
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
  if (s >= 1) return '${s.toStringAsFixed(s == s.roundToDouble() ? 0 : 1)} s';
  return '1/${(1 / s).round()} s';
}

PhotoStory storyOf(MetaReport r, {GeoWorld? world, GeoPlaces? places}) {
  if (r.kind == MetaKind.unknown) {
    return const PhotoStory(
      head: 'Not a kind Kryfo can read.',
      tail: 'So it will not guess.',
      rows: [],
      everything: [],
      canClean: false,
    );
  }
  if (r.status == MetaStatus.unreadable) {
    return const PhotoStory(
      head: 'This file is damaged or cut short.',
      tail: 'Kryfo could not read it to the end.',
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
        sub: video ? 'Where it was recorded' : 'Where it was taken',
      ),
    );
    all.add('Location: ${coordsLine(fix.lat, fix.lon)}');
    if (fix.altitude != null) {
      all.add('Height above the sea: ${fix.altitude!.round()} m');
    }
  } else if (r.gpsBlank) {
    rows.add(
      const StoryRow(
        StoryRowKind.hidden,
        'Location hidden by Android',
        sub:
            'Android blanks it when a photo is picked this way. Sharing it to Kryfo from your gallery often keeps it. The one in your gallery may still have it.',
      ),
    );
    all.add('Location: blanked by Android before Kryfo saw it');
  }

  final phone = deviceName(r.make, r.model);
  final optics = [
    if (r.fNumber != null) 'f/${r.fNumber!.toStringAsFixed(1)}',
    if (r.exposure != null) _shutter(r.exposure!),
  ].join(' · ');
  if (phone.isNotEmpty) {
    rows.add(
      StoryRow(
        StoryRowKind.device,
        phone,
        sub: optics.isEmpty ? 'What took it' : null,
        mono: optics.isEmpty ? null : optics,
      ),
    );
    all.add('Phone or camera: $phone');
  }

  final taken = _taken(r.taken) ?? r.created?.toLocal();
  if (taken != null) {
    rows.add(
      StoryRow(
        StoryRowKind.time,
        DateFormat('EEEE d MMMM y, HH:mm').format(taken),
        sub: r.taken == null
            ? 'When it was recorded'
            : r.offset != null
            ? 'To the second, with the time zone'
            : 'To the second',
      ),
    );
    all.add('Time: ${DateFormat('d MMM y, HH:mm:ss').format(taken)}');
  }

  final named = <String>[];
  void note(bool on, String short, String long) {
    if (!on) return;
    named.add(short);
    all.add(long);
  }

  note(r.lens != null, 'Lens', 'Lens: ${r.lens}');
  note(r.software != null, 'Software', 'Software: ${r.software}');
  note(r.serial != null, 'Serial number', 'Serial number: ${r.serial}');
  note(
    r.owner != null || r.copyright != null,
    'Owner name',
    'Owner: ${r.owner ?? r.copyright}',
  );
  note(
    r.thumbnailBytes > 0,
    'Hidden thumbnail',
    'A small copy of the picture inside the file. It can show what a crop removed',
  );
  note(
    r.makerNote,
    'Maker notes',
    'Maker notes: a block only the maker can read',
  );
  note(r.xmp, 'Editing history', 'XMP: editing history and tags');
  note(r.iptc, 'Captions', 'IPTC: captions and credits');
  note(r.comment, 'Comment', 'A written comment');
  note(r.credentials, 'Content credentials', 'Content credentials');
  note(r.secondImage, 'Second picture', 'A second picture inside the file');
  note(r.embeddedVideo, 'Motion video', 'A short video inside the file');
  note(r.savedTime, 'Save time', 'The time it was last saved');
  note(r.stamps && r.created == null, 'Time stamps', 'Creation time stamps');
  note(
    r.trailingBytes > 0,
    'Data after the picture',
    'Data after the end of the picture: ${r.trailingBytes} bytes',
  );
  for (final k in r.textKeys) {
    all.add('Text field: $k');
  }
  for (final k in r.videoTags) {
    all.add('Video tag: $k');
  }
  for (final k in r.extra) {
    all.add('Also: $k');
  }
  if (r.otherExifTags > 0) {
    all.add('${r.otherExifTags} camera settings (flash, focus, exposure)');
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
        more == 1 ? '1 more field' : '$more more fields',
        sub: named.isEmpty ? 'Camera settings' : named.take(4).join(', '),
      ),
    );
  }

  String head, tail;
  if (fix != null) {
    final acc = r.accuracyM;
    if (acc != null) {
      head = 'Accurate to about ${_metres(acc)}.';
      tail = acc <= 30
          ? 'Enough to find the door.'
          : acc <= 300
          ? 'Enough to find the street.'
          : 'Enough to find the area.';
    } else {
      head = 'It knows where you were.';
      tail = 'Down to the building.';
    }
  } else if (r.gpsBlank) {
    head = 'Android hid the location.';
    tail = 'The original may still carry it.';
  } else if (rows.isNotEmpty) {
    head = 'No location in this one.';
    tail = 'It still says plenty.';
  } else {
    head = 'This one knows nothing.';
    tail = 'Nothing to remove.';
  }

  return PhotoStory(
    head: head,
    tail: tail,
    rows: rows,
    everything: all,
    canClean: rows.isNotEmpty,
  );
}
