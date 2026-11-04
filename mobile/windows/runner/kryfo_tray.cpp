// SPDX-License-Identifier: GPL-3.0-or-later
#include "kryfo_tray.h"

#include <shellapi.h>
#include <windowsx.h>

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
    v4_ = ::Shell_NotifyIconW(NIM_SETVERSION, &data) != FALSE;
  }
  if (data.hIcon) ::DestroyIcon(data.hIcon);
  return ok;
}

void Tray::Show(HWND window, const std::wstring& open, const std::wstring& quit,
                const std::wstring& tip) {
  window_ = window;
  open_ = open.empty() ? L"Open Kryfo" : open;
  quit_ = quit.empty() ? L"Quit Kryfo" : quit;
  tip_ = tip.empty() ? L"Kryfo" : tip;
  wanted_ = true;
  shown_ = Add() || shown_;
}

void Tray::Hide() {
  wanted_ = false;
  if (!shown_) return;
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kIconId;
  ::Shell_NotifyIconW(NIM_DELETE, &data);
  shown_ = false;
}

bool Tray::Balloon(const std::wstring& text) {
  if (!shown_ || text.empty()) return false;
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kIconId;
  data.uFlags = NIF_INFO;
  ::wcsncpy_s(data.szInfo, text.c_str(), _TRUNCATE);
  ::wcsncpy_s(data.szInfoTitle, L"Kryfo", _TRUNCATE);
  data.dwInfoFlags = NIIF_INFO | NIIF_NOSOUND | NIIF_RESPECT_QUIET_TIME;
  return ::Shell_NotifyIconW(NIM_MODIFY, &data) != FALSE;
}

TrayEvent Tray::EventOf(bool v4, UINT event) {
  if (v4) {
    // version 4 sends the mouse messages too, then its own. a right click
    // counts once, or it makes two menus; a left click opens on either, as
    // a shell that leaves out its own select still brings the window, and
    // opening twice does nothing more
    switch (event) {
      case NIN_SELECT:
      case NIN_KEYSELECT:
      case WM_LBUTTONUP:
        return TrayEvent::kOpen;
      case WM_CONTEXTMENU:
        return TrayEvent::kMenu;
    }
    return TrayEvent::kNone;
  }
  switch (event) {
    case WM_LBUTTONUP:
      return TrayEvent::kOpen;
    case WM_RBUTTONUP:
      return TrayEvent::kMenu;
  }
  return TrayEvent::kNone;
}

bool Tray::Handle(UINT message, WPARAM wparam, LPARAM lparam,
                  const std::function<void()>& on_open, const std::function<void()>& on_quit) {
  if (message == taskbar_created_ && taskbar_created_ != 0) {
    // also an icon asked for before the taskbar was up (a start at sign-in)
    if (wanted_) {
      shown_ = false;
      shown_ = Add();
    }
    return false;
  }
  if (message != kMessage) return false;
  switch (EventOf(v4_, LOWORD(lparam))) {
    case TrayEvent::kOpen:
      on_open();
      break;
    case TrayEvent::kMenu: {
      // one menu at a time: its own loop passes tray messages on to here
      if (in_menu_) break;
      POINT at;
      if (v4_) {
        at.x = GET_X_LPARAM(wparam);
        at.y = GET_Y_LPARAM(wparam);
      } else {
        ::GetCursorPos(&at);
      }
      UINT pick = Menu(at);
      if (pick == kOpen) on_open();
      if (pick == kQuit) on_quit();
      break;
    }
    case TrayEvent::kNone:
      break;
  }
  return true;
}

UINT Tray::Menu(POINT at) {
  HMENU menu = ::CreatePopupMenu();
  if (!menu) return 0;
  ::AppendMenuW(menu, MF_STRING, kOpen, open_.c_str());
  ::AppendMenuW(menu, MF_STRING, kQuit, quit_.c_str());
  ::SetMenuDefaultItem(menu, kOpen, FALSE);
  in_menu_ = true;
  // the menu closes on a click elsewhere only while the window is in
  // front, hidden or not
  ::SetForegroundWindow(window_);
  UINT align = ::GetSystemMetrics(SM_MENUDROPALIGNMENT) ? TPM_RIGHTALIGN : TPM_LEFTALIGN;
  UINT pick = static_cast<UINT>(::TrackPopupMenuEx(
      menu, align | TPM_BOTTOMALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY, at.x,
      at.y, window_, nullptr));
  // lets the next right click open the menu again
  ::PostMessageW(window_, WM_NULL, 0, 0);
  in_menu_ = false;
  ::DestroyMenu(menu);
  return pick;
}

}  // namespace kryfo
