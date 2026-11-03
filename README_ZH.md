# xue_hua_navite_volume_controller

[English](./README.md) | 简体中文

一款面向 Flutter 的全平台（`Android`、`iOS`、`macOS`、`Windows`、`Linux`、`Web`）系统级与应用级声音控制插件。深入适配六大操作系统底层音频架构差异，提供统一的音量读写、多音频流混音、静音兜底、响铃模式与免打扰权限引导、原生音量 HUD 显隐控制、物理音量键拦截、音频输出设备枚举与切换以及 WebAudio 增益放大能力。

- **作者**：Matkurban（`3496354336@qq.com`）
- **仓库地址**：[https://github.com/Matkurban/xue_hua_navite_volume_controller](https://github.com/Matkurban/xue_hua_navite_volume_controller)
- **当前版本**：`1.0.0`

## 核心特性

- **统一归一化音量控制（`0.0`–`1.0`）**：支持读取当前音量（`getVolume`）、设置目标音量（`setVolume`）、按相对增减量调节（`adjustVolume`）、按硬件步进微调（`stepVolume`、`volumeUp`、`volumeDown`）以及读取完整状态快照（`getVolumeState`）。
- **Android 8 路独立音频流混音控制**：在 Android 端基于 `AudioManager` 独立控制媒体（`media`）、铃声（`ring`）、闹钟（`alarm`）、通知（`notification`）、通话（`voiceCall`）、系统（`system`）、无障碍（`accessibility`）与拨号音（`dtmf`）共 8 个通道。
- **硬件静音控制与智能零音量兜底**：提供 `isMuted`、`setMute`、`toggleMute`，针对不支持硬件静音寄存器的平台或外接显示器（如 iOS、部分 HDMI/DisplayPort 显示器），自动记录静音前音量并采用零音量兜底与恢复机制。
- **实时系统音量与路由变更监听**：通过 `onVolumeChanged` 广播流、`VolumeControllerListener` 混入或 `stateNotifier`（`ValueNotifier<VolumeState>`），实时响应物理按键、系统控制中心滑块、蓝牙耳机按键及音频输出设备插拔事件。
- **原生系统音量 HUD 弹窗显隐控制**：在 Android（`AudioManager.FLAG_SHOW_UI`）和 iOS（离屏挂载 `MPVolumeView`）上动态控制调节音量时是否弹出系统原生音量指示条（`setShowSystemUI`）。
- **Android 物理硬件音量键拦截**：通过非侵入式 `Window.Callback` 代理拦截 `Volume Up`、`Volume Down`、`Volume Mute` 实体按键事件（`setInterceptHardwareButtons`、`onHardwareButton`），在不改变系统音量的前提下用于拍照快门、小说翻页或自定义播放器快捷键。
- **响铃模式与免打扰（DND）权限管理**：支持查询和切换 Android 响铃模式（`RingerMode.normal`、`vibrate`、`silent`），内置免打扰策略权限检测（`hasDoNotDisturbAccess`）与一键跳转授权页（`requestDoNotDisturbAccess`）。
- **音频输出设备枚举与切换**：支持枚举当前连接的扬声器、有线耳机、蓝牙耳机、USB 声卡、AirPlay、HDMI 等设备（`getOutputDevices`、`getCurrentOutputDevice`），并在 macOS（`CoreAudio`）、Windows（`IPolicyConfig`）、Linux（`pactl`）、Android 12+ 及 Web（`setSinkId`）上切换默认输出设备（`setOutputDevice`）。
- **应用级独立音量与 WebAudio 增益放大**：在 Windows（`ISimpleAudioVolume`）和 Web 上支持独立于系统主音量的进程内音量调节（`getAppVolume`、`setAppVolume`），并在 Web 端提供最高 `400%`（`0.0`–`4.0`）的 Web Audio API `GainNode` 音频增益补偿（`setWebGainBoost`）。
- **内置标准 AI Agent Skills**：遵循 [Dart 官方 Package Skills 规范](https://dart.dev/tools/pub/package-skills)，随包内置 `skills/xue_hua_navite_volume_controller-usage/SKILL.md` 及 `skills_lint.yaml`。

## 各平台底层实现与差异对比

| 功能特性 | Android (`API 24+`) | iOS (`15.0+`) | macOS (`12.0+`) | Windows (`10/11`) | Linux (`GTK3`) | Web (`WASM / JS`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **底层原生引擎** | `AudioManager` + `Window.Callback` | `AVAudioSession` + `MPVolumeView` | `CoreAudio` (`AudioObjectProperty`) | `MMDeviceAPI` + `IAudioEndpointVolume` | `PulseAudio` (`pactl`) / `PipeWire` (`wpctl`) / `ALSA` (`amixer`) | `HTMLMediaElement` + `WebAudio GainNode` |
| **系统主音量控制** | 支持 | 支持（需真机） | 支持 | 支持（含 dB 分贝读取） | 支持 | 浏览器沙箱限制（自动同步页面内 `<audio>`/`<video>`） |
| **多音频流独立控制** | 支持 8 路独立音频流 | 系统统一输出通道 | 系统统一输出通道 | 系统统一输出通道 | 系统统一输出通道 | 页面统一媒体流 |
| **静音与恢复机制** | 硬件流静音 `ADJUST_MUTE` | 软件零音量 + 记忆恢复 | `kAudioDevicePropertyMute` + 零音量兜底 | `IAudioEndpointVolume::SetMute` | 音频接收器静音（`pactl`/`wpctl`/`amixer`） | DOM `.muted` 属性 + 恢复 |
| **系统音量 HUD 显隐** | 支持（`FLAG_SHOW_UI`） | 支持（离屏 `MPVolumeView`） | 由 macOS 系统管理 | 由 Windows 系统管理 | 由桌面环境管理 | 不适用 |
| **物理音量键拦截** | 支持（`KEYCODE_VOLUME_*`） | 不支持（iOS 系统限制） | 不支持 | 不支持 | 不支持 | 不支持 |
| **响铃模式与免打扰** | `normal` / `vibrate` / `silent` | 映射为静音状态 | 映射为静音状态 | 映射为静音状态 | 映射为静音状态 | 映射为静音状态 |
| **输出设备枚举** | `getDevices(GET_DEVICES_OUTPUTS)` | `currentRoute.outputs` | `kAudioHardwarePropertyDevices` | `EnumAudioEndpoints` | 默认 Sink 查询 | `mediaDevices.enumerateDevices()` |
| **输出设备切换** | Android 12+ 通信设备切换 | 仅限系统路由选择器 | `kAudioHardwarePropertyDefaultOutputDevice` | `IPolicyConfig::SetDefaultEndpoint` | `pactl set-default-sink` | `HTMLMediaElement.setSinkId` |
| **应用独立音量/增益** | 映射至媒体流 | 映射至媒体流 | 映射至主音量 | `ISimpleAudioVolume` 进程级音量 | 映射至主输出 | DOM 音量 + `GainNode`（`0.0`–`4.0`） |

## 集成与平台配置

在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  xue_hua_navite_volume_controller: ^1.0.0
```

### Android 配置说明

插件已在自身的 `AndroidManifest.xml` 中自动声明以下权限，宿主项目无需重复配置：

```xml
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
```

- `MODIFY_AUDIO_SETTINGS` 为普通权限，安装时自动授予。
- `ACCESS_NOTIFICATION_POLICY` 仅在 Android 6.0+ 切换进入或退出 `RingerMode.silent`（完全静音/免打扰模式）时需要。调用前请先检查 `await controller.hasDoNotDisturbAccess()`，若未授权可调用 `await controller.requestDoNotDisturbAccess()` 引导用户开启。

### iOS 配置说明

- 最低支持版本：iOS `15.0`。
- iOS 编程式修改音量基于 `MPVolumeView` 内部的 `UISlider` 实现。**重要提示**：Apple 的 iOS 模拟器（Simulator）不会挂载硬件音量滑块，请在 **iPhone 或 iPad 真机** 上测试音量修改和系统音量 HUD 隐藏效果。

### macOS 配置说明

- 最低支持版本：macOS `12.0`。
- 基于 `CoreAudio` 与 `AudioToolbox` 原生框架实现，完美兼容 App Sandbox 沙盒内外环境，无需额外 Entitlements。

### Windows 配置说明

- 基于 Windows CoreAudio 标准 COM 接口（`mmdeviceapi.h`、`endpointvolume.h`、`audiopolicy.h`）直接编译，无需额外部署任何第三方 DLL。

### Linux 配置说明

- 编译期仅依赖标准 `flutter_linux` 与 `gtk+-3.0`，无需安装额外的音频开发头文件。
- 运行时自动探测并优先使用 `pactl`（PulseAudio / PipeWire-Pulse）、`wpctl`（PipeWire WirePlumber）或 `amixer`（ALSA）。

## 快速上手与完整使用示例

### 1. 初始化与响应式 UI 绑定

```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_volume_controller/xue_hua_navite_volume_controller.dart';

final controller = XueHuaNaviteVolumeController.instance;

Future<void> initVolume() async {
  final state = await controller.initialize(
    const VolumeControllerConfig(
      defaultStream: VolumeStreamType.media,
      showSystemUI: false,
      interceptHardwareButtons: false,
      listenToVolumeChanges: true,
    ),
  );
  debugPrint('初始音量: ${state.percentage}% | 是否静音: ${state.isMuted}');
}
```

直接绑定 `controller.stateNotifier` 实现零样板代码的响应式音量控制条：

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

### 2. 监听实时音量变化与物理音量键拦截

```dart
final volumeSub = controller.onVolumeChanged.listen((VolumeChangeEvent event) {
  debugPrint(
    '音量变化 (${event.reason}): ${event.streamType.wireName} -> ${event.state.percentage}% '
    '(当前设备: ${event.state.outputDeviceName})',
  );
});

// 在 Android 上启用物理音量键拦截（按音量加减键只触发事件，不改变系统音量）：
await controller.setInterceptHardwareButtons(true);
final buttonSub = controller.onHardwareButton.listen((VolumeButtonEvent button) {
  if (button.action == VolumeKeyAction.keyDown) {
    debugPrint('捕获物理音量键: ${button.direction.wireName}');
  }
});
```

### 3. Android 多音频流控制与响铃模式切换

```dart
// 独立调节不同音频通道的音量，且不弹出系统原生音量条：
await controller.setVolume(0.80, stream: VolumeStreamType.media, showSystemUI: false);
await controller.setVolume(1.00, stream: VolumeStreamType.alarm, showSystemUI: false);
await controller.setVolume(0.40, stream: VolumeStreamType.notification, showSystemUI: false);

// 一次性读取全部支持的音频流音量：
final Map<VolumeStreamType, double> allStreams = await controller.getAllStreamVolumes();

// 安全切换静音模式（先检测免打扰权限）：
if (await controller.hasDoNotDisturbAccess()) {
  await controller.setRingerMode(RingerMode.silent);
} else {
  await controller.requestDoNotDisturbAccess();
}
```

### 4. 枚举与切换音频输出设备

```dart
final devices = await controller.getOutputDevices();
for (final dev in devices) {
  debugPrint('设备: ${dev.name} [${dev.route.wireName}] (当前默认: ${dev.isDefault})');
}

// 在 macOS、Windows、Linux、Android 12+ 或 Web 上切换输出设备：
if (devices.length > 1) {
  await controller.setOutputDevice(devices.last.id);
}
```

### 5. 应用级独立音量（Windows/Web）与 WebAudio 增益放大

```dart
// 在 Windows (ISimpleAudioVolume) 或 Web 上单独设置当前应用音量（不影响其他应用）：
await controller.setAppVolume(0.75);

// 在 Web 端开启 200% (2.0x) Web Audio API GainNode 音量放大：
await controller.setWebGainBoost(2.0);
```

## 注意事项与最佳实践

1. **iOS 模拟器与真机差异**：iOS 模拟器不支持模拟 `MPVolumeView` 的硬件音量滑块，请在 iOS 真机上验证音量调节和 HUD 隐藏效果。
2. **macOS 外接 HDMI / DisplayPort 显示器**：部分外接显示器或电视通过 HDMI/DP 连接时不向系统开放硬件静音或硬件音量寄存器（`AudioObjectIsPropertySettable` 为 `false`）。插件已内置自动检测逻辑，当硬件静音不可写时自动回退为软件零音量静音并记忆原音量。
3. **Android 免打扰权限异常处理**：在未授予免打扰权限时强行切换 `RingerMode.silent` 会触发系统 `SecurityException`，插件将其封装为 `VolumeControllerException(code: 'DND_PERMISSION_REQUIRED')`，建议在 UI 中结合 `hasDoNotDisturbAccess()` 与 `requestDoNotDisturbAccess()` 友好引导用户。
4. **及时释放物理按键拦截**：若在拍照页或阅读页开启了 `setInterceptHardwareButtons(true)`，请在页面 `dispose()` 时调用 `setInterceptHardwareButtons(false)` 恢复系统默认音量键行为。

## AI Agent Skills 支持

本插件已按照 [Dart Package Skills 规范](https://dart.dev/tools/pub/package-skills) 在 `skills/xue_hua_navite_volume_controller-usage/SKILL.md` 内置标准 AI 技能文件。依赖本插件的项目可通过以下命令一键安装技能：

```bash
dart run skills@ get
```

## 开源协议

MIT License © 2026 Matkurban (`3496354336@qq.com`)
