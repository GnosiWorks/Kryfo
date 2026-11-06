#include "flutter_window.h"

#include "kryfo_win.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <wtsapi32.h>

#include <cstring>
#include <cwctype>
#include <memory>
#include <new>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "kryfo_audio.h"

namespace {
constexpr UINT_PTR kQuitTimer = 0x4B51;
constexpr UINT_PTR kHiddenTimer = 0x4B53;
// how long a hidden start waits for its tray icon before the window shows
constexpr UINT kHiddenWaitMs = 10000;
// the coalesced frame ask (AskFrame)
constexpr UINT kFrameMsg = WM_APP + 3;

// the files copied in explorer, as utf-8 paths
flutter::EncodableList ClipboardFiles(HWND owner) {
  flutter::EncodableList files;
  if (!::IsClipboardFormatAvailable(CF_HDROP) || !::OpenClipboard(owner)) return files;
  HDROP drop = static_cast<HDROP>(::GetClipboardData(CF_HDROP));
  if (drop) {
    UINT n = ::DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
    for (UINT i = 0; i < n; ++i) {
      UINT len = ::DragQueryFileW(drop, i, nullptr, 0);
      if (len == 0) continue;
      std::wstring w(len + 1, L'\0');
      ::DragQueryFileW(drop, i, w.data(), len + 1);
      w.resize(len);
      int m = ::WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), nullptr,
                                    0, nullptr, nullptr);
      std::string s(m, '\0');
      ::WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), s.data(), m,
                            nullptr, nullptr);
      if (!s.empty()) files.push_back(flutter::EncodableValue(s));
    }
  }
  ::CloseClipboard();
  return files;
}

// past this a copied picture is not read: a dib of 8192 by 4096 at 32 bits
constexpr SIZE_T kPictureMost = 160u * 1024 * 1024;

// past this many characters words are no link (kLinkMost in dart)
constexpr size_t kLinkMost = 8192;

// the words on the clipboard as utf-8 when, trimmed, they are only a link:
// http or https, no space, no other word. firefox's copy image puts the
// picture's address beside it. dart checks the link again
bool ClipboardLink(HWND owner, std::string* link) {
  if (!::OpenClipboard(owner)) return false;
  std::wstring w;
  bool fits = false;
  HANDLE h = ::GetClipboardData(CF_UNICODETEXT);
  SIZE_T size = h ? ::GlobalSize(h) : 0;
  const wchar_t* at = size ? static_cast<const wchar_t*>(::GlobalLock(h)) : nullptr;
  if (at) {
    size_t most = size / sizeof(wchar_t);
    size_t n = ::wcsnlen(at, most);
    if (n < most && n <= kLinkMost + 64) {
      w.assign(at, n);
      fits = true;
    }
    ::GlobalUnlock(h);
  }
  ::CloseClipboard();
  if (!fits) return false;
  size_t from = 0;
  size_t to = w.size();
  while (from < to && std::iswspace(w[from])) ++from;
  while (to > from && std::iswspace(w[to - 1])) --to;
  w = w.substr(from, to - from);
  if (w.empty() || w.size() > kLinkMost) return false;
  for (wchar_t c : w) {
    if (std::iswspace(c) || c == 0x200B || c == 0xFEFF) return false;
  }
  auto starts = [&w](const wchar_t* head) {
    size_t n = std::wcslen(head);
    if (w.size() <= n) return false;
    for (size_t i = 0; i < n; ++i) {
      if (std::towlower(w[i]) != head[i]) return false;
    }
    return true;
  };
  if (!starts(L"http://") && !starts(L"https://")) return false;
  int m = ::WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), nullptr, 0,
                                nullptr, nullptr);
  if (m <= 0) return false;
  link->assign(m, '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), link->data(), m,
                        nullptr, nullptr);
  return true;
}

