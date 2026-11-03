import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'xue_hua_navite_volume_controller_method_channel.dart';

abstract class XueHuaNaviteVolumeControllerPlatform extends PlatformInterface {
  /// Constructs a XueHuaNaviteVolumeControllerPlatform.
  XueHuaNaviteVolumeControllerPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteVolumeControllerPlatform _instance = MethodChannelXueHuaNaviteVolumeController();

  /// The default instance of [XueHuaNaviteVolumeControllerPlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteVolumeController].
  static XueHuaNaviteVolumeControllerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteVolumeControllerPlatform] when
  /// they register themselves.
  static set instance(XueHuaNaviteVolumeControllerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
