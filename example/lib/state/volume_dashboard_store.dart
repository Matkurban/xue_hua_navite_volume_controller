import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

/// Reactive state container for the example dashboard, powered by
/// `signals_flutter`.
///
/// Every piece of UI state is held in its own fine-grained signal so that
/// widgets wrapped in `SignalBuilder` only rebuild when the exact signals they
/// read change, instead of rebuilding the whole page via `setState`.
class VolumeDashboardStore with VolumeControllerListener {
  /// Creates a store backed by [controller] (defaults to the plugin singleton).
  VolumeDashboardStore({XueHuaNaviteVolumeController? controller})
    : _controller = controller ?? XueHuaNaviteVolumeController.instance;

  final XueHuaNaviteVolumeController _controller;

  /// Maximum number of retained event log entries.
  static const int maxLogEntries = 60;

  /// Stream controlled by the primary volume card.
  final VolumeStreamType selectedStream = VolumeStreamType.media;

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Signals
  // ---------------------------------------------------------------------------

  /// Whether the initial load is still in progress.
  final FlutterSignal<bool> isLoading = signal<bool>(true);

  /// Runtime capability matrix of the host platform.
  final FlutterSignal<VolumeCapabilities?> capabilities =
      signal<VolumeCapabilities?>(null);

  /// Latest [VolumeState] of [selectedStream].
  final FlutterSignal<VolumeState> volumeState = signal<VolumeState>(
    const VolumeState(volume: 0.5, isMuted: false),
  );

  /// One independent signal per Android stream so that dragging a single
  /// mixer slider only rebuilds that slider row.
  final Map<VolumeStreamType, FlutterSignal<double>> streamVolumes =
      <VolumeStreamType, FlutterSignal<double>>{
        for (final VolumeStreamType stream in VolumeStreamType.values)
          stream: signal<double>(0.5),
      };

  /// Current Android ringer mode.
  final FlutterSignal<RingerMode> ringerMode = signal<RingerMode>(
    RingerMode.normal,
  );

  /// Whether Do Not Disturb (notification policy) access is granted.
  final FlutterSignal<bool> hasDndAccess = signal<bool>(true);

  /// Whether the native OS volume HUD is shown on volume changes.
  final FlutterSignal<bool> showSystemUI = signal<bool>(false);

  /// Whether physical hardware volume buttons are intercepted.
  final FlutterSignal<bool> interceptHardwareButtons = signal<bool>(false);

  /// Per-application volume (`0.0` - `1.0`).
  final FlutterSignal<double> appVolume = signal<double>(1.0);

  /// WebAudio `GainNode` boost multiplier (`0.0` - `4.0`).
  final FlutterSignal<double> webGainBoost = signal<double>(1.0);

  /// Enumerated audio output devices.
  final FlutterSignal<List<AudioDeviceInfo>> outputDevices =
      signal<List<AudioDeviceInfo>>(const <AudioDeviceInfo>[]);

  /// Real-time event log, newest entry first.
  final FlutterSignal<List<String>> eventLogs = signal<List<String>>(
    const <String>[],
  );

  // ---------------------------------------------------------------------------
  // Computed signals
  // ---------------------------------------------------------------------------

  /// Percentage of [selectedStream]. Only notifies when the integer changes.
  late final FlutterComputed<int> percentage = computed<int>(
    () => volumeState.value.percentage,
  );

  /// Mute flag of [selectedStream]. Only notifies when the flag flips.
  late final FlutterComputed<bool> isMuted = computed<bool>(
    () => volumeState.value.isMuted,
  );

  /// Whether the Android multi-stream mixer should be displayed.
  late final FlutterComputed<bool> supportsMultiStream = computed<bool>(
    () => capabilities.value?.supportsMultipleStreamTypes ?? false,
  );

