#include "include/xue_hua_navite_volume_controller/xue_hua_navite_volume_controller_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xue_hua_navite_volume_controller_plugin.h"

void XueHuaNaviteVolumeControllerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_navite_volume_controller::XueHuaNaviteVolumeControllerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
