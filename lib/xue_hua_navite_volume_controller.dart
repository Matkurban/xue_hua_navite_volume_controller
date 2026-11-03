
import 'xue_hua_navite_volume_controller_platform_interface.dart';

class XueHuaNaviteVolumeController {
  Future<String?> getPlatformVersion() {
    return XueHuaNaviteVolumeControllerPlatform.instance.getPlatformVersion();
  }
}
