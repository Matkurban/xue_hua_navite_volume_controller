import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelXueHuaNaviteVolumeController platform =
      MethodChannelXueHuaNaviteVolumeController();
  const MethodChannel channel = MethodChannel(
    'xue_hua_navite_volume_controller',
  );

  double mockVolume = 0.6;
  bool mockMuted = false;
  String mockRinger = 'normal';
  double mockAppVolume = 0.85;

  setUp(() {
    mockVolume = 0.6;
    mockMuted = false;
    mockRinger = 'normal';
    mockAppVolume = 0.85;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          final args = methodCall.arguments as Map<Object?, Object?>?;
          switch (methodCall.method) {
            case 'initialize':
            case 'getVolumeState':
              return <String, Object?>{
                'volume': mockVolume,
                'isMuted': mockMuted,
                'streamType': (args?['streamType'] as String?) ?? 'media',
                'stepIndex': (mockVolume * 15).round(),
                'maxSteps': 15,
                'minSteps': 0,
                'ringerMode': mockRinger,
                'outputDeviceName': 'Mock Studio Monitor',
                'outputRoute': 'speaker',
                'outputDeviceId': 'mock_speaker_1',
              };
            case 'getCapabilities':
              return <String, Object?>{
                'platform': 'android',
                'supportsSystemVolumeControl': true,
                'supportsMuteControl': true,
                'supportsVolumeChangeListening': true,
                'supportsHardwareButtonInterception': true,
                'supportsSystemUIControl': true,
                'supportsMultipleStreamTypes': true,
                'supportsRingerMode': true,
                'supportsAudioDeviceListing': true,
                'supportsDeviceSelection': true,
                'supportsAppVolumeControl': true,
                'supportedStreams': <String>[
                  'media',
                  'ring',
                  'alarm',
                  'notification',
                ],
                'audioBackend': 'Mock AudioManager',
                'platformNotes': <String>['Mock test backend'],
              };
            case 'getVolume':
              return mockVolume;
            case 'setVolume':
              mockVolume = (args?['volume'] as num?)?.toDouble() ?? 0.5;
              mockMuted = mockVolume <= 0.0001;
              return <String, Object?>{
                'volume': mockVolume,
                'isMuted': mockMuted,
                'streamType': (args?['streamType'] as String?) ?? 'media',
                'stepIndex': (mockVolume * 15).round(),
                'maxSteps': 15,
                'minSteps': 0,
                'ringerMode': mockRinger,
              };
            case 'adjustVolume':
              final delta = (args?['delta'] as num?)?.toDouble() ?? 0.0;
              mockVolume = (mockVolume + delta).clamp(0.0, 1.0);
              return <String, Object?>{
                'volume': mockVolume,
                'isMuted': mockMuted,
                'streamType': (args?['streamType'] as String?) ?? 'media',
              };
            case 'stepVolume':
              final dir = (args?['direction'] as String?) ?? 'up';
              if (dir == 'mute') {
                mockMuted = !mockMuted;
              } else {
                mockVolume = (mockVolume + (dir == 'up' ? 0.05 : -0.05)).clamp(
                  0.0,
                  1.0,
                );
              }
              return <String, Object?>{
                'volume': mockVolume,
                'isMuted': mockMuted,
                'streamType': (args?['streamType'] as String?) ?? 'media',
              };
            case 'getAllStreamVolumes':
              return <String, double>{
                'media': mockVolume,
                'ring': 0.8,
                'alarm': 1.0,
              };
            case 'isMuted':
              return mockMuted;
            case 'setMute':
              mockMuted = (args?['muted'] as bool?) ?? false;
              return <String, Object?>{
                'volume': mockMuted ? 0.0 : mockVolume,
                'isMuted': mockMuted,
                'streamType': (args?['streamType'] as String?) ?? 'media',
              };
            case 'toggleMute':
              mockMuted = !mockMuted;
              return <String, Object?>{
                'volume': mockMuted ? 0.0 : mockVolume,
                'isMuted': mockMuted,
                'streamType': (args?['streamType'] as String?) ?? 'media',
              };
            case 'getRingerMode':
              return mockRinger;
            case 'setRingerMode':
              mockRinger = (args?['ringerMode'] as String?) ?? 'normal';
              return mockRinger;
            case 'hasDoNotDisturbAccess':
            case 'requestDoNotDisturbAccess':
              return true;
            case 'getOutputDevices':
              return <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'mock_speaker_1',
                  'name': 'Mock Studio Monitor',
                  'route': 'speaker',
                  'isDefault': true,
                  'isOutput': true,
                  'isInput': false,
                  'volume': mockVolume,
                  'isMuted': mockMuted,
                },
              ];
            case 'getCurrentOutputDevice':
              return <String, Object?>{
                'id': 'mock_speaker_1',
                'name': 'Mock Studio Monitor',
                'route': 'speaker',
                'isDefault': true,
                'isOutput': true,
                'isInput': false,
              };
            case 'setOutputDevice':
              return true;
            case 'getAppVolume':
              return mockAppVolume;
            case 'setAppVolume':
              mockAppVolume = (args?['volume'] as num?)?.toDouble() ?? 1.0;
              return mockAppVolume;
            case 'setShowSystemUI':
            case 'setInterceptHardwareButtons':
            case 'dispose':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize and getCapabilities return expected values', () async {
    final state = await platform.initialize();
    expect(state.volume, closeTo(0.6, 0.001));
    expect(state.isMuted, isFalse);
    expect(state.outputDeviceName, 'Mock Studio Monitor');

    final caps = await platform.getCapabilities();
    expect(caps.platform, 'android');
    expect(caps.supportsMultipleStreamTypes, isTrue);
    expect(caps.supportedStreams, contains(VolumeStreamType.ring));
  });

  test(
    'setVolume, adjustVolume, stepVolume, and mute operations work',
    () async {
      final afterSet = await platform.setVolume(0.35);
      expect(afterSet.volume, closeTo(0.35, 0.001));

      final afterAdjust = await platform.adjustVolume(0.15);
      expect(afterAdjust.volume, closeTo(0.50, 0.001));

      final afterStep = await platform.stepVolume(VolumeDirection.up);
      expect(afterStep.volume, closeTo(0.55, 0.001));

      final mutedState = await platform.setMute(true);
      expect(mutedState.isMuted, isTrue);

      final toggledState = await platform.toggleMute();
      expect(toggledState.isMuted, isFalse);
    },
  );

  test(
    'getAllStreamVolumes, ringerMode, outputDevices, and appVolume work',
    () async {
      final streams = await platform.getAllStreamVolumes();
      expect(streams[VolumeStreamType.alarm], closeTo(1.0, 0.001));

      final mode = await platform.setRingerMode(RingerMode.vibrate);
      expect(mode, RingerMode.vibrate);

      final devices = await platform.getOutputDevices();
      expect(devices, hasLength(1));
      expect(devices.first.name, 'Mock Studio Monitor');

      final switched = await platform.setOutputDevice('mock_speaker_1');
      expect(switched, isTrue);

      final appVol = await platform.setAppVolume(0.42);
      expect(appVol, closeTo(0.42, 0.001));
    },
  );
}
