// SPDX-License-Identifier: GPL-3.0-or-later
#include "kryfo_win.h"

#include <aclapi.h>
#include <dbghelp.h>
#include <sddl.h>
#include <shlobj.h>
#include <werapi.h>

#include <csignal>
#include <cstring>
#include <cstdio>
#include <exception>
#include <vector>

namespace kryfo {
namespace {

// kept open for the life of the process: windows lets the lock go when
// the process ends, however it ends
HANDLE g_lock = INVALID_HANDLE_VALUE;

template <typename T>
bool Mitigate(PROCESS_MITIGATION_POLICY which, T policy) {
  return ::SetProcessMitigationPolicy(which, &policy, sizeof(policy)) != 0;
}

void Mitigations() {
  // no dll from a network share or a low integrity folder, system32 first
  PROCESS_MITIGATION_IMAGE_LOAD_POLICY image = {};
  image.NoRemoteImages = 1;
  image.NoLowMandatoryLabelImages = 1;
  image.PreferSystem32Images = 1;
  Mitigate(ProcessImageLoadPolicy, image);

  // a bad handle ends the process instead of going on with someone else's
  PROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY handles = {};
  handles.RaiseExceptionOnInvalidHandleReference = 1;
  handles.HandleExceptionsPermanentlyEnabled = 1;
  Mitigate(ProcessStrictHandleCheckPolicy, handles);

  PROCESS_MITIGATION_ASLR_POLICY aslr = {};
  aslr.EnableBottomUpRandomization = 1;
  aslr.EnableForceRelocateImages = 1;
  aslr.EnableHighEntropy = 1;
  Mitigate(ProcessASLRPolicy, aslr);

  // these two may break old input methods and fonts: on only for the pc
  // tests until checked there
  wchar_t v[4] = {};
  if (::GetEnvironmentVariableW(L"KRYFO_STRICT_TEST", v, 4) == 1 && v[0] == L'1') {
    PROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY ext = {};
    ext.DisableExtensionPoints = 1;
    Mitigate(ProcessExtensionPointDisablePolicy, ext);
    PROCESS_MITIGATION_FONT_DISABLE_POLICY fonts = {};
    fonts.DisableNonSystemFonts = 1;
    Mitigate(ProcessFontDisablePolicy, fonts);
  }
}

// other processes of the user may wait on, ask the name of, and end
// kryfo.exe, nothing more: no memory read, no dump, no injection. the
// owner rights entry keeps the owner from rewriting this dacl
void ProcessDacl() {
  std::wstring sid = UserSid();
  if (sid.empty()) return;
  std::wstring sddl = L"D:P(A;;0x101001;;;OW)(A;;0x101001;;;" + sid + L")";
  PSECURITY_DESCRIPTOR sd = nullptr;
  if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1,
                                                              &sd, nullptr)) {
    return;
  }
  BOOL present = FALSE, defaulted = FALSE;
  PACL dacl = nullptr;
  if (::GetSecurityDescriptorDacl(sd, &present, &dacl, &defaulted) && present) {
    ::SetSecurityInfo(::GetCurrentProcess(), SE_KERNEL_OBJECT,
                      DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION,
                      nullptr, nullptr, dacl, nullptr);
  }
  ::LocalFree(sd);
}

bool IsLink(const std::wstring& path) {
  DWORD a = ::GetFileAttributesW(path.c_str());
  return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_REPARSE_POINT);
}

bool OwnedByUser(const std::wstring& path) {
  PSID owner = nullptr;
  PSECURITY_DESCRIPTOR sd = nullptr;
  if (::GetNamedSecurityInfoW(path.c_str(), SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION, &owner,
                              nullptr, nullptr, nullptr, &sd) != ERROR_SUCCESS) {
    return false;
  }
  PSID me = nullptr;
  bool same = false;
  if (::ConvertStringSidToSidW(UserSid().c_str(), &me)) {
    same = ::EqualSid(owner, me) != 0;
    ::LocalFree(me);
  }
  ::LocalFree(sd);
  return same;
}

