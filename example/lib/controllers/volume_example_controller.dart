import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

/// Reactive controller managing all state and actions for the example dashboard
/// using `signals_flutter` (`^7.1.0`) for surgical, fine-grained UI rebuilds.
class VolumeExampleController with VolumeControllerListener {
  /// Constructs a [VolumeExampleController].
  VolumeExampleController({
    XueHuaNaviteVolumeController? plugin,
  }) : _plugin = plugin ?? XueHuaNaviteVolumeController.instance;

  final XueHuaNaviteVolumeController _plugin;

  /// Whether the initial native platform query is still in progress.
  final Signal<bool> isLoading = signal<bool>(true);

  /// Platform capabilities reported by the native audio backend.
  final Signal<VolumeCapabilities?> capabilities =
      signal<VolumeCapabilities?>(null);

  /// Latest master / active stream volume state snapshot.
  final Signal<VolumeState> state = signal<VolumeState>(
    const VolumeState(volume: 0.5, isMuted: false),
  );

  /// Currently selected audio stream for primary volume actions.
  final Signal<VolumeStreamType> selectedStream =
      signal<VolumeStreamType>(VolumeStreamType.media);

  /// Map of normalized volumes (`0.0` to `1.0`) for each supported stream.
  final Signal<Map<VolumeStreamType, double>> streamVolumes =
      signal<Map<VolumeStreamType, double>>(<VolumeStreamType, double>{});

  /// List of available audio output devices.
  final Signal<List<AudioDeviceInfo>> outputDevices =
      signal<List<AudioDeviceInfo>>(const <AudioDeviceInfo>[]);

  /// Current system ringer mode (`normal`, `vibrate`, `silent`, `unknown`).
  final Signal<RingerMode> ringerMode = signal<RingerMode>(RingerMode.normal);

  /// Whether Android Do Not Disturb (`NotificationPolicy`) access is granted.
  final Signal<bool> hasDndAccess = signal<bool>(true);

  /// Whether the native OS volume HUD overlay is displayed on volume changes.
  final Signal<bool> showSystemUI = signal<bool>(false);

  /// Whether physical hardware volume buttons are intercepted on Android.
  final Signal<bool> interceptHardwareButtons = signal<bool>(false);

  /// Process-local application volume (`0.0` to `1.0`).
  final Signal<double> appVolume = signal<double>(1.0);

  /// Web Audio API `GainNode` amplification factor (`0.0` to `4.0`).
  final Signal<double> webGainBoost = signal<double>(1.0);

  /// Chronological event log entries (newest first).
  final Signal<List<String>> eventLogs =
      signal<List<String>>(const <String>[]);

  /// Computed integer percentage (`0` to `100`) of the primary volume state.
  late final Computed<int> percentage = computed<int>(
    () => state.value.percentage,
  );

  /// Computed mute status of the primary volume state.
  late final Computed<bool> isMuted = computed<bool>(
    () => state.value.isMuted,
  );

  /// Initializes the plugin, registers listeners, and populates all signals.
  Future<void> initialize() async {
    _plugin.addListener(this);
    isLoading.value = true;
    try {
      final initialState = await _plugin.initialize(
        VolumeControllerConfig(
          defaultStream: selectedStream.value,
          showSystemUI: showSystemUI.value,
          interceptHardwareButtons: interceptHardwareButtons.value,
          listenToVolumeChanges: true,
        ),
      );
      final caps = await _plugin.getCapabilities();
      final streams = await _plugin.getAllStreamVolumes();
      final devices = await _plugin.getOutputDevices();
      final ringer = await _plugin.getRingerMode();
      final dnd = await _plugin.hasDoNotDisturbAccess();
      final appVol = await _plugin.getAppVolume();
      final webBoost = await _plugin.getWebGainBoost();

      batch(() {
        state.value = initialState;
        capabilities.value = caps;
        streamVolumes.value = Map<VolumeStreamType, double>.from(streams);
        outputDevices.value = List<AudioDeviceInfo>.unmodifiable(devices);
        ringerMode.value = ringer;
        hasDndAccess.value = dnd;
        appVolume.value = appVol;
        webGainBoost.value = webBoost;
        isLoading.value = false;
      });

      appendLog(
        'Initialized on ${caps.platform} (${caps.audioBackend ?? "native"}) - '
        'Initial volume: ${initialState.percentage}%',
      );
    } catch (e) {
      isLoading.value = false;
      appendLog('Initialization error: $e');
    }
  }

