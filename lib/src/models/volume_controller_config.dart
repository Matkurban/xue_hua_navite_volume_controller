import 'package:flutter/foundation.dart';

import 'volume_enums.dart';
import 'volume_events.dart';

/// Configuration options passed to `XueHuaNaviteVolumeController.initialize`.
@immutable
class VolumeControllerConfig {
  /// Creates a [VolumeControllerConfig].
  const VolumeControllerConfig({
    this.defaultStream = VolumeStreamType.media,
    this.showSystemUI = false,
    this.interceptHardwareButtons = false,
    this.listenToVolumeChanges = true,
  });

  /// Default audio stream used when `stream` is omitted in API calls.
  final VolumeStreamType defaultStream;

  /// Whether to show the native system volume HUD overlay by default when
  /// changing volume programmatically (supported on Android and iOS).
  final bool showSystemUI;

  /// Whether to intercept physical hardware volume buttons on Android so that
  /// pressing Volume Up/Down emits `onHardwareButton` events without changing
  /// system volume.
  final bool interceptHardwareButtons;

  /// Whether to immediately start listening for OS volume/mute changes.
  final bool listenToVolumeChanges;

  /// Converts this configuration into a map for the platform channel.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'defaultStream': defaultStream.wireName,
      'showSystemUI': showSystemUI,
      'interceptHardwareButtons': interceptHardwareButtons,
      'listenToVolumeChanges': listenToVolumeChanges,
    };
  }
}

/// Listener interface for receiving volume and hardware button callbacks.
mixin VolumeControllerListener {
  /// Invoked when the system or stream volume, mute state, ringer mode, or
  /// audio output route changes.
  void onVolumeChanged(VolumeChangeEvent event) {}

  /// Invoked when a physical hardware volume button is pressed while
  /// hardware button interception is active.
  void onHardwareVolumeButtonPressed(VolumeButtonEvent event) {}
}

/// Typed exception thrown when a volume control operation fails.
class VolumeControllerException implements Exception {
  /// Creates a [VolumeControllerException].
  const VolumeControllerException({
    required this.code,
    required this.message,
    this.details,
  });

  /// Machine-readable error code (e.g., `'DND_PERMISSION_REQUIRED'`,
  /// `'DEVICE_NOT_FOUND'`, `'AUDIO_BACKEND_UNAVAILABLE'`).
  final String code;

  /// Human-readable description of the error.
  final String message;

  /// Optional platform-specific diagnostic details.
  final Object? details;

  @override
  String toString() =>
      'VolumeControllerException($code): $message${details != null ? " ($details)" : ""}';
}
