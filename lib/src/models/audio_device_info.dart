import 'package:flutter/foundation.dart';

import 'volume_enums.dart';

/// Information describing an audio output (or input) endpoint device.
@immutable
class AudioDeviceInfo {
  /// Creates an [AudioDeviceInfo] descriptor.
  const AudioDeviceInfo({
    required this.id,
    required this.name,
    required this.route,
    required this.isDefault,
    this.isOutput = true,
    this.isInput = false,
    this.volume,
    this.isMuted,
  });

  /// Platform-unique identifier of the audio device.
  final String id;

  /// Human-readable display name of the audio device.
  final String name;

  /// Route type classification (speaker, bluetooth, usb, hdmi, etc.).
  final AudioOutputRoute route;

  /// Whether this device is currently the active/default output endpoint.
  final bool isDefault;

  /// Whether this device supports audio output (sink/render).
  final bool isOutput;

  /// Whether this device supports audio input (source/capture).
  final bool isInput;

  /// Device-specific normalized volume (`0.0`–`1.0`) if available.
  final double? volume;

  /// Device-specific mute state if available.
  final bool? isMuted;

  /// Deserializes an [AudioDeviceInfo] from a platform channel map.
  factory AudioDeviceInfo.fromMap(Map<Object?, Object?> map) {
    return AudioDeviceInfo(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] as String?) ?? 'Unknown Audio Device',
      route: AudioOutputRoute.fromWireName(map['route'] as String?),
      isDefault: (map['isDefault'] as bool?) ?? false,
      isOutput: (map['isOutput'] as bool?) ?? true,
      isInput: (map['isInput'] as bool?) ?? false,
      volume: (map['volume'] as num?)?.toDouble(),
      isMuted: map['isMuted'] as bool?,
    );
  }

  /// Serializes this [AudioDeviceInfo] into a plain map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'route': route.wireName,
      'isDefault': isDefault,
      'isOutput': isOutput,
      'isInput': isInput,
      'volume': volume,
      'isMuted': isMuted,
    };
  }

  @override
  String toString() {
    return 'AudioDeviceInfo(id: $id, name: $name, route: ${route.wireName}, '
        'isDefault: $isDefault)';
  }
}
