import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// Native iOS implementation of `xue_hua_navite_volume_controller`.
///
/// Capabilities:
/// - Reads and observes real-time system output volume via `AVAudioSession.sharedInstance().outputVolume` KVO.
/// - Programmatically sets system volume via an embedded `MPVolumeView` `UISlider` control.
/// - Controls native iOS system volume HUD visibility by positioning the `MPVolumeView` off-screen
///   (suppresses system HUD when `showSystemUI == false`) or removing it from the view hierarchy
///   (allows standard iOS HUD when `showSystemUI == true`).
/// - Supports software mute/unmute with automatic pre-mute volume caching and restoration.
/// - Enumerates active audio output ports via `AVAudioSession.sharedInstance().currentRoute.outputs`
///   and listens to `AVAudioSession.routeChangeNotification`.
public class XueHuaNaviteVolumeControllerPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel?
  private var volumeView: MPVolumeView?
  private weak var volumeSlider: UISlider?
  private var outputVolumeObservation: NSKeyValueObservation?
  private var routeChangeObserver: NSObjectProtocol?

  private var showSystemUI: Bool = false
  private var defaultStreamName: String = "media"
  private var isObserving: Bool = false
  private var isMutedSoftware: Bool = false
  private var preMuteVolume: Double = 0.5
  private var lastKnownVolume: Double = 0.5

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
      binaryMessenger: registrar.messenger()
    )
    let instance = XueHuaNaviteVolumeControllerPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  deinit {
    stopVolumeObservation()
    removeVolumeView()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "initialize":
      defaultStreamName = (args?["defaultStream"] as? String) ?? "media"
      showSystemUI = (args?["showSystemUI"] as? Bool) ?? false
      let listenToVolumeChanges = (args?["listenToVolumeChanges"] as? Bool) ?? true

      configureAudioSession()
      ensureVolumeViewConfigured(showHUD: showSystemUI)
      if listenToVolumeChanges {
        startVolumeObservation()
      }
      result(buildVolumeStateMap(streamName: defaultStreamName))

    case "getCapabilities":
      result(buildCapabilitiesMap())

    case "getVolumeState":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      result(buildVolumeStateMap(streamName: streamName))

    case "getVolume":
      result(readCurrentVolume())

    case "setVolume":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let target = min(max((args?["volume"] as? NSNumber)?.doubleValue ?? 0.5, 0.0), 1.0)
      let showUi = (args?["showSystemUI"] as? Bool) ?? showSystemUI
      let state = applyVolume(target, streamName: streamName, showHUD: showUi, reason: "programmatic")
      result(state)

    case "adjustVolume":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let delta = min(max((args?["delta"] as? NSNumber)?.doubleValue ?? 0.0, -1.0), 1.0)
      let showUi = (args?["showSystemUI"] as? Bool) ?? showSystemUI
      let current = readCurrentVolume()
      let target = min(max(current + delta, 0.0), 1.0)
      let state = applyVolume(target, streamName: streamName, showHUD: showUi, reason: "adjustVolume")
      result(state)

    case "stepVolume":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let direction = (args?["direction"] as? String) ?? "up"
      let showUi = (args?["showSystemUI"] as? Bool) ?? showSystemUI
      if direction == "mute" {
        let state = applyMute(!readIsMuted(), streamName: streamName, showHUD: showUi)
        result(state)
      } else {
        let stepDelta = direction == "up" ? 0.0625 : -0.0625
        let current = readCurrentVolume()
        let target = min(max(current + stepDelta, 0.0), 1.0)
        let state = applyVolume(target, streamName: streamName, showHUD: showUi, reason: "stepVolume")
        result(state)
      }

    case "getAllStreamVolumes":
      let vol = readCurrentVolume()
      result(["media": vol])

    case "isMuted":
      result(readIsMuted())

    case "setMute":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let muted = (args?["muted"] as? Bool) ?? false
      let showUi = (args?["showSystemUI"] as? Bool) ?? showSystemUI
      result(applyMute(muted, streamName: streamName, showHUD: showUi))

    case "toggleMute":
      let streamName = (args?["streamType"] as? String) ?? defaultStreamName
      let showUi = (args?["showSystemUI"] as? Bool) ?? showSystemUI
      result(applyMute(!readIsMuted(), streamName: streamName, showHUD: showUi))

    case "getRingerMode":
      result(readIsMuted() ? "silent" : "normal")

    case "setRingerMode":
      let mode = (args?["ringerMode"] as? String) ?? "normal"
      if mode == "silent" || mode == "vibrate" {
        _ = applyMute(true, streamName: defaultStreamName, showHUD: showSystemUI)
        result("silent")
      } else {
        _ = applyMute(false, streamName: defaultStreamName, showHUD: showSystemUI)
        result("normal")
      }

    case "hasDoNotDisturbAccess":
      result(true)

    case "requestDoNotDisturbAccess":
      result(true)

    case "setShowSystemUI":
      showSystemUI = (args?["showSystemUI"] as? Bool) ?? false
      ensureVolumeViewConfigured(showHUD: showSystemUI)
      result(nil)

    case "setInterceptHardwareButtons":
      result(nil)

    case "getOutputDevices":
      result(listOutputDevices())

    case "getCurrentOutputDevice":
      result(listOutputDevices().first)

    case "setOutputDevice":
      result(false)

    case "getAppVolume":
      result(readCurrentVolume())

    case "setAppVolume":
      let target = min(max((args?["volume"] as? NSNumber)?.doubleValue ?? 1.0, 0.0), 1.0)
      _ = applyVolume(target, streamName: defaultStreamName, showHUD: false, reason: "appVolume")
      result(readCurrentVolume())

    case "dispose":
      stopVolumeObservation()
      removeVolumeView()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      if session.category == .soloAmbient || session.category == .ambient {
        try session.setCategory(.ambient, options: [.mixWithOthers])
      }
      try session.setActive(true, options: [])
    } catch {
      // Non-fatal: AVAudioSession may already be managed by another audio plugin
    }
  }

  private func activeKeyWindow() -> UIWindow? {
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        for window in windowScene.windows where window.isKeyWindow {
          return window
        }
        if let first = windowScene.windows.first {
          return first
        }
      }
    }
    return nil
  }

  private func ensureVolumeViewConfigured(showHUD: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.volumeView == nil {
        let view = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        view.clipsToBounds = true
        self.volumeView = view
        for subview in view.subviews {
          if let slider = subview as? UISlider {
            self.volumeSlider = slider
            break
          }
        }
      }

      guard let view = self.volumeView else { return }
      if showHUD {
        // When the MPVolumeView is detached from the window hierarchy, iOS displays the native system volume HUD.
        view.removeFromSuperview()
      } else {
        // When the MPVolumeView is mounted inside the active window with a tiny off-screen frame and non-zero alpha,
        // iOS suppresses the native system volume HUD while still updating the hardware volume via UISlider.
        view.alpha = 0.01
        view.isHidden = false
        if view.superview == nil, let window = self.activeKeyWindow() {
          window.addSubview(view)
        }
      }
    }
  }

  private func removeVolumeView() {
    DispatchQueue.main.async { [weak self] in
      self?.volumeView?.removeFromSuperview()
      self?.volumeView = nil
      self?.volumeSlider = nil
    }
  }

  private func readCurrentVolume() -> Double {
    if let slider = volumeSlider {
      return Double(slider.value).clamped(to: 0.0...1.0)
    }
    let sessionVol = Double(AVAudioSession.sharedInstance().outputVolume).clamped(to: 0.0...1.0)
    return sessionVol
  }

  private func readIsMuted() -> Bool {
    let vol = readCurrentVolume()
    return isMutedSoftware || vol <= 0.0001
  }

  private func applyVolume(
    _ target: Double,
    streamName: String,
    showHUD: Bool,
    reason: String
  ) -> [String: Any?] {
    let clamped = target.clamped(to: 0.0...1.0)
    let oldVolume = readCurrentVolume()
    if clamped > 0.0001 {
      preMuteVolume = clamped
      isMutedSoftware = false
    } else {
      isMutedSoftware = true
    }
    lastKnownVolume = clamped

    ensureVolumeViewConfigured(showHUD: showHUD)
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.volumeSlider == nil, let view = self.volumeView {
        for subview in view.subviews {
          if let slider = subview as? UISlider {
            self.volumeSlider = slider
            break
          }
        }
      }
      self.volumeSlider?.setValue(Float(clamped), animated: false)
      self.volumeSlider?.sendActions(for: .touchUpInside)
    }

    let state = buildVolumeStateMap(streamName: streamName, overrideVolume: clamped)
    emitVolumeChange(state: state, oldVolume: oldVolume, reason: reason)
    return state
  }

  private func applyMute(
    _ muted: Bool,
    streamName: String,
    showHUD: Bool
  ) -> [String: Any?] {
    let current = readCurrentVolume()
    if muted {
      if current > 0.0001 {
        preMuteVolume = current
      }
      isMutedSoftware = true
      return applyVolume(0.0, streamName: streamName, showHUD: showHUD, reason: "muteChange")
    } else {
      isMutedSoftware = false
      let restored = preMuteVolume > 0.0001 ? preMuteVolume : 0.5
      return applyVolume(restored, streamName: streamName, showHUD: showHUD, reason: "muteChange")
    }
  }

  private func classifyPortRoute(_ portType: AVAudioSession.Port) -> String {
    switch portType {
    case .builtInSpeaker:
      return "speaker"
    case .builtInReceiver:
      return "earpiece"
    case .headphones, .headsetMic, .lineOut:
      return "wiredHeadset"
    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
      return "bluetooth"
    case .usbAudio:
      return "usb"
    case .airPlay:
      return "airPlay"
    case .HDMI:
      return "hdmi"
    default:
      return "speaker"
    }
  }

  private func listOutputDevices() -> [[String: Any?]] {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    let currentVol = readCurrentVolume()
    let muted = readIsMuted()

    if outputs.isEmpty {
      return [
        [
          "id": "builtin_speaker",
          "name": "iPhone Speaker",
          "route": "speaker",
          "isDefault": true,
          "isOutput": true,
          "isInput": false,
          "volume": currentVol,
          "isMuted": muted,
        ]
      ]
    }

    var devices: [[String: Any?]] = []
    for (index, port) in outputs.enumerated() {
      devices.append([
        "id": port.uid,
        "name": port.portName,
        "route": classifyPortRoute(port.portType),
        "isDefault": index == 0,
        "isOutput": true,
        "isInput": false,
        "volume": currentVol,
        "isMuted": muted,
      ])
    }
    return devices
  }

  private func buildVolumeStateMap(
    streamName: String,
    overrideVolume: Double? = nil
  ) -> [String: Any?] {
    let vol = (overrideVolume ?? readCurrentVolume()).clamped(to: 0.0...1.0)
    let muted = isMutedSoftware || vol <= 0.0001
    let activeDevice = listOutputDevices().first
    let stepIndex = Int((vol * 16.0).rounded())

    return [
      "volume": vol,
      "isMuted": muted,
      "streamType": streamName,
      "stepIndex": stepIndex,
      "maxSteps": 16,
      "minSteps": 0,
      "ringerMode": muted ? "silent" : "normal",
      "outputDeviceName": (activeDevice?["name"] as? String) ?? "iOS Speaker",
      "outputRoute": (activeDevice?["route"] as? String) ?? "speaker",
      "outputDeviceId": (activeDevice?["id"] as? String) ?? "builtin_speaker",
    ]
  }

  private func buildCapabilitiesMap() -> [String: Any?] {
    return [
      "platform": "ios",
      "supportsSystemVolumeControl": true,
      "supportsMuteControl": true,
      "supportsVolumeChangeListening": true,
      "supportsHardwareButtonInterception": false,
      "supportsSystemUIControl": true,
      "supportsMultipleStreamTypes": false,
      "supportsRingerMode": false,
      "supportsAudioDeviceListing": true,
      "supportsDeviceSelection": false,
      "supportsAppVolumeControl": false,
      "supportedStreams": ["media"],
      "audioBackend": "AVAudioSession + MPVolumeView",
      "platformNotes": [
        "iOS unifies output volume through AVAudioSession and MPVolumeView (16 hardware steps).",
        "Physical Ring/Silent switch state cannot be toggled programmatically on iOS; setMute uses zero-volume with pre-mute restoration.",
        "Note: iOS Simulator does not emulate MPVolumeView hardware slider changes; test programmatic volume changes on a physical iOS device."
      ],
    ]
  }

  private func startVolumeObservation() {
    if isObserving { return }
    isObserving = true
    configureAudioSession()

    let session = AVAudioSession.sharedInstance()
    lastKnownVolume = Double(session.outputVolume)

    outputVolumeObservation = session.observe(\.outputVolume, options: [.new, .old]) {
      [weak self] audioSession, change in
      guard let self = self else { return }
      let newVol = Double(audioSession.outputVolume).clamped(to: 0.0...1.0)
      let oldVol = change.oldValue.map { Double($0).clamped(to: 0.0...1.0) } ?? self.lastKnownVolume
      if abs(newVol - self.lastKnownVolume) > 0.001 {
        self.lastKnownVolume = newVol
        if newVol > 0.0001 {
          self.isMutedSoftware = false
          self.preMuteVolume = newVol
        }
        let state = self.buildVolumeStateMap(streamName: self.defaultStreamName, overrideVolume: newVol)
        self.emitVolumeChange(state: state, oldVolume: oldVol, reason: "system")
      }
    }

    routeChangeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      let state = self.buildVolumeStateMap(streamName: self.defaultStreamName)
      self.emitVolumeChange(state: state, oldVolume: self.lastKnownVolume, reason: "routeChange")
    }
  }

  private func stopVolumeObservation() {
    outputVolumeObservation?.invalidate()
    outputVolumeObservation = nil
    if let observer = routeChangeObserver {
      NotificationCenter.default.removeObserver(observer)
      routeChangeObserver = nil
    }
    isObserving = false
  }

  private func emitVolumeChange(
    state: [String: Any?],
    oldVolume: Double?,
    reason: String
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod(
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
