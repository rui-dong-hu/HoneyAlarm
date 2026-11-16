# HoneyAlarm · 亲唤

为小朋友设计的一款柔和叫醒闹钟 App（iPhone/iPad 通用）。完全离线运行，不依赖网络、服务器或账号。屏幕显示名称为**「亲唤」**（见 `HoneyAlarm/Info.plist` 的 `CFBundleDisplayName`）。

## 核心功能

- **闹钟**：到点通过系统本地通知（`UNUserNotificationCenter`）在锁屏/后台可靠响铃；可设重复日、标签、自定义铃声。
- **定时器**：设定时长，到点响铃。
- **铃声库 / 混音**：内置柔和音乐 + 导入本地音频（m4a/mp3/wav，≤60s）+ 录音（≤60s），可把音乐与录音按音量**混成一条铃声**，循环播放，保存到沙盒 `Library/Sounds`。

## 技术栈

- Swift / SwiftUI，iOS 15+（SwiftData 部分需 iOS 17+，已用 `@available` 防护）
- SwiftData（Alarm / TimerModel / Ringtone 持久化）
- AVFoundation（录音 `AVAudioRecorder`、混音 `MixEngine` 离线 PCM 逐采样混合、试听）
- UserNotifications（锁屏/后台闹钟与定时器）

## 构建

```bash
# 模拟器（本机无运行时时可改为真机构建）
xcodebuild -project HoneyAlarm.xcodeproj -scheme HoneyAlarm \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

单元测试目标 `HoneyAlarmTests` 含时间归一化测试（本机未装模拟器运行时，改用原生 macOS 脚本验证，见各任务 ledger）。

## 真机安装与重签（免费 Apple ID）

本机为 **Intel Mac，Xcode 上限 16.2（iOS 18.2 SDK）**。用**免费 Apple ID** 签名安装到 iPhone/iPad 时：

> ⚠️ **免费开发者证书 7 天过期**，过期后需重新签名并重装到设备。

### 首次安装

1. **Xcode → Settings → Accounts**，添加你的**免费 Apple ID**。
2. 工程 **Target → Signing & Capabilities**：勾选 **Automatically manage signing**，选择你的 Team。
3. **Bundle Identifier** 设为唯一（当前为 `com.ruidong.HoneyAlarm`，可按需改为你自己的域名反写）。
4. iPhone 连接 Mac（USB），在设备列表选择你的 iPhone，点 **Run**。
5. 首次在 iPhone 上：**设置 → 通用 → VPN 与设备管理 → 信任开发者**，信任后即可运行。

### 证书过期重装（每 7 天）

1. 用 Xcode 重新 **Run** 一次到设备（会自动重新签名并安装）。
2. 若设备提示"未受信任的开发者"，重新执行**信任开发者**步骤即可。

### 注意事项

- 免费 ID 无法在 Xcode 中保存**完整 App 图标/能力**等，仅限本机调试与家庭自用。
- 若换电脑需重新添加 Apple ID 并重新签名。
- 正式发布请升级到付费开发者账号。

## 内置铃声

预置 3 段柔和占位音乐（`HoneyAlarm/Resources/*.caf`，`lullaby` / `morning` / `forest`），为便于开发用正弦波合成生成，时长各 20s。**正式使用请替换为你的免版权音乐片段**，并在 Xcode 勾选加入 Target（Copy Bundle Resources）。

## 目录

- `HoneyAlarm/Models.swift` — SwiftData 数据模型
- `HoneyAlarm/Store.swift` — SwiftData 容器
- `HoneyAlarm/NotificationScheduler.swift` — 通知调度与自定义铃声声音
- `HoneyAlarm/Audio/` — 铃声库、导入、录音、混音引擎
- `HoneyAlarm/Views/` — SwiftUI 界面
- `HoneyAlarmTests/` — 单元测试
- `docs/superpowers/` — 设计文档与实现计划