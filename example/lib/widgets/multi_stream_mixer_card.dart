import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Android multi-stream mixer. Each row has its own `SignalBuilder`, so
/// dragging one slider only rebuilds that single row.
class MultiStreamMixerCard extends StatelessWidget {
  const MultiStreamMixerCard({super.key, required this.store});

  final VolumeDashboardStore store;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (BuildContext context) {
        if (!store.supportsMultiStream.value) {
          return const SizedBox.shrink();
        }
        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle('Android Multi-Stream Audio Mixer'),
              const SizedBox(height: 12),
              for (final VolumeStreamType stream in VolumeStreamType.values)
                _StreamSliderRow(store: store, stream: stream),
            ],
          ),
        );
      },
    );
  }
}

class _StreamSliderRow extends StatelessWidget {
  const _StreamSliderRow({required this.store, required this.stream});

  final VolumeDashboardStore store;
  final VolumeStreamType stream;

  @override
  Widget build(BuildContext context) {
    final FlutterSignal<double> volume = store.streamVolumes[stream]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              stream.wireName.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            child: SignalBuilder(
              builder: (BuildContext context) => Slider(
                value: volume.value.clamp(0.0, 1.0),
                onChanged: (double v) => store.setStreamVolume(stream, v),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: SignalBuilder(
              builder: (BuildContext context) => Text(
                '${(volume.value * 100).round()}%',
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
