import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../state/volume_dashboard_store.dart';
import '../widgets/app_volume_card.dart';
import '../widgets/behavior_options_card.dart';
import '../widgets/capabilities_card.dart';
import '../widgets/event_log_card.dart';
import '../widgets/multi_stream_mixer_card.dart';
import '../widgets/output_devices_card.dart';
import '../widgets/primary_volume_card.dart';
import '../widgets/ringer_dnd_card.dart';

/// Interactive dashboard showcasing master volume, multi-stream sliders,
/// ringer & DND controls, hardware volume button interception, audio output
/// device routing, per-app volume / WebAudio GainNode boost, and live event logs.
///
/// The page itself never calls `setState`; each section subscribes only to the
/// signals it reads through `SignalBuilder`.
class VolumeDashboardPage extends StatefulWidget {
  const VolumeDashboardPage({super.key, this.store});

  /// Optional externally owned store (useful for tests).
  final VolumeDashboardStore? store;

  @override
  State<VolumeDashboardPage> createState() => _VolumeDashboardPageState();
}

class _VolumeDashboardPageState extends State<VolumeDashboardPage> {
  late final VolumeDashboardStore _store;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? VolumeDashboardStore();
    _store.initialize();
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XueHua Volume Controller v1.0.0'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh State & Devices',
            icon: const Icon(Icons.refresh),
            onPressed: _store.refresh,
          ),
        ],
      ),
      // Only depends on `isLoading`; the list below is built once and every
      // card refreshes itself independently.
      body: SignalBuilder(
        builder: (BuildContext context) {
          if (_store.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              PrimaryVolumeCard(store: _store),
              BehaviorOptionsCard(store: _store),
              MultiStreamMixerCard(store: _store),
              RingerDndCard(store: _store),
              AppVolumeCard(store: _store),
              OutputDevicesCard(store: _store),
              CapabilitiesCard(store: _store),
              EventLogCard(store: _store),
            ],
          );
        },
      ),
    );
  }
}
