import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_volume_controller_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'xue_hua_navite_volume_controller',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'initialize':
            case 'getVolumeState':
              return <String, Object?>{
                'volume': 0.65,
                'isMuted': false,
                'streamType': 'media',
                'stepIndex': 10,
                'maxSteps': 16,
                'minSteps': 0,
                'ringerMode': 'normal',
                'outputDeviceName': 'MacBook Pro Speakers',
                'outputRoute': 'speaker',
                'outputDeviceId': 'default',
              };
            case 'getCapabilities':
              return <String, Object?>{
                'platform': 'macos',
                'supportsSystemVolumeControl': true,
                'supportsMuteControl': true,
                'supportsVolumeChangeListening': true,
                'supportsHardwareButtonInterception': false,
                'supportsSystemUIControl': false,
                'supportsMultipleStreamTypes': false,
                'supportsRingerMode': false,
                'supportsAudioDeviceListing': true,
                'supportsDeviceSelection': true,
                'supportsAppVolumeControl': false,
                'supportedStreams': <String>['media'],
                'audioBackend': 'macOS CoreAudio',
                'platformNotes': <String>['CoreAudio test backend'],
              };
            case 'getAllStreamVolumes':
              return <String, double>{'media': 0.65};
            case 'getOutputDevices':
              return <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'default',
                  'name': 'MacBook Pro Speakers',
                  'route': 'speaker',
                  'isDefault': true,
                  'isOutput': true,
                  'isInput': false,
                  'volume': 0.65,
                  'isMuted': false,
                },
              ];
            case 'getRingerMode':
              return 'normal';
            case 'hasDoNotDisturbAccess':
              return true;
            case 'getAppVolume':
              return 1.0;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('VolumeControllerExampleApp renders dashboard and volume state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VolumeControllerExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('XueHua Volume Controller v1.0.0'), findsOneWidget);
    expect(find.textContaining('65%'), findsWidgets);
    expect(find.textContaining('MacBook Pro Speakers'), findsWidgets);
  });
}
