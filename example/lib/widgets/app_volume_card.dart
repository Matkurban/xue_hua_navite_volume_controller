import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Per-application volume slider and (Web only) WebAudio gain boost slider.
class AppVolumeCard extends StatelessWidget {
  const AppVolumeCard({super.key, required this.store});

  final VolumeDashboardStore store;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionTitle('Per-Application Volume & WebAudio Gain Boost'),
          const SizedBox(height: 8),
          SignalBuilder(
            builder: (BuildContext context) {
              final double value = store.appVolume.value;
              return Row(
                children: <Widget>[
                  const SizedBox(width: 110, child: Text('App Volume:')),
                  Expanded(
                    child: Slider(
                      value: value.clamp(0.0, 1.0),
                      onChanged: store.setAppVolume,
                    ),
                  ),
                  SizedBox(width: 48, child: Text('${(value * 100).round()}%')),
                ],
              );
            },
          ),
          if (kIsWeb)
            SignalBuilder(
              builder: (BuildContext context) {
                final double value = store.webGainBoost.value;
                return Row(
                  children: <Widget>[
                    const SizedBox(width: 110, child: Text('Web Gain Boost:')),
                    Expanded(
                      child: Slider(
                        value: value.clamp(0.0, 4.0),
                        min: 0.0,
                        max: 4.0,
                        divisions: 40,
                        label: '${(value * 100).round()}%',
                        onChanged: store.setWebGainBoost,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('${(value * 100).round()}%'),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
