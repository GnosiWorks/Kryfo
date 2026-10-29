#include <app_links/app_links_plugin_c_api.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "kryfo_win.h"
#include "utils.h"

namespace {

// a reopen's new process: the old one is going, so it is never the copy
// to hand over to
bool Reopened() {
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  bool r = argv != nullptr && argc == 2 && ::wcscmp(argv[1], L"--reopen") == 0;
  ::LocalFree(argv);
  return r;
}

// the first copy's window, found by its class and title even while it sits
// in the tray: it gets this start's kryfo: link and comes forward
bool SendLinkToFirst() {
  HWND w = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Kryfo");
  if (w == nullptr) return false;
  SendAppLink(w);
  ::ShowWindow(w, ::IsIconic(w) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(w);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  kryfo::Harden();
  // the shortcut's id (kryfo.iss): the taskbar and the toasts go under it
  ::SetCurrentProcessExplicitAppUserModelID(L"app.kryfo");

  // a second start brings the first window forward, with its kryfo: link
  // if it has one, and ends. a first copy still starting has no window
  // yet: the folder lock below stops this one then
  bool reopen = Reopened();
  if (!kryfo::FirstCopy() && !reopen) {
    for (int i = 0; i < 15; i++) {
      if (SendLinkToFirst()) return EXIT_SUCCESS;
      ::Sleep(200);
    }
  }
  kryfo::ClaimFolder(reopen ? 3000 : 0);

  std::wstring missing;
  if (!kryfo::LoadNatives(&missing)) {
    std::wstring text = L"Kryfo cannot start: " + missing +
                        L" is missing next to kryfo.exe. Install Kryfo again.";
    ::MessageBoxW(nullptr, text.c_str(), L"Kryfo", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Kryfo", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // no engine shutdown or dll unload after the loop: either can wait
  // forever on a native call still running (flutter_window.cpp, EndNow)
  ::TerminateProcess(::GetCurrentProcess(), EXIT_SUCCESS);
  return EXIT_SUCCESS;
}
