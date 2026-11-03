# xue_hua_navite_volume_controller

English | [简体中文](./README_ZH.md)

A production-grade, 6-platform system and application audio volume controller plugin for Flutter (`Android`, `iOS`, `macOS`, `Windows`, `Linux`, and `Web`).

- **Author**: Matkurban (`3496354336@qq.com`)
- **Repository**: [https://github.com/Matkurban/xue_hua_navite_volume_controller](https://github.com/Matkurban/xue_hua_navite_volume_controller)
- **Version**: `1.0.0`

## Features

- **Unified Normalized Volume Control (`0.0`–`1.0`)**: Read (`getVolume`), write (`setVolume`), adjust by relative delta (`adjustVolume`), or step up/down (`stepVolume`, `volumeUp`, `volumeDown`) with rich state snapshots (`VolumeState`).
- **Android 8-Stream Audio Mixer**: Independently read and control `media`, `ring`, `alarm`, `notification`, `voiceCall`, `system`, `accessibility`, and `dtmf` streams via `AudioManager`.
- **Mute & Unmute with Smart Fallback**: Hardware mute control (`isMuted`, `setMute`, `toggleMute`) with automatic software zero-volume fallback and pre-mute level restoration on iOS or external HDMI/DisplayPort monitors that lack a hardware mute register.
- **Real-Time OS Volume & Route Event Stream**: Subscribe to `onVolumeChanged` or bind directly to `stateNotifier` (`ValueNotifier<VolumeState>`) to react immediately to physical volume buttons, Control Center sliders, Bluetooth headset buttons, or audio device hot-plugging.
- **Native System Volume HUD Control**: Show or suppress the OS volume overlay (`setShowSystemUI`) on Android (`AudioManager.FLAG_SHOW_UI`) and iOS (`MPVolumeView`).
- **Physical Hardware Volume Button Interception**: Capture physical `Volume Up`, `Volume Down`, and `Volume Mute` key presses on Android (`setInterceptHardwareButtons`, `onHardwareButton`) without modifying the system volume—ideal for camera shutters, page turners, or custom in-app media players.
- **Ringer Mode & Do Not Disturb (DND) Management**: Query and switch Android ringer modes (`RingerMode.normal`, `vibrate`, `silent`) with built-in Notification Policy permission checking (`hasDoNotDisturbAccess`) and settings navigation (`requestDoNotDisturbAccess`).
- **Audio Output Device Enumeration & Switching**: List connected audio output endpoints (`getOutputDevices`, `getCurrentOutputDevice`) and switch the default system output device (`setOutputDevice`) on macOS (`CoreAudio`), Windows (`IPolicyConfig`), Linux (`pactl`), Android 12+ (`setCommunicationDevice`), and Web (`setSinkId`).
- **Per-Application Volume & WebAudio Gain Boost**: Control process-local volume on Windows (`ISimpleAudioVolume`) and Web (`getAppVolume`, `setAppVolume`), plus amplify quiet HTML5 `<audio>`/`<video>` elements up to `400%` (`setWebGainBoost(0.0..4.0)`) via the Web Audio API `GainNode`.
- **Bundled AI Agent Skill**: Ships with a standardized Dart package skill (`skills/xue_hua_navite_volume_controller-usage/SKILL.md`) following [Ship skills with packages](https://dart.dev/tools/pub/package-skills).

## Platform Architecture & Differences

| Capability | Android (`API 24+`) | iOS (`15.0+`) | macOS (`12.0+`) | Windows (`10/11`) | Linux (`GTK3`) | Web (`WASM / JS`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Native Audio Backend** | `AudioManager` + `Window.Callback` | `AVAudioSession` + `MPVolumeView` | `CoreAudio` (`AudioObjectProperty`) | `MMDeviceAPI` + `IAudioEndpointVolume` | `PulseAudio` (`pactl`) / `PipeWire` (`wpctl`) / `ALSA` (`amixer`) | `HTMLMediaElement` + `WebAudio GainNode` |
| **System Master Volume** | Yes | Yes (physical device) | Yes | Yes (+ dB reading) | Yes | Sandboxed (controls DOM `<audio>`/`<video>`) |
| **Multi-Stream Support** | 8 independent streams | Unified output | Unified output | Unified output | Unified output | Unified DOM media |
| **Mute Control** | `ADJUST_MUTE` / `ADJUST_UNMUTE` | Software 0.0 + restore | `kAudioDevicePropertyMute` + fallback | `IAudioEndpointVolume::SetMute` | Sink mute (`pactl`/`wpctl`/`amixer`) | `.muted` property + restore |
| **System Volume HUD Toggle** | Yes (`FLAG_SHOW_UI`) | Yes (offscreen `MPVolumeView`) | Managed by macOS | Managed by Windows | Managed by DE | N/A |
| **Hardware Key Interception** | Yes (`KEYCODE_VOLUME_*`) | No (restricted by iOS) | No | No | No | No |
| **Ringer Mode & DND** | `normal`, `vibrate`, `silent` | Maps to mute state | Maps to mute state | Maps to mute state | Maps to mute state | Maps to mute state |
| **Audio Device Listing** | `getDevices(GET_DEVICES_OUTPUTS)` | `currentRoute.outputs` | `kAudioHardwarePropertyDevices` | `EnumAudioEndpoints` | Default sink query | `mediaDevices.enumerateDevices()` |
| **Output Device Switching** | Android 12+ comm device | System route picker only | `kAudioHardwarePropertyDefaultOutputDevice` | `IPolicyConfig::SetDefaultEndpoint` | `pactl set-default-sink` | `HTMLMediaElement.setSinkId` |
| **Per-App Volume / Gain** | Media stream | Media stream | Master stream | `ISimpleAudioVolume` (per-process) | Master sink | DOM volume + `GainNode` (`0.0`–`4.0`) |

## Installation & Native Setup

Add `xue_hua_navite_volume_controller` to your `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_navite_volume_controller: ^1.0.0
```

### Android Setup

The plugin automatically merges the following permissions in its `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
```

- `MODIFY_AUDIO_SETTINGS` is a normal permission granted automatically at install time.
- `ACCESS_NOTIFICATION_POLICY` is required only if your app switches the device into or out of `RingerMode.silent` (Do Not Disturb) on Android 6.0+. Always check `await controller.hasDoNotDisturbAccess()` and call `await controller.requestDoNotDisturbAccess()` before setting `RingerMode.silent`.

### iOS Setup

- Requires iOS `15.0` or later.
- Programmatic volume changes use `MPVolumeView`'s internal `UISlider`. **Important**: Apple's iOS Simulator does not emulate hardware `MPVolumeView` slider changes—always test programmatic volume changes and HUD hiding on a **physical iPhone or iPad**.

### macOS Setup

- Requires macOS `12.0` or later.
- Works out of the box inside or outside the macOS App Sandbox using `CoreAudio` and `AudioToolbox`.

### Windows Setup

- Uses standard Windows CoreAudio COM interfaces (`mmdeviceapi.h`, `endpointvolume.h`, `audiopolicy.h`). No extra DLLs or runtime installers are required.

### Linux Setup

- Compiles with standard `flutter_linux` and `gtk+-3.0` headers without requiring extra `-dev` audio packages at build time.
- At runtime, automatically detects and uses `pactl` (PulseAudio / PipeWire-Pulse), `wpctl` (PipeWire WirePlumber), or `amixer` (ALSA).

## Quick Start & Usage

### 1. Initialize and Bind Reactive UI

```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

final controller = XueHuaNaviteVolumeController.instance;

Future<void> setupVolumeController() async {
  final initialState = await controller.initialize(
    const VolumeControllerConfig(
      defaultStream: VolumeStreamType.media,
      showSystemUI: false,
      interceptHardwareButtons: false,
      listenToVolumeChanges: true,
    ),
  );
  debugPrint('Initial volume: ${initialState.percentage}% (muted: ${initialState.isMuted})');
}
```

Use `ValueListenableBuilder<VolumeState>` with `controller.stateNotifier` for zero-boilerplate reactive UI updates:

```dart
ValueListenableBuilder<VolumeState>(
  valueListenable: XueHuaNaviteVolumeController.instance.stateNotifier,
  builder: (context, state, _) {
    return Row(
      children: [
        IconButton(
          icon: Icon(state.isMuted ? Icons.volume_off : Icons.volume_up),
          onPressed: () => XueHuaNaviteVolumeController.instance.toggleMute(),
        ),
        Expanded(
          child: Slider(
            value: state.volume,
            onChanged: (val) => XueHuaNaviteVolumeController.instance.setVolume(val),
          ),
        ),
        Text('${state.percentage}%'),
      ],
    );
  },
)
```

### 2. Listen to Volume Change & Hardware Key Streams

```dart
final volumeSub = controller.onVolumeChanged.listen((VolumeChangeEvent event) {
  debugPrint(
    'Stream ${event.streamType.wireName} changed to ${event.state.percentage}% '
    '(reason: ${event.reason}, device: ${event.state.outputDeviceName})',
  );
});

// Enable physical hardware volume button interception on Android:
await controller.setInterceptHardwareButtons(true);
final buttonSub = controller.onHardwareButton.listen((VolumeButtonEvent button) {
  if (button.action == VolumeKeyAction.keyDown) {
    debugPrint('Intercepted hardware key: ${button.direction.wireName}');
  }
});
```

### 3. Control Android Multi-Stream Volumes & Ringer Mode

```dart
// Set individual Android stream volumes:
await controller.setVolume(0.8, stream: VolumeStreamType.media, showSystemUI: false);
await controller.setVolume(1.0, stream: VolumeStreamType.alarm, showSystemUI: false);
await controller.setVolume(0.4, stream: VolumeStreamType.notification, showSystemUI: false);

// Read all stream volumes at once:
final Map<VolumeStreamType, double> allVolumes = await controller.getAllStreamVolumes();

// Safely switch ringer mode:
if (await controller.hasDoNotDisturbAccess()) {
  await controller.setRingerMode(RingerMode.silent);
} else {
  await controller.requestDoNotDisturbAccess();
}
```

### 4. Enumerate & Switch Audio Output Devices

```dart
final devices = await controller.getOutputDevices();
for (final dev in devices) {
  debugPrint('${dev.name} [${dev.route.wireName}] (default: ${dev.isDefault})');
}

// Switch to a specific output device on macOS, Windows, Linux, Android 12+, or Web:
if (devices.length > 1) {
  await controller.setOutputDevice(devices.last.id);
}
```

### 5. Per-Application Volume (Windows/Web) & WebAudio Gain Boost

```dart
// Set process-local application volume on Windows (ISimpleAudioVolume) or Web:
await controller.setAppVolume(0.75);

// Apply 200% Web Audio API GainNode boost to HTML5 <audio>/<video> elements on Web:
await controller.setWebGainBoost(2.0);
```

## Important Caveats & Best Practices

1. **iOS Simulator vs Physical Device**: iOS Simulator does not attach a hardware audio output slider to `MPVolumeView`. Always verify programmatic volume setting and HUD suppression on a real iOS device.
2. **External HDMI / DisplayPort Monitors on macOS**: Many external HDMI/DisplayPort displays do not expose a writable hardware volume or mute register over CEC (`AudioObjectIsPropertySettable` returns `false`). The plugin automatically falls back to software zero-volume mute so `setMute(true)` still silences output reliably.
3. **Android Do Not Disturb (`SecurityException`)**: Android 6.0+ throws a `SecurityException` if an app attempts to enter or exit `RingerMode.silent` without Notification Policy access. The plugin surfaces this as a typed `VolumeControllerException(code: 'DND_PERMISSION_REQUIRED')` and provides `hasDoNotDisturbAccess()` / `requestDoNotDisturbAccess()`.
4. **Cleaning Up Interception**: If you enable `setInterceptHardwareButtons(true)` on a specific screen (such as a camera or reader page), call `setInterceptHardwareButtons(false)` in `dispose()` so normal system volume button behavior is restored when the user leaves that screen.

## AI Agent Skills Support

This package ships with an official AI Agent Skill under `skills/xue_hua_navite_volume_controller-usage/SKILL.md` in compliance with the [Dart Package Skills specification](https://dart.dev/tools/pub/package-skills). Consumers can install it into their project with:

```bash
dart run skills@ get
```

## License

MIT License © 2026 Matkurban (`3496354336@qq.com`)
