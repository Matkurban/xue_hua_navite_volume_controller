import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/volume_controller_models.dart';
import 'xue_hua_navite_volume_controller_platform_interface.dart';

/// An implementation of [XueHuaNaviteVolumeControllerPlatform] that uses
/// Flutter [MethodChannel] for commands and Reverse Method Callbacks / EventStreams
/// for real-time OS notifications.
class MethodChannelXueHuaNaviteVolumeController
    extends XueHuaNaviteVolumeControllerPlatform {
  /// Creates a [MethodChannelXueHuaNaviteVolumeController] and registers
  /// incoming native event handlers.
  MethodChannelXueHuaNaviteVolumeController() {
    methodChannel.setMethodCallHandler(_handleNativeCallback);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'xue_hua_navite_volume_controller',
  );

  final StreamController<VolumeChangeEvent> _volumeChangedController =
      StreamController<VolumeChangeEvent>.broadcast();

  final StreamController<VolumeButtonEvent> _hardwareButtonController =
      StreamController<VolumeButtonEvent>.broadcast();

  bool _showSystemUI = false;
  VolumeStreamType _defaultStream = VolumeStreamType.media;

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onVolumeChanged':
        final rawArgs = call.arguments;
        if (rawArgs is Map<Object?, Object?>) {
          _volumeChangedController.add(VolumeChangeEvent.fromMap(rawArgs));
        }
        return null;
      case 'onHardwareButton':
        final rawArgs = call.arguments;
        if (rawArgs is Map<Object?, Object?>) {
          _hardwareButtonController.add(VolumeButtonEvent.fromMap(rawArgs));
        }
        return null;
      default:
        return null;
    }
  }

  @override
  Stream<VolumeChangeEvent> get onVolumeChanged =>
      _volumeChangedController.stream;

  @override
  Stream<VolumeButtonEvent> get onHardwareButton =>
      _hardwareButtonController.stream;

  Future<T> _invokeWithErrorWrapping<T>(
    Future<T> Function() action,
    String fallbackCode,
  ) async {
    try {
      return await action();
    } on PlatformException catch (e) {
      throw VolumeControllerException(
        code: e.code,
        message: e.message ?? 'Platform volume operation failed.',
        details: e.details,
      );
    } catch (e) {
      if (e is VolumeControllerException) rethrow;
      throw VolumeControllerException(
        code: fallbackCode,
        message: e.toString(),
      );
    }
  }

  @override
  Future<VolumeState> initialize([
    VolumeControllerConfig config = const VolumeControllerConfig(),
  ]) {
    _showSystemUI = config.showSystemUI;
    _defaultStream = config.defaultStream;
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'initialize',
        config.toMap(),
      );
      if (result == null) {
        return VolumeState(
          volume: 0.5,
          isMuted: false,
          streamType: config.defaultStream,
        );
      }
      return VolumeState.fromMap(result);
    }, 'INITIALIZE_FAILED');
  }

  @override
  Future<VolumeCapabilities> getCapabilities() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getCapabilities',
      );
      if (result == null) {
        return const VolumeCapabilities(
          platform: 'unknown',
          supportsSystemVolumeControl: true,
          supportsMuteControl: true,
          supportsVolumeChangeListening: true,
          supportsHardwareButtonInterception: false,
          supportsSystemUIControl: false,
          supportsMultipleStreamTypes: false,
          supportsRingerMode: false,
          supportsAudioDeviceListing: false,
          supportsDeviceSelection: false,
          supportsAppVolumeControl: false,
          supportedStreams: <VolumeStreamType>[VolumeStreamType.media],
        );
      }
      return VolumeCapabilities.fromMap(result);
    }, 'GET_CAPABILITIES_FAILED');
  }

  @override
  Future<VolumeState> getVolumeState({
    VolumeStreamType stream = VolumeStreamType.media,
  }) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getVolumeState',
        <String, Object?>{'streamType': stream.wireName},
      );
      if (result == null) {
        return VolumeState(volume: 0.0, isMuted: true, streamType: stream);
      }
      return VolumeState.fromMap(result);
    }, 'GET_VOLUME_STATE_FAILED');
  }

  @override
  Future<double> getVolume({VolumeStreamType stream = VolumeStreamType.media}) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<Object?>(
        'getVolume',
        <String, Object?>{'streamType': stream.wireName},
      );
      if (result is num) {
        return result.toDouble().clamp(0.0, 1.0);
      }
      if (result is Map<Object?, Object?>) {
        return VolumeState.fromMap(result).volume;
      }
      return 0.0;
    }, 'GET_VOLUME_FAILED');
  }

  @override
  Future<VolumeState> setVolume(
    double volume, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    final normalizedVolume = volume.clamp(0.0, 1.0);
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'setVolume',
        <String, Object?>{
          'volume': normalizedVolume,
          'streamType': stream.wireName,
          'showSystemUI': showSystemUI ?? _showSystemUI,
        },
      );
      if (result == null) {
        return VolumeState(
          volume: normalizedVolume,
          isMuted: normalizedVolume <= 0.0001,
          streamType: stream,
        );
      }
      return VolumeState.fromMap(result);
    }, 'SET_VOLUME_FAILED');
  }

  @override
  Future<VolumeState> adjustVolume(
    double delta, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'adjustVolume',
        <String, Object?>{
          'delta': delta.clamp(-1.0, 1.0),
          'streamType': stream.wireName,
          'showSystemUI': showSystemUI ?? _showSystemUI,
        },
      );
      if (result != null) {
        return VolumeState.fromMap(result);
      }
      final current = await getVolume(stream: stream);
      return setVolume(
        (current + delta).clamp(0.0, 1.0),
        stream: stream,
        showSystemUI: showSystemUI,
      );
    }, 'ADJUST_VOLUME_FAILED');
  }

  @override
  Future<VolumeState> stepVolume(
    VolumeDirection direction, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'stepVolume',
        <String, Object?>{
          'direction': direction.wireName,
          'streamType': stream.wireName,
          'showSystemUI': showSystemUI ?? _showSystemUI,
        },
      );
      if (result != null) {
        return VolumeState.fromMap(result);
      }
      if (direction == VolumeDirection.mute) {
        return toggleMute(stream: stream, showSystemUI: showSystemUI);
      }
      final delta = direction == VolumeDirection.up ? 0.05 : -0.05;
      return adjustVolume(delta, stream: stream, showSystemUI: showSystemUI);
    }, 'STEP_VOLUME_FAILED');
  }

  @override
  Future<Map<VolumeStreamType, double>> getAllStreamVolumes() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getAllStreamVolumes',
      );
      if (result == null) {
        final vol = await getVolume(stream: _defaultStream);
        return <VolumeStreamType, double>{VolumeStreamType.media: vol};
      }
      final mapped = <VolumeStreamType, double>{};
      for (final entry in result.entries) {
        final key = entry.key?.toString();
        final val = entry.value;
        if (key != null && val is num) {
          mapped[VolumeStreamType.fromWireName(key)] = val.toDouble().clamp(
            0.0,
            1.0,
          );
        }
      }
      return mapped;
    }, 'GET_ALL_STREAM_VOLUMES_FAILED');
  }

  @override
  Future<bool> isMuted({VolumeStreamType stream = VolumeStreamType.media}) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<Object?>(
        'isMuted',
        <String, Object?>{'streamType': stream.wireName},
      );
      if (result is bool) return result;
      if (result is Map<Object?, Object?>) {
        return VolumeState.fromMap(result).isMuted;
      }
      return false;
    }, 'IS_MUTED_FAILED');
  }

  @override
  Future<VolumeState> setMute(
    bool muted, {
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'setMute',
        <String, Object?>{
          'muted': muted,
          'streamType': stream.wireName,
          'showSystemUI': showSystemUI ?? _showSystemUI,
        },
      );
      if (result == null) {
        final current = await getVolumeState(stream: stream);
        return current.copyWith(isMuted: muted);
      }
      return VolumeState.fromMap(result);
    }, 'SET_MUTE_FAILED');
  }

  @override
  Future<VolumeState> toggleMute({
    VolumeStreamType stream = VolumeStreamType.media,
    bool? showSystemUI,
  }) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'toggleMute',
        <String, Object?>{
          'streamType': stream.wireName,
          'showSystemUI': showSystemUI ?? _showSystemUI,
        },
      );
      if (result != null) {
        return VolumeState.fromMap(result);
      }
      final currentMuted = await isMuted(stream: stream);
      return setMute(!currentMuted, stream: stream, showSystemUI: showSystemUI);
    }, 'TOGGLE_MUTE_FAILED');
  }

  @override
  Future<RingerMode> getRingerMode() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<String>('getRingerMode');
      return RingerMode.fromWireName(result);
    }, 'GET_RINGER_MODE_FAILED');
  }

  @override
  Future<RingerMode> setRingerMode(RingerMode mode) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<String>(
        'setRingerMode',
        <String, Object?>{'ringerMode': mode.wireName},
      );
      return RingerMode.fromWireName(result ?? mode.wireName);
    }, 'SET_RINGER_MODE_FAILED');
  }

  @override
  Future<bool> hasDoNotDisturbAccess() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<bool>(
        'hasDoNotDisturbAccess',
      );
      return result ?? true;
    }, 'HAS_DND_ACCESS_FAILED');
  }

  @override
  Future<bool> requestDoNotDisturbAccess() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<bool>(
        'requestDoNotDisturbAccess',
      );
      return result ?? false;
    }, 'REQUEST_DND_ACCESS_FAILED');
  }

  @override
  Future<void> setShowSystemUI(bool show) {
    _showSystemUI = show;
    return _invokeWithErrorWrapping(() async {
      await methodChannel.invokeMethod<void>(
        'setShowSystemUI',
        <String, Object?>{'showSystemUI': show},
      );
    }, 'SET_SHOW_SYSTEM_UI_FAILED');
  }

  @override
  Future<void> setInterceptHardwareButtons(bool intercept) {
    return _invokeWithErrorWrapping(() async {
      await methodChannel.invokeMethod<void>(
        'setInterceptHardwareButtons',
        <String, Object?>{'intercept': intercept},
      );
    }, 'SET_INTERCEPT_HARDWARE_BUTTONS_FAILED');
  }

  @override
  Future<List<AudioDeviceInfo>> getOutputDevices() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeListMethod<Object?>(
        'getOutputDevices',
      );
      if (result == null) return const <AudioDeviceInfo>[];
      return result
          .whereType<Map<Object?, Object?>>()
          .map(AudioDeviceInfo.fromMap)
          .toList(growable: false);
    }, 'GET_OUTPUT_DEVICES_FAILED');
  }

  @override
  Future<AudioDeviceInfo?> getCurrentOutputDevice() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getCurrentOutputDevice',
      );
      if (result == null) return null;
      return AudioDeviceInfo.fromMap(result);
    }, 'GET_CURRENT_OUTPUT_DEVICE_FAILED');
  }

  @override
  Future<bool> setOutputDevice(String deviceId) {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<bool>(
        'setOutputDevice',
        <String, Object?>{'deviceId': deviceId},
      );
      return result ?? false;
    }, 'SET_OUTPUT_DEVICE_FAILED');
  }

  @override
  Future<double> getAppVolume() {
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<num>('getAppVolume');
      return (result?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    }, 'GET_APP_VOLUME_FAILED');
  }

  @override
  Future<double> setAppVolume(double volume) {
    final normalized = volume.clamp(0.0, 1.0);
    return _invokeWithErrorWrapping(() async {
      final result = await methodChannel.invokeMethod<num>(
        'setAppVolume',
        <String, Object?>{'volume': normalized},
      );
      return (result?.toDouble() ?? normalized).clamp(0.0, 1.0);
    }, 'SET_APP_VOLUME_FAILED');
  }

  @override
  Future<double> setWebGainBoost(double gain) async {
    return 1.0;
  }

  @override
  Future<double> getWebGainBoost() async {
    return 1.0;
  }

  @override
  Future<void> dispose() {
    return _invokeWithErrorWrapping(() async {
      await methodChannel.invokeMethod<void>('dispose');
    }, 'DISPOSE_FAILED');
  }
}
