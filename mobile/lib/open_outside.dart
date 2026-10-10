// SPDX-License-Identifier: GPL-3.0-or-later
// a link handed to another app. on android 11 and later canLaunchUrl says no
// for every scheme the manifest does not list, so it is never asked: the
// launch is tried and its answer kept
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dlog.dart';

Future<bool> _launch(Uri u) =>
    launchUrl(u, mode: LaunchMode.externalApplication);

Future<bool> Function(Uri u) _open = _launch;

@visibleForTesting
set openOutsideForTest(Future<bool> Function(Uri u)? f) => _open = f ?? _launch;

/// whether an app on this phone took [u]
Future<bool> openOutside(Uri u) async {
  try {
    return await _open(u);
  } catch (e) {
    dlog('open outside: ${e.runtimeType}');
    return false;
  }
}
