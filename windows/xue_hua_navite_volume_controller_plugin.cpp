#include "xue_hua_navite_volume_controller_plugin.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <mmdeviceapi.h>
#include <functiondiscoverykeys_devpkey.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <endpointvolume.h>
#include <propidl.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <memory>
#include <string>
#include <vector>

namespace xue_hua_navite_volume_controller {

namespace {

std::string WideToUtf8(const std::wstring &wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(),
                                        static_cast<int>(wstr.size()), nullptr,
                                        0, nullptr, nullptr);
  if (size_needed <= 0) return std::string();
  std::string result(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.size()),
                      &result[0], size_needed, nullptr, nullptr);
  return result;
}

std::wstring Utf8ToWide(const std::string &str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
                                        static_cast<int>(str.size()), nullptr, 0);
  if (size_needed <= 0) return std::wstring();
  std::wstring result(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), static_cast<int>(str.size()),
                      &result[0], size_needed);
  return result;
}

class ScopedComInitializer {
 public:
  ScopedComInitializer() {
    hr_ = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  }
  ~ScopedComInitializer() {
    if (SUCCEEDED(hr_)) {
      CoUninitialize();
    }
  }

 private:
  HRESULT hr_;
};

std::string ClassifyWindowsDeviceRoute(const std::string &name) {
  std::string lower = name;
  std::transform(lower.begin(), lower.end(), lower.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  if (lower.find("bluetooth") != std::string::npos ||
      lower.find("airpods") != std::string::npos) {
    return "bluetooth";
  }
  if (lower.find("usb") != std::string::npos) {
    return "usb";
  }
  if (lower.find("hdmi") != std::string::npos ||
      lower.find("displayport") != std::string::npos ||
      lower.find("nvidia") != std::string::npos) {
    return "hdmi";
  }
  if (lower.find("headphone") != std::string::npos ||
      lower.find("headset") != std::string::npos) {
    return "wiredHeadset";
  }
  return "speaker";
}

// Undocumented Windows IPolicyConfig COM interface for switching default output device.
interface DECLSPEC_UUID("f8679f50-850a-41cf-9c72-430f290290c8")
    IPolicyConfig : public IUnknown {
 public:
  virtual HRESULT STDMETHODCALLTYPE GetMixFormat(PCWSTR, WAVEFORMATEX **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetDeviceFormat(
      PCWSTR, INT, WAVEFORMATEX **) = 0;
  virtual HRESULT STDMETHODCALLTYPE ResetDeviceFormat(PCWSTR) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetDeviceFormat(
      PCWSTR, WAVEFORMATEX *, WAVEFORMATEX *) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetProcessingPeriod(
      PCWSTR, INT, PINT64, PINT64) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetProcessingPeriod(PCWSTR, PINT64) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetShareMode(
      PCWSTR, struct DeviceShareMode *) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetShareMode(
      PCWSTR, struct DeviceShareMode *) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetPropertyValue(
      PCWSTR, const PROPERTYKEY &, PROPVARIANT *) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetPropertyValue(
      PCWSTR, const PROPERTYKEY &, PROPVARIANT *) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetDefaultEndpoint(
      PCWSTR wszDeviceId, ERole eRole) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetEndpointVisibility(PCWSTR, INT) = 0;
};

class DECLSPEC_UUID("870af99c-171d-4f9e-af0d-e63df40c2bc9") CPolicyConfigClient;

}  // namespace

class VolumeEndpointNotificationClient : public IAudioEndpointVolumeCallback,
                                         public IMMNotificationClient {
 public:
  explicit VolumeEndpointNotificationClient(
      XueHuaNaviteVolumeControllerPlugin *plugin)
      : ref_count_(1),
        plugin_(plugin),
        enumerator_(nullptr),
        device_(nullptr),
        endpoint_volume_(nullptr) {}

  virtual ~VolumeEndpointNotificationClient() { Detach(); }

  void Attach() {
    ScopedComInitializer com;
    Detach();
    HRESULT hr = CoCreateInstance(
        __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
        __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator_));
    if (FAILED(hr) || !enumerator_) return;

    enumerator_->RegisterEndpointNotificationCallback(this);
    BindDefaultDevice();
  }

  void BindDefaultDevice() {
    if (endpoint_volume_) {
      endpoint_volume_->UnregisterControlChangeNotify(this);
      endpoint_volume_->Release();
      endpoint_volume_ = nullptr;
    }
    if (device_) {
      device_->Release();
      device_ = nullptr;
    }
    if (!enumerator_) return;

    HRESULT hr = enumerator_->GetDefaultAudioEndpoint(eRender, eMultimedia,
                                                      &device_);
    if (SUCCEEDED(hr) && device_) {
      hr = device_->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                             nullptr,
                             reinterpret_cast<void **>(&endpoint_volume_));
      if (SUCCEEDED(hr) && endpoint_volume_) {
        endpoint_volume_->RegisterControlChangeNotify(this);
      }
    }
  }

  void Detach() {
    if (endpoint_volume_) {
      endpoint_volume_->UnregisterControlChangeNotify(this);
      endpoint_volume_->Release();
      endpoint_volume_ = nullptr;
    }
    if (device_) {
      device_->Release();
      device_ = nullptr;
    }
    if (enumerator_) {
      enumerator_->UnregisterEndpointNotificationCallback(this);
      enumerator_->Release();
      enumerator_ = nullptr;
    }
  }

  // IUnknown
  ULONG STDMETHODCALLTYPE AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }

  ULONG STDMETHODCALLTYPE Release() override {
    ULONG ulRef = InterlockedDecrement(&ref_count_);
    if (0 == ulRef) {
      delete this;
    }
    return ulRef;
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                           VOID **ppvInterface) override {
    if (IID_IUnknown == riid) {
      AddRef();
      *ppvInterface = static_cast<IUnknown *>(
          static_cast<IAudioEndpointVolumeCallback *>(this));
    } else if (__uuidof(IAudioEndpointVolumeCallback) == riid) {
      AddRef();
      *ppvInterface = static_cast<IAudioEndpointVolumeCallback *>(this);
    } else if (__uuidof(IMMNotificationClient) == riid) {
      AddRef();
      *ppvInterface = static_cast<IMMNotificationClient *>(this);
    } else {
      *ppvInterface = nullptr;
      return E_NOINTERFACE;
    }
    return S_OK;
  }

  // IAudioEndpointVolumeCallback
  HRESULT STDMETHODCALLTYPE
  OnNotify(PAUDIO_VOLUME_NOTIFICATION_DATA pNotify) override {
    if (pNotify && plugin_) {
      plugin_->NotifyVolumeChangedFromCallback(pNotify->fMasterVolume,
                                               pNotify->bMuted != FALSE);
    }
    return S_OK;
  }

  // IMMNotificationClient
  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(
      EDataFlow flow, ERole role, LPCWSTR /*pwstrDeviceId*/) override {
    if (flow == eRender && role == eMultimedia && plugin_) {
      BindDefaultDevice();
      plugin_->NotifyDefaultDeviceChangedFromCallback();
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR,
                                                   const PROPERTYKEY) override {
    return S_OK;
  }

 private:
  LONG ref_count_;
  XueHuaNaviteVolumeControllerPlugin *plugin_;
  IMMDeviceEnumerator *enumerator_;
  IMMDevice *device_;
  IAudioEndpointVolume *endpoint_volume_;
};

