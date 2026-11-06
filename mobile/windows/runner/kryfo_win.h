// SPDX-License-Identifier: GPL-3.0-or-later
// what kryfo.exe does before flutter starts: process hardening, its own
// folder made private and locked, and the native libraries loaded by full
// path from the app's folder
#ifndef RUNNER_KRYFO_WIN_H_
#define RUNNER_KRYFO_WIN_H_

#include <windows.h>

#include <string>

namespace kryfo {

// error mode, dll search order, mitigations, crash reporting off, and a
// process dacl that keeps other processes of the user out of its memory.
// first thing in wWinMain, before any plugin loads
void Harden();

// the folder's state for the dart side, also put in KRYFO_FOLDER:
// ok, link, owner, acl, locked, nofolder
enum class Folder { kOk, kLink, kOwner, kAcl, kLocked, kNoFolder };

// %LOCALAPPDATA%\Kryfo: made if missing, refused when it is a link or
// someone else's, then a protected dacl (the user and SYSTEM), not indexed,
// and <root>\lock held for the life of the process. a lock held by another
// run is asked for up to wait_ms, as a reopen's new process finds it
Folder ClaimFolder(DWORD wait_ms);

const wchar_t* FolderWord(Folder f);

// the first copy on this folder for this user: a named mutex in the
// session, only the user may open it. false when another copy holds it
bool FirstCopy();

// halo.dll, kryfo_signal.dll and sqlcipher.dll from the exe's folder, never
// from PATH or the current folder. false names the one that did not load
bool LoadNatives(std::wstring* missing);

// the exe's own folder, with a trailing backslash
std::wstring AppDir();

// the user's sid as a string, empty when the token cannot be read
std::wstring UserSid();

// with KRYFO_TRACE=1: what ends the process outside dart and go, an
// exception nothing caught, an abort or a terminate, is one line of
// <root>\trace.txt: its code and the module and offset it happened at
void WatchCrashes();

// one line into the trace, when it is on
void TraceLine(const char* line);

}  // namespace kryfo

#endif  // RUNNER_KRYFO_WIN_H_
