// SPDX-License-Identifier: GPL-3.0-or-later
// the linked-devices switch, on its own so the engine side can read it
// without the devices model

/// the settings row, its screens and every linked-devices call stay out
/// of builds until linking is wired end to end: on only in a build made
/// with --dart-define=KRYFO_LINKED=1 (or true)
const bool kLinkedDevicesOn =
    String.fromEnvironment('KRYFO_LINKED') == '1' ||
    bool.fromEnvironment('KRYFO_LINKED');