// static
void XueHuaNaviteVolumeControllerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "xue_hua_navite_volume_controller",
          &flutter::StandardMethodCodec::GetInstance());

  auto *channel_raw = channel.get();
  auto plugin = std::make_unique<XueHuaNaviteVolumeControllerPlugin>(
      std::move(channel));

  channel_raw->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

XueHuaNaviteVolumeControllerPlugin::XueHuaNaviteVolumeControllerPlugin()
    : channel_(nullptr) {}

XueHuaNaviteVolumeControllerPlugin::XueHuaNaviteVolumeControllerPlugin(
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : channel_(std::move(channel)) {}

XueHuaNaviteVolumeControllerPlugin::~XueHuaNaviteVolumeControllerPlugin() {
  StopEndpointObservation();
}

void XueHuaNaviteVolumeControllerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  auto get_string_arg = [&](const std::string &key,
                            const std::string &fallback) -> std::string {
    if (!args) return fallback;
    auto it = args->find(flutter::EncodableValue(key));
    if (it != args->end()) {
      if (const auto *val = std::get_if<std::string>(&it->second)) {
        return *val;
      }
    }
    return fallback;
  };

  auto get_double_arg = [&](const std::string &key, double fallback) -> double {
    if (!args) return fallback;
    auto it = args->find(flutter::EncodableValue(key));
    if (it != args->end()) {
      if (const auto *val = std::get_if<double>(&it->second)) return *val;
      if (const auto *ival = std::get_if<int32_t>(&it->second)) {
        return static_cast<double>(*ival);
      }
      if (const auto *lval = std::get_if<int64_t>(&it->second)) {
        return static_cast<double>(*lval);
      }
    }
    return fallback;
  };

  auto get_bool_arg = [&](const std::string &key, bool fallback) -> bool {
    if (!args) return fallback;
    auto it = args->find(flutter::EncodableValue(key));
    if (it != args->end()) {
      if (const auto *val = std::get_if<bool>(&it->second)) return *val;
    }
    return fallback;
  };

  if (method == "initialize") {
    default_stream_name_ = get_string_arg("defaultStream", "media");
    bool listen = get_bool_arg("listenToVolumeChanges", true);
    if (listen) {
      StartEndpointObservation();
    }
    result->Success(
        flutter::EncodableValue(BuildVolumeStateMap(default_stream_name_)));
  } else if (method == "getCapabilities") {
    result->Success(flutter::EncodableValue(BuildCapabilitiesMap()));
  } else if (method == "getVolumeState") {
    std::string stream = get_string_arg("streamType", default_stream_name_);
    result->Success(flutter::EncodableValue(BuildVolumeStateMap(stream)));
  } else if (method == "getVolume") {
    result->Success(flutter::EncodableValue(ReadMasterVolume()));
  } else if (method == "setVolume") {
    std::string stream = get_string_arg("streamType", default_stream_name_);
    double vol = std::clamp(get_double_arg("volume", 0.5), 0.0, 1.0);
    result->Success(flutter::EncodableValue(
        WriteMasterVolume(vol, stream, "programmatic")));
  } else if (method == "adjustVolume") {
    std::string stream = get_string_arg("streamType", default_stream_name_);
    double delta = std::clamp(get_double_arg("delta", 0.0), -1.0, 1.0);
    double target = std::clamp(ReadMasterVolume() + delta, 0.0, 1.0);
    result->Success(flutter::EncodableValue(
        WriteMasterVolume(target, stream, "adjustVolume")));
  } else if (method == "stepVolume") {
    std::string stream = get_string_arg("streamType", default_stream_name_);
    std::string direction = get_string_arg("direction", "up");
    if (direction == "mute") {
      result->Success(flutter::EncodableValue(
          WriteMasterMuted(!ReadMasterMuted(), stream)));
    } else {
      double delta = (direction == "up") ? 0.02 : -0.02;
      double target = std::clamp(ReadMasterVolume() + delta, 0.0, 1.0);
      result->Success(flutter::EncodableValue(
          WriteMasterVolume(target, stream, "stepVolume")));
    }
  } else if (method == "getAllStreamVolumes") {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("media")] =
        flutter::EncodableValue(ReadMasterVolume());
    result->Success(flutter::EncodableValue(map));
  } else if (method == "isMuted") {
    result->Success(flutter::EncodableValue(ReadMasterMuted()));
  } else if (method == "setMute") {
    std::string stream = get_string_arg("streamType", default_stream_name_);
    bool muted = get_bool_arg("muted", false);
    result->Success(
        flutter::EncodableValue(WriteMasterMuted(muted, stream)));
  } else if (method == "toggleMute") {
    std::string stream = get_string_arg("streamType", default_stream_name_);
    result->Success(flutter::EncodableValue(
        WriteMasterMuted(!ReadMasterMuted(), stream)));
  } else if (method == "getRingerMode") {
    result->Success(flutter::EncodableValue(
        ReadMasterMuted() ? std::string("silent") : std::string("normal")));
  } else if (method == "setRingerMode") {
    std::string mode = get_string_arg("ringerMode", "normal");
    bool should_mute = (mode == "silent" || mode == "vibrate");
    WriteMasterMuted(should_mute, default_stream_name_);
    result->Success(flutter::EncodableValue(
        should_mute ? std::string("silent") : std::string("normal")));
  } else if (method == "hasDoNotDisturbAccess" ||
             method == "requestDoNotDisturbAccess") {
    result->Success(flutter::EncodableValue(true));
  } else if (method == "setShowSystemUI" ||
             method == "setInterceptHardwareButtons") {
    result->Success();
  } else if (method == "getOutputDevices") {
    result->Success(flutter::EncodableValue(ListOutputDevices()));
  } else if (method == "getCurrentOutputDevice") {
    auto devices = ListOutputDevices();
    for (const auto &val : devices) {
      if (const auto *map = std::get_if<flutter::EncodableMap>(&val)) {
        auto it = map->find(flutter::EncodableValue("isDefault"));
        if (it != map->end() && std::get_if<bool>(&it->second) &&
            *std::get_if<bool>(&it->second)) {
          result->Success(val);
          return;
        }
      }
    }
    if (!devices.empty()) {
      result->Success(devices.front());
    } else {
      result->Success();
    }
  } else if (method == "setOutputDevice") {
    std::string device_id = get_string_arg("deviceId", "");
    result->Success(
        flutter::EncodableValue(SelectDefaultOutputDevice(device_id)));
  } else if (method == "getAppVolume") {
    result->Success(flutter::EncodableValue(ReadProcessAppVolume()));
  } else if (method == "setAppVolume") {
    double vol = std::clamp(get_double_arg("volume", 1.0), 0.0, 1.0);
    result->Success(flutter::EncodableValue(WriteProcessAppVolume(vol)));
  } else if (method == "dispose") {
    StopEndpointObservation();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

double XueHuaNaviteVolumeControllerPlugin::ReadMasterVolume() {
  ScopedComInitializer com;
  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioEndpointVolume *endpoint_volume = nullptr;
  float level = 0.5f;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (SUCCEEDED(hr) && enumerator) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    if (SUCCEEDED(hr) && device) {
      hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                            reinterpret_cast<void **>(&endpoint_volume));
      if (SUCCEEDED(hr) && endpoint_volume) {
        endpoint_volume->GetMasterVolumeLevelScalar(&level);
        endpoint_volume->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }
  return std::clamp(static_cast<double>(level), 0.0, 1.0);
}

bool XueHuaNaviteVolumeControllerPlugin::ReadMasterMuted() {
  ScopedComInitializer com;
  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioEndpointVolume *endpoint_volume = nullptr;
  BOOL muted = FALSE;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (SUCCEEDED(hr) && enumerator) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    if (SUCCEEDED(hr) && device) {
      hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                            reinterpret_cast<void **>(&endpoint_volume));
      if (SUCCEEDED(hr) && endpoint_volume) {
        endpoint_volume->GetMute(&muted);
        endpoint_volume->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }
  return muted != FALSE || ReadMasterVolume() <= 0.0001;
}

flutter::EncodableMap XueHuaNaviteVolumeControllerPlugin::WriteMasterVolume(
    double target_volume, const std::string &stream_name,
    const std::string &reason) {
  ScopedComInitializer com;
  double clamped = std::clamp(target_volume, 0.0, 1.0);
  double old_vol = ReadMasterVolume();

  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioEndpointVolume *endpoint_volume = nullptr;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (SUCCEEDED(hr) && enumerator) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    if (SUCCEEDED(hr) && device) {
      hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                            reinterpret_cast<void **>(&endpoint_volume));
      if (SUCCEEDED(hr) && endpoint_volume) {
        endpoint_volume->SetMasterVolumeLevelScalar(
            static_cast<float>(clamped), nullptr);
        if (clamped > 0.0001) {
          pre_mute_volume_ = clamped;
          endpoint_volume->SetMute(FALSE, nullptr);
        }
        endpoint_volume->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }

  auto state = BuildVolumeStateMap(stream_name);
  EmitVolumeChange(state, old_vol, reason);
  return state;
}

flutter::EncodableMap XueHuaNaviteVolumeControllerPlugin::WriteMasterMuted(
    bool muted, const std::string &stream_name) {
  ScopedComInitializer com;
  double old_vol = ReadMasterVolume();
  if (muted && old_vol > 0.0001) {
    pre_mute_volume_ = old_vol;
  }

  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioEndpointVolume *endpoint_volume = nullptr;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (SUCCEEDED(hr) && enumerator) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    if (SUCCEEDED(hr) && device) {
      hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                            reinterpret_cast<void **>(&endpoint_volume));
      if (SUCCEEDED(hr) && endpoint_volume) {
        endpoint_volume->SetMute(muted ? TRUE : FALSE, nullptr);
        if (!muted && old_vol <= 0.0001) {
          float restore = static_cast<float>(
              pre_mute_volume_ > 0.0001 ? pre_mute_volume_ : 0.5);
          endpoint_volume->SetMasterVolumeLevelScalar(restore, nullptr);
        }
        endpoint_volume->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }

  auto state = BuildVolumeStateMap(stream_name);
  EmitVolumeChange(state, old_vol, "muteChange");
  return state;
}

double XueHuaNaviteVolumeControllerPlugin::ReadProcessAppVolume() {
  ScopedComInitializer com;
  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioSessionManager *session_manager = nullptr;
  ISimpleAudioVolume *simple_volume = nullptr;
  float level = 1.0f;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (SUCCEEDED(hr) && enumerator) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    if (SUCCEEDED(hr) && device) {
      hr = device->Activate(__uuidof(IAudioSessionManager), CLSCTX_ALL, nullptr,
                            reinterpret_cast<void **>(&session_manager));
      if (SUCCEEDED(hr) && session_manager) {
        hr = session_manager->GetSimpleAudioVolume(nullptr, FALSE,
                                                   &simple_volume);
        if (SUCCEEDED(hr) && simple_volume) {
          simple_volume->GetMasterVolume(&level);
          simple_volume->Release();
        }
        session_manager->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }
  return std::clamp(static_cast<double>(level), 0.0, 1.0);
}

double XueHuaNaviteVolumeControllerPlugin::WriteProcessAppVolume(
    double target_volume) {
  ScopedComInitializer com;
  double clamped = std::clamp(target_volume, 0.0, 1.0);
  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioSessionManager *session_manager = nullptr;
  ISimpleAudioVolume *simple_volume = nullptr;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (SUCCEEDED(hr) && enumerator) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    if (SUCCEEDED(hr) && device) {
      hr = device->Activate(__uuidof(IAudioSessionManager), CLSCTX_ALL, nullptr,
                            reinterpret_cast<void **>(&session_manager));
      if (SUCCEEDED(hr) && session_manager) {
        hr = session_manager->GetSimpleAudioVolume(nullptr, FALSE,
                                                   &simple_volume);
        if (SUCCEEDED(hr) && simple_volume) {
          simple_volume->SetMasterVolume(static_cast<float>(clamped), nullptr);
          simple_volume->Release();
        }
        session_manager->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }
  return ReadProcessAppVolume();
}

flutter::EncodableList XueHuaNaviteVolumeControllerPlugin::ListOutputDevices() {
  ScopedComInitializer com;
  flutter::EncodableList list;
  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDeviceCollection *collection = nullptr;
  IMMDevice *default_device = nullptr;
  std::wstring default_id;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (FAILED(hr) || !enumerator) return list;

  if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia,
                                                    &default_device)) &&
      default_device) {
    LPWSTR raw_id = nullptr;
    if (SUCCEEDED(default_device->GetId(&raw_id)) && raw_id) {
      default_id = raw_id;
      CoTaskMemFree(raw_id);
    }
    default_device->Release();
  }

  if (SUCCEEDED(enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE,
                                               &collection)) &&
      collection) {
    UINT count = 0;
    collection->GetCount(&count);
    for (UINT i = 0; i < count; ++i) {
      IMMDevice *dev = nullptr;
      if (SUCCEEDED(collection->Item(i, &dev)) && dev) {
        std::wstring dev_id;
        LPWSTR raw_id = nullptr;
        if (SUCCEEDED(dev->GetId(&raw_id)) && raw_id) {
          dev_id = raw_id;
          CoTaskMemFree(raw_id);
        }

        std::string friendly_name = "Windows Audio Output";
        IPropertyStore *props = nullptr;
        if (SUCCEEDED(dev->OpenPropertyStore(STGM_READ, &props)) && props) {
          PROPVARIANT var_name;
          PropVariantInit(&var_name);
          if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &var_name)) &&
              var_name.vt == VT_LPWSTR && var_name.pwszVal) {
            friendly_name = WideToUtf8(var_name.pwszVal);
          }
          PropVariantClear(&var_name);
          props->Release();
        }

        float dev_vol = 0.5f;
        BOOL dev_muted = FALSE;
        IAudioEndpointVolume *ep_vol = nullptr;
        if (SUCCEEDED(dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                                    nullptr,
                                    reinterpret_cast<void **>(&ep_vol))) &&
            ep_vol) {
          ep_vol->GetMasterVolumeLevelScalar(&dev_vol);
          ep_vol->GetMute(&dev_muted);
          ep_vol->Release();
        }

        flutter::EncodableMap dev_map;
        dev_map[flutter::EncodableValue("id")] =
            flutter::EncodableValue(WideToUtf8(dev_id));
        dev_map[flutter::EncodableValue("name")] =
            flutter::EncodableValue(friendly_name);
        dev_map[flutter::EncodableValue("route")] =
            flutter::EncodableValue(ClassifyWindowsDeviceRoute(friendly_name));
        dev_map[flutter::EncodableValue("isDefault")] =
            flutter::EncodableValue(dev_id == default_id);
        dev_map[flutter::EncodableValue("isOutput")] =
            flutter::EncodableValue(true);
        dev_map[flutter::EncodableValue("isInput")] =
            flutter::EncodableValue(false);
        dev_map[flutter::EncodableValue("volume")] =
            flutter::EncodableValue(static_cast<double>(dev_vol));
        dev_map[flutter::EncodableValue("isMuted")] =
            flutter::EncodableValue(dev_muted != FALSE);

        list.push_back(flutter::EncodableValue(dev_map));
        dev->Release();
      }
    }
    collection->Release();
  }
  enumerator->Release();
  return list;
}

