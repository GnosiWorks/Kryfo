// desktop_drop 0.8.4, cut down for kryfo: see pubspec.yaml
#include "include/desktop_drop/desktop_drop_plugin.h"

#include <windows.h>
#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

namespace {

using FlutterMethodChannel =
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>;

std::string Utf8Of(const std::wstring &wide) {
  if (wide.empty()) return {};
  const int size =
      WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide.data(),
                          static_cast<int>(wide.size()), nullptr, 0, nullptr,
                          nullptr);
  if (size <= 0) return {};
  std::string out(size, 0);
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide.data(),
                      static_cast<int>(wide.size()), &out[0], size, nullptr,
                      nullptr);
  return out;
}

bool HasFiles(IDataObject *data) {
  FORMATETC fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  return data != nullptr && data->QueryGetData(&fmt) == S_OK;
}

// a copy when the source allows one, else nothing. never a move: on a move
// the source deletes its own file once the drop is done
DWORD CopyOnly(bool files, DWORD allowed) {
  return files && (allowed & DROPEFFECT_COPY) ? DROPEFFECT_COPY
                                              : DROPEFFECT_NONE;
}

class DesktopDropTarget : public IDropTarget {
 public:
  DesktopDropTarget(FlutterMethodChannel channel, HWND window_handle);

  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject *pDataObj, DWORD grfKeyState,
                                      POINTL pt, DWORD *pdwEffect) override;
  HRESULT STDMETHODCALLTYPE DragOver(DWORD grfKeyState, POINTL pt,
                                     DWORD *pdwEffect) override;
  HRESULT STDMETHODCALLTYPE DragLeave() override;
  HRESULT STDMETHODCALLTYPE Drop(IDataObject *pDataObj, DWORD grfKeyState,
                                 POINTL pt, DWORD *pdwEffect) override;
  HRESULT STDMETHODCALLTYPE QueryInterface(const IID &riid,
                                           void **ppvObject) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;

  void Revoke();

 private:
  virtual ~DesktopDropTarget();
  flutter::EncodableList Point(POINTL pt);

  FlutterMethodChannel channel_;
  HWND window_handle_;
  LONG ref_count_;
  bool registered_;
  bool need_ole_uninitialize_;
  bool files_;
};

class DesktopDropPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit DesktopDropPlugin(DesktopDropTarget *target);
  ~DesktopDropPlugin() override;

 private:
  DesktopDropTarget *target_;
};

DesktopDropPlugin::DesktopDropPlugin(DesktopDropTarget *target)
    : target_(target) {
  target_->AddRef();
}

DesktopDropPlugin::~DesktopDropPlugin() {
  target_->Revoke();
  target_->Release();
}

// static
void DesktopDropPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  HWND hwnd = nullptr;
  if (registrar->GetView()) {
    hwnd = registrar->GetView()->GetNativeWindow();
  }
  // no window, no drop
  if (hwnd == nullptr) return;

  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "desktop_drop",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const auto &call, auto result) { result->NotImplemented(); });

  auto target = new DesktopDropTarget(std::move(channel), hwnd);
  registrar->AddPlugin(std::make_unique<DesktopDropPlugin>(target));
}

DesktopDropTarget::DesktopDropTarget(FlutterMethodChannel channel,
                                     HWND window_handle)
    : channel_(std::move(channel)),
      window_handle_(window_handle),
      ref_count_(0),
      registered_(false),
      need_ole_uninitialize_(false),
      files_(false) {
  HRESULT ret = RegisterDragDrop(window_handle_, this);
  // the runner starts com, not ole: ole once, here
  if (ret == E_OUTOFMEMORY) {
    if (SUCCEEDED(OleInitialize(nullptr))) need_ole_uninitialize_ = true;
    ret = RegisterDragDrop(window_handle_, this);
  }
  registered_ = ret == S_OK;
}

DesktopDropTarget::~DesktopDropTarget() {
  if (need_ole_uninitialize_) OleUninitialize();
}

void DesktopDropTarget::Revoke() {
  if (!registered_) return;
  registered_ = false;
  RevokeDragDrop(window_handle_);
}

flutter::EncodableList DesktopDropTarget::Point(POINTL pt) {
  POINT point = {pt.x, pt.y};
  ScreenToClient(window_handle_, &point);
  return flutter::EncodableList{flutter::EncodableValue(double(point.x)),
                                flutter::EncodableValue(double(point.y))};
}

HRESULT DesktopDropTarget::DragEnter(IDataObject *pDataObj, DWORD grfKeyState,
                                     POINTL pt, DWORD *pdwEffect) {
  files_ = HasFiles(pDataObj);
  *pdwEffect = CopyOnly(files_, *pdwEffect);
  if (files_) {
    channel_->InvokeMethod(
        "updated", std::make_unique<flutter::EncodableValue>(Point(pt)));
  }
  return S_OK;
}

HRESULT DesktopDropTarget::DragOver(DWORD grfKeyState, POINTL pt,
                                    DWORD *pdwEffect) {
  *pdwEffect = CopyOnly(files_, *pdwEffect);
  if (files_) {
    channel_->InvokeMethod(
        "updated", std::make_unique<flutter::EncodableValue>(Point(pt)));
  }
  return S_OK;
}

HRESULT DesktopDropTarget::DragLeave() {
  files_ = false;
  channel_->InvokeMethod("exited", std::make_unique<flutter::EncodableValue>());
  return S_OK;
}

HRESULT DesktopDropTarget::Drop(IDataObject *pDataObj, DWORD grfKeyState,
                                POINTL pt, DWORD *pdwEffect) {
  files_ = false;
  *pdwEffect = CopyOnly(HasFiles(pDataObj), *pdwEffect);
  flutter::EncodableList paths;
  FORMATETC fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM stg = {};
  if (*pdwEffect == DROPEFFECT_COPY && pDataObj->GetData(&fmt, &stg) == S_OK) {
    auto drop = static_cast<HDROP>(GlobalLock(stg.hGlobal));
    if (drop != nullptr) {
      const UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
      for (UINT i = 0; i < count; ++i) {
        // a long path is read whole: its length first
        const UINT len = DragQueryFileW(drop, i, nullptr, 0);
        if (len == 0) continue;
        std::wstring wide(len + 1, L'\0');
        if (DragQueryFileW(drop, i, &wide[0], len + 1) == 0) continue;
        wide.resize(len);
        std::string path = Utf8Of(wide);
        if (!path.empty()) paths.push_back(flutter::EncodableValue(path));
      }
      GlobalUnlock(stg.hGlobal);
    }
    ReleaseStgMedium(&stg);
  }
  flutter::EncodableList args{flutter::EncodableValue(paths)};
  for (auto &v : Point(pt)) args.push_back(v);
  channel_->InvokeMethod("dropped",
                         std::make_unique<flutter::EncodableValue>(args));
  return S_OK;
}

HRESULT DesktopDropTarget::QueryInterface(const IID &iid, void **ppvObject) {
  if (iid == IID_IDropTarget || iid == IID_IUnknown) {
    AddRef();
    *ppvObject = this;
    return S_OK;
  }
  *ppvObject = nullptr;
  return E_NOINTERFACE;
}

ULONG DesktopDropTarget::AddRef() { return InterlockedIncrement(&ref_count_); }

ULONG DesktopDropTarget::Release() {
  const LONG count = InterlockedDecrement(&ref_count_);
  if (count == 0) delete this;
  return count;
}

}  // namespace

void DesktopDropPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  DesktopDropPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
