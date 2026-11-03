import 'package:material_ui/material_ui.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const VolumeDashboardPage(),
    );
  }
}
