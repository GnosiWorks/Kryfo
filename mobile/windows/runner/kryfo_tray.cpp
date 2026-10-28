// SPDX-License-Identifier: GPL-3.0-or-later
#include "kryfo_tray.h"

#include <shellapi.h>

#include "resource.h"

namespace kryfo {
namespace {

constexpr UINT kIconId = 1;
constexpr UINT kOpen = 1;
constexpr UINT kQuit = 2;

}  // namespace

Tray::Tray() : taskbar_created_(::RegisterWindowMessageW(L"TaskbarCreated")) {}

Tray::~Tray() { Hide(); }

bool Tray::Add() {
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kIconId;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  data.uCallbackMessage = kMessage;
  data.hIcon = static_cast<HICON>(::LoadImageW(::GetModuleHandleW(nullptr),
                                               MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
                                               ::GetSystemMetrics(SM_CXSMICON),
                                               ::GetSystemMetrics(SM_CYSMICON), 0));
  // the tip says only the app's name, never who wrote
  ::wcsncpy_s(data.szTip, tip_.c_str(), _TRUNCATE);
  bool ok = ::Shell_NotifyIconW(shown_ ? NIM_MODIFY : NIM_ADD, &data) ||
            ::Shell_NotifyIconW(NIM_ADD, &data);
  if (ok) {
    data.uVersion = NOTIFYICON_VERSION_4;
    ::Shell_NotifyIconW(NIM_SETVERSION, &data);
  }
  if (data.hIcon) ::DestroyIcon(data.hIcon);
  return ok;
}

void Tray::Show(HWND window, const std::wstring& open, const std::wstring& quit,
                const std::wstring& tip) {
  window_ = window;
  open_ = open;
  quit_ = quit;
  tip_ = tip.empty() ? L"Kryfo" : tip;
  shown_ = Add() || shown_;
}

void Tray::Hide() {
  if (!shown_) return;
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kIconId;
  ::Shell_NotifyIconW(NIM_DELETE, &data);
  shown_ = false;
}

bool Tray::Handle(UINT message, WPARAM wparam, LPARAM lparam,
                  const std::function<void()>& on_open, const std::function<void()>& on_quit) {
  if (message == taskbar_created_ && taskbar_created_ != 0) {
    if (shown_) {
      shown_ = false;
      shown_ = Add();
    }
    return false;
  }
  if (message != kMessage) return false;
  switch (LOWORD(lparam)) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
    case WM_LBUTTONUP:
      on_open();
      return true;
    case WM_CONTEXTMENU:
    case WM_RBUTTONUP: {
      HMENU menu = ::CreatePopupMenu();
      ::AppendMenuW(menu, MF_STRING, kOpen, open_.c_str());
      ::AppendMenuW(menu, MF_STRING, kQuit, quit_.c_str());
      POINT at;
      ::GetCursorPos(&at);
      // the menu closes when the user clicks elsewhere only if the window
      // is in front
      ::SetForegroundWindow(window_);
      UINT pick = ::TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, at.x,
                                   at.y, 0, window_, nullptr);
      ::DestroyMenu(menu);
      ::PostMessageW(window_, WM_NULL, 0, 0);
      if (pick == kOpen) on_open();
      if (pick == kQuit) on_quit();
      return true;
    }
  }
  (void)wparam;
  return true;
}

}  // namespace kryfo
