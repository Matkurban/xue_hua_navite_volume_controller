import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Primary volume card: percentage header, mute toggle, slider, presets and
/// step buttons for the selected stream.
class PrimaryVolumeCard extends StatelessWidget {
  const PrimaryVolumeCard({super.key, required this.store});

  final VolumeDashboardStore store;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SectionCard(
      outlined: false,
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Rebuilds only when percentage / mute flag change.
              SignalBuilder(
                builder: (BuildContext context) {
                  final int pct = store.percentage.value;
                  final IconData icon = store.isMuted.value || pct == 0
                      ? Icons.volume_off_rounded
                      : pct < 50
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded;
                  return CircleAvatar(
                    radius: 26,
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    child: Icon(icon, size: 28),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SignalBuilder(
                  builder: (BuildContext context) {
                    final VolumeState state = store.volumeState.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${state.percentage}% ${state.isMuted ? "(MUTED)" : ""}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Device: ${state.outputDeviceName ?? "Default Output"} '
                          '[${state.outputRoute.wireName}]'
                          '${state.volumeDb != null ? " • ${state.volumeDb!.toStringAsFixed(1)} dB" : ""}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Rebuilds only when the mute flag flips.
              SignalBuilder(
                builder: (BuildContext context) {
                  final bool muted = store.isMuted.value;
                  return FilledButton.tonalIcon(
                    onPressed: store.toggleMute,
                    icon: Icon(muted ? Icons.volume_up : Icons.volume_off),
                    label: Text(muted ? 'Unmute' : 'Mute'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (BuildContext context) {
              final VolumeState state = store.volumeState.value;
              return Slider(
                value: state.volume.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                divisions: state.maxSteps != null && state.maxSteps! > 0
                    ? state.maxSteps
                    : 100,
                label: '${state.percentage}%',
                onChanged: store.setVolume,
              );
            },
          ),
          // Static controls: never rebuilt by signal changes.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              for (final double preset in const <double>[
                0.0,
                0.25,
                0.5,
                0.75,
                1.0,
              ])
                ActionChip(
                  label: Text('${(preset * 100).round()}%'),
                  onPressed: () => store.setVolume(preset),
                ),
              OutlinedButton.icon(
                onPressed: store.volumeDown,
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('Step -'),
              ),
              OutlinedButton.icon(
                onPressed: store.volumeUp,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Step +'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
