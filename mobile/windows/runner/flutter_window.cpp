#include "flutter_window.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr UINT_PTR kQuitTimer = 0x4B51;
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
    } else if (call.method_name() == "show") {
      ShowAndRaise();
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::ShowAndRaise() {
  HWND w = GetHandle();
  if (!w) return;
  ::ShowWindow(w, ::IsIconic(w) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(w);
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
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  if (tray_.Handle(message, wparam, lparam, [this]() { ShowAndRaise(); },
                   [this]() { Quit(); })) {
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    // with a tray the window only hides, and the app keeps receiving
    case WM_CLOSE:
      if (tray_.shown()) {
        ::ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case WM_TIMER:
    case WM_APP + 2:
      if (message == WM_APP + 2 || wparam == kQuitTimer) {
        ::KillTimer(hwnd, kQuitTimer);
        tray_.Hide();
        ::DestroyWindow(hwnd);
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
