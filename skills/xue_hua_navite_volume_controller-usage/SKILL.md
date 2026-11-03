---
name: xue_hua_navite_volume_controller-usage
description: >-
  Use when the user is working with xue_hua_navite_volume_controller APIs
  (XueHuaNaviteVolumeController, VolumeStreamType, RingerMode, VolumeState,
  VolumeCapabilities, AudioDeviceInfo, VolumeControllerConfig,
  VolumeControllerListener) to control system or application audio volume,
  mute state, multi-stream Android audio, ringer modes, Do Not Disturb
  permissions, system volume HUD visibility, physical hardware volume button
  interception, audio output device routing, or Web Audio GainNode boost across
  Android, iOS, macOS, Windows, Linux, and Web.
---

# xue_hua_navite_volume_controller Usage Guide

Provide idiomatic integration patterns, platform difference handling, and error recovery for the `xue_hua_navite_volume_controller` plugin across Android, iOS, macOS, Windows, Linux, and Web.

## Guidelines

* Always call `await XueHuaNaviteVolumeController.instance.initialize(const VolumeControllerConfig(...))` before reading or subscribing to volume changes so native observers (`BroadcastReceiver`, `AVAudioSession` KVO, `CoreAudio` property listeners, Windows `IAudioEndpointVolumeCallback`, or Web `MutationObserver`) are registered.
* Always pass normalized values in the `[0.0, 1.0]` range to `setVolume` and `setAppVolume`. Use `adjustVolume(delta)` for relative changes (such as `+0.05` or `-0.05`) and `stepVolume(VolumeDirection.up)` / `volumeUp()` / `volumeDown()` for native hardware steps.
* Query `await XueHuaNaviteVolumeController.instance.getCapabilities()` at runtime when building adaptive UI so platform-specific controls (such as Android multi-stream sliders, ringer modes, hardware button interception, or Web `GainNode` boost) are only shown when supported.
* On Android 6.0+ (API 23+), check `await controller.hasDoNotDisturbAccess()` before switching into or out of `RingerMode.silent`. If `false`, call `await controller.requestDoNotDisturbAccess()` to open the system Notification Policy settings screen instead of allowing a `SecurityException` (`VolumeControllerException` with code `'DND_PERMISSION_REQUIRED'`).
* Cancel stream subscriptions (`onVolumeChanged`, `onHardwareButton`) or remove `VolumeControllerListener`s in `State.dispose()` to prevent memory leaks, and disable hardware button interception (`setInterceptHardwareButtons(false)`) when leaving routes that capture physical volume keys.
* On Web, remember that browsers sandbox OS hardware master volume (`capabilities.supportsSystemVolumeControl == false`). `setVolume` and `setMute` synchronize all `<audio>` and `<video>` elements in the DOM, and `setWebGainBoost(1.0..4.0)` applies Web Audio API `GainNode` amplification up to 400%.

## Platform Differences

| Feature | Android | iOS | macOS | Windows | Linux | Web |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Native Backend | `AudioManager` | `AVAudioSession` + `MPVolumeView` | `CoreAudio` (`AudioObjectProperty`) | `MMDeviceAPI` + `IAudioEndpointVolume` | `PulseAudio` (`pactl`) / `PipeWire` (`wpctl`) / `ALSA` (`amixer`) | `HTMLMediaElement` + `WebAudio GainNode` |
| System Master Volume | Yes | Yes (physical device) | Yes | Yes (+ dB reading) | Yes | No (DOM media elements) |
| Multi-Stream (`ring`, `alarm`, etc.) | Yes (8 streams) | Unified output | Unified output | Unified output | Unified output | Unified media |
| Mute Control | Hardware stream mute | Software zero-volume + restore | Hardware mute + zero-volume fallback | Hardware endpoint mute | Sink mute (`pactl`/`wpctl`/`amixer`) | DOM `.muted` + restore |
| System Volume HUD Control | Yes (`FLAG_SHOW_UI`) | Yes (offscreen `MPVolumeView`) | No | No | No | No |
| Hardware Key Interception | Yes (`Window.Callback`) | No | No | No | No | No |
| Ringer Mode & DND | Yes (`normal`/`vibrate`/`silent`) | Maps to mute | Maps to mute | Maps to mute | Maps to mute | Maps to mute |
| Output Device Listing & Switching | Listing + API 31+ comm routing | Listing (`currentRoute.outputs`) | Listing + default device switching | Listing + `IPolicyConfig` switching | Default sink listing + `pactl` switching | `enumerateDevices` + `setSinkId` |
| Per-App Volume / Gain Boost | Media stream | Media stream | Master stream | `ISimpleAudioVolume` per-process | Master sink | DOM volume + `GainNode` (0x-4x) |

