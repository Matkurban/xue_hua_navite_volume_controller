import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize and query volume capabilities on host platform', (
    WidgetTester tester,
  ) async {
    final controller = XueHuaNaviteVolumeController.instance;
    final state = await controller.initialize();
    expect(state.volume, inInclusiveRange(0.0, 1.0));

    final capabilities = await controller.getCapabilities();
    expect(capabilities.platform.isNotEmpty, isTrue);
    expect(capabilities.supportedStreams, isNotEmpty);
  });
}
