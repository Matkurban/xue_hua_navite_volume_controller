import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Displays the runtime [VolumeCapabilities] matrix of the host platform.
class CapabilitiesCard extends StatelessWidget {
  const CapabilitiesCard({super.key, required this.store});

  final VolumeDashboardStore store;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (BuildContext context) {
        final VolumeCapabilities? caps = store.capabilities.value;
        if (caps == null) return const SizedBox.shrink();

        final List<MapEntry<String, bool>> badges = <MapEntry<String, bool>>[
          MapEntry<String, bool>(
            'System Volume',
            caps.supportsSystemVolumeControl,
          ),
          MapEntry<String, bool>('Mute Control', caps.supportsMuteControl),
          MapEntry<String, bool>(
            'Live Listener',
            caps.supportsVolumeChangeListening,
          ),
          MapEntry<String, bool>(
            'Multi-Stream',
            caps.supportsMultipleStreamTypes,
          ),
          MapEntry<String, bool>('Ringer Mode', caps.supportsRingerMode),
          MapEntry<String, bool>('System UI HUD', caps.supportsSystemUIControl),
          MapEntry<String, bool>(
            'HW Key Intercept',
            caps.supportsHardwareButtonInterception,
          ),
          MapEntry<String, bool>(
            'Device Listing',
            caps.supportsAudioDeviceListing,
          ),
          MapEntry<String, bool>(
            'Device Switching',
            caps.supportsDeviceSelection,
          ),
          MapEntry<String, bool>(
            'Per-App Volume',
            caps.supportsAppVolumeControl,
          ),
        ];

        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionTitle(
                'Platform Capabilities (${caps.platform.toUpperCase()})',
              ),
              if (caps.audioBackend != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Native Audio Backend: ${caps.audioBackend}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final MapEntry<String, bool> entry in badges)
                    Chip(
                      avatar: Icon(
                        entry.value ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: entry.value ? Colors.green : Colors.grey,
                      ),
                      label: Text(entry.key),
                    ),
                ],
              ),
              if (caps.platformNotes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                for (final String note in caps.platformNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $note',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
