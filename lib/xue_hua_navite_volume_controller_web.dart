import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/volume_controller_models.dart';
import 'xue_hua_navite_volume_controller_platform_interface.dart';

/// Web implementation of [XueHuaNaviteVolumeControllerPlatform].
///
/// Because web browsers sandbox OS hardware master volume for security,
/// [XueHuaNaviteVolumeControllerWeb] provides:
/// 1. Page-wide synchronization of all `<audio>` and `<video>` DOM elements
///    (including dynamically inserted elements observed via `MutationObserver`).
/// 2. Bidirectional `volumechange` DOM event listening so native media controls
///    immediately notify Flutter.
/// 3. Optional Web Audio API `AudioContext` + `GainNode` amplification boost
///    (`0.0` to `4.0`, up to 400% gain compensation) for quiet media sources.
/// 4. Audio output device listing via `navigator.mediaDevices.enumerateDevices()`
///    and output sink switching via `HTMLMediaElement.setSinkId` where supported.
class XueHuaNaviteVolumeControllerWeb
    extends XueHuaNaviteVolumeControllerPlatform {
  /// Constructs a [XueHuaNaviteVolumeControllerWeb].
  XueHuaNaviteVolumeControllerWeb();

  /// Registers [XueHuaNaviteVolumeControllerWeb] as the platform implementation.
  static void registerWith(Registrar registrar) {
    XueHuaNaviteVolumeControllerPlatform.instance =
        XueHuaNaviteVolumeControllerWeb();
  }

  final StreamController<VolumeChangeEvent> _volumeChangedController =
      StreamController<VolumeChangeEvent>.broadcast();

  final StreamController<VolumeButtonEvent> _hardwareButtonController =
      StreamController<VolumeButtonEvent>.broadcast();

  double _volume = 1.0;
  double _preMuteVolume = 1.0;
  bool _isMuted = false;
  double _gainBoost = 1.0;
  String _selectedDeviceId = 'default';
  String _selectedDeviceName = 'Browser Default Audio Output';
  bool _initialized = false;
  bool _suppressDomEcho = false;

  web.MutationObserver? _mutationObserver;
  final Set<web.HTMLMediaElement> _attachedElements = <web.HTMLMediaElement>{};
  final Map<web.HTMLMediaElement, JSObject> _gainNodes =
      <web.HTMLMediaElement, JSObject>{};
  JSObject? _audioContext;

  @override
  Stream<VolumeChangeEvent> get onVolumeChanged =>
      _volumeChangedController.stream;

  @override
  Stream<VolumeButtonEvent> get onHardwareButton =>
      _hardwareButtonController.stream;

  VolumeState _buildCurrentState({
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    final effectiveVolume = _isMuted ? 0.0 : _volume;
    return VolumeState(
      volume: effectiveVolume,
      isMuted: _isMuted || effectiveVolume <= 0.0001,
      streamType: stream,
      stepIndex: (effectiveVolume * 100).round(),
      maxSteps: 100,
      minSteps: 0,
      ringerMode: (_isMuted || effectiveVolume <= 0.0001)
          ? RingerMode.silent
          : RingerMode.normal,
      outputDeviceName: _selectedDeviceName,
      outputRoute: AudioOutputRoute.speaker,
      outputDeviceId: _selectedDeviceId,
    );
  }

  void _emitChange({
    required double oldVolume,
    required String reason,
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    if (_volumeChangedController.isClosed) return;
    _volumeChangedController.add(
      VolumeChangeEvent(
        state: _buildCurrentState(stream: stream),
        oldVolume: oldVolume,
        reason: reason,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _syncAllMediaElements() {
    _suppressDomEcho = true;
    try {
      final nodes = web.document.querySelectorAll('audio, video');
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes.item(i);
        if (node != null && node.isA<web.HTMLMediaElement>()) {
          final media = node as web.HTMLMediaElement;
          _attachToMediaElement(media);
          media.volume = _volume.clamp(0.0, 1.0);
          media.muted = _isMuted;
          if (_selectedDeviceId != 'default') {
            _trySetElementSinkId(media, _selectedDeviceId);
          }
          if ((_gainBoost - 1.0).abs() > 0.001) {
            _applyGainToElement(media, _gainBoost);
          }
        }
      }
    } finally {
      _suppressDomEcho = false;
    }
  }

  void _attachToMediaElement(web.HTMLMediaElement element) {
    if (_attachedElements.contains(element)) return;
    _attachedElements.add(element);

    element.addEventListener(
      'volumechange',
      ((web.Event _) {
        if (_suppressDomEcho) return;
        final oldVolume = _isMuted ? 0.0 : _volume;
        final newVolume = element.volume.clamp(0.0, 1.0);
        final newMuted = element.muted || newVolume <= 0.0001;
        if ((newVolume - _volume).abs() > 0.001 || newMuted != _isMuted) {
          _volume = newVolume;
          if (!newMuted && newVolume > 0.0001) {
            _preMuteVolume = newVolume;
          }
          _isMuted = newMuted;
          _syncAllMediaElements();
          _emitChange(oldVolume: oldVolume, reason: 'domVolumeChange');
        }
      }).toJS,
    );
  }

  void _startDomObservation() {
    if (_mutationObserver != null) return;
    _syncAllMediaElements();

    final body = web.document.body;
    if (body == null) return;

    _mutationObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> mutations, web.MutationObserver _) {
        _syncAllMediaElements();
      }).toJS,
    );
    _mutationObserver!.observe(
      body,
      web.MutationObserverInit(childList: true, subtree: true),
    );
  }

  void _trySetElementSinkId(web.HTMLMediaElement element, String sinkId) {
    final jsElement = element as JSObject;
    if (jsElement.has('setSinkId')) {
      try {
        jsElement.callMethodVarArgs<JSAny?>('setSinkId'.toJS, <JSAny?>[
          sinkId.toJS,
        ]);
      } catch (_) {
        // Ignore if browser or permissions block setSinkId
      }
    }
  }

  void _applyGainToElement(web.HTMLMediaElement element, double gainValue) {
    try {
      final win = web.window as JSObject;
      JSFunction? audioCtxCtor;
      if (win.has('AudioContext')) {
        audioCtxCtor = win.getProperty<JSFunction>('AudioContext'.toJS);
      } else if (win.has('webkitAudioContext')) {
        audioCtxCtor = win.getProperty<JSFunction>('webkitAudioContext'.toJS);
      }
      if (audioCtxCtor == null) return;

      _audioContext ??= audioCtxCtor.callAsConstructor<JSObject>();
      final ctx = _audioContext!;

      JSObject? gainNode = _gainNodes[element];
      if (gainNode == null) {
        final source = ctx.callMethodVarArgs<JSObject>(
          'createMediaElementSource'.toJS,
          <JSAny?>[element],
        );
        gainNode = ctx.callMethodVarArgs<JSObject>('createGain'.toJS);
        final destination = ctx.getProperty<JSObject>('destination'.toJS);
        source.callMethodVarArgs<JSAny?>('connect'.toJS, <JSAny?>[gainNode]);
        gainNode.callMethodVarArgs<JSAny?>('connect'.toJS, <JSAny?>[
          destination,
        ]);
        _gainNodes[element] = gainNode;
      }

      final gainParam = gainNode.getProperty<JSObject>('gain'.toJS);
      gainParam.setProperty('value'.toJS, gainValue.toJS);
    } catch (_) {
      // Cross-origin media elements or autoplay policies may restrict WebAudio graph binding
    }
  }

  @override
  Future<VolumeState> initialize([
    VolumeControllerConfig config = const VolumeControllerConfig(),
  ]) async {
    if (!_initialized) {
      _initialized = true;
      _startDomObservation();
    }
    return _buildCurrentState(stream: config.defaultStream);
  }

  @override
  Future<VolumeCapabilities> getCapabilities() async {
    return const VolumeCapabilities(
      platform: 'web',
      supportsSystemVolumeControl: false,
      supportsMuteControl: true,
      supportsVolumeChangeListening: true,
      supportsHardwareButtonInterception: false,
      supportsSystemUIControl: false,
      supportsMultipleStreamTypes: false,
      supportsRingerMode: false,
      supportsAudioDeviceListing: true,
      supportsDeviceSelection: true,
      supportsAppVolumeControl: true,
      supportedStreams: <VolumeStreamType>[VolumeStreamType.media],
      audioBackend: 'HTMLMediaElement + WebAudio GainNode',
      platformNotes: <String>[
        'Browsers sandbox OS-level hardware master volume; volume and mute calls synchronize all <audio> and <video> elements in the page DOM.',
        'Use setWebGainBoost(0.0..4.0) to apply Web Audio API GainNode amplification up to 400%.',
        'Audio output device switching uses HTMLMediaElement.setSinkId where supported by the browser.',
      ],
    );
  }

  @override
  Future<VolumeState> getVolumeState({
    VolumeStreamType stream = VolumeStreamType.media,
  }) async {
    _syncAllMediaElements();
    return _buildCurrentState(stream: stream);
  }

  @override
  Future<double> getVolume({
    VolumeStreamType stream = VolumeStreamType.media,
  }) async {
    return _isMuted ? 0.0 : _volume;
  }

  @override
  Future<VolumeState> setVolume(
    double volume, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final oldVolume = _isMuted ? 0.0 : _volume;
    final clamped = volume.clamp(0.0, 1.0);
    _volume = clamped;
    if (clamped > 0.0001) {
      _preMuteVolume = clamped;
      _isMuted = false;
    } else {
      _isMuted = true;
    }
    _syncAllMediaElements();
    _emitChange(oldVolume: oldVolume, reason: 'programmatic', stream: stream);
    return _buildCurrentState(stream: stream);
  }

  @override
  Future<VolumeState> adjustVolume(
    double delta, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final base = _isMuted ? 0.0 : _volume;
    return setVolume(
      (base + delta).clamp(0.0, 1.0),
      stream: stream,
      showSystemUI: showSystemUI,
    );
  }

  @override
  Future<VolumeState> stepVolume(
    VolumeDirection direction, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    if (direction == VolumeDirection.mute) {
      return toggleMute(stream: stream, showSystemUI: showSystemUI);
    }
    final delta = direction == VolumeDirection.up ? 0.05 : -0.05;
    return adjustVolume(delta, stream: stream, showSystemUI: showSystemUI);
  }

  @override
  Future<Map<VolumeStreamType, double>> getAllStreamVolumes() async {
    final current = _isMuted ? 0.0 : _volume;
    return <VolumeStreamType, double>{VolumeStreamType.media: current};
  }

  @override
  Future<bool> isMuted({
    VolumeStreamType stream = VolumeStreamType.media,
  }) async {
    return _isMuted || _volume <= 0.0001;
  }

  @override
  Future<VolumeState> setMute(
    bool muted, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) async {
    final oldVolume = _isMuted ? 0.0 : _volume;
    if (muted) {
      if (_volume > 0.0001) {
        _preMuteVolume = _volume;
      }
      _isMuted = true;
    } else {
      _isMuted = false;
      if (_volume <= 0.0001) {
        _volume = _preMuteVolume > 0.0001 ? _preMuteVolume : 0.5;
      }
    }
    _syncAllMediaElements();
    _emitChange(oldVolume: oldVolume, reason: 'muteChange', stream: stream);
    return _buildCurrentState(stream: stream);
  }

  @override
  Future<VolumeState> toggleMute({
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    return setMute(!_isMuted, stream: stream, showSystemUI: showSystemUI);
  }

  @override
  Future<RingerMode> getRingerMode() async {
    return (_isMuted || _volume <= 0.0001)
        ? RingerMode.silent
        : RingerMode.normal;
  }

  @override
  Future<RingerMode> setRingerMode(RingerMode mode) async {
    if (mode == RingerMode.silent || mode == RingerMode.vibrate) {
      await setMute(true);
      return RingerMode.silent;
    } else {
      await setMute(false);
      return RingerMode.normal;
    }
  }

  @override
  Future<bool> hasDoNotDisturbAccess() async => true;

  @override
  Future<bool> requestDoNotDisturbAccess() async => true;

  @override
  Future<void> setShowSystemUI(bool show) async {}

  @override
  Future<void> setInterceptHardwareButtons(bool intercept) async {}

  @override
  Future<List<AudioDeviceInfo>> getOutputDevices() async {
    final devices = <AudioDeviceInfo>[];
    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      final jsDevices = await mediaDevices.enumerateDevices().toDart;
      final list = jsDevices.toDart;
      var index = 0;
      for (final item in list) {
        if (item.kind == 'audiooutput') {
          index++;
          final id = item.deviceId.isNotEmpty ? item.deviceId : 'output_$index';
          final label = item.label.isNotEmpty
              ? item.label
              : 'Audio Output #$index';
          devices.add(
            AudioDeviceInfo(
              id: id,
              name: label,
              route: label.toLowerCase().contains('bluetooth')
                  ? AudioOutputRoute.bluetooth
                  : label.toLowerCase().contains('usb')
                  ? AudioOutputRoute.usb
                  : AudioOutputRoute.speaker,
              isDefault:
                  id == _selectedDeviceId ||
                  (devices.isEmpty && _selectedDeviceId == 'default'),
              isOutput: true,
              isInput: false,
              volume: _isMuted ? 0.0 : _volume,
              isMuted: _isMuted,
            ),
          );
        }
      }
    } catch (_) {
      // Fallback if enumerateDevices is restricted by Permissions-Policy
    }

    if (devices.isEmpty) {
      devices.add(
        AudioDeviceInfo(
          id: 'default',
          name: _selectedDeviceName,
          route: AudioOutputRoute.speaker,
          isDefault: true,
          isOutput: true,
          isInput: false,
          volume: _isMuted ? 0.0 : _volume,
          isMuted: _isMuted,
        ),
      );
    }
    return devices;
  }

  @override
  Future<AudioDeviceInfo?> getCurrentOutputDevice() async {
    final devices = await getOutputDevices();
    for (final device in devices) {
      if (device.isDefault) return device;
    }
    return devices.isNotEmpty ? devices.first : null;
  }

  @override
  Future<bool> setOutputDevice(String deviceId) async {
    _selectedDeviceId = deviceId;
    final devices = await getOutputDevices();
    for (final dev in devices) {
      if (dev.id == deviceId) {
        _selectedDeviceName = dev.name;
        break;
      }
    }
    _syncAllMediaElements();
    _emitChange(oldVolume: _isMuted ? 0.0 : _volume, reason: 'routeChange');
    return true;
  }

  @override
  Future<double> getAppVolume() async => _isMuted ? 0.0 : _volume;

  @override
  Future<double> setAppVolume(double volume) async {
    final state = await setVolume(volume);
    return state.volume;
  }

  @override
  Future<double> setWebGainBoost(double gain) async {
    _gainBoost = gain.clamp(0.0, 4.0);
    _syncAllMediaElements();
    return _gainBoost;
  }

  @override
  Future<double> getWebGainBoost() async => _gainBoost;

  @override
  Future<void> dispose() async {
    _mutationObserver?.disconnect();
    _mutationObserver = null;
    _attachedElements.clear();
  }
}
