// SPDX-License-Identifier: GPL-3.0-or-later
// true in the linux and windows app (main_desktop.dart sets it before
// anything runs). a plain flag, not Platform: the tests run on linux too
// and test the phone's behaviour there
bool onDesktop = false;

/// a share sheet to hand things to other apps. linux has none: share_plus
/// there turns text into a mailto link for the mail client, which writes it
/// to its drafts and its logs. desktop offers copy and the qr instead
bool get canShareOut => !onDesktop;
