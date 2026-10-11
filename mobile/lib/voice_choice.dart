// SPDX-License-Identifier: GPL-3.0-or-later
// whether a chat's voice notes go out disguised

/// a chat's own choice wins. without one a burner room starts disguised and
/// any other chat takes the identity's default, the one switch there was
/// before each chat had its own
bool chatDisguise({bool? own, bool burner = false, bool fallback = false}) =>
    own ?? (burner || fallback);
