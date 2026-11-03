import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Lists audio output devices and allows switching the active route.
class OutputDevicesCard extends StatelessWidget {
  const OutputDevicesCard({super.key, required this.store});

  final VolumeDashboardStore store;

  static IconData _iconFor(AudioOutputRoute route) {
    switch (route) {
      case AudioOutputRoute.bluetooth:
        return Icons.bluetooth_audio;
      case AudioOutputRoute.wiredHeadset:
        return Icons.headphones;
      case AudioOutputRoute.usb:
        return Icons.usb;
      case AudioOutputRoute.hdmi:
        return Icons.tv;
      default:
        return Icons.speaker;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: SignalBuilder(
        builder: (BuildContext context) {
          final List<AudioDeviceInfo> devices = store.outputDevices.value;
          final bool canSelect =
              store.capabilities.value?.supportsDeviceSelection ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionTitle('Audio Output Devices (${devices.length})'),
              const SizedBox(height: 8),
              if (devices.isEmpty)
                const Text('No output devices reported.')
              else
                for (final AudioDeviceInfo device in devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_iconFor(device.route)),
                    title: Text(device.name),
                    subtitle: Text(
                      'Route: ${device.route.wireName} • ID: ${device.id}',
                    ),
                    trailing: device.isDefault
                        ? const Chip(label: Text('Active'))
                        : canSelect
                        ? OutlinedButton(
                            onPressed: () => store.selectOutputDevice(device),
                            child: const Text('Switch'),
                          )
                        : null,
                  ),
            ],
          );
        },
      ),
    );
  }
}