  /// Refreshes volume state, stream levels, ringer mode, and output devices.
  Future<void> refreshState() async {
    try {
      final currentState = await _plugin.getVolumeState(
        stream: selectedStream.value,
      );
      final streams = await _plugin.getAllStreamVolumes();
      final devices = await _plugin.getOutputDevices();
      final ringer = await _plugin.getRingerMode();
      final dnd = await _plugin.hasDoNotDisturbAccess();
      final appVol = await _plugin.getAppVolume();

      batch(() {
        state.value = currentState;
        streamVolumes.value = Map<VolumeStreamType, double>.from(streams);
        outputDevices.value = List<AudioDeviceInfo>.unmodifiable(devices);
        ringerMode.value = ringer;
        hasDndAccess.value = dnd;
        appVolume.value = appVol;
      });
      appendLog('Refreshed volume state and audio devices.');
    } catch (e) {
      appendLog('Refresh error: $e');
    }
  }

  /// Sets the master / active stream volume (`0.0` to `1.0`).
  Future<void> setMasterVolume(double value) async {
    try {
      final stream = selectedStream.value;
      final updated = await _plugin.setVolume(
        value,
        stream: stream,
        showSystemUI: showSystemUI.value,
      );
      batch(() {
        state.value = updated;
        final nextStreams = Map<VolumeStreamType, double>.from(
          streamVolumes.value,
        );
        nextStreams[stream] = updated.volume;
        streamVolumes.value = nextStreams;
      });
    } catch (e) {
      appendLog('setVolume failed: $e');
    }
  }

  /// Steps the master volume up by one native step.
  Future<void> stepVolumeUp() async {
    try {
      final updated = await _plugin.volumeUp(
        stream: selectedStream.value,
        showSystemUI: showSystemUI.value,
      );
      state.value = updated;
    } catch (e) {
      appendLog('volumeUp failed: $e');
    }
  }

  /// Steps the master volume down by one native step.
  Future<void> stepVolumeDown() async {
    try {
      final updated = await _plugin.volumeDown(
        stream: selectedStream.value,
        showSystemUI: showSystemUI.value,
      );
      state.value = updated;
    } catch (e) {
      appendLog('volumeDown failed: $e');
    }
  }

  /// Toggles mute state for the currently selected stream.
  Future<void> toggleMute() async {
    try {
      final updated = await _plugin.toggleMute(
        stream: selectedStream.value,
        showSystemUI: showSystemUI.value,
      );
      state.value = updated;
    } catch (e) {
      appendLog('toggleMute failed: $e');
    }
  }

  /// Sets the normalized volume for a specific [VolumeStreamType].
  Future<void> setSpecificStreamVolume(
    VolumeStreamType stream,
    double value,
  ) async {
    try {
      final updated = await _plugin.setVolume(
        value,
        stream: stream,
        showSystemUI: showSystemUI.value,
      );
      batch(() {
        final nextStreams = Map<VolumeStreamType, double>.from(
          streamVolumes.value,
        );
        nextStreams[stream] = updated.volume;
        streamVolumes.value = nextStreams;
        if (stream == selectedStream.value) {
          state.value = updated;
        }
      });
    } catch (e) {
      appendLog('setVolume(${stream.wireName}) failed: $e');
    }
  }