  /// Whether the ringer mode / DND card should be displayed.
  late final FlutterComputed<bool> supportsRingerMode = computed<bool>(
    () => capabilities.value?.supportsRingerMode ?? false,
  );

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Registers listeners, initializes the plugin and loads the first snapshot.
  Future<void> initialize() async {
    _controller.addListener(this);
    _commit(() => isLoading.value = true);
    try {
      final VolumeState initialState = await _controller.initialize(
        VolumeControllerConfig(
          defaultStream: selectedStream,
          showSystemUI: showSystemUI.value,
          interceptHardwareButtons: interceptHardwareButtons.value,
          listenToVolumeChanges: true,
        ),
      );
      final VolumeCapabilities caps = await _controller.getCapabilities();
      final Map<VolumeStreamType, double> streams = await _controller
          .getAllStreamVolumes();
      final List<AudioDeviceInfo> devices = await _controller
          .getOutputDevices();
      final RingerMode ringer = await _controller.getRingerMode();
      final bool dnd = await _controller.hasDoNotDisturbAccess();
      final double appVol = await _controller.getAppVolume();
      final double webBoost = await _controller.getWebGainBoost();

      _commit(() {
        volumeState.value = initialState;
        capabilities.value = caps;
        _applyStreamVolumes(streams);
        outputDevices.value = List<AudioDeviceInfo>.unmodifiable(devices);
        ringerMode.value = ringer;
        hasDndAccess.value = dnd;
        appVolume.value = appVol;
        webGainBoost.value = webBoost;
        isLoading.value = false;
      });
      _appendLog(
        'Initialized on ${caps.platform} (${caps.audioBackend ?? "native"}) - '
        'Initial volume: ${initialState.percentage}%',
      );
    } catch (e) {
      _commit(() => isLoading.value = false);
      _appendLog('Initialization error: $e');
    }
  }

