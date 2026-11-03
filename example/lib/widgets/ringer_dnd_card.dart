import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Android ringer mode selector and Do Not Disturb access status.
class RingerDndCard extends StatelessWidget {
  const RingerDndCard({super.key, required this.store});

  final VolumeDashboardStore store;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (BuildContext context) {
        if (!store.supportsRingerMode.value) {
          return const SizedBox.shrink();
        }
        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const SectionTitle('Ringer Mode & Do Not Disturb'),
                  SignalBuilder(
                    builder: (BuildContext context) => Chip(
                      label: Text(
                        store.hasDndAccess.value
                            ? 'DND Granted'
                            : 'DND Permission Needed',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SignalBuilder(
                builder: (BuildContext context) {
                  final RingerMode mode = store.ringerMode.value;
                  return SegmentedButton<RingerMode>(
                    segments: const <ButtonSegment<RingerMode>>[
                      ButtonSegment<RingerMode>(
                        value: RingerMode.normal,
                        icon: Icon(Icons.notifications_active_outlined),
                        label: Text('Normal'),
                      ),
                      ButtonSegment<RingerMode>(
                        value: RingerMode.vibrate,
                        icon: Icon(Icons.vibration),
                        label: Text('Vibrate'),
                      ),
                      ButtonSegment<RingerMode>(
                        value: RingerMode.silent,
                        icon: Icon(Icons.notifications_off_outlined),
                        label: Text('Silent'),
                      ),
                    ],
                    selected: <RingerMode>{
                      mode == RingerMode.unknown ? RingerMode.normal : mode,
                    },
                    onSelectionChanged: (Set<RingerMode> selection) {
                      if (selection.isNotEmpty) {
                        store.changeRingerMode(selection.first);
                      }
                    },
                  );
                },
              ),
              SignalBuilder(
                builder: (BuildContext context) {
                  if (store.hasDndAccess.value) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: store.requestDndAccess,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text(
                        'Grant Do Not Disturb Access in Settings',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