## Examples

### Initialize and listen to real-time volume & hardware button changes

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

class VolumeMonitorPage extends StatefulWidget {
  const VolumeMonitorPage({super.key});

  @override
  State<VolumeMonitorPage> createState() => _VolumeMonitorPageState();
}

class _VolumeMonitorPageState extends State<VolumeMonitorPage> {
  final _controller = XueHuaNaviteVolumeController.instance;
  StreamSubscription<VolumeChangeEvent>? _volumeSub;
  StreamSubscription<VolumeButtonEvent>? _buttonSub;
  VolumeCapabilities? _capabilities;

  @override
  void initState() {
    super.initState();
    _initVolumeController();
  }

  Future<void> _initVolumeController() async {
    await _controller.initialize(
      const VolumeControllerConfig(
        defaultStream: VolumeStreamType.media,
        showSystemUI: false,
        interceptHardwareButtons: false,
        listenToVolumeChanges: true,
      ),
    );
    final caps = await _controller.getCapabilities();
    _volumeSub = _controller.onVolumeChanged.listen((event) {
      debugPrint(
        'Volume changed (${event.reason}): '
        '${event.state.percentage}% | muted=${event.state.isMuted}',
      );
    });
    _buttonSub = _controller.onHardwareButton.listen((button) {
      debugPrint('Hardware key: ${button.direction.wireName} (${button.action.wireName})');
    });
    if (mounted) {
      setState(() => _capabilities = caps);
    }
  }

  @override
  void dispose() {
    _volumeSub?.cancel();
    _buttonSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VolumeState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Volume: ${state.percentage}% (${_capabilities?.audioBackend ?? "loading"})'),
            Slider(
              value: state.volume,
              onChanged: (value) => _controller.setVolume(value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => _controller.volumeDown(),
                ),
                IconButton(
                  icon: Icon(state.isMuted ? Icons.volume_off : Icons.volume_up),
                  onPressed: () => _controller.toggleMute(),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _controller.volumeUp(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
```

### Android multi-stream control and safe Do Not Disturb ringer mode switching

```dart
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

Future<void> configureAndroidAudioProfile() async {
  final controller = XueHuaNaviteVolumeController.instance;

  // Adjust independent Android audio streams without showing the system HUD
  await controller.setVolume(0.75, stream: VolumeStreamType.media, showSystemUI: false);
  await controller.setVolume(0.90, stream: VolumeStreamType.alarm, showSystemUI: false);
  await controller.setVolume(0.50, stream: VolumeStreamType.notification, showSystemUI: false);

  // Safely switch to Silent ringer mode after verifying Do Not Disturb access
  final hasDnd = await controller.hasDoNotDisturbAccess();
  if (!hasDnd) {
    await controller.requestDoNotDisturbAccess();
    return;
  }
  await controller.setRingerMode(RingerMode.silent);
}
```

### Enumerate and switch audio output devices on Desktop / Mobile / Web

```dart
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

Future<void> switchAudioOutputIfAvailable() async {
  final controller = XueHuaNaviteVolumeController.instance;
  final capabilities = await controller.getCapabilities();
  final devices = await controller.getOutputDevices();

  for (final device in devices) {
    if (!device.isDefault && capabilities.supportsDeviceSelection) {
      await controller.setOutputDevice(device.id);
      break;
    }
  }
}
```
