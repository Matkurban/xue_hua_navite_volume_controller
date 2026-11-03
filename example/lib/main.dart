import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VolumeControllerExampleApp());
}

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
      home: const VolumeControllerDashboardPage(),
    );
  }
}

/// Interactive dashboard showcasing master volume, multi-stream sliders,
/// ringer & DND controls, hardware volume button interception, audio output
/// device routing, per-app volume / WebAudio GainNode boost, and live event logs.
class VolumeControllerDashboardPage extends StatefulWidget {
  const VolumeControllerDashboardPage({super.key});

  @override
  State<VolumeControllerDashboardPage> createState() =>
      _VolumeControllerDashboardPageState();
}

class _VolumeControllerDashboardPageState
    extends State<VolumeControllerDashboardPage>
    with VolumeControllerListener {
  final XueHuaNaviteVolumeController _controller =
      XueHuaNaviteVolumeController.instance;

  VolumeCapabilities? _capabilities;
  VolumeState _state = const VolumeState(volume: 0.5, isMuted: false);
  Map<VolumeStreamType, double> _streamVolumes = <VolumeStreamType, double>{};
  List<AudioDeviceInfo> _outputDevices = const <AudioDeviceInfo>[];
  RingerMode _ringerMode = RingerMode.normal;
  bool _hasDndAccess = true;
  bool _showSystemUI = false;
  bool _interceptHardwareButtons = false;
  double _appVolume = 1.0;
  double _webGainBoost = 1.0;
  final VolumeStreamType _selectedStream = VolumeStreamType.media;
  bool _isLoading = true;
  final List<String> _eventLogs = <String>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(this);
    _initializeAll();
  }

  @override
  void dispose() {
    _controller.removeListener(this);
    super.dispose();
  }

  void _appendLog(String message) {
    if (!mounted) return;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    setState(() {
      _eventLogs.insert(0, '[$timeStr] $message');
      if (_eventLogs.length > 60) {
        _eventLogs.removeLast();
      }
    });
  }

  @override
  void onVolumeChanged(VolumeChangeEvent event) {
    if (!mounted) return;
    setState(() {
      _state = event.state;
      _ringerMode = event.state.ringerMode;
      _streamVolumes[event.state.streamType] = event.state.volume;
    });
    _appendLog(
      'VolumeChanged (${event.reason}): '
      '${event.state.streamType.wireName} -> ${event.state.percentage}% '
      '(muted: ${event.state.isMuted}, device: ${event.state.outputDeviceName ?? "default"})',
    );
  }

  @override
  void onHardwareVolumeButtonPressed(VolumeButtonEvent event) {
    _appendLog(
      'HardwareButton: ${event.direction.wireName.toUpperCase()} '
      '[${event.action.wireName}] (intercepted=${event.intercepted})',
    );
  }

  Future<void> _initializeAll() async {
    setState(() => _isLoading = true);
    try {
      final initialState = await _controller.initialize(
        VolumeControllerConfig(
          defaultStream: _selectedStream,
          showSystemUI: _showSystemUI,
          interceptHardwareButtons: _interceptHardwareButtons,
          listenToVolumeChanges: true,
        ),
      );
      final caps = await _controller.getCapabilities();
      final streams = await _controller.getAllStreamVolumes();
      final devices = await _controller.getOutputDevices();
      final ringer = await _controller.getRingerMode();
      final dnd = await _controller.hasDoNotDisturbAccess();
      final appVol = await _controller.getAppVolume();
      final webBoost = await _controller.getWebGainBoost();

      if (!mounted) return;
      setState(() {
        _state = initialState;
        _capabilities = caps;
        _streamVolumes = Map<VolumeStreamType, double>.from(streams);
        _outputDevices = devices;
        _ringerMode = ringer;
        _hasDndAccess = dnd;
        _appVolume = appVol;
        _webGainBoost = webBoost;
        _isLoading = false;
      });
      _appendLog(
        'Initialized on ${caps.platform} (${caps.audioBackend ?? "native"}) - '
        'Initial volume: ${initialState.percentage}%',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _appendLog('Initialization error: $e');
    }
  }

  Future<void> _refreshState() async {
    try {
      final state = await _controller.getVolumeState(stream: _selectedStream);
      final streams = await _controller.getAllStreamVolumes();
      final devices = await _controller.getOutputDevices();
      final ringer = await _controller.getRingerMode();
      final dnd = await _controller.hasDoNotDisturbAccess();
      final appVol = await _controller.getAppVolume();
      if (!mounted) return;
      setState(() {
        _state = state;
        _streamVolumes = Map<VolumeStreamType, double>.from(streams);
        _outputDevices = devices;
        _ringerMode = ringer;
        _hasDndAccess = dnd;
        _appVolume = appVol;
      });
      _appendLog('Refreshed volume state and audio devices.');
    } catch (e) {
      _appendLog('Refresh error: $e');
    }
  }

  Future<void> _setMasterVolume(double value) async {
    try {
      final updated = await _controller.setVolume(
        value,
        stream: _selectedStream,
        showSystemUI: _showSystemUI,
      );
      if (!mounted) return;
      setState(() {
        _state = updated;
        _streamVolumes[_selectedStream] = updated.volume;
      });
    } catch (e) {
      _appendLog('setVolume failed: $e');
    }
  }

  Future<void> _setSpecificStreamVolume(
    VolumeStreamType stream,
    double value,
  ) async {
    try {
      final updated = await _controller.setVolume(
        value,
        stream: stream,
        showSystemUI: _showSystemUI,
      );
      if (!mounted) return;
      setState(() {
        _streamVolumes[stream] = updated.volume;
        if (stream == _selectedStream) {
          _state = updated;
        }
      });
    } catch (e) {
      _appendLog('setVolume(${stream.wireName}) failed: $e');
    }
  }

  Future<void> _changeRingerMode(RingerMode mode) async {
    try {
      if (mode == RingerMode.silent && !_hasDndAccess) {
        _appendLog('Requesting Do Not Disturb Policy access...');
        await _controller.requestDoNotDisturbAccess();
        return;
      }
      final result = await _controller.setRingerMode(mode);
      if (!mounted) return;
      setState(() => _ringerMode = result);
      _appendLog('Ringer mode updated to ${result.wireName}');
    } catch (e) {
      _appendLog('setRingerMode error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('XueHua Volume Controller v1.0.0'),
        actions: [
          IconButton(
            tooltip: 'Refresh State & Devices',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshState,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPrimaryVolumeCard(colorScheme),
                const SizedBox(height: 16),
                _buildQuickActionsAndOptionsCard(colorScheme),
                if (_capabilities?.supportsMultipleStreamTypes == true) ...[
                  const SizedBox(height: 16),
                  _buildMultiStreamMixerCard(colorScheme),
                ],
                if (_capabilities?.supportsRingerMode == true) ...[
                  const SizedBox(height: 16),
                  _buildRingerAndDndCard(colorScheme),
                ],
                const SizedBox(height: 16),
                _buildAppVolumeAndWebBoostCard(colorScheme),
                const SizedBox(height: 16),
                _buildOutputDevicesCard(colorScheme),
                const SizedBox(height: 16),
                _buildCapabilitiesCard(colorScheme),
                const SizedBox(height: 16),
                _buildEventLogCard(colorScheme),
              ],
            ),
    );
  }

  Widget _buildPrimaryVolumeCard(ColorScheme colorScheme) {
    final pct = _state.percentage;
    final icon = _state.isMuted || pct == 0
        ? Icons.volume_off_rounded
        : pct < 50
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: Icon(icon, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_state.percentage}% ${_state.isMuted ? "(MUTED)" : ""}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device: ${_state.outputDeviceName ?? "Default Output"} '
                        '[${_state.outputRoute.wireName}]'
                        '${_state.volumeDb != null ? " • ${_state.volumeDb!.toStringAsFixed(1)} dB" : ""}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _controller.toggleMute(
                    stream: _selectedStream,
                    showSystemUI: _showSystemUI,
                  ),
                  icon: Icon(
                    _state.isMuted ? Icons.volume_up : Icons.volume_off,
                  ),
                  label: Text(_state.isMuted ? 'Unmute' : 'Mute'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: _state.volume.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              divisions: _state.maxSteps != null && _state.maxSteps! > 0
                  ? _state.maxSteps
                  : 100,
              label: '${_state.percentage}%',
              onChanged: _setMasterVolume,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                for (final preset in const <double>[0.0, 0.25, 0.5, 0.75, 1.0])
                  ActionChip(
                    label: Text('${(preset * 100).round()}%'),
                    onPressed: () => _setMasterVolume(preset),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _controller.volumeDown(
                    stream: _selectedStream,
                    showSystemUI: _showSystemUI,
                  ),
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Step -'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _controller.volumeUp(
                    stream: _selectedStream,
                    showSystemUI: _showSystemUI,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Step +'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsAndOptionsCard(ColorScheme colorScheme) {
    final supportsHud = _capabilities?.supportsSystemUIControl ?? false;
    final supportsHwIntercept =
        _capabilities?.supportsHardwareButtonInterception ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controller Behavior & Hardware Keys',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Native System Volume HUD Overlay'),
              subtitle: Text(
                supportsHud
                    ? 'Supported on this platform (Android FLAG_SHOW_UI / iOS MPVolumeView)'
                    : 'Not applicable on ${_capabilities?.platform ?? "this platform"}',
              ),
              value: _showSystemUI,
              onChanged: supportsHud
                  ? (val) async {
                      await _controller.setShowSystemUI(val);
                      if (mounted) setState(() => _showSystemUI = val);
                      _appendLog('setShowSystemUI($val)');
                    }
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Intercept Physical Hardware Volume Buttons'),
              subtitle: Text(
                supportsHwIntercept
                    ? 'Captures Volume Up/Down keys into onHardwareButton without changing system volume'
                    : 'Only supported on Android physical devices',
              ),
              value: _interceptHardwareButtons,
              onChanged: supportsHwIntercept
                  ? (val) async {
                      await _controller.setInterceptHardwareButtons(val);
                      if (mounted) {
                        setState(() => _interceptHardwareButtons = val);
                      }
                      _appendLog('setInterceptHardwareButtons($val)');
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiStreamMixerCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Android Multi-Stream Audio Mixer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final stream in VolumeStreamType.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        stream.wireName.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: (_streamVolumes[stream] ?? 0.5).clamp(0.0, 1.0),
                        onChanged: (v) => _setSpecificStreamVolume(stream, v),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${((_streamVolumes[stream] ?? 0.5) * 100).round()}%',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingerAndDndCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ringer Mode & Do Not Disturb',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    _hasDndAccess ? 'DND Granted' : 'DND Permission Needed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<RingerMode>(
              segments: const [
                ButtonSegment(
                  value: RingerMode.normal,
                  icon: Icon(Icons.notifications_active_outlined),
                  label: Text('Normal'),
                ),
                ButtonSegment(
                  value: RingerMode.vibrate,
                  icon: Icon(Icons.vibration),
                  label: Text('Vibrate'),
                ),
                ButtonSegment(
                  value: RingerMode.silent,
                  icon: Icon(Icons.notifications_off_outlined),
                  label: Text('Silent'),
                ),
              ],
              selected: <RingerMode>{
                _ringerMode == RingerMode.unknown
                    ? RingerMode.normal
                    : _ringerMode,
              },
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  _changeRingerMode(selection.first);
                }
              },
            ),
            if (!_hasDndAccess) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _controller.requestDoNotDisturbAccess(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Grant Do Not Disturb Access in Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppVolumeAndWebBoostCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Per-Application Volume & WebAudio Gain Boost',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 110, child: Text('App Volume:')),
                Expanded(
                  child: Slider(
                    value: _appVolume.clamp(0.0, 1.0),
                    onChanged: (v) async {
                      final updated = await _controller.setAppVolume(v);
                      if (mounted) setState(() => _appVolume = updated);
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text('${(_appVolume * 100).round()}%'),
                ),
              ],
            ),
            if (kIsWeb) ...[
              Row(
                children: [
                  const SizedBox(width: 110, child: Text('Web Gain Boost:')),
                  Expanded(
                    child: Slider(
                      value: _webGainBoost.clamp(0.0, 4.0),
                      min: 0.0,
                      max: 4.0,
                      divisions: 40,
                      label: '${(_webGainBoost * 100).round()}%',
                      onChanged: (v) async {
                        final updated = await _controller.setWebGainBoost(v);
                        if (mounted) setState(() => _webGainBoost = updated);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${(_webGainBoost * 100).round()}%'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutputDevicesCard(ColorScheme colorScheme) {
    final canSelect = _capabilities?.supportsDeviceSelection ?? false;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Output Devices (${_outputDevices.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_outputDevices.isEmpty)
              const Text('No output devices reported.')
            else
              for (final device in _outputDevices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    device.route == AudioOutputRoute.bluetooth
                        ? Icons.bluetooth_audio
                        : device.route == AudioOutputRoute.wiredHeadset
                            ? Icons.headphones
                            : device.route == AudioOutputRoute.usb
                                ? Icons.usb
                                : device.route == AudioOutputRoute.hdmi
                                    ? Icons.tv
                                    : Icons.speaker,
                  ),
                  title: Text(device.name),
                  subtitle: Text(
                    'Route: ${device.route.wireName} • ID: ${device.id}',
                  ),
                  trailing: device.isDefault
                      ? const Chip(label: Text('Active'))
                      : canSelect
                          ? OutlinedButton(
                              onPressed: () async {
                                final ok = await _controller.setOutputDevice(
                                  device.id,
                                );
                                _appendLog(
                                  'setOutputDevice(${device.name}): $ok',
                                );
                                await _refreshState();
                              },
                              child: const Text('Switch'),
                            )
                          : null,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesCard(ColorScheme colorScheme) {
    final caps = _capabilities;
    if (caps == null) return const SizedBox.shrink();

    final badges = <MapEntry<String, bool>>[
      MapEntry('System Volume', caps.supportsSystemVolumeControl),
      MapEntry('Mute Control', caps.supportsMuteControl),
      MapEntry('Live Listener', caps.supportsVolumeChangeListening),
      MapEntry('Multi-Stream', caps.supportsMultipleStreamTypes),
      MapEntry('Ringer Mode', caps.supportsRingerMode),
      MapEntry('System UI HUD', caps.supportsSystemUIControl),
      MapEntry('HW Key Intercept', caps.supportsHardwareButtonInterception),
      MapEntry('Device Listing', caps.supportsAudioDeviceListing),
      MapEntry('Device Switching', caps.supportsDeviceSelection),
      MapEntry('Per-App Volume', caps.supportsAppVolumeControl),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Capabilities (${caps.platform.toUpperCase()})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (caps.audioBackend != null) ...[
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
              children: [
                for (final entry in badges)
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
            if (caps.platformNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final note in caps.platformNotes)
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
      ),
    );
  }

  Widget _buildEventLogCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Real-Time Event Stream Log',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_eventLogs.clear),
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
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _eventLogs.isEmpty
                  ? const Center(child: Text('No events recorded yet.'))
                  : ListView.builder(
                      itemCount: _eventLogs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _eventLogs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
