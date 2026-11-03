import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/volume_controller_models.dart';
import 'xue_hua_navite_volume_controller_method_channel.dart';

/// The interface that implementations of `xue_hua_navite_volume_controller` must implement.
///
/// Platform implementations should extend this class rather than implement it
/// as `xue_hua_navite_volume_controller` does not consider newly added methods to be
/// breaking changes. Extending this class (using `extends`) ensures that the
/// subclass will get the default implementation, while platform implementations
/// that `implements` this interface will be broken by newly added
/// [XueHuaNaviteVolumeControllerPlatform] methods.
abstract class XueHuaNaviteVolumeControllerPlatform extends PlatformInterface {
  /// Constructs a [XueHuaNaviteVolumeControllerPlatform].
  XueHuaNaviteVolumeControllerPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteVolumeControllerPlatform _instance =
      MethodChannelXueHuaNaviteVolumeController();

  /// The default instance of [XueHuaNaviteVolumeControllerPlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteVolumeController].
  static XueHuaNaviteVolumeControllerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteVolumeControllerPlatform]
  /// when they register themselves.
  static set instance(XueHuaNaviteVolumeControllerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream of real-time volume, mute, ringer mode, and audio route changes.
  Stream<VolumeChangeEvent> get onVolumeChanged {
    throw UnimplementedError('onVolumeChanged has not been implemented.');
  }

  /// Broadcast stream of physical hardware volume button events (when intercepted).
  Stream<VolumeButtonEvent> get onHardwareButton {
    throw UnimplementedError('onHardwareButton has not been implemented.');
  }

  /// Initializes the native volume controller and starts OS observers if requested.
  Future<VolumeState> initialize([
    VolumeControllerConfig config = const VolumeControllerConfig(),
  ]) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Queries the platform-specific volume control capabilities and active backend.
  Future<VolumeCapabilities> getCapabilities() {
    throw UnimplementedError('getCapabilities() has not been implemented.');
  }

  /// Reads the complete [VolumeState] for [stream].
  Future<VolumeState> getVolumeState({
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    throw UnimplementedError('getVolumeState() has not been implemented.');
  }

  /// Gets the normalized volume (`0.0` to `1.0`) for [stream].
  Future<double> getVolume({
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    throw UnimplementedError('getVolume() has not been implemented.');
  }

  /// Sets the normalized volume (`0.0` to `1.0`) for [stream].
  ///
  /// When [showSystemUI] is provided, it overrides the default system HUD
  /// visibility setting on platforms that support it (Android, iOS).
  Future<VolumeState> setVolume(
    double volume, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  /// Adjusts the volume of [stream] by a relative [delta] (e.g., `0.05` or `-0.05`),
  /// clamping the resulting level to `[0.0, 1.0]`.
  Future<VolumeState> adjustVolume(
    double delta, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    throw UnimplementedError('adjustVolume() has not been implemented.');
  }

  /// Increments or decrements the volume by one native discrete step (or ~5% on
  /// continuous scalar platforms).
  Future<VolumeState> stepVolume(
    VolumeDirection direction, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    throw UnimplementedError('stepVolume() has not been implemented.');
  }

  /// Reads the normalized volume levels (`0.0` to `1.0`) for all supported
  /// [VolumeStreamType] streams on the current platform.
  Future<Map<VolumeStreamType, double>> getAllStreamVolumes() {
    throw UnimplementedError('getAllStreamVolumes() has not been implemented.');
  }

  /// Checks whether [stream] (or the system master output) is currently muted.
  Future<bool> isMuted({
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    throw UnimplementedError('isMuted() has not been implemented.');
  }

  /// Mutes or unmutes [stream] (or the system master output).
  Future<VolumeState> setMute(
    bool muted, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    throw UnimplementedError('setMute() has not been implemented.');
  }

  /// Toggles the mute state of [stream] and returns the updated [VolumeState].
  Future<VolumeState> toggleMute({
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    throw UnimplementedError('toggleMute() has not been implemented.');
  }

  /// Queries the current system [RingerMode] (primarily for Android).
  Future<RingerMode> getRingerMode() {
    throw UnimplementedError('getRingerMode() has not been implemented.');
  }

  /// Sets the system [RingerMode] (supported on Android; requires Do Not Disturb
  /// policy access when switching into or out of [RingerMode.silent] on Android 6.0+).
  Future<RingerMode> setRingerMode(RingerMode mode) {
    throw UnimplementedError('setRingerMode() has not been implemented.');
  }

  /// Checks whether the app has Do Not Disturb (`NotificationPolicy`) access on Android.
  /// Returns `true` on platforms where DND access is not required.
  Future<bool> hasDoNotDisturbAccess() {
    throw UnimplementedError('hasDoNotDisturbAccess() has not been implemented.');
  }

  /// Opens the system Do Not Disturb access settings screen on Android so the user
  /// can grant permission for changing ringer mode to/from `RingerMode.silent`.
  Future<bool> requestDoNotDisturbAccess() {
    throw UnimplementedError(
      'requestDoNotDisturbAccess() has not been implemented.',
    );
  }

  /// Configures whether the native OS volume HUD overlay is displayed when
  /// volume changes are triggered (supported on Android and iOS).
  Future<void> setShowSystemUI(bool show) {
    throw UnimplementedError('setShowSystemUI() has not been implemented.');
  }

  /// Enables or disables physical hardware volume key interception (supported on Android).
  Future<void> setInterceptHardwareButtons(bool intercept) {
    throw UnimplementedError(
      'setInterceptHardwareButtons() has not been implemented.',
    );
  }

  /// Lists available audio output devices on the current system.
  Future<List<AudioDeviceInfo>> getOutputDevices() {
    throw UnimplementedError('getOutputDevices() has not been implemented.');
  }

  /// Returns the currently active default audio output device, if available.
  Future<AudioDeviceInfo?> getCurrentOutputDevice() {
    throw UnimplementedError(
      'getCurrentOutputDevice() has not been implemented.',
    );
  }

  /// Switches the system default audio output device by [deviceId] (supported on
  /// macOS, Windows, and Linux PulseAudio/PipeWire).
  Future<bool> setOutputDevice(String deviceId) {
    throw UnimplementedError('setOutputDevice() has not been implemented.');
  }

  /// Sets the process/application-specific audio volume (`0.0` to `1.0`)
  /// independently of the OS master volume (supported on Windows and Web;
  /// falls back to media stream volume on other platforms).
  Future<double> getAppVolume() {
    throw UnimplementedError('getAppVolume() has not been implemented.');
  }

  /// Sets the process/application-specific audio volume (`0.0` to `1.0`).
  Future<double> setAppVolume(double volume) {
    throw UnimplementedError('setAppVolume() has not been implemented.');
  }

  /// Configures Web Audio API `GainNode` amplification factor (`0.0` to `4.0`,
  /// where `1.0` is unity gain and `2.0` is 200% boost) for HTML5 media elements
  /// on Web targets. No-op on native platforms.
  Future<double> setWebGainBoost(double gain) {
    throw UnimplementedError('setWebGainBoost() has not been implemented.');
  }

  /// Gets the current Web Audio API `GainNode` amplification factor (`1.0` on native).
  Future<double> getWebGainBoost() {
    throw UnimplementedError('getWebGainBoost() has not been implemented.');
  }

  /// Releases native observers and listeners when no longer needed.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
