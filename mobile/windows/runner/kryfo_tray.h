// SPDX-License-Identifier: GPL-3.0-or-later
// the tray icon: Open Kryfo and Quit Kryfo, in the app's language. while it
// is shown, closing the window hides it and the app keeps receiving
#ifndef RUNNER_KRYFO_TRAY_H_
#define RUNNER_KRYFO_TRAY_H_

#include <windows.h>

#include <functional>
#include <string>

namespace kryfo {

enum class TrayEvent { kNone, kOpen, kMenu };

class Tray {
 public:
  // the window's messages for the tray
  static constexpr UINT kMessage = WM_APP + 1;

  Tray();
  ~Tray();

  // shown with these words, or the words changed
  void Show(HWND window, const std::wstring& open, const std::wstring& quit,
            const std::wstring& tip);
  void Hide();
  bool shown() const { return shown_; }

  // the window's message handler calls this first; true when it was the
  // tray's. on_open and on_quit run on a menu pick or a click
  bool Handle(UINT message, WPARAM wparam, LPARAM lparam,
              const std::function<void()>& on_open, const std::function<void()>& on_quit);

  // what a callback's event means, by the version the shell took
  static TrayEvent EventOf(bool v4, UINT event);

 private:
  bool Add();
  UINT Menu(POINT at);

  HWND window_ = nullptr;
  bool shown_ = false;
  // asked for by dart and not taken down since, shown or not
  bool wanted_ = false;
  bool v4_ = false;
  bool in_menu_ = false;
  std::wstring open_, quit_, tip_;
  // explorer sends it when it starts again: the icon is added again
  UINT taskbar_created_ = 0;
};

}  // namespace kryfo

#endif  // RUNNER_KRYFO_TRAY_H_