  /// Removes the plugin listener and disposes every signal.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(this);
    percentage.dispose();
    isMuted.dispose();
    supportsMultiStream.dispose();
    supportsRingerMode.dispose();
    for (final FlutterSignal<double> s in streamVolumes.values) {
      s.dispose();
    }
    isLoading.dispose();
    capabilities.dispose();
    volumeState.dispose();
    ringerMode.dispose();
    hasDndAccess.dispose();
    showSystemUI.dispose();
    interceptHardwareButtons.dispose();
    appVolume.dispose();
    webGainBoost.dispose();
    outputDevices.dispose();
    eventLogs.dispose();
  }

  // ---------------------------------------------------------------------------
  // VolumeControllerListener
  // ---------------------------------------------------------------------------

  @override
  void onVolumeChanged(VolumeChangeEvent event) {
    final VolumeState state = event.state;
    _commit(() {
      if (state.streamType == selectedStream) {
        volumeState.value = state;
      }
      ringerMode.value = state.ringerMode;
      streamVolumes[state.streamType]?.value = state.volume;
    });
    _appendLog(
      'VolumeChanged (${event.reason}): '
      '${state.streamType.wireName} -> ${state.percentage}% '
      '(muted: ${state.isMuted}, device: ${state.outputDeviceName ?? "default"})',
    );
  }

  @override
  void onHardwareVolumeButtonPressed(VolumeButtonEvent event) {
    _appendLog(
      'HardwareButton: ${event.direction.wireName.toUpperCase()} '
      '[${event.action.wireName}] (intercepted=${event.intercepted})',
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Re-reads volume, streams, devices, ringer mode, DND and app volume.
  Future<void> refresh() async {
    try {
      final VolumeState state = await _controller.getVolumeState(
        stream: selectedStream,
      );
      final Map<VolumeStreamType, double> streams = await _controller
          .getAllStreamVolumes();
      final List<AudioDeviceInfo> devices = await _controller
          .getOutputDevices();
      final RingerMode ringer = await _controller.getRingerMode();
      final bool dnd = await _controller.hasDoNotDisturbAccess();
      final double appVol = await _controller.getAppVolume();

      _commit(() {
        volumeState.value = state;
        _applyStreamVolumes(streams);
        outputDevices.value = List<AudioDeviceInfo>.unmodifiable(devices);
        ringerMode.value = ringer;
        hasDndAccess.value = dnd;
        appVolume.value = appVol;
      });
      _appendLog('Refreshed volume state and audio devices.');
    } catch (e) {
      _appendLog('Refresh error: $e');
    }
  }

  /// Sets the volume of [selectedStream].
  Future<void> setVolume(double value) =>
      setStreamVolume(selectedStream, value);

  /// Sets the volume of an arbitrary [stream].
  Future<void> setStreamVolume(VolumeStreamType stream, double value) async {
    try {
      final VolumeState updated = await _controller.setVolume(
        value,
        stream: stream,
        showSystemUI: showSystemUI.value,
      );
      _applyVolumeState(updated);
    } catch (e) {
      _appendLog('setVolume(${stream.wireName}) failed: $e');
    }
  }

  /// Toggles the mute state of [selectedStream].
  Future<void> toggleMute() async {
    try {
      _applyVolumeState(
        await _controller.toggleMute(
          stream: selectedStream,
          showSystemUI: showSystemUI.value,
        ),
      );
    } catch (e) {
      _appendLog('toggleMute failed: $e');
    }
  }

  /// Steps [selectedStream] one native volume step up.
  Future<void> volumeUp() async {
    try {
      _applyVolumeState(
        await _controller.volumeUp(
          stream: selectedStream,
          showSystemUI: showSystemUI.value,
        ),
      );
    } catch (e) {
      _appendLog('volumeUp failed: $e');
    }
  }

  /// Steps [selectedStream] one native volume step down.
  Future<void> volumeDown() async {
    try {
      _applyVolumeState(
        await _controller.volumeDown(
          stream: selectedStream,
          showSystemUI: showSystemUI.value,
        ),
      );
    } catch (e) {
      _appendLog('volumeDown failed: $e');
    }
  }

  /// Shows or hides the native OS volume HUD.
  Future<void> setShowSystemUI(bool value) async {
    try {
      await _controller.setShowSystemUI(value);
      _commit(() => showSystemUI.value = value);
      _appendLog('setShowSystemUI($value)');
    } catch (e) {
      _appendLog('setShowSystemUI failed: $e');
    }
  }

  /// Enables or disables hardware volume button interception.
  Future<void> setInterceptHardwareButtons(bool value) async {
    try {
      await _controller.setInterceptHardwareButtons(value);
      _commit(() => interceptHardwareButtons.value = value);
      _appendLog('setInterceptHardwareButtons($value)');
    } catch (e) {
      _appendLog('setInterceptHardwareButtons failed: $e');
    }
  }

  /// Changes the ringer mode, requesting DND access first when required.
  Future<void> changeRingerMode(RingerMode mode) async {
    try {
      if (mode == RingerMode.silent && !hasDndAccess.value) {
        _appendLog('Requesting Do Not Disturb Policy access...');
        await _controller.requestDoNotDisturbAccess();
        return;
      }
      final RingerMode result = await _controller.setRingerMode(mode);
      _commit(() => ringerMode.value = result);
      _appendLog('Ringer mode updated to ${result.wireName}');
    } catch (e) {
      _appendLog('setRingerMode error: $e');
    }
  }

  /// Opens the system Do Not Disturb access settings.
  Future<void> requestDndAccess() async {
    try {
      await _controller.requestDoNotDisturbAccess();
    } catch (e) {
      _appendLog('requestDoNotDisturbAccess error: $e');
    }
  }

  /// Sets the per-application volume.
  Future<void> setAppVolume(double value) async {
    try {
      final double updated = await _controller.setAppVolume(value);
      _commit(() => appVolume.value = updated);
    } catch (e) {
      _appendLog('setAppVolume failed: $e');
    }
  }

  /// Sets the WebAudio gain boost multiplier.
  Future<void> setWebGainBoost(double value) async {
    try {
      final double updated = await _controller.setWebGainBoost(value);
      _commit(() => webGainBoost.value = updated);
    } catch (e) {
      _appendLog('setWebGainBoost failed: $e');
    }
  }

  /// Routes audio output to [device] and refreshes the device list.
  Future<void> selectOutputDevice(AudioDeviceInfo device) async {
    try {
      final bool ok = await _controller.setOutputDevice(device.id);
      _appendLog('setOutputDevice(${device.name}): $ok');
      await refresh();
    } catch (e) {
      _appendLog('setOutputDevice failed: $e');
    }
  }

  /// Clears all event log entries.
  void clearLogs() => _commit(() => eventLogs.value = const <String>[]);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Applies signal writes atomically and ignores them after [dispose].
  void _commit(void Function() writes) {
    if (_disposed) return;
    batch(writes);
  }

  void _applyVolumeState(VolumeState state) {
    _commit(() {
      streamVolumes[state.streamType]?.value = state.volume;
      if (state.streamType == selectedStream) {
        volumeState.value = state;
      }
    });
  }

  void _applyStreamVolumes(Map<VolumeStreamType, double> volumes) {
    for (final MapEntry<VolumeStreamType, double> entry in volumes.entries) {
      streamVolumes[entry.key]?.value = entry.value;
    }
  }

  void _appendLog(String message) {
    final DateTime now = DateTime.now();
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    _commit(() {
      final List<String> current = eventLogs.value;
      eventLogs.value = List<String>.unmodifiable(<String>[
        '[$time] $message',
        ...current.take(maxLogEntries - 1),
      ]);
    });
  }
}