bool XueHuaNaviteVolumeControllerPlugin::SelectDefaultOutputDevice(
    const std::string &device_id) {
  if (device_id.empty()) return false;
  ScopedComInitializer com;
  std::wstring wide_id = Utf8ToWide(device_id);
  IPolicyConfig *policy_config = nullptr;
  HRESULT hr = CoCreateInstance(
      __uuidof(CPolicyConfigClient), nullptr, CLSCTX_ALL,
      __uuidof(IPolicyConfig), reinterpret_cast<void **>(&policy_config));
  if (SUCCEEDED(hr) && policy_config) {
    HRESULT r1 = policy_config->SetDefaultEndpoint(wide_id.c_str(), eConsole);
    HRESULT r2 =
        policy_config->SetDefaultEndpoint(wide_id.c_str(), eMultimedia);
    HRESULT r3 =
        policy_config->SetDefaultEndpoint(wide_id.c_str(), eCommunications);
    policy_config->Release();
    return SUCCEEDED(r1) || SUCCEEDED(r2) || SUCCEEDED(r3);
  }
  return false;
}

flutter::EncodableMap XueHuaNaviteVolumeControllerPlugin::BuildVolumeStateMap(
    const std::string &stream_name) {
  ScopedComInitializer com;
  float vol_scalar = 0.5f;
  float vol_db = 0.0f;
  BOOL muted = FALSE;
  UINT current_step = 50;
  UINT step_count = 100;
  std::string device_name = "Windows Default Speaker";
  std::string device_id = "default";

  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioEndpointVolume *endpoint_volume = nullptr;

  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));
  if (SUCCEEDED(hr) && enumerator) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &device);
    if (SUCCEEDED(hr) && device) {
      LPWSTR raw_id = nullptr;
      if (SUCCEEDED(device->GetId(&raw_id)) && raw_id) {
        device_id = WideToUtf8(raw_id);
        CoTaskMemFree(raw_id);
      }

      IPropertyStore *props = nullptr;
      if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &props)) && props) {
        PROPVARIANT var_name;
        PropVariantInit(&var_name);
        if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &var_name)) &&
            var_name.vt == VT_LPWSTR && var_name.pwszVal) {
          device_name = WideToUtf8(var_name.pwszVal);
        }
        PropVariantClear(&var_name);
        props->Release();
      }

      hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                            reinterpret_cast<void **>(&endpoint_volume));
      if (SUCCEEDED(hr) && endpoint_volume) {
        endpoint_volume->GetMasterVolumeLevelScalar(&vol_scalar);
        endpoint_volume->GetMasterVolumeLevel(&vol_db);
        endpoint_volume->GetMute(&muted);
        endpoint_volume->GetVolumeStepInfo(&current_step, &step_count);
        endpoint_volume->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }

  double normalized = std::clamp(static_cast<double>(vol_scalar), 0.0, 1.0);
  bool is_muted = (muted != FALSE) || (normalized <= 0.0001);
  last_known_volume_ = normalized;
  if (!is_muted && normalized > 0.0001) {
    pre_mute_volume_ = normalized;
  }

  flutter::EncodableMap map;
  map[flutter::EncodableValue("volume")] = flutter::EncodableValue(normalized);
  map[flutter::EncodableValue("isMuted")] = flutter::EncodableValue(is_muted);
  map[flutter::EncodableValue("streamType")] =
      flutter::EncodableValue(stream_name);
  map[flutter::EncodableValue("stepIndex")] =
      flutter::EncodableValue(static_cast<int32_t>(current_step));
  map[flutter::EncodableValue("maxSteps")] = flutter::EncodableValue(
      static_cast<int32_t>(step_count > 0 ? step_count : 100));
  map[flutter::EncodableValue("minSteps")] = flutter::EncodableValue(0);
  map[flutter::EncodableValue("volumeDb")] =
      flutter::EncodableValue(static_cast<double>(vol_db));
  map[flutter::EncodableValue("ringerMode")] = flutter::EncodableValue(
      is_muted ? std::string("silent") : std::string("normal"));
  map[flutter::EncodableValue("outputDeviceName")] =
      flutter::EncodableValue(device_name);
  map[flutter::EncodableValue("outputRoute")] =
      flutter::EncodableValue(ClassifyWindowsDeviceRoute(device_name));
  map[flutter::EncodableValue("outputDeviceId")] =
      flutter::EncodableValue(device_id);
  return map;
}

