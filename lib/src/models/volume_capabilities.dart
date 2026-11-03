import 'package:flutter/foundation.dart';

import 'volume_enums.dart';

/// Describes the exact volume control capabilities supported by the current
/// operating system and active audio device.
@immutable
class VolumeCapabilities {
  /// Creates a [VolumeCapabilities] descriptor.
  const VolumeCapabilities({
    required this.platform,
    required this.supportsSystemVolumeControl,
    required this.supportsMuteControl,
    required this.supportsVolumeChangeListening,
    required this.supportsHardwareButtonInterception,
    required this.supportsSystemUIControl,
    required this.supportsMultipleStreamTypes,
    required this.supportsRingerMode,
    required this.supportsAudioDeviceListing,
    required this.supportsDeviceSelection,
    required this.supportsAppVolumeControl,
    required this.supportedStreams,
    this.audioBackend,
    this.platformNotes = const <String>[],
  });

  /// Current platform identifier (`android`, `ios`, `macos`, `windows`, `linux`, `web`).
  final String platform;

  /// Whether the plugin can read and modify OS-wide hardware/master volume.
  ///
  /// `true` on Android, iOS, macOS, Windows, and Linux; `false` on Web
  /// (where browsers sandbox OS hardware volume and only allow controlling
  /// page `<audio>`/`<video>` elements and WebAudio `GainNode`s).
  final bool supportsSystemVolumeControl;

  /// Whether dedicated mute/unmute state control is supported.
  ///
  /// On iOS, Apple does not expose a public API to toggle the physical hardware
  /// Ring/Silent switch, so `setMute(true)` uses software zero-volume + cached
  /// pre-mute restoration.
  final bool supportsMuteControl;

  /// Whether real-time volume/mute change events are emitted via `onVolumeChanged`.
  final bool supportsVolumeChangeListening;

  /// Whether physical hardware volume buttons (`Volume Up` / `Volume Down`) can
  /// be intercepted without changing the system volume (supported on Android).
  final bool supportsHardwareButtonInterception;

  /// Whether the native system volume HUD overlay can be shown or hidden
  /// programmatically (`FLAG_SHOW_UI` on Android, `MPVolumeView` on iOS).
  final bool supportsSystemUIControl;

  /// Whether multiple independent audio stream categories (media, ring, alarm,
  /// notification, voiceCall, etc.) have separate volume sliders (`true` on Android).
  final bool supportsMultipleStreamTypes;

  /// Whether system ringer mode (`normal`, `vibrate`, `silent`) can be queried
  /// or modified (`true` on Android).
  final bool supportsRingerMode;

  /// Whether enumerating connected audio output devices is supported.
  final bool supportsAudioDeviceListing;

  /// Whether switching the active default audio output device is supported
  /// (`true` on macOS, Windows, and Linux PulseAudio/PipeWire).
  final bool supportsDeviceSelection;

  /// Whether per-application (process-local) audio volume control is supported
  /// independently of system master volume (`true` on Windows and Web).
  final bool supportsAppVolumeControl;

  /// List of [VolumeStreamType] values natively distinct on this platform.
  final List<VolumeStreamType> supportedStreams;

  /// Underlying native audio subsystem name (e.g., `'AudioManager'`,
  /// `'AVAudioSession + MPVolumeView'`, `'CoreAudio'`, `'MMDeviceAPI / CoreAudio'`,
  /// `'PulseAudio / PipeWire / ALSA'`, `'HTMLMediaElement + WebAudio'`).
  final String? audioBackend;

  /// Human-readable notes describing platform-specific behavior or nuances.
  final List<String> platformNotes;

  /// Deserializes [VolumeCapabilities] from a platform channel map.
  factory VolumeCapabilities.fromMap(Map<Object?, Object?> map) {
    final rawStreams =
        map['supportedStreams'] as List<Object?>? ?? const <Object?>['media'];
    final rawNotes = map['platformNotes'] as List<Object?>? ?? const <Object?>[];
    return VolumeCapabilities(
      platform: (map['platform'] as String?) ?? 'unknown',
      supportsSystemVolumeControl:
          (map['supportsSystemVolumeControl'] as bool?) ?? true,
      supportsMuteControl: (map['supportsMuteControl'] as bool?) ?? true,
      supportsVolumeChangeListening:
          (map['supportsVolumeChangeListening'] as bool?) ?? true,
      supportsHardwareButtonInterception:
          (map['supportsHardwareButtonInterception'] as bool?) ?? false,
      supportsSystemUIControl:
          (map['supportsSystemUIControl'] as bool?) ?? false,
      supportsMultipleStreamTypes:
          (map['supportsMultipleStreamTypes'] as bool?) ?? false,
      supportsRingerMode: (map['supportsRingerMode'] as bool?) ?? false,
      supportsAudioDeviceListing:
          (map['supportsAudioDeviceListing'] as bool?) ?? false,
      supportsDeviceSelection:
          (map['supportsDeviceSelection'] as bool?) ?? false,
      supportsAppVolumeControl:
          (map['supportsAppVolumeControl'] as bool?) ?? false,
      supportedStreams: rawStreams
          .map((e) => VolumeStreamType.fromWireName(e?.toString()))
          .toList(growable: false),
      audioBackend: map['audioBackend'] as String?,
      platformNotes: rawNotes
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// Serializes this [VolumeCapabilities] into a plain map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'platform': platform,
      'supportsSystemVolumeControl': supportsSystemVolumeControl,
      'supportsMuteControl': supportsMuteControl,
      'supportsVolumeChangeListening': supportsVolumeChangeListening,
      'supportsHardwareButtonInterception': supportsHardwareButtonInterception,
      'supportsSystemUIControl': supportsSystemUIControl,
      'supportsMultipleStreamTypes': supportsMultipleStreamTypes,
      'supportsRingerMode': supportsRingerMode,
      'supportsAudioDeviceListing': supportsAudioDeviceListing,
      'supportsDeviceSelection': supportsDeviceSelection,
      'supportsAppVolumeControl': supportsAppVolumeControl,
      'supportedStreams': supportedStreams.map((e) => e.wireName).toList(),
      'audioBackend': audioBackend,
      'platformNotes': platformNotes,
    };
  }

  @override
  String toString() {
    return 'VolumeCapabilities(platform: $platform, backend: $audioBackend, '
        'systemVolume: $supportsSystemVolumeControl, mute: $supportsMuteControl, '
        'multiStream: $supportsMultipleStreamTypes)';
  }
}
