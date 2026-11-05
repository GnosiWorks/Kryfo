// SPDX-License-Identifier: GPL-3.0-or-later
// your own devices, as only you see them. names and kinds live here on the
// phone alone: the device lists contacts get carry neither
import 'package:flutter/widgets.dart';

import '../bidi_safe.dart' show unmarked;
import 'link_flow.dart';

export 'linked_switch.dart' show kLinkedDevicesOn;

/// the phone and five more
const int kMaxLinkedDevices = 5;

/// unused this long, a device unlinks itself and wipes
const int kUnusedDays = 30;

/// the last days before that, when the list says so
const int kUnlinkWarnDays = 7;

/// the days left before a device unlinks, from the phone's own time online
/// since its last word ([onlineMs]); null while it is not near
int? unlinksInDaysOf(int onlineMs) {
  const day = Duration.millisecondsPerDay;
  final left = kUnusedDays * day - onlineMs;
  if (left > kUnlinkWarnDays * day) return null;
  return left <= 0 ? 0 : left ~/ day;
}

enum DeviceKind { phone, computer }

/// how recently a device was used, in the steps the list shows. never a
/// time: finer steps would only tell someone holding the phone when the
/// computer was in use
enum DeviceUse { today, week, month, notYet }

DeviceUse deviceUseOf(DateTime? last, DateTime now) {
  if (last == null) return DeviceUse.notYet;
  if (last.year == now.year && last.month == now.month && last.day == now.day) {
    return DeviceUse.today;
  }
  if (now.difference(last) < const Duration(days: 7)) return DeviceUse.week;
  return DeviceUse.month;
}

@immutable
class OwnDevice {
  final String id;
  final String name;
  final DeviceKind kind;
  final bool thisDevice;
  final DateTime? linkedAt;
  final DateTime? lastUsed;
  // days left before it unlinks itself, counted the way the phone counts
  // them (its own online time), null when not near
  final int? unlinksInDays;
  // the device's key number groups, the same as in its own settings
  final List<String> code;

  const OwnDevice({
    required this.id,
    required this.name,
    required this.kind,
    this.thisDevice = false,
    this.linkedAt,
    this.lastUsed,
    this.unlinksInDays,
    this.code = const [],
  });

  bool get isPhone => kind == DeviceKind.phone;

  OwnDevice renamed(String to) => OwnDevice(
    id: id,
    name: to,
    kind: kind,
    thisDevice: thisDevice,
    linkedAt: linkedAt,
    lastUsed: lastUsed,
    unlinksInDays: unlinksInDays,
    code: code,
  );
}

/// what a history copy brings to a new device
enum LinkHistory { all, textOnly, none }

/// where the screens read and change the devices. until linking is wired
/// the phone lists only itself and cannot link
abstract class OwnDevices {
  Future<List<OwnDevice>> load();
  Future<void> rename(String id, String name);
  Future<void> remove(String id);
  Future<void> removeOthers();

  /// whether this build can link a device now
  bool get canLink;

  /// whether the page offers linking at all: never on a linked device,
  /// nor on a computer that is the account's own (phones link in 0.6)
  bool get linksHere;

  /// this is a linked device: its phone links and removes
  bool get linkedDevice;

  /// a link to the device whose code was scanned
  LinkFlow linkFlow(String code, LinkHistory history);

  /// the person opened the page: notices of new devices have done their job
  Future<void> opened();

  /// a linked device can unlink itself here
  bool get canLeave => false;

  /// this linked device unlinks itself: its phone is told, everything Kryfo
  /// keeps here is erased
  Future<void> leaveHere() async {}
}

class ThisPhoneOnly implements OwnDevices {
  final String phoneName;
  final DateTime? since;
  const ThisPhoneOnly({required this.phoneName, this.since});

  @override
  Future<List<OwnDevice>> load() async => [
    OwnDevice(
      id: 'phone',
      name: phoneName,
      kind: DeviceKind.phone,
      thisDevice: true,
      linkedAt: since,
    ),
  ];

  @override
  Future<void> rename(String id, String name) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> removeOthers() async {}

  @override
  bool get canLink => false;

  @override
  bool get linksHere => true;

  @override
  bool get linkedDevice => false;

  @override
  LinkFlow linkFlow(String code, LinkHistory history) =>
      throw StateError('this phone cannot link yet');

  @override
  Future<void> opened() async {}

  @override
  bool get canLeave => false;

  @override
  Future<void> leaveHere() async {}
}

/// the decoy's devices: this phone alone, and a link that looks like any
/// and reaches nobody. nothing of the real account is read or written
class DecoyDevices extends ThisPhoneOnly {
  const DecoyDevices({
    required super.phoneName,
    super.since,
    this.flow,
    this.here = true,
  });

  /// a stand-in for tests
  final LinkFlow Function()? flow;

  /// whether the real app links here: a phone does, a computer that holds
  /// the account does not, and the decoy looks the same
  final bool here;

  @override
  bool get canLink => here;

  @override
  bool get linksHere => here;

  @override
  LinkFlow linkFlow(String code, LinkHistory history) =>
      flow?.call() ?? DecoyLinkFlow(code: code);
}

/// the longest name kept for a device, in characters
const int kDeviceNameMax = 32;

/// a name as typed, trimmed and without direction controls, or null when
/// it cannot be one
String? deviceNameOf(String typed) {
  final t = unmarked(
    typed,
  ).replaceAll(RegExp('[\\u0000-\\u001f\\u007f]'), '').trim();
  if (t.isEmpty || t.characters.length > kDeviceNameMax) return null;
  return t;
}
