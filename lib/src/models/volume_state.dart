import 'package:flutter/foundation.dart';

import 'volume_enums.dart';

/// Snapshot of the current volume and audio state for a specific stream.
@immutable
class VolumeState {
  /// Creates an immutable [VolumeState] snapshot.
  const VolumeState({
    required this.volume,
    required this.isMuted,
    this.streamType = VolumeStreamType.media,
    this.stepIndex,
    this.maxSteps,
    this.minSteps,
    this.volumeDb,
    this.ringerMode = RingerMode.unknown,
    this.outputDeviceName,
    this.outputRoute = AudioOutputRoute.unknown,
    this.outputDeviceId,
  });

  /// Normalized volume level clamped between `0.0` (silent) and `1.0` (maximum).
  final double volume;

  /// Whether the target audio stream or master output is currently muted.
  final bool isMuted;

  /// The audio stream this state represents.
  final VolumeStreamType streamType;

  /// Discrete integer volume step on platforms that use stepped volume (e.g., Android).
  final int? stepIndex;

  /// Maximum discrete integer step on platforms that use stepped volume.
  final int? maxSteps;

  /// Minimum discrete integer step on platforms that use stepped volume.
  final int? minSteps;

  /// Volume attenuation in decibels (dB) when reported by the OS (e.g., Windows CoreAudio).
  final double? volumeDb;

  /// Current system ringer mode (`normal`, `vibrate`, `silent`, or `unknown`).
  final RingerMode ringerMode;

  /// Human-readable name of the active audio output device, if available.
  final String? outputDeviceName;

  /// Classification of the active audio output route.
  final AudioOutputRoute outputRoute;

  /// Platform-specific identifier of the active audio output device, if available.
  final String? outputDeviceId;

  /// Volume formatted as an integer percentage (`0` to `100`).
  int get percentage => (volume.clamp(0.0, 1.0) * 100).round();

  /// Deserializes a [VolumeState] from a platform channel map.
  factory VolumeState.fromMap(Map<Object?, Object?> map) {
    final rawVolume = (map['volume'] as num?)?.toDouble() ?? 0.0;
    final clampedVolume = rawVolume.clamp(0.0, 1.0);
    return VolumeState(
      volume: clampedVolume,
      isMuted: (map['isMuted'] as bool?) ?? (clampedVolume <= 0.0001),
      streamType: VolumeStreamType.fromWireName(map['streamType'] as String?),
      stepIndex: (map['stepIndex'] as num?)?.toInt(),
      maxSteps: (map['maxSteps'] as num?)?.toInt(),
      minSteps: (map['minSteps'] as num?)?.toInt(),
      volumeDb: (map['volumeDb'] as num?)?.toDouble(),
      ringerMode: RingerMode.fromWireName(map['ringerMode'] as String?),
      outputDeviceName: map['outputDeviceName'] as String?,
      outputRoute: AudioOutputRoute.fromWireName(map['outputRoute'] as String?),
      outputDeviceId: map['outputDeviceId'] as String?,
    );
  }

  /// Serializes this [VolumeState] into a plain map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'volume': volume,
      'isMuted': isMuted,
      'streamType': streamType.wireName,
      'stepIndex': stepIndex,
      'maxSteps': maxSteps,
      'minSteps': minSteps,
      'volumeDb': volumeDb,
      'ringerMode': ringerMode.wireName,
      'outputDeviceName': outputDeviceName,
      'outputRoute': outputRoute.wireName,
      'outputDeviceId': outputDeviceId,
    };
  }

  /// Returns a copy of this [VolumeState] with updated fields.
  VolumeState copyWith({
    double? volume,
    bool? isMuted,
    VolumeStreamType? streamType,
    int? stepIndex,
    int? maxSteps,
    int? minSteps,
    double? volumeDb,
    RingerMode? ringerMode,
    String? outputDeviceName,
    AudioOutputRoute? outputRoute,
    String? outputDeviceId,
  }) {
    return VolumeState(
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      streamType: streamType ?? this.streamType,
      stepIndex: stepIndex ?? this.stepIndex,
      maxSteps: maxSteps ?? this.maxSteps,
      minSteps: minSteps ?? this.minSteps,
      volumeDb: volumeDb ?? this.volumeDb,
      ringerMode: ringerMode ?? this.ringerMode,
      outputDeviceName: outputDeviceName ?? this.outputDeviceName,
      outputRoute: outputRoute ?? this.outputRoute,
      outputDeviceId: outputDeviceId ?? this.outputDeviceId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VolumeState &&
        (other.volume - volume).abs() < 0.0001 &&
        other.isMuted == isMuted &&
        other.streamType == streamType &&
        other.stepIndex == stepIndex &&
        other.maxSteps == maxSteps &&
        other.minSteps == minSteps &&
        other.volumeDb == volumeDb &&
        other.ringerMode == ringerMode &&
        other.outputDeviceName == outputDeviceName &&
        other.outputRoute == outputRoute &&
        other.outputDeviceId == outputDeviceId;
  }

  @override
  int get hashCode => Object.hash(
    (volume * 10000).round(),
    isMuted,
    streamType,
    stepIndex,
    maxSteps,
    minSteps,
    volumeDb,
    ringerMode,
    outputDeviceName,
    outputRoute,
    outputDeviceId,
  );

  @override
  String toString() {
    return 'VolumeState(volume: ${volume.toStringAsFixed(3)} ($percentage%), '
        'isMuted: $isMuted, streamType: ${streamType.wireName}, '
        'step: ${stepIndex ?? "-"}/${maxSteps ?? "-"}, '
        'ringerMode: ${ringerMode.wireName}, '
        'device: ${outputDeviceName ?? "default"} [${outputRoute.wireName}])';
  }
}
