## 1.0.0

* Initial stable release of `xue_hua_navite_volume_controller` across Android, iOS, macOS, Windows, Linux, and Web.
* Added normalized volume control (`getVolume`, `setVolume`, `adjustVolume`, `stepVolume`, `volumeUp`, `volumeDown`, `getVolumeState`) and reactive `stateNotifier` / `onVolumeChanged` stream.
* Added multi-stream volume control on Android (`media`, `ring`, `alarm`, `notification`, `voiceCall`, `system`, `accessibility`, `dtmf`) via `AudioManager`.
* Added mute, unmute, and toggle mute (`isMuted`, `setMute`, `toggleMute`) with automatic software zero-volume fallback and pre-mute restoration for devices without hardware mute registers.
* Added Android ringer mode control (`normal`, `vibrate`, `silent`) and Do Not Disturb (`NotificationPolicy`) access checks and settings navigation.
* Added native system volume HUD visibility toggle (`setShowSystemUI`) on Android (`FLAG_SHOW_UI`) and iOS (`MPVolumeView`).
* Added physical hardware volume button interception (`setInterceptHardwareButtons`, `onHardwareButton`) on Android.
* Added audio output device enumeration and default output device switching (`getOutputDevices`, `getCurrentOutputDevice`, `setOutputDevice`).
* Added per-application session volume (`getAppVolume`, `setAppVolume`) on Windows (`ISimpleAudioVolume`) and Web, plus Web Audio API `GainNode` boost (`setWebGainBoost`, `getWebGainBoost`) up to 400%.
* Bundled Dart package skill under `skills/xue_hua_navite_volume_controller-usage/SKILL.md`.
