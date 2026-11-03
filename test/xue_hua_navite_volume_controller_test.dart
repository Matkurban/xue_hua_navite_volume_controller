import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller_method_channel.dart';

class MockXueHuaNaviteVolumeControllerPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteVolumeControllerPlatform {
  final StreamController<VolumeChangeEvent> volumeController =
      StreamController<VolumeChangeEvent>.broadcast();
  final StreamController<VolumeButtonEvent> buttonController =
      StreamController<VolumeButtonEvent>.broadcast();

  double currentVolume = 0.5;
  bool currentMuted = false;
  RingerMode currentRingerMode = RingerMode.normal;
  double currentAppVolume = 1.0;
  double currentWebBoost = 1.0;

  @override
  Stream<VolumeChangeEvent> get onVolumeChanged => volumeController.stream;

  @override
  Stream<VolumeButtonEvent> get onHardwareButton => buttonController.stream;

  @override
  Future<VolumeState> initialize([
    VolumeControllerConfig config = const VolumeControllerConfig(),
  ]) async {
    return VolumeState(
      volume: currentVolume,
      isMuted: currentMuted,
      streamType: config.defaultStream,
    );
  }

  @override
  Future<VolumeCapabilities> getCapabilities() async {
    return const VolumeCapabilities(
      platform: 'macos',
      supportsSystemVolumeControl: true,
      supportsMuteControl: true,
      supportsVolumeChangeListening: true,
      supportsHardwareButtonInterception: false,
      supportsSystemUIControl: false,
      supportsMultipleStreamTypes: false,
      supportsRingerMode: false,
      supportsAudioDeviceListing: true,
      supportsDeviceSelection: true,
      supportsAppVolumeControl: false,
      supportedStreams: <VolumeStreamType>[VolumeStreamType.media],
      audioBackend: 'CoreAudio',
    );
  }

  @override
  Future<VolumeState> getVolumeState({
    VolumeStreamType stream = VolumeStreamType.media,
  }) async {
    return VolumeState(
      volume: currentVolume,
      isMuted: currentMuted,
      streamType: stream,
    );
  }

  @override
  Future<double> getVolume({
    VolumeStreamType stream = VolumeStreamType.media,
  }) async => currentVolume;

  @override
  Future<VolumeState> setVolume(
    double volume, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    currentVolume = volume.clamp(0.0, 1.0);
    currentMuted = currentVolume <= 0.0001;
    return VolumeState(
      volume: currentVolume,
      isMuted: currentMuted,
      streamType: stream,
    );
  }

  @override
  Future<VolumeState> adjustVolume(
    double delta, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    return setVolume(currentVolume + delta, stream: stream);
  }

  @override
  Future<VolumeState> stepVolume(
    VolumeDirection direction, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    if (direction == VolumeDirection.mute) {
      return toggleMute(stream: stream);
    }
    return adjustVolume(
      direction == VolumeDirection.up ? 0.05 : -0.05,
      stream: stream,
    );
  }

  @override
  Future<Map<VolumeStreamType, double>> getAllStreamVolumes() async {
    return <VolumeStreamType, double>{VolumeStreamType.media: currentVolume};
  }

  @override
  Future<bool> isMuted({
    VolumeStreamType stream = VolumeStreamType.media,
  }) async => currentMuted;

  @override
  Future<VolumeState> setMute(
    bool muted, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    currentMuted = muted;
    return VolumeState(
      volume: currentMuted ? 0.0 : currentVolume,
      isMuted: currentMuted,
      streamType: stream,
    );
  }

  @override
  Future<VolumeState> toggleMute({
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    return setMute(!currentMuted, stream: stream);
  }

  @override
  Future<RingerMode> getRingerMode() async => currentRingerMode;

  @override
  Future<RingerMode> setRingerMode(RingerMode mode) async {
    currentRingerMode = mode;
    return currentRingerMode;
  }

  @override
  Future<bool> hasDoNotDisturbAccess() async => true;

  @override
  Future<bool> requestDoNotDisturbAccess() async => true;

  @override
  Future<void> setShowSystemUI(bool show) async {}

  @override
  Future<void> setInterceptHardwareButtons(bool intercept) async {}

  @override
  Future<List<AudioDeviceInfo>> getOutputDevices() async {
    return const <AudioDeviceInfo>[
      AudioDeviceInfo(
        id: 'dev_1',
        name: 'Built-in Speakers',
        route: AudioOutputRoute.speaker,
        isDefault: true,
      ),
    ];
  }

  @override
  Future<AudioDeviceInfo?> getCurrentOutputDevice() async {
    final list = await getOutputDevices();
    return list.first;
  }

  @override
  Future<bool> setOutputDevice(String deviceId) async => deviceId == 'dev_1';

  @override
  Future<double> getAppVolume() async => currentAppVolume;

  @override
  Future<double> setAppVolume(double volume) async {
    currentAppVolume = volume.clamp(0.0, 1.0);
    return currentAppVolume;
  }

  @override
  Future<double> setWebGainBoost(double gain) async {
    currentWebBoost = gain.clamp(0.0, 4.0);
    return currentWebBoost;
  }

  @override
  Future<double> getWebGainBoost() async => currentWebBoost;

  @override
  Future<void> dispose() async {}
}

void main() {
  final XueHuaNaviteVolumeControllerPlatform initialPlatform =
      XueHuaNaviteVolumeControllerPlatform.instance;

  test(
    '$MethodChannelXueHuaNaviteVolumeController is the default instance',
    () {
      expect(
        initialPlatform,
        isInstanceOf<MethodChannelXueHuaNaviteVolumeController>(),
      );
    },
  );

  test(
    'XueHuaNaviteVolumeController high-level APIs and stateNotifier work',
    () async {
      final controller = XueHuaNaviteVolumeController();
      final fakePlatform = MockXueHuaNaviteVolumeControllerPlatform();
      XueHuaNaviteVolumeControllerPlatform.instance = fakePlatform;

      final initState = await controller.initialize();
      expect(initState.volume, closeTo(0.5, 0.001));
      expect(controller.stateNotifier.value.percentage, 50);

      final updated = await controller.setVolume(0.8);
      expect(updated.percentage, 80);
      expect(controller.stateNotifier.value.percentage, 80);

      final steppedUp = await controller.volumeUp(step: 0.1);
      expect(steppedUp.percentage, 90);

      final steppedDown = await controller.volumeDown(step: 0.2);
      expect(steppedDown.percentage, 70);

      final mutedState = await controller.toggleMute();
      expect(mutedState.isMuted, isTrue);

      final boost = await controller.setWebGainBoost(2.5);
      expect(boost, closeTo(2.5, 0.001));

      await controller.dispose();
    },
  );
}
