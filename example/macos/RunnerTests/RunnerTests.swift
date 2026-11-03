import Cocoa
import FlutterMacOS
import XCTest

@testable import xue_hua_navite_volume_controller

class RunnerTests: XCTestCase {

  func testGetCapabilitiesReturnsMacOSCoreAudioBackend() {
    let plugin = XueHuaNaviteVolumeControllerPlugin()
    let call = FlutterMethodCall(methodName: "getCapabilities", arguments: nil)

    let resultExpectation = expectation(description: "getCapabilities result block must be called.")
    plugin.handle(call) { result in
      let map = result as? [String: Any?]
      XCTAssertNotNil(map)
      XCTAssertEqual(map?["platform"] as? String, "macos")
      XCTAssertEqual(map?["supportsSystemVolumeControl"] as? Bool, true)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 2.0)
  }

  func testGetVolumeReturnsNormalizedRange() {
    let plugin = XueHuaNaviteVolumeControllerPlugin()
    let call = FlutterMethodCall(methodName: "getVolume", arguments: ["streamType": "media"])

    let resultExpectation = expectation(description: "getVolume result block must be called.")
    plugin.handle(call) { result in
      let vol = (result as? NSNumber)?.doubleValue ?? -1.0
      XCTAssertGreaterThanOrEqual(vol, 0.0)
      XCTAssertLessThanOrEqual(vol, 1.0)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 2.0)
  }
}
