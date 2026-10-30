#include "flutter_window.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr UINT_PTR kQuitTimer = 0x4B51;
constexpr UINT_PTR kFrameTimer = 0x4B52;
constexpr UINT_PTR kHiddenTimer = 0x4B53;
// how long a hidden start waits for its tray icon before the window shows
constexpr UINT kHiddenWaitMs = 10000;
// how long the window asks for frames itself after it comes up
constexpr ULONGLONG kPumpMs = 3000;
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
    } else if (call.method_name() == "show") {
      ShowAndRaise();
      result->Success();
    } else if (call.method_name() == "frames") {
      PumpFrames();
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
  PumpFrames();
}

// frames asked for from here for a while: what was drawn while hidden is
// stale, and an animation that starts with the window would otherwise move
// only on input
void FlutterWindow::PumpFrames() {
  HWND w = GetHandle();
  if (!w || !flutter_controller_) return;
  pump_until_ = ::GetTickCount64() + kPumpMs;
  flutter_controller_->ForceRedraw();
  ::SetTimer(w, kFrameTimer, 16, nullptr);
}

void FlutterWindow::PumpTick() {
  HWND w = GetHandle();
  if (!w || !flutter_controller_ || ::GetTickCount64() >= pump_until_ ||
      !::IsWindowVisible(w)) {
    if (w) ::KillTimer(w, kFrameTimer);
    return;
  }
  HWND view = flutter_controller_->view()->GetNativeWindow();
  ::InvalidateRect(view, nullptr, FALSE);
  flutter_controller_->ForceRedraw();
}

// the window goes, then the process, at once: no engine shutdown or dll
// unload that can wait forever on a native call still running. tor.exe is
// in kryfo's job and ends with it
void FlutterWindow::EndNow() {
  HWND w = GetHandle();
  if (w) {
    ::KillTimer(w, kQuitTimer);
    ::KillTimer(w, kFrameTimer);
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
      ::ShowWindow(hwnd, SW_HIDE);
    } else {
      Quit();
    }
    return 0;
  }
  switch (message) {
    case WM_TIMER:
      if (wparam == kFrameTimer) {
        PumpTick();
        return 0;
      }
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