// a picture copied (a screenshot, a browser's copy image), its bytes as
// they are on the clipboard and in memory only: the png a copy carries,
// else its dib (windows makes one from a plain bitmap). none while words
// are there too (they paste as words), unless the words are only a link
flutter::EncodableValue ClipboardPicture(HWND owner) {
  std::string link;
  if (::IsClipboardFormatAvailable(CF_UNICODETEXT) && !ClipboardLink(owner, &link)) {
    return flutter::EncodableValue();
  }
  static const UINT png = ::RegisterClipboardFormatW(L"PNG");
  static const UINT mime = ::RegisterClipboardFormatW(L"image/png");
  UINT pick = 0;
  const char* kind = "dib";
  if (png && ::IsClipboardFormatAvailable(png)) {
    pick = png;
    kind = "png";
  } else if (mime && ::IsClipboardFormatAvailable(mime)) {
    pick = mime;
    kind = "png";
  } else if (::IsClipboardFormatAvailable(CF_DIBV5)) {
    pick = CF_DIBV5;
  } else if (::IsClipboardFormatAvailable(CF_DIB)) {
    pick = CF_DIB;
  }
  if (!pick || !::OpenClipboard(owner)) return flutter::EncodableValue();
  // copied out and the clipboard let go before the bytes go over to dart
  std::unique_ptr<uint8_t[]> buf;
  SIZE_T n = 0;
  HANDLE h = ::GetClipboardData(pick);
  SIZE_T size = h ? ::GlobalSize(h) : 0;
  if (size > 0 && size <= kPictureMost) {
    buf.reset(new (std::nothrow) uint8_t[size]);
    const void* at = buf ? ::GlobalLock(h) : nullptr;
    if (at) {
      std::memcpy(buf.get(), at, size);
      ::GlobalUnlock(h);
      n = size;
    }
  }
  ::CloseClipboard();
  if (n == 0) return flutter::EncodableValue();
  flutter::EncodableMap got{
      {flutter::EncodableValue("kind"), flutter::EncodableValue(std::string(kind))},
      {flutter::EncodableValue("bytes"),
       flutter::EncodableValue(std::vector<uint8_t>(buf.get(), buf.get() + n))},
  };
  if (!link.empty()) {
    got[flutter::EncodableValue("text")] = flutter::EncodableValue(link);
  }
  return flutter::EncodableValue(got);
}

// a block of [n] bytes the clipboard owns once handed over
HGLOBAL GlobalCopy(const std::vector<uint8_t>& bytes) {
  HGLOBAL h = ::GlobalAlloc(GMEM_MOVEABLE, bytes.size());
  if (!h) return nullptr;
  void* at = ::GlobalLock(h);
  if (!at) {
    ::GlobalFree(h);
    return nullptr;
  }
  std::memcpy(at, bytes.data(), bytes.size());
  ::GlobalUnlock(h);
  return h;
}

// "Copy picture": a png kryfo made (a qr, a cleaned picture) and the same
// as a dib dart drew from it, for the apps that take only a bitmap
bool SetClipboardPicture(HWND owner, const flutter::EncodableValue* args) {
  const auto* map = std::get_if<flutter::EncodableMap>(args);
  if (!map) return false;
  auto bytes = [map](const char* key) -> const std::vector<uint8_t>* {
    auto it = map->find(flutter::EncodableValue(key));
    if (it == map->end()) return nullptr;
    const auto* b = std::get_if<std::vector<uint8_t>>(&it->second);
    return b && !b->empty() && b->size() <= kPictureMost ? b : nullptr;
  };
  const auto* png = bytes("png");
  const auto* dib = bytes("dib");
  if (!png || !dib) return false;
  static const UINT png_format = ::RegisterClipboardFormatW(L"PNG");
  if (!png_format || !::OpenClipboard(owner)) return false;
  bool ok = ::EmptyClipboard() != 0;
  for (auto [format, data] : {std::pair<UINT, const std::vector<uint8_t>*>{CF_DIBV5, dib},
                              std::pair<UINT, const std::vector<uint8_t>*>{png_format, png}}) {
    if (!ok) break;
    HGLOBAL h = GlobalCopy(*data);
    // the clipboard owns a block it took; one it refused is still ours
    if (!h || !::SetClipboardData(format, h)) {
      if (h) ::GlobalFree(h);
      ok = false;
    }
  }
  if (!ok) ::EmptyClipboard();
  ::CloseClipboard();
  return ok;
}

