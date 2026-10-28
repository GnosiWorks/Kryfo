// SPDX-License-Identifier: GPL-3.0-or-later
#include "kryfo_win.h"

#include <aclapi.h>
#include <sddl.h>
#include <shlobj.h>
#include <werapi.h>

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
