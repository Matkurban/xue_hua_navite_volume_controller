import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_volume_controller_example/themes/app_theme.dart';

import '../pages/volume_dashboard_page.dart';

/// Comprehensive example app demonstrating all features of
/// `xue_hua_navite_volume_controller` across Android, iOS, macOS, Windows,
/// Linux, and Web.
class VolumeControllerExampleApp extends StatelessWidget {
  const VolumeControllerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XueHua Volume Controller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const VolumeDashboardPage(),
    );
  }
}
