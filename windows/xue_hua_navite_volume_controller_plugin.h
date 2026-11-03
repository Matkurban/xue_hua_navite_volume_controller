#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace xue_hua_navite_volume_controller {

class XueHuaNaviteVolumeControllerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  XueHuaNaviteVolumeControllerPlugin();

  virtual ~XueHuaNaviteVolumeControllerPlugin();

  // Disallow copy and assign.
  XueHuaNaviteVolumeControllerPlugin(const XueHuaNaviteVolumeControllerPlugin&) = delete;
  XueHuaNaviteVolumeControllerPlugin& operator=(const XueHuaNaviteVolumeControllerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace xue_hua_navite_volume_controller

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_VOLUME_CONTROLLER_PLUGIN_H_
