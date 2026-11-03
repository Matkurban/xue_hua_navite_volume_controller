import 'dart:async';
import 'package:flutter/foundation.dart';

import 'src/volume_controller_models.dart';
import 'xue_hua_navite_volume_controller_platform_interface.dart';

export 'src/volume_controller_models.dart';
export 'xue_hua_navite_volume_controller_platform_interface.dart';

/// Cross-platform system & application audio volume controller for Flutter
/// across Android, iOS, macOS, Windows, Linux, and Web.
///
/// Use [XueHuaNaviteVolumeController.instance] (or construct an instance) to:
/// - Read and set normalized volume (`0.0` to `1.0`), step volume, or adjust by delta
/// - Control individual audio streams on Android (`media`, `ring`, `alarm`,
///   `notification`, `voiceCall`, `system`, `accessibility`, `dtmf`)
/// - Mute, unmute, or toggle mute with automatic software zero-volume fallback
///   on platforms or digital outputs without hardware mute registers
/// - Query and change Android ringer mode (`normal`, `vibrate`, `silent`) and
///   manage Do Not Disturb (`NotificationPolicy`) access
/// - Show or hide the native OS volume HUD overlay (`FLAG_SHOW_UI` on Android,
///   `MPVolumeView` on iOS)
/// - Intercept physical hardware volume buttons on Android (`onHardwareButton`)
/// - Enumerate and switch active audio output devices on desktop/mobile
/// - Control per-application session volume on Windows and Web (`getAppVolume`,
///   `setAppVolume`) and WebAudio `GainNode` amplification on Web (`setWebGainBoost`)
class XueHuaNaviteVolumeController {
  /// Constructs a [XueHuaNaviteVolumeController] delegating to
  /// [XueHuaNaviteVolumeControllerPlatform.instance].
  XueHuaNaviteVolumeController();

  /// Singleton instance of [XueHuaNaviteVolumeController].
  static final XueHuaNaviteVolumeController instance =
      XueHuaNaviteVolumeController();

  static XueHuaNaviteVolumeControllerPlatform get _platform =>
      XueHuaNaviteVolumeControllerPlatform.instance;

  final ObserverList<VolumeControllerListener> _listeners =
      ObserverList<VolumeControllerListener>();

  StreamSubscription<VolumeChangeEvent>? _volumeSub;
  StreamSubscription<VolumeButtonEvent>? _buttonSub;

  /// Reactive `ValueNotifier` holding the latest observed [VolumeState].
  ///
  /// Updated automatically whenever [initialize], [getVolumeState], [setVolume],
  /// [adjustVolume], [stepVolume], [setMute], [toggleMute], or [onVolumeChanged]
  /// emits a new state.
  final ValueNotifier<VolumeState> stateNotifier = ValueNotifier<VolumeState>(
    const VolumeState(volume: 0.5, isMuted: false),
  );

  /// Broadcast stream of real-time [VolumeChangeEvent] notifications when system
  /// or stream volume, mute state, ringer mode, or audio output route changes.
  Stream<VolumeChangeEvent> get onVolumeChanged => _platform.onVolumeChanged;

  /// Broadcast stream of [VolumeButtonEvent] notifications when physical
  /// hardware volume buttons are pressed and intercepted.
  Stream<VolumeButtonEvent> get onHardwareButton => _platform.onHardwareButton;

  void _ensureInternalSubscriptions() {
    _volumeSub ??= onVolumeChanged.listen((event) {
      stateNotifier.value = event.state;
      for (final listener in List<VolumeControllerListener>.of(_listeners)) {
        if (_listeners.contains(listener)) {
          listener.onVolumeChanged(event);
        }
      }
    });
    _buttonSub ??= onHardwareButton.listen((event) {
      for (final listener in List<VolumeControllerListener>.of(_listeners)) {
        if (_listeners.contains(listener)) {
          listener.onHardwareVolumeButtonPressed(event);
        }
      }
    });
  }

  /// Registers a [VolumeControllerListener] to receive volume change and
  /// hardware button callbacks.
  void addListener(VolumeControllerListener listener) {
    _ensureInternalSubscriptions();
    _listeners.add(listener);
  }