// the session's lock now. no answer counts as locked: the first unlock
// says otherwise
bool SessionLockedNow() {
  WTSINFOEXW* info = nullptr;
  DWORD n = 0;
  bool locked = true;
  if (::WTSQuerySessionInformationW(WTS_CURRENT_SERVER_HANDLE, WTS_CURRENT_SESSION,
                                    WTSSessionInfoEx, reinterpret_cast<LPWSTR*>(&info),
                                    &n)) {
    if (info && n >= sizeof(WTSINFOEXW) && info->Level == 1) {
      locked = info->Data.WTSInfoExLevel1.SessionFlags != WTS_SESSIONSTATE_UNLOCK;
    }
    ::WTSFreeMemory(info);
  }
  return locked;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // lock and unlock come as WM_WTSSESSION_CHANGE from here on, so the
  // state read after it misses none
  session_watched_ =
      ::WTSRegisterSessionNotification(GetHandle(), NOTIFY_FOR_THIS_SESSION) != FALSE;
  session_locked_ = SessionLockedNow();

  desktop_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "kryfo/desktop",
      &flutter::StandardMethodCodec::GetInstance());
  desktop_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "tray") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      auto word = [args](const char* key) {
        if (!args) return std::wstring();
        auto it = args->find(flutter::EncodableValue(key));
        if (it == args->end()) return std::wstring();
        const auto* s = std::get_if<std::string>(&it->second);
        if (!s || s->empty()) return std::wstring();
        int n = ::MultiByteToWideChar(CP_UTF8, 0, s->data(), static_cast<int>(s->size()),
                                      nullptr, 0);
        std::wstring w(n, L'\0');
        ::MultiByteToWideChar(CP_UTF8, 0, s->data(), static_cast<int>(s->size()), w.data(), n);
        return w;
      };
      tray_.Show(GetHandle(), word("open"), word("quit"), word("tip"));
      // said once, the first time closing hides the window. dart sends it
      // until it hears "hinted"
      hint_ = word("hint");
      result->Success();
    } else if (call.method_name() == "noTray") {
      // the tray switch off: no icon, and closing the window quits
      tray_.Hide();
      // no icon left to open a hidden window from
      if (!::IsWindowVisible(GetHandle())) ShowAndRaise();
      result->Success();
    } else if (call.method_name() == "startHidden") {
      result->Success(flutter::EncodableValue(start_hidden_));
    } else if (call.method_name() == "trayState") {
      result->Success(flutter::EncodableValue(tray_.shown()));
    } else if (call.method_name() == "audio") {
      // the mic and speaker calls for dart's ffi, by address
      flutter::EncodableList calls;
      for (int64_t a : kryfo::AudioCalls()) calls.push_back(flutter::EncodableValue(a));
      result->Success(flutter::EncodableValue(calls));
    } else if (call.method_name() == "sessionLocked") {
      // toasts say only kryfo and new message while it is
      result->Success(flutter::EncodableValue(session_locked_));
    } else if (call.method_name() == "clipFiles") {
      // ctrl and v in a composer: files copied in explorer wait in its row
      result->Success(flutter::EncodableValue(ClipboardFiles(GetHandle())));
    } else if (call.method_name() == "clipPicture") {
      // ctrl and v in a composer: a copied picture waits in its row
      result->Success(ClipboardPicture(GetHandle()));
    } else if (call.method_name() == "setClipPicture") {
      result->Success(flutter::EncodableValue(SetClipboardPicture(GetHandle(), call.arguments())));
    } else if (call.method_name() == "show") {
      ShowAndRaise();
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // the first frame is there: the window comes up in front with the view
  // focused, so nothing waits for a click to be drawn or typed into
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // a hidden start stays in the tray; ShowAndRaise brings it up
    if (start_hidden_) return;
    this->Show();
    ShowAndRaise();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // no tray icon in time (no shell, or dart never said its words): the
  // window after all
  if (start_hidden_) ::SetTimer(GetHandle(), kHiddenTimer, kHiddenWaitMs, nullptr);

  return true;
}

void FlutterWindow::ShowAndRaise() {
  HWND w = GetHandle();
  if (!w) return;
  ::KillTimer(w, kHiddenTimer);
  ::ShowWindow(w, ::IsIconic(w) ? SW_RESTORE : SW_SHOWNORMAL);
  // over the other windows even when windows keeps the focus where it is
  ::SetWindowPos(w, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  ::SetWindowPos(w, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  // the focus may move only from the thread that has it: joined for this
  HWND front = ::GetForegroundWindow();
  DWORD mine = ::GetCurrentThreadId();
  DWORD theirs = front ? ::GetWindowThreadProcessId(front, nullptr) : 0;
  bool joined = theirs != 0 && theirs != mine && ::AttachThreadInput(mine, theirs, TRUE);
  ::SetForegroundWindow(w);
  ::BringWindowToTop(w);
  ::SetActiveWindow(w);
  if (flutter_controller_) {
    ::SetFocus(flutter_controller_->view()->GetNativeWindow());
  }
  if (joined) ::AttachThreadInput(mine, theirs, FALSE);
  // what was drawn while hidden is stale: one new frame
  FrameNow();
}

void FlutterWindow::AskFrame() {
  HWND w = GetHandle();
  if (frame_asked_ || !w) return;
  frame_asked_ = ::PostMessageW(w, kFrameMsg, 0, 0) != FALSE;
}

// the engine's redraw is skipped while a resize waits for its frame, and
// dart schedules nothing while it thinks the window hidden: dart is asked
// for a forced frame as well, which it draws either way
void FlutterWindow::FrameNow() {
  frame_asked_ = false;
  if (!flutter_controller_) return;
  flutter_controller_->ForceRedraw();
  if (!desktop_) return;
  HWND w = GetHandle();
  bool shown = w && ::IsWindowVisible(w) && !::IsIconic(w);
  auto args = std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
      {flutter::EncodableValue("shown"), flutter::EncodableValue(shown)},
      {flutter::EncodableValue("active"),
       flutter::EncodableValue(shown && ::GetForegroundWindow() == w)},
  });
  desktop_->InvokeMethod("frame", std::move(args));
}

