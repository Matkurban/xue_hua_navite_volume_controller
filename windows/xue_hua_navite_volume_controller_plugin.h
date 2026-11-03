#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <string>

namespace xue_hua_navite_volume_controller {

class VolumeEndpointNotificationClient;

class XueHuaNaviteVolumeControllerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  XueHuaNaviteVolumeControllerPlugin();

  explicit XueHuaNaviteVolumeControllerPlugin(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);

  virtual ~XueHuaNaviteVolumeControllerPlugin();

  // Disallow copy and assign.
  XueHuaNaviteVolumeControllerPlugin(
      const XueHuaNaviteVolumeControllerPlugin &) = delete;
  XueHuaNaviteVolumeControllerPlugin &operator=(
      const XueHuaNaviteVolumeControllerPlugin &) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void NotifyVolumeChangedFromCallback(float new_volume, bool new_muted);
  void NotifyDefaultDeviceChangedFromCallback();

 private:
  flutter::EncodableMap BuildVolumeStateMap(const std::string &stream_name);
  flutter::EncodableMap BuildCapabilitiesMap();
  flutter::EncodableList ListOutputDevices();
  bool SelectDefaultOutputDevice(const std::string &device_id);
  double ReadMasterVolume();
  bool ReadMasterMuted();
  flutter::EncodableMap WriteMasterVolume(double target_volume,
                                          const std::string &stream_name,
                                          const std::string &reason);
  flutter::EncodableMap WriteMasterMuted(bool muted,
                                         const std::string &stream_name);
  double ReadProcessAppVolume();
  double WriteProcessAppVolume(double target_volume);

  void StartEndpointObservation();
  void StopEndpointObservation();
  void EmitVolumeChange(const flutter::EncodableMap &state_map,
                        double old_volume,
                        const std::string &reason);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::string default_stream_name_ = "media";
  double pre_mute_volume_ = 0.5;
  double last_known_volume_ = 0.5;
  bool is_observing_ = false;
  std::mutex mutex_;
  VolumeEndpointNotificationClient *notification_client_ = nullptr;
};

}  // namespace xue_hua_navite_volume_controller

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN_H_
