import 'package:flutter/foundation.dart';

import 'volume_enums.dart';
import 'volume_state.dart';

/// Real-time event emitted whenever system or stream volume, mute status,
/// ringer mode, or active output route changes.
@immutable
class VolumeChangeEvent {
  /// Creates a [VolumeChangeEvent].
  const VolumeChangeEvent({
    required this.state,
    this.oldVolume,
    this.reason = 'system',
    required this.timestamp,
  });

  /// Updated volume state after the change.
  final VolumeState state;

  /// Previous normalized volume level (`0.0` to `1.0`) if known.
  final double? oldVolume;

  /// Reason or source of the change (e.g., `'system'`, `'programmatic'`,
  /// `'hardwareButton'`, `'routeChange'`, `'ringerModeChange'`).
  final String reason;

  /// Local timestamp when the event was observed.
  final DateTime timestamp;

  /// Convenience getter for [state.volume].
  double get volume => state.volume;

  /// Convenience getter for [state.isMuted].
  bool get isMuted => state.isMuted;

  /// Convenience getter for [state.streamType].
  VolumeStreamType get streamType => state.streamType;

  /// Deserializes a [VolumeChangeEvent] from a platform channel map.
  factory VolumeChangeEvent.fromMap(Map<Object?, Object?> map) {
    final stateMap = map['state'] is Map<Object?, Object?>
        ? map['state'] as Map<Object?, Object?>
        : map;
    final millis = (map['timestamp'] as num?)?.toInt();
    return VolumeChangeEvent(
      state: VolumeState.fromMap(stateMap),
      oldVolume: (map['oldVolume'] as num?)?.toDouble(),
      reason: (map['reason'] as String?) ?? 'system',
      timestamp: millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
    );
  }

  /// Serializes this [VolumeChangeEvent] into a plain map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'state': state.toMap(),
      'oldVolume': oldVolume,
      'reason': reason,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'VolumeChangeEvent(state: $state, oldVolume: $oldVolume, reason: $reason)';
  }
}

/// Event emitted when a physical or media hardware volume key is pressed
/// while hardware button interception is enabled.
@immutable
class VolumeButtonEvent {
  /// Creates a [VolumeButtonEvent].
  const VolumeButtonEvent({
    required this.direction,
    required this.action,
    required this.intercepted,
    required this.timestamp,
  });

  /// Direction of the volume button ([VolumeDirection.up], [VolumeDirection.down],
  /// or [VolumeDirection.mute]).
  final VolumeDirection direction;

  /// Key action phase ([VolumeKeyAction.keyDown], [VolumeKeyAction.keyUp],
  /// or [VolumeKeyAction.press]).
  final VolumeKeyAction action;

  /// Whether the OS default volume change was suppressed by the plugin.
  final bool intercepted;

  /// Local timestamp when the key event occurred.
  final DateTime timestamp;

  /// Deserializes a [VolumeButtonEvent] from a platform channel map.
  factory VolumeButtonEvent.fromMap(Map<Object?, Object?> map) {
    final millis = (map['timestamp'] as num?)?.toInt();
    return VolumeButtonEvent(
      direction: VolumeDirection.fromWireName(map['direction'] as String?),
      action: VolumeKeyAction.fromWireName(map['action'] as String?),
      intercepted: (map['intercepted'] as bool?) ?? true,
      timestamp: millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
    );
  }

  /// Serializes this [VolumeButtonEvent] into a plain map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'direction': direction.wireName,
      'action': action.wireName,
      'intercepted': intercepted,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'VolumeButtonEvent(direction: ${direction.wireName}, '
        'action: ${action.wireName}, intercepted: $intercepted)';
  }
}