// the user and SYSTEM, full control, inherited by all below, nothing from
// AppData. SYSTEM stays: defender and windows run as it, and it reads
// anything anyway. administrators can take ownership; this keeps out other
// standard users
bool PrivateDacl(const std::wstring& path) {
  std::wstring sddl = L"D:P(A;OICI;FA;;;" + UserSid() + L")(A;OICI;FA;;;SY)";
  PSECURITY_DESCRIPTOR sd = nullptr;
  if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1,
                                                              &sd, nullptr)) {
    return false;
  }
  BOOL present = FALSE, defaulted = FALSE;
  PACL dacl = nullptr;
  bool ok = ::GetSecurityDescriptorDacl(sd, &present, &dacl, &defaulted) && present &&
            ::SetNamedSecurityInfoW(const_cast<wchar_t*>(path.c_str()), SE_FILE_OBJECT,
                                    DACL_SECURITY_INFORMATION |
                                        PROTECTED_DACL_SECURITY_INFORMATION,
                                    nullptr, nullptr, dacl, nullptr) == ERROR_SUCCESS;
  ::LocalFree(sd);
  return ok;
}

std::wstring DataDir() {
  PWSTR local = nullptr;
  std::wstring dir;
  if (SUCCEEDED(::SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT, nullptr, &local))) {
    dir = std::wstring(local) + L"\\Kryfo";
  }
  ::CoTaskMemFree(local);
  return dir;
}

bool TakeLock(const std::wstring& path) {
  HANDLE h = ::CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_ALWAYS,
                           FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  if (h == INVALID_HANDLE_VALUE) return false;
  BY_HANDLE_FILE_INFORMATION info = {};
  OVERLAPPED at = {};
  if (!::GetFileInformationByHandle(h, &info) ||
      (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) ||
      !::LockFileEx(h, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &at)) {
    ::CloseHandle(h);
    return false;
  }
  g_lock = h;
  return true;
}

// held for the life of the process, like the lock
HANDLE g_mutex = nullptr;

}  // namespace

bool FirstCopy() {
  std::wstring sid = UserSid();
  // named from the user and the folder, so two users or two folders never
  // meet. not a secret: the dacl keeps others from making it first
  std::wstring key = sid + L"|" + DataDir();
  unsigned long long h = 1469598103934665603ULL;
  for (wchar_t c : key) {
    h = (h ^ static_cast<unsigned long long>(c)) * 1099511628211ULL;
  }
  wchar_t name[64];
  ::swprintf_s(name, L"Local\\Kryfo-%016llx", h);
  std::wstring sddl = L"D:P(A;;GA;;;" + sid + L")";
  PSECURITY_DESCRIPTOR sd = nullptr;
  SECURITY_ATTRIBUTES sa = {sizeof(sa), nullptr, FALSE};
  if (!sid.empty() && ::ConvertStringSecurityDescriptorToSecurityDescriptorW(
                          sddl.c_str(), SDDL_REVISION_1, &sd, nullptr)) {
    sa.lpSecurityDescriptor = sd;
  }
  g_mutex = ::CreateMutexW(&sa, FALSE, name);
  DWORD err = ::GetLastError();
  if (sd) ::LocalFree(sd);
  // one made by someone else, or ours already: not the first. the folder
  // lock decides in the end
  return g_mutex != nullptr && err != ERROR_ALREADY_EXISTS;
}

std::wstring AppDir() {
  std::vector<wchar_t> buf(MAX_PATH);
  for (;;) {
    DWORD n = ::GetModuleFileNameW(nullptr, buf.data(), static_cast<DWORD>(buf.size()));
    if (n == 0) return L"";
    if (n < buf.size()) break;
    buf.resize(buf.size() * 2);
  }
  std::wstring exe(buf.data());
  return exe.substr(0, exe.find_last_of(L'\\') + 1);
}

std::wstring UserSid() {
  HANDLE token = nullptr;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token)) return L"";
  DWORD n = 0;
  ::GetTokenInformation(token, TokenUser, nullptr, 0, &n);
  std::vector<BYTE> buf(n);
  std::wstring out;
  LPWSTR s = nullptr;
  if (n > 0 && ::GetTokenInformation(token, TokenUser, buf.data(), n, &n) &&
      ::ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buf.data())->User.Sid, &s)) {
    out = s;
    ::LocalFree(s);
  }
  ::CloseHandle(token);
  return out;
}

void Harden() {
  // no crash dialog that waits while memory sits there
  ::SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
  // later loads come from the app's folder and system32 only
  ::SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_APPLICATION_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
  ::SetDllDirectoryW(L"");
  Mitigations();
  // error reporting neither collects nor sends reports of kryfo or its tor.
  // per user, no admin; the uninstaller removes both
  ::WerAddExcludedApplication(L"kryfo.exe", FALSE);
  ::WerAddExcludedApplication(L"tor.exe", FALSE);
  ::WerSetFlags(WER_FAULT_REPORTING_NO_UI);
  ProcessDacl();
}

