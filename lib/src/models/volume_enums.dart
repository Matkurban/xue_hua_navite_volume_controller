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
