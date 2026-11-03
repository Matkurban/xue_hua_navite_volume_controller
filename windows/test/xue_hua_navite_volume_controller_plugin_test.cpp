#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "xue_hua_navite_volume_controller_plugin.h"

namespace xue_hua_navite_volume_controller {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(XueHuaNaviteVolumeControllerPlugin, GetCapabilities) {
  XueHuaNaviteVolumeControllerPlugin plugin;
  EncodableMap result_map;
  plugin.HandleMethodCall(
      MethodCall("getCapabilities", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_map](const EncodableValue* result) {
            result_map = std::get<EncodableMap>(*result);
          },
          nullptr, nullptr));

  auto it = result_map.find(EncodableValue("platform"));
  ASSERT_NE(it, result_map.end());
  EXPECT_EQ(std::get<std::string>(it->second), "windows");
}

}  // namespace test
}  // namespace xue_hua_navite_volume_controller