  /// Removes a previously registered [VolumeControllerListener].
  void removeListener(VolumeControllerListener listener) {
    _listeners.remove(listener);
  }

  /// Initializes the volume controller with [config] and returns the initial
  /// [VolumeState] for [VolumeControllerConfig.defaultStream].
  Future<VolumeState> initialize([
    VolumeControllerConfig config = const VolumeControllerConfig(),
  ]) async {
    _ensureInternalSubscriptions();
    final state = await _platform.initialize(config);
    stateNotifier.value = state;
    return state;
  }

  /// Queries the platform-specific [VolumeCapabilities] and active native audio
  /// backend information.
  Future<VolumeCapabilities> getCapabilities() {
    return _platform.getCapabilities();
  }

  /// Queries the complete [VolumeState] snapshot for [stream].
  Future<VolumeState> getVolumeState({
    VolumeStreamType stream = VolumeStreamType.media,
  }) async {
    final state = await _platform.getVolumeState(stream: stream);
    if (stream == VolumeStreamType.media ||
        stateNotifier.value.streamType == stream) {
      stateNotifier.value = state;
    }
    return state;
  }

  /// Reads the current normalized volume (`0.0` to `1.0`) for [stream].
  Future<double> getVolume({
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    return _platform.getVolume(stream: stream);
  }

  /// Sets the normalized volume (`0.0` to `1.0`) for [stream] and returns the
  /// resulting [VolumeState].
  ///
  /// Values outside `[0.0, 1.0]` are automatically clamped.
  /// Provide [showSystemUI] to explicitly show or hide the OS volume HUD overlay
  /// for this call on Android and iOS.
  Future<VolumeState> setVolume(
    double volume, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final state = await _platform.setVolume(
      volume.clamp(0.0, 1.0),
      stream: stream,
      showSystemUI: showSystemUI,
    );
    stateNotifier.value = state;
    return state;
  }

  /// Adjusts the volume of [stream] by a relative [delta] (e.g., `0.1` for +10%
  /// or `-0.1` for -10%), clamping the result to `[0.0, 1.0]`.
  Future<VolumeState> adjustVolume(
    double delta, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final state = await _platform.adjustVolume(
      delta,
      stream: stream,
      showSystemUI: showSystemUI,
    );
    stateNotifier.value = state;
    return state;
  }

  /// Steps the volume of [stream] up, down, or toggles mute by one native step.
  Future<VolumeState> stepVolume(
    VolumeDirection direction, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final state = await _platform.stepVolume(
      direction,
      stream: stream,
      showSystemUI: showSystemUI,
    );
    stateNotifier.value = state;
    return state;
  }

  /// Convenience method to increase the volume of [stream] by [step] (or one
  /// native step when [step] is omitted).
  Future<VolumeState> volumeUp({
    double? step,
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    if (step != null) {
      return adjustVolume(
        step.abs(),
        stream: stream,
        showSystemUI: showSystemUI,
      );
    }
    return stepVolume(
      VolumeDirection.up,
      stream: stream,
      showSystemUI: showSystemUI,
    );
  }

  /// Convenience method to decrease the volume of [stream] by [step] (or one
  /// native step when [step] is omitted).
  Future<VolumeState> volumeDown({
    double? step,
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    if (step != null) {
      return adjustVolume(
        -step.abs(),
        stream: stream,
        showSystemUI: showSystemUI,
      );
    }
    return stepVolume(
      VolumeDirection.down,
      stream: stream,
      showSystemUI: showSystemUI,
    );
  }

  /// Reads the current normalized volume (`0.0` to `1.0`) for all supported
  /// [VolumeStreamType] categories on the current platform.
  Future<Map<VolumeStreamType, double>> getAllStreamVolumes() {
    return _platform.getAllStreamVolumes();
  }

  /// Returns `true` if [stream] (or the system master output) is currently muted.
  Future<bool> isMuted({
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    return _platform.isMuted(stream: stream);
  }

  /// Mutes or unmutes [stream] (or the system master output) and returns the
  /// updated [VolumeState].
  Future<VolumeState> setMute(
    bool muted, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final state = await _platform.setMute(
      muted,
      stream: stream,
      showSystemUI: showSystemUI,
    );
    stateNotifier.value = state;
    return state;
  }

  /// Toggles the mute state of [stream] and returns the updated [VolumeState].
  Future<VolumeState> toggleMute({
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final state = await _platform.toggleMute(
      stream: stream,
      showSystemUI: showSystemUI,
    );
    stateNotifier.value = state;
    return state;
  }

  /// Queries the current system [RingerMode] (`normal`, `vibrate`, `silent`, or `unknown`).
  Future<RingerMode> getRingerMode() {
    return _platform.getRingerMode();
  }

  /// Sets the system [RingerMode] (supported on Android).
  ///
  /// Note: Switching into or out of [RingerMode.silent] on Android 6.0+ requires
  /// Do Not Disturb (`NotificationPolicy`) access. Check [hasDoNotDisturbAccess]
  /// and call [requestDoNotDisturbAccess] if needed.
  Future<RingerMode> setRingerMode(RingerMode mode) {
    return _platform.setRingerMode(mode);
  }

  /// Checks whether Do Not Disturb (`NotificationPolicy`) access is granted on
  /// Android. Always returns `true` on non-Android platforms.
  Future<bool> hasDoNotDisturbAccess() {
    return _platform.hasDoNotDisturbAccess();
  }

  /// Opens the Android system settings screen to grant Do Not Disturb
  /// (`ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`) permission.
  Future<bool> requestDoNotDisturbAccess() {
    return _platform.requestDoNotDisturbAccess();
  }

  /// Configures whether the native OS volume HUD overlay is shown when volume
  /// is modified programmatically (supported on Android and iOS).
  Future<void> setShowSystemUI(bool show) {
    return _platform.setShowSystemUI(show);
  }

  /// Enables or disables physical hardware volume button interception on Android.
  ///
  /// When enabled, pressing the physical Volume Up/Down keys emits events on
  /// [onHardwareButton] without altering the system volume.
  Future<void> setInterceptHardwareButtons(bool intercept) {
    return _platform.setInterceptHardwareButtons(intercept);
  }

  /// Lists all available audio output devices on the current system.
  Future<List<AudioDeviceInfo>> getOutputDevices() {
    return _platform.getOutputDevices();
  }

  /// Returns the currently active default audio output device, if available.
  Future<AudioDeviceInfo?> getCurrentOutputDevice() {
    return _platform.getCurrentOutputDevice();
  }

  /// Switches the active default audio output device by [deviceId] (supported on
  /// macOS, Windows, and Linux PulseAudio/PipeWire).
  Future<bool> setOutputDevice(String deviceId) {
    return _platform.setOutputDevice(deviceId);
  }

  /// Reads the application/process-local audio volume (`0.0` to `1.0`).
  Future<double> getAppVolume() {
    return _platform.getAppVolume();
  }

  /// Sets the application/process-local audio volume (`0.0` to `1.0`)
  /// independently of system-wide master volume (supported on Windows and Web).
  Future<double> setAppVolume(double volume) {
    return _platform.setAppVolume(volume.clamp(0.0, 1.0));
  }

  /// Sets the Web Audio API `GainNode` amplification factor (`0.0` to `4.0`,
  /// where `1.0` is 100% unity gain and `2.0` is 200% boost) for HTML5 media
  /// elements on Web. Returns `1.0` on native platforms.
  Future<double> setWebGainBoost(double gain) {
    return _platform.setWebGainBoost(gain.clamp(0.0, 4.0));
  }

  /// Reads the current Web Audio API `GainNode` amplification factor (`1.0` on native).
  Future<double> getWebGainBoost() {
    return _platform.getWebGainBoost();
  }

  /// Disposes internal stream subscriptions and releases native observers.
  Future<void> dispose() async {
    await _volumeSub?.cancel();
    _volumeSub = null;
    await _buttonSub?.cancel();
    _buttonSub = null;
    _listeners.clear();
    await _platform.dispose();
  }
}
