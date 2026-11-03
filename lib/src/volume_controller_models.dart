import 'dart:async';
import 'package:flutter/foundation.dart';

/// Audio stream categories supported across platforms.
///
/// On **Android**, each stream maps directly to `AudioManager.STREAM_*`,
/// allowing independent control of media, ringtone, alarm, notification,
/// voice call, system, accessibility, and DTMF volumes.
///
/// On **iOS, macOS, Windows, Linux, and Web**, the operating system exposes a
/// unified master/output volume (or media element volume on Web), so non-media
/// streams automatically map to the primary output volume while preserving the
/// requested [VolumeStreamType] metadata in returned state objects.
enum VolumeStreamType {
  /// Music, video, games, and general media playback (`STREAM_MUSIC` on Android,
  /// master output volume on desktop/iOS, media elements on Web).
  media('media'),

  /// Incoming phone ringtone volume (`STREAM_RING` on Android).
  ring('ring'),

  /// Alarm clock volume (`STREAM_ALARM` on Android).
  alarm('alarm'),

  /// Notification alert volume (`STREAM_NOTIFICATION` on Android).
  notification('notification'),

  /// In-call voice / VoIP audio volume (`STREAM_VOICE_CALL` on Android).
  voiceCall('voiceCall'),

  /// System UI interaction sounds (`STREAM_SYSTEM` on Android).
  system('system'),

  /// Accessibility screen-reader audio (`STREAM_ACCESSIBILITY` on Android).
  accessibility('accessibility'),

  /// Dual-tone multi-frequency dial-pad tones (`STREAM_DTMF` on Android).
  dtmf('dtmf');

  const VolumeStreamType(this.wireName);

  /// Wire identifier transmitted over the platform channel.
  final String wireName;

  /// Parses a [VolumeStreamType] from its [wireName], falling back to
  /// [VolumeStreamType.media] when unrecognized.
  static VolumeStreamType fromWireName(String? value) {
    if (value == null) return VolumeStreamType.media;
    for (final stream in VolumeStreamType.values) {
      if (stream.wireName == value) {
        return stream;
      }
    }
    return VolumeStreamType.media;
  }
}

/// System ringer / sound profile mode.
///
/// Primarily supported on **Android** (`AudioManager.RINGER_MODE_*`).
/// On desktop and Web platforms, resolves to [RingerMode.silent] when muted
/// and [RingerMode.normal] when unmuted.
enum RingerMode {
  /// Normal audible mode (`RINGER_MODE_NORMAL`).
  normal('normal'),

  /// Vibrate-only mode without audible ringtone (`RINGER_MODE_VIBRATE`).
  vibrate('vibrate'),

  /// Silent mode with neither audible ringtone nor vibration (`RINGER_MODE_SILENT`).
  silent('silent'),

  /// Ringer mode cannot be determined on the current platform/device.
  unknown('unknown');

  const RingerMode(this.wireName);

  /// Wire identifier transmitted over the platform channel.
  final String wireName;

  /// Parses a [RingerMode] from its [wireName].
  static RingerMode fromWireName(String? value) {
    if (value == null) return RingerMode.unknown;
    for (final mode in RingerMode.values) {
      if (mode.wireName == value) {
        return mode;
      }
    }
    return RingerMode.unknown;
  }
}

/// Physical or logical audio output route classification.
enum AudioOutputRoute {
  /// Built-in device speaker(s).
  speaker('speaker'),

  /// Wired 3.5mm headphones or headset.
  wiredHeadset('wiredHeadset'),

  /// Bluetooth A2DP, LE Audio, or SCO/HFP device.
  bluetooth('bluetooth'),

  /// USB DAC, USB headset, or external USB audio interface.
  usb('usb'),

  /// Apple AirPlay wireless receiver.
  airPlay('airPlay'),

  /// HDMI or DisplayPort external monitor/TV audio.
  hdmi('hdmi'),

  /// Built-in phone receiver earpiece (voice call handset).
  earpiece('earpiece'),

  /// Virtual, loopback, or unclassified audio route.
  unknown('unknown');

  const AudioOutputRoute(this.wireName);

  /// Wire identifier transmitted over the platform channel.
  final String wireName;

  /// Parses an [AudioOutputRoute] from its [wireName].
  static AudioOutputRoute fromWireName(String? value) {
    if (value == null) return AudioOutputRoute.unknown;
    for (final route in AudioOutputRoute.values) {
      if (route.wireName == value) {
        return route;
      }
    }
    return AudioOutputRoute.unknown;
  }
}

/// Direction of a hardware volume key press or relative volume adjustment.
enum VolumeDirection {
  /// Volume up (`KEYCODE_VOLUME_UP`).
  up('up'),

  /// Volume down (`KEYCODE_VOLUME_DOWN`).
  down('down'),

  /// Mute toggle key (`KEYCODE_VOLUME_MUTE`).
  mute('mute');

  const VolumeDirection(this.wireName);

  /// Wire identifier transmitted over the platform channel.
  final String wireName;

  /// Parses a [VolumeDirection] from its [wireName].
  static VolumeDirection fromWireName(String? value) {
    for (final direction in VolumeDirection.values) {
      if (direction.wireName == value) {
        return direction;
      }
    }
    return VolumeDirection.up;
  }
}

/// Hardware volume key action phase.
enum VolumeKeyAction {
  /// Key pressed down.
  keyDown('down'),

  /// Key released.
  keyUp('up'),

  /// Single discrete key trigger.
  press('press');

  const VolumeKeyAction(this.wireName);

  /// Wire identifier transmitted over the platform channel.
  final String wireName;

  /// Parses a [VolumeKeyAction] from its [wireName].
  static VolumeKeyAction fromWireName(String? value) {
    for (final action in VolumeKeyAction.values) {
      if (action.wireName == value) {
        return action;
      }
    }
    return VolumeKeyAction.press;
  }
}

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
    required this. intercepted,
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
    final rawStreams = map['supportedStreams'] as List<Object?>? ?? const <Object?>['media'];
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
