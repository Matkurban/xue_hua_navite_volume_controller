import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Native volume HUD visibility & hardware button interception switches.
class BehaviorOptionsCard extends StatelessWidget {
  const BehaviorOptionsCard({super.key, required this.store});

  final VolumeDashboardStore store;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionTitle('Controller Behavior & Hardware Keys'),
          const SizedBox(height: 8),
          SignalBuilder(
            builder: (BuildContext context) {
              final caps = store.capabilities.value;
              final bool supportsHud = caps?.supportsSystemUIControl ?? false;
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Native System Volume HUD Overlay'),
                subtitle: Text(
                  supportsHud
                      ? 'Supported on this platform (Android FLAG_SHOW_UI / iOS MPVolumeView)'
                      : 'Not applicable on ${caps?.platform ?? "this platform"}',
                ),
                value: store.showSystemUI.value,
                onChanged: supportsHud ? store.setShowSystemUI : null,
              );
            },
          ),
          SignalBuilder(
            builder: (BuildContext context) {
              final bool supportsIntercept =
                  store
                      .capabilities
                      .value
                      ?.supportsHardwareButtonInterception ??
                  false;
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Intercept Physical Hardware Volume Buttons'),
                subtitle: Text(
                  supportsIntercept
                      ? 'Captures Volume Up/Down keys into onHardwareButton without changing system volume'
                      : 'Only supported on Android physical devices',
                ),
                value: store.interceptHardwareButtons.value,
                onChanged: supportsIntercept
                    ? store.setInterceptHardwareButtons
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
