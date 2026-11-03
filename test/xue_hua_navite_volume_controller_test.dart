import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller_platform_interface.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockXueHuaNaviteVolumeControllerPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteVolumeControllerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final XueHuaNaviteVolumeControllerPlatform initialPlatform = XueHuaNaviteVolumeControllerPlatform.instance;

  test('$MethodChannelXueHuaNaviteVolumeController is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelXueHuaNaviteVolumeController>());
  });

  test('getPlatformVersion', () async {
    XueHuaNaviteVolumeController xueHuaNaviteVolumeControllerPlugin = XueHuaNaviteVolumeController();
    MockXueHuaNaviteVolumeControllerPlatform fakePlatform = MockXueHuaNaviteVolumeControllerPlatform();
    XueHuaNaviteVolumeControllerPlatform.instance = fakePlatform;

    expect(await xueHuaNaviteVolumeControllerPlugin.getPlatformVersion(), '42');
  });
}
