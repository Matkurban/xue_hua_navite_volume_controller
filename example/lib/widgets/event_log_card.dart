import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../state/volume_dashboard_store.dart';
import 'section_card.dart';

/// Real-time log of volume change and hardware button events.
class EventLogCard extends StatelessWidget {
  const EventLogCard({super.key, required this.store});

  final VolumeDashboardStore store;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const SectionTitle('Real-Time Event Stream Log'),
              TextButton(
                onPressed: store.clearLogs,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            // Only the log list rebuilds when a new event arrives.
            child: SignalBuilder(
              builder: (BuildContext context) {
                final List<String> logs = store.eventLogs.value;
                if (logs.isEmpty) {
                  return const Center(child: Text('No events recorded yet.'));
                }
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (BuildContext context, int index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