flutter::EncodableMap
XueHuaNaviteVolumeControllerPlugin::BuildCapabilitiesMap() {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("platform")] =
      flutter::EncodableValue(std::string("windows"));
  map[flutter::EncodableValue("supportsSystemVolumeControl")] =
      flutter::EncodableValue(true);
  map[flutter::EncodableValue("supportsMuteControl")] =
      flutter::EncodableValue(true);
  map[flutter::EncodableValue("supportsVolumeChangeListening")] =
      flutter::EncodableValue(true);
  map[flutter::EncodableValue("supportsHardwareButtonInterception")] =
      flutter::EncodableValue(false);
  map[flutter::EncodableValue("supportsSystemUIControl")] =
      flutter::EncodableValue(false);
  map[flutter::EncodableValue("supportsMultipleStreamTypes")] =
      flutter::EncodableValue(false);
  map[flutter::EncodableValue("supportsRingerMode")] =
      flutter::EncodableValue(false);
  map[flutter::EncodableValue("supportsAudioDeviceListing")] =
      flutter::EncodableValue(true);
  map[flutter::EncodableValue("supportsDeviceSelection")] =
      flutter::EncodableValue(true);
  map[flutter::EncodableValue("supportsAppVolumeControl")] =
      flutter::EncodableValue(true);

  flutter::EncodableList streams = {flutter::EncodableValue("media")};
  map[flutter::EncodableValue("supportedStreams")] =
      flutter::EncodableValue(streams);
  map[flutter::EncodableValue("audioBackend")] = flutter::EncodableValue(
      std::string("Windows CoreAudio (MMDeviceAPI / IAudioEndpointVolume)"));

  flutter::EncodableList notes = {
      flutter::EncodableValue(std::string(
          "Controls system master volume and dB attenuation via IAudioEndpointVolume.")),
      flutter::EncodableValue(std::string(
          "Supports independent per-application volume via ISimpleAudioVolume (getAppVolume / setAppVolume).")),
      flutter::EncodableValue(std::string(
          "Supports enumerating and switching active audio output endpoints."))};
  map[flutter::EncodableValue("platformNotes")] =
      flutter::EncodableValue(notes);
  return map;
}

