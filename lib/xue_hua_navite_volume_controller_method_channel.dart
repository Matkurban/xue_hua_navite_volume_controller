import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'xue_hua_navite_volume_controller_platform_interface.dart';

/// An implementation of [XueHuaNaviteVolumeControllerPlatform] that uses method channels.
class MethodChannelXueHuaNaviteVolumeController extends XueHuaNaviteVolumeControllerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('xue_hua_navite_volume_controller');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
