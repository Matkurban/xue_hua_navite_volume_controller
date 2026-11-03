import AudioToolbox
import Cocoa
import CoreAudio
import FlutterMacOS

/// Native macOS implementation of `xue_hua_navite_volume_controller`.
///
/// Capabilities:
/// - Reads and writes system master output volume via `CoreAudio`
///   (`kAudioHardwareServiceDeviceProperty_VirtualMainVolume` with per-channel
///   `kAudioDevicePropertyVolumeScalar` fallback for multi-channel/external audio interfaces).
/// - Reads and writes hardware mute state (`kAudioDevicePropertyMute`) with automatic
///   software zero-volume fallback for HDMI/DisplayPort/USB devices that lack a hardware mute register.
/// - Real-time property listeners via `AudioObjectAddPropertyListenerBlock` on both
///   `kAudioObjectSystemObject` (default output device route changes) and the active
///   `AudioDeviceID` (volume and mute changes).
/// - Full enumeration and switching of macOS audio output devices (`kAudioHardwarePropertyDevices`,
///   `kAudioHardwarePropertyDefaultOutputDevice`).
public class XueHuaNaviteVolumeControllerPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel?
  private let listenerQueue = DispatchQueue(label: "com.kurban.xue_hua_navite_volume_controller.coreaudio")

  private var defaultStreamName: String = "media"
  private var isObserving: Bool = false
  private var observedDeviceId: AudioDeviceID = kAudioObjectUnknown
  private var preMuteVolume: Double = 0.5
  private var softwareMuted: Bool = false
  private var lastKnownVolume: Double = 0.5
  private var lastKnownMuted: Bool = false

  private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
  private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
  private var muteListenerBlock: AudioObjectPropertyListenerBlock?

  public override init() {
    self.channel = nil
    super.init()
  }

  public init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "xue_hua_navite_volume_controller",
      binaryMessenger: registrar.messenger
    )
    let instance = XueHuaNaviteVolumeControllerPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  deinit {
    stopCoreAudioObservation()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "initialize":
      defaultStreamName = (args?["defaultStream"] as? String) ?? "media"
      let listenToVolumeChanges = (args?["listenToVolumeChanges"] as? Bool) ?? true
      if listenToVolumeChanges {
        startCoreAudioObservation()
      }
      result(buildVolumeStateMap(streamName: defaultStreamName))

    case "getCapabilities":
      result(buildCapabilitiesMap())

    case "getVolumeState":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      result(buildVolumeStateMap(streamName: streamName))

    case "getVolume":
      let devId = getDefaultOutputDeviceID()
      result(readDeviceVolume(deviceId: devId))

    case "setVolume":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let target = min(max((args?["volume"] as? NSNumber)?.doubleValue ?? 0.5, 0.0), 1.0)
      let state = writeDeviceVolume(target, streamName: streamName, reason: "programmatic")
      result(state)

    case "adjustVolume":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let delta = min(max((args?["delta"] as? NSNumber)?.doubleValue ?? 0.0, -1.0), 1.0)
      let devId = getDefaultOutputDeviceID()
      let current = readDeviceVolume(deviceId: devId)
      let target = min(max(current + delta, 0.0), 1.0)
      let state = writeDeviceVolume(target, streamName: streamName, reason: "adjustVolume")
      result(state)

    case "stepVolume":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let direction = (args?["direction"] as? String) ?? "up"
      if direction == "mute" {
        let devId = getDefaultOutputDeviceID()
        let currentlyMuted = readDeviceMuted(deviceId: devId)
        result(writeDeviceMute(!currentlyMuted, streamName: streamName))
      } else {
        let delta = direction == "up" ? 0.0625 : -0.0625
        let devId = getDefaultOutputDeviceID()
        let current = readDeviceVolume(deviceId: devId)
        let target = min(max(current + delta, 0.0), 1.0)
        result(writeDeviceVolume(target, streamName: streamName, reason: "stepVolume"))
      }

    case "getAllStreamVolumes":
      let devId = getDefaultOutputDeviceID()
      result(["media": readDeviceVolume(deviceId: devId)])

    case "isMuted":
      let devId = getDefaultOutputDeviceID()
      result(readDeviceMuted(deviceId: devId))

    case "setMute":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let muted = (args?["muted"] as? Bool) ?? false
      result(writeDeviceMute(muted, streamName: streamName))

    case "toggleMute":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let devId = getDefaultOutputDeviceID()
      let currentlyMuted = readDeviceMuted(deviceId: devId)
      result(writeDeviceMute(!currentlyMuted, streamName: streamName))

    case "getRingerMode":
      let devId = getDefaultOutputDeviceID()
      result(readDeviceMuted(deviceId: devId) ? "silent" : "normal")

    case "setRingerMode":
      let mode = (args?["ringerMode"] as? String) ?? "normal"
      if mode == "silent" || mode == "vibrate" {
        _ = writeDeviceMute(true, streamName: defaultStreamName)
        result("silent")
      } else {
        _ = writeDeviceMute(false, streamName: defaultStreamName)
        result("normal")
      }

    case "hasDoNotDisturbAccess":
      result(true)

    case "requestDoNotDisturbAccess":
      result(true)

    case "setShowSystemUI":
      result(nil)

    case "setInterceptHardwareButtons":
      result(nil)

    case "getOutputDevices":
      result(listOutputDevices())

    case "getCurrentOutputDevice":
      let devices = listOutputDevices()
      result(devices.first(where: { ($0["isDefault"] as? Bool) == true }) ?? devices.first)

    case "setOutputDevice":
      let deviceIdStr = (args?["deviceId"] as? String) ?? ""
      result(selectDefaultOutputDevice(deviceIdStr))

    case "getAppVolume":
      let devId = getDefaultOutputDeviceID()
      result(readDeviceVolume(deviceId: devId))

    case "setAppVolume":
      let target = min(max((args?["volume"] as? NSNumber)?.doubleValue ?? 1.0, 0.0), 1.0)
      _ = writeDeviceVolume(target, streamName: defaultStreamName, reason: "appVolume")
      let devId = getDefaultOutputDeviceID()
      result(readDeviceVolume(deviceId: devId))

    case "dispose":
      stopCoreAudioObservation()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - CoreAudio Helpers

  private func getDefaultOutputDeviceID() -> AudioDeviceID {
    var deviceId = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceId
    )
    return status == noErr ? deviceId : AudioDeviceID(kAudioObjectUnknown)
  }

  private func readDeviceVolume(deviceId: AudioDeviceID) -> Double {
    guard deviceId != kAudioObjectUnknown else { return 0.5 }

    // 1. Try VirtualMainVolume (AudioToolbox Hardware Service)
    var volume = Float32(0.5)
    var size = UInt32(MemoryLayout<Float32>.size)
    var virtualAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    if AudioObjectHasProperty(deviceId, &virtualAddress) {
      let status = AudioObjectGetPropertyData(deviceId, &virtualAddress, 0, nil, &size, &volume)
      if status == noErr {
        return Double(volume).clamped(to: 0.0...1.0)
      }
    }

    // 2. Fallback: Master channel (0) or stereo channels (1, 2) VolumeScalar
    for channelElement: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
      var channelAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: channelElement
      )
      if AudioObjectHasProperty(deviceId, &channelAddress) {
        var channelVol = Float32(0.5)
        var channelSize = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceId, &channelAddress, 0, nil, &channelSize, &channelVol) == noErr {
          return Double(channelVol).clamped(to: 0.0...1.0)
        }
      }
    }

    return softwareMuted ? 0.0 : preMuteVolume
  }

  private func readDeviceMuted(deviceId: AudioDeviceID) -> Bool {
    guard deviceId != kAudioObjectUnknown else { return false }

    var muteAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    if AudioObjectHasProperty(deviceId, &muteAddress) {
      var muted: UInt32 = 0
      var size = UInt32(MemoryLayout<UInt32>.size)
      if AudioObjectGetPropertyData(deviceId, &muteAddress, 0, nil, &size, &muted) == noErr {
        if muted != 0 { return true }
      }
    }

    let currentVol = readDeviceVolume(deviceId: deviceId)
    return softwareMuted || currentVol <= 0.0001
  }

  private func writeDeviceVolume(
    _ targetVolume: Double,
    streamName: String,
    reason: String
  ) -> [String: Any?] {
    let devId = getDefaultOutputDeviceID()
    let clamped = targetVolume.clamped(to: 0.0...1.0)
    let oldVolume = readDeviceVolume(deviceId: devId)

    if clamped > 0.0001 {
      preMuteVolume = clamped
      softwareMuted = false
      // Unmute hardware register if currently muted
      setHardwareMuteRegister(deviceId: devId, muted: false)
    } else {
      softwareMuted = true
    }

    if devId != kAudioObjectUnknown {
      var scalar = Float32(clamped)
      let size = UInt32(MemoryLayout<Float32>.size)

      var virtualAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      var wroteVolume = false
      if AudioObjectHasProperty(devId, &virtualAddress) {
        var settable: DarwinBoolean = false
        if AudioObjectIsPropertySettable(devId, &virtualAddress, &settable) == noErr && settable.boolValue {
          if AudioObjectSetPropertyData(devId, &virtualAddress, 0, nil, size, &scalar) == noErr {
            wroteVolume = true
          }
        }
      }

      if !wroteVolume {
        for channelElement: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
          var channelAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channelElement
          )
          if AudioObjectHasProperty(devId, &channelAddress) {
            var settable: DarwinBoolean = false
            if AudioObjectIsPropertySettable(devId, &channelAddress, &settable) == noErr && settable.boolValue {
              _ = AudioObjectSetPropertyData(devId, &channelAddress, 0, nil, size, &scalar)
            }
          }
        }
      }
    }

    let state = buildVolumeStateMap(streamName: streamName)
    emitVolumeChange(state: state, oldVolume: oldVolume, reason: reason)
    return state
  }

  @discardableResult
  private func setHardwareMuteRegister(deviceId: AudioDeviceID, muted: Bool) -> Bool {
    guard deviceId != kAudioObjectUnknown else { return false }
    var muteAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    if AudioObjectHasProperty(deviceId, &muteAddress) {
      var settable: DarwinBoolean = false
      if AudioObjectIsPropertySettable(deviceId, &muteAddress, &settable) == noErr && settable.boolValue {
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(deviceId, &muteAddress, 0, nil, size, &value) == noErr
      }
    }
    return false
  }

  private func writeDeviceMute(_ muted: Bool, streamName: String) -> [String: Any?] {
    let devId = getDefaultOutputDeviceID()
    let oldVolume = readDeviceVolume(deviceId: devId)
    if muted && oldVolume > 0.0001 {
      preMuteVolume = oldVolume
    }

    softwareMuted = muted
    let hardwareMuteSucceeded = setHardwareMuteRegister(deviceId: devId, muted: muted)
    if !hardwareMuteSucceeded {
      let fallbackVolume = muted ? 0.0 : (preMuteVolume > 0.0001 ? preMuteVolume : 0.5)
      return writeDeviceVolume(fallbackVolume, streamName: streamName, reason: "muteChange")
    } else if !muted && readDeviceVolume(deviceId: devId) <= 0.0001 {
      let restored = preMuteVolume > 0.0001 ? preMuteVolume : 0.5
      return writeDeviceVolume(restored, streamName: streamName, reason: "muteChange")
    }

    let state = buildVolumeStateMap(streamName: streamName)
    emitVolumeChange(state: state, oldVolume: oldVolume, reason: "muteChange")
    return state
  }

  private func hasOutputStreams(deviceId: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    if AudioObjectGetPropertyDataSize(deviceId, &address, 0, nil, &size) == noErr {
      return size > 0
    }
    return false
  }

  private func hasInputStreams(deviceId: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioDevicePropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    if AudioObjectGetPropertyDataSize(deviceId, &address, 0, nil, &size) == noErr {
      return size > 0
    }
    return false
  }

  private func readDeviceName(deviceId: AudioDeviceID) -> String {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var name: CFString = "macOS Audio Output" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let status = withUnsafeMutablePointer(to: &name) { ptr in
      AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, ptr)
    }
    return status == noErr ? (name as String) : "macOS Audio Output"
  }

  private func readDeviceRoute(deviceId: AudioDeviceID) -> String {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyTransportType,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var transportType: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    if AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &transportType) == noErr {
      switch transportType {
      case kAudioDeviceTransportTypeBuiltIn:
        let lowerName = readDeviceName(deviceId: deviceId).lowercased()
        return (lowerName.contains("headphone") || lowerName.contains("headset"))
          ? "wiredHeadset"
          : "speaker"
      case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
        return "bluetooth"
      case kAudioDeviceTransportTypeUSB:
        return "usb"
      case kAudioDeviceTransportTypeAirPlay:
        return "airPlay"
      case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
        return "hdmi"
      default:
        return "speaker"
      }
    }
    return "speaker"
  }

  private func listOutputDevices() -> [[String: Any?]] {
    let defaultId = getDefaultOutputDeviceID()
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size
    ) == noErr, size > 0 else {
      return []
    }

    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var deviceIds = [AudioDeviceID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceIds
    ) == noErr else {
      return []
    }

    var results: [[String: Any?]] = []
    for devId in deviceIds where hasOutputStreams(deviceId: devId) {
      let vol = readDeviceVolume(deviceId: devId)
      let muted = readDeviceMuted(deviceId: devId)
      results.append([
        "id": String(devId),
        "name": readDeviceName(deviceId: devId),
        "route": readDeviceRoute(deviceId: devId),
        "isDefault": devId == defaultId,
        "isOutput": true,
        "isInput": hasInputStreams(deviceId: devId),
        "volume": vol,
        "isMuted": muted,
      ])
    }
    return results
  }

  private func selectDefaultOutputDevice(_ deviceIdStr: String) -> Bool {
    guard let targetId = UInt32(deviceIdStr), targetId != kAudioObjectUnknown else {
      return false
    }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var devId = AudioDeviceID(targetId)
    let size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectSetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      size,
      &devId
    )
    if status == noErr {
      rebindDevicePropertyListeners()
      let state = buildVolumeStateMap(streamName: defaultStreamName)
      emitVolumeChange(state: state, oldVolume: lastKnownVolume, reason: "routeChange")
      return true
    }
    return false
  }

  private func buildVolumeStateMap(streamName: String) -> [String: Any?] {
    let devId = getDefaultOutputDeviceID()
    let vol = readDeviceVolume(deviceId: devId)
    let muted = readDeviceMuted(deviceId: devId)
    let devName = devId != kAudioObjectUnknown ? readDeviceName(deviceId: devId) : "Mac Built-in Output"
    let devRoute = devId != kAudioObjectUnknown ? readDeviceRoute(deviceId: devId) : "speaker"

    lastKnownVolume = vol
    lastKnownMuted = muted
    if !muted && vol > 0.0001 {
      preMuteVolume = vol
    }

    return [
      "volume": vol,
      "isMuted": muted,
      "streamType": streamName,
      "stepIndex": Int((vol * 16.0).rounded()),
      "maxSteps": 16,
      "minSteps": 0,
      "ringerMode": muted ? "silent" : "normal",
      "outputDeviceName": devName,
      "outputRoute": devRoute,
      "outputDeviceId": String(devId),
    ]
  }

  private func buildCapabilitiesMap() -> [String: Any?] {
    return [
      "platform": "macos",
      "supportsSystemVolumeControl": true,
      "supportsMuteControl": true,
      "supportsVolumeChangeListening": true,
      "supportsHardwareButtonInterception": false,
      "supportsSystemUIControl": false,
      "supportsMultipleStreamTypes": false,
      "supportsRingerMode": false,
      "supportsAudioDeviceListing": true,
      "supportsDeviceSelection": true,
      "supportsAppVolumeControl": false,
      "supportedStreams": ["media"],
      "audioBackend": "macOS CoreAudio (AudioObjectProperty)",
      "platformNotes": [
        "Controls macOS hardware master volume via CoreAudio kAudioHardwareServiceDeviceProperty_VirtualMainVolume with per-channel fallback.",
        "Supports enumerating and switching the system default output audio device.",
        "Automatically falls back to software zero-volume mute on HDMI/DisplayPort devices that lack a hardware mute register."
      ],
    ]
  }

  // MARK: - CoreAudio Property Listeners

  private func startCoreAudioObservation() {
    if isObserving { return }
    isObserving = true

    var defaultDevAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let sysBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      guard let self = self else { return }
      self.rebindDevicePropertyListeners()
      let state = self.buildVolumeStateMap(streamName: self.defaultStreamName)
      self.emitVolumeChange(state: state, oldVolume: self.lastKnownVolume, reason: "routeChange")
    }
    defaultDeviceListenerBlock = sysBlock
    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &defaultDevAddress,
      listenerQueue,
      sysBlock
    )

    rebindDevicePropertyListeners()
  }

  private func rebindDevicePropertyListeners() {
    unbindDevicePropertyListeners()
    let devId = getDefaultOutputDeviceID()
    guard devId != kAudioObjectUnknown else { return }
    observedDeviceId = devId

    let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      guard let self = self else { return }
      let prevVol = self.lastKnownVolume
      let prevMuted = self.lastKnownMuted
      let state = self.buildVolumeStateMap(streamName: self.defaultStreamName)
      let newVol = (state["volume"] as? Double) ?? prevVol
      let newMuted = (state["isMuted"] as? Bool) ?? prevMuted
      if abs(newVol - prevVol) > 0.0005 || newMuted != prevMuted {
        self.emitVolumeChange(state: state, oldVolume: prevVol, reason: "system")
      }
    }
    volumeListenerBlock = volBlock
    muteListenerBlock = volBlock

    var virtualVolAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectAddPropertyListenerBlock(devId, &virtualVolAddress, listenerQueue, volBlock)

    var muteAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectAddPropertyListenerBlock(devId, &muteAddress, listenerQueue, volBlock)
  }

  private func unbindDevicePropertyListeners() {
    guard observedDeviceId != kAudioObjectUnknown else { return }
    if let volBlock = volumeListenerBlock {
      var virtualVolAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(observedDeviceId, &virtualVolAddress, listenerQueue, volBlock)

      var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(observedDeviceId, &muteAddress, listenerQueue, volBlock)
    }
    volumeListenerBlock = nil
    muteListenerBlock = nil
    observedDeviceId = kAudioObjectUnknown
  }

  private func stopCoreAudioObservation() {
    unbindDevicePropertyListeners()
    if let sysBlock = defaultDeviceListenerBlock {
      var defaultDevAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &defaultDevAddress,
        listenerQueue,
        sysBlock
      )
      defaultDeviceListenerBlock = nil
    }
    isObserving = false
  }

  private func emitVolumeChange(
    state: [String: Any?],
    oldVolume: Double?,
    reason: String
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod(
        "onVolumeChanged",
        arguments: [
          "state": state,
          "oldVolume": oldVolume as Any,
          "reason": reason,
          "timestamp": Int64(Date().timeIntervalSince1970 * 1000.0),
        ]
      )
    }
  }
}

private extension Double {
  func clamped(to range: ClosedRange<Double>) -> Double {
    return min(max(self, range.lowerBound), range.upperBound)
  }
}
