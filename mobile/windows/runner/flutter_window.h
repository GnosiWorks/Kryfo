#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "kryfo_tray.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // before Create: no window until the tray or a second start asks
  void SetStartHidden(bool hidden) { start_hidden_ = hidden; }

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // kryfo/desktop: tray words and show from dart, quit to dart
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> desktop_;
  kryfo::Tray tray_;

  // the one-time line for the first close to the tray, from dart
  std::wstring hint_;

  // started with the computer (--hidden)
  bool start_hidden_ = false;

  void ShowAndRaise();
  void HideToTray();
  void Quit();
  void EndNow();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