Folder ClaimFolder(DWORD wait_ms) {
  Folder f = Folder::kOk;
  std::wstring root = DataDir();
  if (root.empty()) {
    f = Folder::kNoFolder;
  } else {
    ::CreateDirectoryW(root.c_str(), nullptr);
    DWORD a = ::GetFileAttributesW(root.c_str());
    if (a == INVALID_FILE_ATTRIBUTES || !(a & FILE_ATTRIBUTE_DIRECTORY)) {
      f = Folder::kNoFolder;
    } else if (IsLink(root)) {
      f = Folder::kLink;
    } else if (!OwnedByUser(root)) {
      f = Folder::kOwner;
    } else if (!PrivateDacl(root)) {
      f = Folder::kAcl;
    } else {
      ::SetFileAttributesW(root.c_str(), a | FILE_ATTRIBUTE_NOT_CONTENT_INDEXED);
      ULONGLONG until = ::GetTickCount64() + wait_ms;
      while (!TakeLock(root + L"\\lock")) {
        if (::GetTickCount64() >= until) {
          f = Folder::kLocked;
          break;
        }
        ::Sleep(200);
      }
    }
  }
  // set here whatever the parent gave, so the dart side reads only ours
  ::SetEnvironmentVariableW(L"KRYFO_FOLDER", FolderWord(f));
  return f;
}

const wchar_t* FolderWord(Folder f) {
  switch (f) {
    case Folder::kOk:
      return L"ok";
    case Folder::kLink:
      return L"link";
    case Folder::kOwner:
      return L"owner";
    case Folder::kAcl:
      return L"acl";
    case Folder::kLocked:
      return L"locked";
    case Folder::kNoFolder:
      break;
  }
  return L"nofolder";
}