// closing with the tray up only hides; the first time, the tray says so
void FlutterWindow::HideToTray() {
  ::ShowWindow(GetHandle(), SW_HIDE);
  if (hint_.empty() || !tray_.Balloon(hint_)) return;
  hint_.clear();
  if (desktop_) desktop_->InvokeMethod("hinted", nullptr);
}

// the window goes, then the process, at once: no engine shutdown or dll
// unload that can wait forever on a native call still running. tor.exe is
// in kryfo's job and ends with it
void FlutterWindow::EndNow() {
  kryfo::TraceLine("runner: ends now");
  HWND w = GetHandle();
  if (w) {
    ::KillTimer(w, kQuitTimer);
    ::ShowWindow(w, SW_HIDE);
  }
  tray_.Hide();
  ::TerminateProcess(::GetCurrentProcess(), 0);
}

// dart keeps its marks and lets its keys go first, then the window goes.
// a dart side that does not answer does not keep the app open
void FlutterWindow::Quit() {
  ::SetTimer(GetHandle(), kQuitTimer, 3000, nullptr);
  HWND w = GetHandle();
  auto done = [w]() { ::PostMessageW(w, WM_APP + 2, 0, 0); };
  desktop_->InvokeMethod(
      "quit", nullptr,
      std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
          [done](const flutter::EncodableValue*) { done(); },
          [done](const std::string&, const std::string&, const flutter::EncodableValue*) {
            done();
          },
          [done]() { done(); }));
}

void FlutterWindow::OnDestroy() {
  tray_.Hide();
  if (session_watched_) {
    ::WTSUnRegisterSessionNotification(GetHandle());
    session_watched_ = false;
  }
  desktop_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // the tray's own before flutter's: with a tray, closing only hides, every
  // time, without asking dart whether the app may end. without one it ends
  // the app as the tray's quit does
  if (tray_.Handle(message, wparam, lparam, [this]() { ShowAndRaise(); },
                   [this]() { Quit(); })) {
    return 0;
  }
  if (message == WM_CLOSE) {
    if (tray_.shown()) {
      HideToTray();
    } else {
      Quit();
    }
    return 0;
  }
  switch (message) {
    case WM_TIMER:
      if (wparam == kHiddenTimer) {
        ::KillTimer(hwnd, kHiddenTimer);
        if (!tray_.shown()) ShowAndRaise();
        return 0;
      }
      if (wparam == kQuitTimer) {
        EndNow();
        return 0;
      }
      break;
    case WM_APP + 2:
      EndNow();
      return 0;
    case kFrameMsg:
      FrameNow();
      return 0;
    case WM_WTSSESSION_CHANGE:
      if (wparam == static_cast<WPARAM>(WTS_SESSION_LOCK) ||
          wparam == static_cast<WPARAM>(WTS_SESSION_UNLOCK)) {
        session_locked_ = wparam == static_cast<WPARAM>(WTS_SESSION_LOCK);
        if (desktop_) {
          desktop_->InvokeMethod(
              "sessionLock",
              std::make_unique<flutter::EncodableValue>(session_locked_));
        }
      }
      return 0;
  }

  // the window up, forward or back from the taskbar: a frame for it
  if ((message == WM_SHOWWINDOW && wparam) ||
      (message == WM_ACTIVATE && LOWORD(wparam) != WA_INACTIVE) ||
      (message == WM_SIZE && (wparam == SIZE_RESTORED || wparam == SIZE_MAXIMIZED))) {
    AskFrame();
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