  /// Updates the system ringer mode, requesting DND access first if needed.
  Future<void> changeRingerMode(RingerMode mode) async {
    try {
      if (mode == RingerMode.silent && !hasDndAccess.value) {
        appendLog('Requesting Do Not Disturb Policy access...');
        await _plugin.requestDoNotDisturbAccess();
        return;
      }
      final updated = await _plugin.setRingerMode(mode);
      ringerMode.value = updated;
      appendLog('Ringer mode updated to ${updated.wireName}');
    } catch (e) {
      appendLog('setRingerMode error: $e');
    }
  }

  /// Opens the Android Do Not Disturb access settings screen.
  Future<void> requestDoNotDisturbAccess() async {
    try {
      await _plugin.requestDoNotDisturbAccess();
      appendLog('Opened Do Not Disturb access settings.');
    } catch (e) {
      appendLog('requestDoNotDisturbAccess error: $e');
    }
  }

  /// Toggles whether the native OS volume HUD overlay is displayed.
  Future<void> updateShowSystemUI(bool show) async {
    try {
      await _plugin.setShowSystemUI(show);
      showSystemUI.value = show;
      appendLog('setShowSystemUI($show)');
    } catch (e) {
      appendLog('setShowSystemUI error: $e');
    }
  }

  /// Toggles physical hardware volume button interception on Android.
  Future<void> updateInterceptHardwareButtons(bool intercept) async {
    try {
      await _plugin.setInterceptHardwareButtons(intercept);
      interceptHardwareButtons.value = intercept;
      appendLog('setInterceptHardwareButtons($intercept)');
    } catch (e) {
      appendLog('setInterceptHardwareButtons error: $e');
    }
  }

  /// Sets the process-local application volume (`0.0` to `1.0`).
  Future<void> updateAppVolume(double value) async {
    try {
      final updated = await _plugin.setAppVolume(value);
      appVolume.value = updated;
    } catch (e) {
      appendLog('setAppVolume error: $e');
    }
  }

  /// Sets the WebAudio `GainNode` amplification factor (`0.0` to `4.0`).
  Future<void> updateWebGainBoost(double value) async {
    try {
      final updated = await _plugin.setWebGainBoost(value);
      webGainBoost.value = updated;
    } catch (e) {
      appendLog('setWebGainBoost error: $e');
    }
  }

  /// Switches the active audio output device by [deviceId].
  Future<void> selectOutputDevice(AudioDeviceInfo device) async {
    try {
      final ok = await _plugin.setOutputDevice(device.id);
      appendLog('setOutputDevice(${device.name}): $ok');
      await refreshState();
    } catch (e) {
      appendLog('setOutputDevice error: $e');
    }
  }

  /// Appends a timestamped entry to [eventLogs].
  void appendLog(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    final nextLogs = <String>['[$timeStr] $message', ...eventLogs.value];
    if (nextLogs.length > 60) {
      nextLogs.removeRange(60, nextLogs.length);
    }
    eventLogs.value = List<String>.unmodifiable(nextLogs);
  }

  /// Clears all recorded event logs.
  void clearLogs() {
    eventLogs.value = const <String>[];
  }

  @override
  void onVolumeChanged(VolumeChangeEvent event) {
    batch(() {
      state.value = event.state;
      ringerMode.value = event.state.ringerMode;
      final nextStreams = Map<VolumeStreamType, double>.from(
        streamVolumes.value,
      );
      nextStreams[event.state.streamType] = event.state.volume;
      streamVolumes.value = nextStreams;
    });
    appendLog(
      'VolumeChanged (${event.reason}): '
      '${event.state.streamType.wireName} -> ${event.state.percentage}% '
      '(muted: ${event.state.isMuted}, device: ${event.state.outputDeviceName ?? "default"})',
    );
  }

  @override
  void onHardwareVolumeButtonPressed(VolumeButtonEvent event) {
    appendLog(
      'HardwareButton: ${event.direction.wireName.toUpperCase()} '
      '[${event.action.wireName}] (intercepted=${event.intercepted})',
    );
  }

  /// Unregisters the listener when the controller is disposed.
  void dispose() {
    _plugin.removeListener(this);
  }
}