namespace {

// set once, before anything can crash: the filter makes no string of its own
wchar_t g_trace[MAX_PATH] = {};
wchar_t g_dump[MAX_PATH] = {};
LPTOP_LEVEL_EXCEPTION_FILTER g_before = nullptr;

using WriteDumpFn = BOOL(WINAPI*)(HANDLE, DWORD, HANDLE, MINIDUMP_TYPE,
                                  PMINIDUMP_EXCEPTION_INFORMATION, PMINIDUMP_USER_STREAM_INFORMATION,
                                  PMINIDUMP_CALLBACK_INFORMATION);
using ThreadNameFn = HRESULT(WINAPI*)(HANDLE, PWSTR*);
// looked up before anything can crash: no library loads in the filter
WriteDumpFn g_write_dump = nullptr;
ThreadNameFn g_thread_name = nullptr;

// as dart writes its lines: local time, then the line. no heap
void WriteTrace(const char* line) {
  if (g_trace[0] == 0) return;
  HANDLE h = ::CreateFileW(g_trace, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                           nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (h == INVALID_HANDLE_VALUE) return;
  SYSTEMTIME t;
  ::GetLocalTime(&t);
  char buf[768];
  int n = ::_snprintf_s(buf, sizeof(buf), _TRUNCATE, "%04u-%02u-%02uT%02u:%02u:%02u.%03u %s\n",
                        t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond,
                        t.wMilliseconds, line);
  if (n < 0) n = static_cast<int>(::strlen(buf));
  DWORD put = 0;
  ::WriteFile(h, buf, static_cast<DWORD>(n), &put, nullptr);
  ::FlushFileBuffers(h);
  ::CloseHandle(h);
}

// the module's file name alone, never its folder
void ModuleAt(const void* at, char* name, size_t size, unsigned long long* offset) {
  ::strcpy_s(name, size, "unknown");
  *offset = reinterpret_cast<unsigned long long>(at);
  HMODULE m = nullptr;
  if (!::GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                                GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            static_cast<LPCWSTR>(at), &m) ||
      m == nullptr) {
    return;
  }
  *offset = reinterpret_cast<unsigned long long>(at) - reinterpret_cast<unsigned long long>(m);
  wchar_t path[MAX_PATH];
  DWORD n = ::GetModuleFileNameW(m, path, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) return;
  const wchar_t* base = path;
  for (const wchar_t* c = path; *c; c++) {
    if (*c == L'\\' || *c == L'/') base = c + 1;
  }
  ::WideCharToMultiByte(CP_UTF8, 0, base, -1, name, static_cast<int>(size), nullptr, nullptr);
}

bool Runs(DWORD protect) {
  return (protect & (PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE |
                     PAGE_EXECUTE_WRITECOPY)) != 0;
}

// code at [at]: a module's name and offset, or, for code no module holds
// (dart's own, loaded from app.so by dart), its block's base and offset
bool CodeAt(unsigned long long at, char* out, size_t size) {
  MEMORY_BASIC_INFORMATION mi = {};
  if (at < 0x10000 || !::VirtualQuery(reinterpret_cast<const void*>(at), &mi, sizeof(mi)) ||
      mi.State != MEM_COMMIT || !Runs(mi.Protect)) {
    return false;
  }
  unsigned long long base = reinterpret_cast<unsigned long long>(mi.AllocationBase);
  if (mi.Type == MEM_IMAGE) {
    char name[128];
    unsigned long long off = 0;
    ModuleAt(reinterpret_cast<const void*>(at), name, sizeof(name), &off);
    ::_snprintf_s(out, size, _TRUNCATE, "%s+0x%llx", name, off);
  } else {
    ::_snprintf_s(out, size, _TRUNCATE, "code@0x%llx+0x%llx", base, at - base);
  }
  return true;
}

// what the faulting address is: the kind of memory, its block, its rights
void Region(const void* at, char* out, size_t size) {
  MEMORY_BASIC_INFORMATION mi = {};
  if (!::VirtualQuery(at, &mi, sizeof(mi))) {
    ::strcpy_s(out, size, "no region");
    return;
  }
  const char* kind = mi.State != MEM_COMMIT  ? "free"
                     : mi.Type == MEM_IMAGE  ? "image"
                     : mi.Type == MEM_MAPPED ? "mapped"
                                             : "private";
  unsigned long long base = reinterpret_cast<unsigned long long>(mi.AllocationBase);
  ::_snprintf_s(out, size, _TRUNCATE, "%s, rights 0x%lx, block 0x%llx+0x%llx, size 0x%llx", kind,
                mi.Protect, base, reinterpret_cast<unsigned long long>(at) - base,
                static_cast<unsigned long long>(mi.RegionSize));
}

// the return addresses on the faulting thread's stack, as code places
void StackScan(const CONTEXT* c, char* out, size_t size) {
  ::strcpy_s(out, size, "native stack:");
  if (!c) return;
  ULONG_PTR low = 0, high = 0;
  ::GetCurrentThreadStackLimits(&low, &high);
  unsigned long long sp = c->Rsp;
  if (sp < low || sp >= high) return;
  const unsigned long long* q = reinterpret_cast<const unsigned long long*>(sp);
  const unsigned long long* end = reinterpret_cast<const unsigned long long*>(high);
  int hits = 0;
  for (int i = 0; q + i < end && i < 4096 && hits < 14; i++) {
    char one[96];
    if (!CodeAt(q[i], one, sizeof(one))) continue;
    size_t used = ::strlen(out);
    if (used + ::strlen(one) + 2 >= size) break;
    ::strcat_s(out, size, " ");
    ::strcat_s(out, size, one);
    hits++;
  }
}

// the thread's name, as flutter and dart give theirs: io.flutter.ui and so on
void ThreadName(char* out, size_t size) {
  ::strcpy_s(out, size, "unnamed");
  PWSTR w = nullptr;
  if (!g_thread_name || FAILED(g_thread_name(::GetCurrentThread(), &w)) || !w) return;
  if (w[0]) ::WideCharToMultiByte(CP_UTF8, 0, w, -1, out, static_cast<int>(size), nullptr, nullptr);
  ::LocalFree(w);
}

// every thread's stack and the module list, for windbg. stacks can hold
// key bytes: written only with the trace on, into the private folder
bool WriteDump(EXCEPTION_POINTERS* e) {
  if (!g_write_dump || g_dump[0] == 0) return false;
  HANDLE h = ::CreateFileW(g_dump, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                           FILE_ATTRIBUTE_NORMAL, nullptr);
  if (h == INVALID_HANDLE_VALUE) return false;
  MINIDUMP_EXCEPTION_INFORMATION x = {};
  x.ThreadId = ::GetCurrentThreadId();
  x.ExceptionPointers = e;
  x.ClientPointers = FALSE;
  auto type = static_cast<MINIDUMP_TYPE>(MiniDumpNormal | MiniDumpWithUnloadedModules |
                                         MiniDumpWithThreadInfo);
  BOOL ok = g_write_dump(::GetCurrentProcess(), ::GetCurrentProcessId(), h, type, e ? &x : nullptr,
                         nullptr, nullptr);
  ::CloseHandle(h);
  return ok != FALSE;
}

LONG WINAPI OnCrash(EXCEPTION_POINTERS* e) {
  char name[128];
  unsigned long long offset = 0;
  const EXCEPTION_RECORD* r = e ? e->ExceptionRecord : nullptr;
  ModuleAt(r ? r->ExceptionAddress : nullptr, name, sizeof(name), &offset);
  char line[512];
  ::_snprintf_s(line, sizeof(line), _TRUNCATE, "native crash 0x%08lx at %s+0x%llx thread %lu",
                r ? r->ExceptionCode : 0UL, name, offset, ::GetCurrentThreadId());
  WriteTrace(line);
  if (r) {
    char where[192];
    Region(r->ExceptionAddress, where, sizeof(where));
    // an access violation says what it tried and where: 0 read, 1 write,
    // 8 ran memory that holds no code
    if (r->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && r->NumberParameters >= 2) {
      ULONG_PTR how = r->ExceptionInformation[0];
      ::_snprintf_s(line, sizeof(line), _TRUNCATE, "native crash: %s 0x%llx, code in %s",
                    how == 0 ? "reading" : how == 1 ? "writing" : how == 8 ? "running" : "using",
                    static_cast<unsigned long long>(r->ExceptionInformation[1]), where);
    } else {
      ::_snprintf_s(line, sizeof(line), _TRUNCATE, "native crash: code in %s", where);
    }
    WriteTrace(line);
  }
  StackScan(e ? e->ContextRecord : nullptr, line, sizeof(line));
  WriteTrace(line);
  char thread[64];
  ThreadName(thread, sizeof(thread));
  ::_snprintf_s(line, sizeof(line), _TRUNCATE, "native crash thread name %s", thread);
  WriteTrace(line);
  WriteTrace(WriteDump(e) ? "native crash dump written" : "native crash dump failed");
  return g_before ? g_before(e) : EXCEPTION_CONTINUE_SEARCH;
}

void OnAbort(int) {
  char line[64];
  ::_snprintf_s(line, sizeof(line), _TRUNCATE, "native abort thread %lu", ::GetCurrentThreadId());
  WriteTrace(line);
}

void OnTerminate() {
  WriteTrace("native terminate");
  std::abort();
}

}  // namespace

