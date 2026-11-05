// SPDX-License-Identifier: GPL-3.0-or-later
// the linked-devices switch, on its own so the engine side can read it
// without the devices model

/// linked devices are on in every build. only a build made with
/// --dart-define=KRYFO_LINKED=0 (or false) leaves them out: a way to take
/// the feature out of a dev build, never a release one (linked_on_test)
const bool kLinkedDevicesOn =
    String.fromEnvironment('KRYFO_LINKED', defaultValue: '1') != '0' &&
    String.fromEnvironment('KRYFO_LINKED', defaultValue: '1') != 'false';