void XueHuaNaviteVolumeControllerPlugin::StartEndpointObservation() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (is_observing_) return;
  is_observing_ = true;
  notification_client_ = new VolumeEndpointNotificationClient(this);
  notification_client_->Attach();
}

void XueHuaNaviteVolumeControllerPlugin::StopEndpointObservation() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!is_observing_) return;
  is_observing_ = false;
  if (notification_client_) {
    notification_client_->Detach();
    notification_client_->Release();
    notification_client_ = nullptr;
  }
}

void XueHuaNaviteVolumeControllerPlugin::NotifyVolumeChangedFromCallback(
    float new_volume, bool /*new_muted*/) {
  double prev_vol = last_known_volume_;
  last_known_volume_ = std::clamp(static_cast<double>(new_volume), 0.0, 1.0);
  auto state = BuildVolumeStateMap(default_stream_name_);
  EmitVolumeChange(state, prev_vol, "system");
}

void XueHuaNaviteVolumeControllerPlugin::NotifyDefaultDeviceChangedFromCallback() {
  double prev_vol = last_known_volume_;
  auto state = BuildVolumeStateMap(default_stream_name_);
  EmitVolumeChange(state, prev_vol, "routeChange");
}

void XueHuaNaviteVolumeControllerPlugin::EmitVolumeChange(
    const flutter::EncodableMap &state_map, double old_volume,
    const std::string &reason) {
  if (!channel_) return;
  auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::system_clock::now().time_since_epoch())
                    .count();
  flutter::EncodableMap event;
  event[flutter::EncodableValue("state")] = flutter::EncodableValue(state_map);
  event[flutter::EncodableValue("oldVolume")] =
      flutter::EncodableValue(old_volume);
  event[flutter::EncodableValue("reason")] = flutter::EncodableValue(reason);
  event[flutter::EncodableValue("timestamp")] =
      flutter::EncodableValue(static_cast<int64_t>(now_ms));

  channel_->InvokeMethod("onVolumeChanged",
                         std::make_unique<flutter::EncodableValue>(event));
}

}  // namespace xue_hua_navite_volume_controller