void WatchCrashes() {
  wchar_t on[8] = {};
  DWORD n = ::GetEnvironmentVariableW(L"KRYFO_TRACE", on, 8);
  if (n != 1 || on[0] != L'1') return;
  std::wstring path = DataDir();
  if (path.empty()) return;
  std::wstring dump = path + L"\\crash.dmp";
  path += L"\\trace.txt";
  if (path.size() >= MAX_PATH || dump.size() >= MAX_PATH) return;
  ::wcscpy_s(g_trace, path.c_str());
  ::wcscpy_s(g_dump, dump.c_str());
  HMODULE help = ::LoadLibraryExW(L"dbghelp.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (help) {
    g_write_dump = reinterpret_cast<WriteDumpFn>(::GetProcAddress(help, "MiniDumpWriteDump"));
  }
  HMODULE k32 = ::GetModuleHandleW(L"kernel32.dll");
  if (k32) {
    g_thread_name = reinterpret_cast<ThreadNameFn>(::GetProcAddress(k32, "GetThreadDescription"));
  }
  g_before = ::SetUnhandledExceptionFilter(OnCrash);
  std::signal(SIGABRT, OnAbort);
  std::set_terminate(OnTerminate);
  char line[96];
  ::_snprintf_s(line, sizeof(line), _TRUNCATE, "runner watches native crashes, main thread %lu",
                ::GetCurrentThreadId());
  WriteTrace(line);
}

void TraceLine(const char* line) { WriteTrace(line); }

bool LoadNatives(std::wstring* missing) {
  std::wstring dir = AppDir();
  for (const wchar_t* name : {L"halo.dll", L"kryfo_signal.dll", L"sqlcipher.dll"}) {
    std::wstring path = dir + name;
    // their own imports from system32 only
    if (!::LoadLibraryExW(path.c_str(), nullptr,
                          LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32)) {
      if (missing) *missing = name;
      return false;
    }
  }
  return true;
}

}  // namespace kryfo
