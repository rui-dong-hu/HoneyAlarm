# HoneyAlarm 实现计划

> **给执行代理的说明：** 必需子技能：用 superpowers:executing-plans（本会话内原生执行）或 superpowers:subagent-driven-development 按任务逐步实现。步骤用复选框（`- [ ]`）跟踪。

**目标：** 一个离线的 iPhone/iPad 闹钟 App，含闹钟、定时器两个 Tab，内置柔和音乐，并支持把家人人声录音混入音乐合成为自定义铃声。

**架构：** SwiftUI 单 Target Universal App，SwiftData 持久化数据（闹钟、定时器、铃声），AVFoundation（录音、混音、播放），UserNotifications 调度本地通知（锁屏/后台可靠响铃）。三个 Tab：闹钟、定时器、铃声库。

**技术栈：** Swift 6 / SwiftUI / SwiftData / AVFoundation / UserNotifications。

**规格：** `docs/superpowers/specs/2026-11-16-honeyalarm-design.md`

## 全局约束

- 系统目标 iOS 15+（iPhone / iPad Universal）。
- 完全离线，不依赖网络/账号/服务器。
- 预置铃声为 App 内置 Bundle 资源（免版权）。
- 混音 = 一段人声录音叠在所选音乐之上，调节音量，合成单一铃声文件。
- 铃声来源：① App 内置音乐 ② 用户本地录音 ③ 从"文件"App 导入的本地音乐文件（m4a/mp3/wav，用 `UIDocumentPicker`） ④ 以上任意混合结果。
- 素材长度限制：内置音乐、导入文件、录音均 ≤ 1 分钟，做成铃声后循环播放。
- 混合产物默认保存在本地。
- 设备代码签名用免费 Apple ID（7 天重签）。
- v1 不含高级混音时间轴编辑。
- 编码语言：Swift 6 语言模式，可编译 iOS 18.2 SDK。
- 所有对现有代码的修改保持与现有文件一致的风格与命名。

## Review Focus

- **自定义铃声能否在锁屏/后台准点响**：通知的自定义声音必须使用 Bundle 内 `Library/Sounds` 打包的文件。因此每次混音成的新铃声须**重新导出并作为 Bundle 资源随 App 一起安装**；App 记录"上次安装的铃声版本"，若用户已选的自定义铃声在本次安装后变了则用系统默认音 + 前台提示。测试：混音后铃声文件必须落盘到可复用的导出目录，且文件名稳定可被 Schedule 引用。
- **通知权限被拒**：首次进 App 就请求通知与麦克风权限；若通知权限被拒，闹钟无法响铃——列表页显示提示条引导去设置开启。测试：权限状态存模型，UI 反映。
- **闹钟时间 24 小时制跨午夜**：`UNCalendarNotificationTrigger` 用 24 小时制（0-23）时刻组件，重复闹钟用 `repeats=true`，避免日期错位。测试：时刻归一化到当日/次日的 Date 计算正确。
- **录音权限被拒或超时**：录音上限 60 秒，权限被拒给出明确提示并停用录音按钮。测试：超限自动停止录音。
- **重复闹钟下次触发时刻计算**：禁用状态的闹钟不调度；编辑/删除后撤销旧通知并重新调度。测试：保存/删除后通知标识（`alarm.id`）一致。
- **断网/离线完整性**：App 首次启动无需任何网络请求即完整可用。
- **本地音乐来源限定**：铃声只用①内置 ②录音 ③从"文件"App 导入的本地文件（m4a/mp3/wav）。**不接入 iTunes/Apple Music 歌曲库**（规避 DRM）。导入与录音素材均 ≤ 1 分钟；超限被拒并有提示。测试：>60s 的导入/录音被拒绝并提示。

---

## 任务分解

### Task 1: Xcode 16.2 环境就绪（前置，阻塞一切）

Xcode 无法由我代装（需用户 Apple ID 在 App Store 手动下载）。这一步由用户手动完成，用于验证环境可用后再继续。

**Files:**（无工程文件；只记录验证命令）
- 操作：用户在 **App Store** 安装 Xcode 16.x（Intel Mac 上限 16.2）。装完在终端执行切换开发者目录。
- 备选：若 App Store 仅提供 17+，去 Apple 开发者网站 Downloads 下载 Xcode 16.2 的 `.xip`。

**Interfaces:**
- Consumes: 无
- Produces: 可用的 `xcodebuild`（Xcode 16.x），作为 Task 2 前置。

- [ ] **Step 1: 用户安装 Xcode 16.2**
  在 App Store 下载并安装 Xcode（16.x，Intel 兼容版）。

- [ ] **Step 2: 切换到 Xcode 开发者目录并验证**
  ```
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  xcodebuild -version
  ```
  期望输出 `Xcode 16.x` 与对应 Build 版本。输出仍是 CommandLineTools 则继续直到指向 Xcode.app。
  成功后向我汇报"Xcode 已就绪"，我再继续 Task 2 起的代码实现。

- [ ] **Step 3: 检查真机部署工具**
  ```
  xcrun simctl list devices   # 应有至少一个 iOS 模拟器
  security find-identity -v -p codesigning   # 预期 0 valid identities（免费 ID 稍后登录）
  ```

---

### Task 2: 初始化 Xcode 工程（Xcode 16 / SwiftUI / Universal）

**Files:**
- Create: `HoneyAlarm.xcodeproj`（由 Xcode 16 生成）
- Create: `HoneyAlarm/HoneyAlarmApp.swift`
- Create: `HoneyAlarm/ContentView.swift`
- Create: `HoneyAlarm/Info.plist`（含麦克风用途描述 `NSMicrophoneUsageDescription`）
- Create: `HoneyAlarm/Assets.xcassets`

**Interfaces:**
- Consumes: Task 1 的 Xcode 16
- Produces: 可编译空 SwiftUI App 骨架；`HoneyAlarmApp.swift` 导出 `HoneyAlarmApp` 结构体；`ContentView.swift` 导出 `ContentView`。

- [ ] **Step 1: 生成工程骨架**
  用 Xcode 16 新建 SwiftUI App 工程（Product Name `HoneyAlarm`，Interface SwiftUI，Language Swift，iPhone+iPad Universal，iOS 15.0 最低版本）。

- [ ] **Step 2: 写最小可编译入口**
  `HoneyAlarmApp.swift` 定义 `@main struct HoneyAlarmApp: App`；`ContentView.swift` 定义 `ContentView` 显示占位文本 "HoneyAlarm"。

- [ ] **Step 3: Info.plist 加麦克风用途**
  加入 `NSMicrophoneUsageDescription` 与中文说明字符串（录音前向用户说明用途）。

- [ ] **Step 4: 编译验证**
  ```
  xcodebuild -project HoneyAlarm.xcodeproj -scheme HoneyAlarm -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
  ```
  期望 BUILD SUCCEEDED。

- [ ] **Step 5: 提交（若已 git init）**
  `git init && git add . && git commit -m "chore: scaffold HoneyAlarm SwiftUI project"`

---

### Task 3: 数据模型与持久化（SwiftData）

**Files:**
- Create: `HoneyAlarm/Models.swift`（Alarm、TimerModel、Ringtone）
- Create: `HoneyAlarm/Store.swift`（`@main` 里挂 ModelContainer；提供 store 查询接口）

**Interfaces:**
- Consumes: Task 2 的工程骨架
- Produces:
  - `@Model final class Alarm { var id: UUID; var time: Date; var repeats: [Int]; var label: String; var isEnabled: Bool; var ringtoneID: String }`
  - `@Model final class TimerModel { var id: UUID; var seconds: Int; var label: String }`
  - `@Model final class Ringtone { var id: String; var name: String; var kind: String; var sourceFileURL: String?; var voiceFileURL: String?; var musicVolume: Double; var voiceVolume: Double; var fileName: String }`
  - `func alarmTimeComponents(_ time: Date) -> DateComponents`（归一化为 24 小时制 0-23 时分）

- [ ] **Step 1: 写测试（归一化）**
  ```swift
  func testTimeComponentsNormalization() {
      // 午夜/跨日/随机时间
  }
  ```
  验证 `DateComponents.hour ∈ 0...23`、`minute ∈ 0...59`。

- [ ] **Step 2: 运行测试确认失败**
  目标尚未实现，编译失败/测试未定义。

- [ ] **Step 3: 实现三个模型与 `alarmTimeComponents`**
  `Models.swift` 中实现 SwiftData `@Model`；`Store.swift` 配置 `ModelContainer(for: Alarm.self, TimerModel.self, Ringtone.self)` 并在 App 注入 `modelContainer`。

- [ ] **Step 4: 运行测试通过**
  归一化测试 PASS，工程可编译。

- [ ] **Step 5: 提交**

---

### Task 4: 通知调度模块（闹钟 + 定时器到点）

**Files:**
- Create: `HoneyAlarm/NotificationScheduler.swift`
  - `enum NotificationScheduler`
  - `static func requestAuthorization() async`
  - `static func scheduleAlarm(_ alarm: Alarm)`
  - `static func scheduleTimer(_ timer: TimerModel, fireAfter seconds: Int)`
  - `static func cancel(_ alarmID: UUID)`
  - `static func cancelTimer()`

**Interfaces:**
- Consumes: Task 3 的 `Alarm`/`TimerModel`、`alarmTimeComponents`
- Produces: 供 Task 5/6 调用：闹钟用 `UNCalendarNotificationTrigger(repeats: true 当 repeats 非空)`；定时器用 `UNTimeIntervalNotificationTrigger`。通知的 `userInfo` 携带 `alarmID`/`kind`，`sound` 指向铃声文件（Task 4 先用系统默认音 `.defaultCritical`/`.default`，Task 6 接入自定义铃声文件）。

- [ ] **Step 1: 写测试（跨午夜 / 禁用不调度）**
  验证 `scheduleAlarm` 对 `isEnabled=false` 不创建触发；重复闹钟的日期组件用 24 小时制。

- [ ] **Step 2: 实现 `NotificationScheduler`**
  用 `UNUserNotificationCenter` 管理；取消与重排以 `alarm.id` 为标识。

- [ ] **Step 3: 权限检查**
  `requestAuthorization` 请求 `.alert, .sound`；被拒时返回状态供 UI（Review Focus 第 2 条）。

- [ ] **Step 4: 测试通过 + 提交**

---

### Task 5: 闹钟 Tab UI + 定时器 Tab UI

**Files:**
- Create: `HoneyAlarm/Views/AlarmListView.swift`
- Create: `HoneyAlarm/Views/AlarmEditView.swift`
- Create: `HoneyAlarm/Views/TimerView.swift`
- Create: `HoneyAlarm/Views/RootTabView.swift`

**Interfaces:**
- Consumes: Task 3 模型 + Store、Task 4 `NotificationScheduler`
- Produces: `RootTabView`（`TabView`：闹钟/定时器/铃声库三个 tab）；闹钟列表、编辑（时间选择、重复日、标签、开关、选铃声）、定时器主界面（时长、开始/暂停/复位、到时通知）。

- [ ] **Step 1: 实现 `RootTabView` 与三个 Tab 容器**
  闹钟、定时器、铃声库各一 tab。

- [ ] **Step 2: 实现闹钟列表 + 编辑视图**
  列表显示每条闹钟（时间、重复、开关）；开关 toggle 时调用 `scheduleAlarm`/`cancel`。编辑页用 `DatePicker`（time）与重复日多选，保存即重排通知。

- [ ] **Step 3: 实现定时器视图**
  时长选择 → 开始启动 `scheduleTimer`；后台通知到点响。剩余时间显示与暂停/复位用 `TimelineView`/`Timer.publish`。

- [ ] **Step 4: 权限被拒提示条**
  通知权限被拒时列表顶部显示引导条（Review Focus 第 2 条）。

- [ ] **Step 5: 编译 + 真机冒烟（可选）+ 提交**

---

### Task 6: 铃声库、录音与混音

**Files:**
- Create: `HoneyAlarm/Audio/RingLibrary.swift`（内置音乐清单 + Bundle 引用）
- Create: `HoneyAlarm/Audio/LocalFileImporter.swift`（`UIDocumentPicker` 导入本地 m4a/mp3/wav 到沙盒）
- Create: `HoneyAlarm/Audio/VoiceRecorder.swift`（AVAudioRecorder，m4a，60s 上限）
- Create: `HoneyAlarm/Audio/MixEngine.swift`（AVAudioEngine 混音并导出）
- Create: `HoneyAlarm/Views/RingLibraryView.swift`（铃声列表/录音/混音 UI）
- Create: `HoneyAlarm/Views/MixEditorView.swift`

**Interfaces:**
- Consumes: Task 3 `Ringtone` 模型、Task 5 铃声库 tab 入口
- Produces:
  - `enum RingLibrary { static let bundled: [Ringtone]; static func soundFileURL(for id: String) -> URL? }`
  - `enum LocalFileImporter { static func makePicker() -> UIDocumentPickerViewController }`（允许 m4a/mp3/wav；回调把所选文件复制进沙盒，超 1 分钟则拒绝并提示）
  - `final class VoiceRecorder { func start(); func stop() -> URL; func cancel() }`（录音临时文件，60s 上限）
  - `enum MixEngine { static func mix(musicURL: URL, voiceURL: URL, musicVolume: Float, voiceVolume: Float, outURL: URL) async throws }`
  - 混音导出文件：落盘到 `Library/Sounds` 同层可被通知引用的目录，文件名稳定（`custom_<id>.caf`）。

- [ ] **Step 1: 内置音乐清单**
  `RingLibrary.bundled` 返回 3–5 条内置 `Ringtone`（Bundle 资源文件名，如 `lullaby.caf`、`morning.caf`…）。音频资源文件由用户提供到 `HoneyAlarm/Resources/`（见 Task 7）。

- [ ] **Step 2: 本地文件导入器**
  `LocalFileImporter.makePicker()` 用 `UIDocumentPickerViewController(forOpeningContentTypes: [.audio])`；回调中校验所选文件时长 ≤ 60s（用 `AVAsset` 读 duration），超限则拒绝并提示，符合 `AVURLAsset` 读取；合法则复制进沙盒 `Documents/ImportedAudio/` 并生成 `Ringtone` 记录。

- [ ] **Step 3: 录音器**
  `VoiceRecorder` 用 `AVAudioRecorder` 录 m4a；录音超 60s 自动停止；权限被拒时 `start` 抛错、UI 停用按钮（Review Focus 第 4 条）。

- [ ] **Step 4: 混音引擎**
  `MixEngine.mix` 用 `AVAudioEngine`（或 `AVAudioMixerNode`）把音乐与录音混到一条并导出音频文件。测试混音后文件存在、时长>0、体积>0。

- [ ] **Step 5: 铃声库 + 混音编辑 UI**
  铃声库列出内置 + 导入 + 自定义铃声；"新建混音"进 `MixEditorView`：选预置音乐或导入文件 → 录/选人声 → 调音量 → 试听 → 保存生成 `Ringtone` 记录。

- [ ] **Step 6: 试听**
  用 `AVAudioPlayer` 播放混音结果（循环播放）。

- [ ] **Step 7: 测试 + 提交**

---

### Task 7: 音频资源准备（用户手动）

预置铃声音频文件需用户提供，作为 Bundle 资源进工程。

**Files:**
- Add（用户放置）: `HoneyAlarm/Resources/*.caf`（3–5 段柔和音乐，15–30s）
- Modify: Task 6 的 `RingLibrary.bundled` 引用这些文件名。

- [ ] **Step 1: 用户放入音频文件**
  把 3–5 段免版权柔和音乐片段（.caf/.m4a/.mp3）放入 `HoneyAlarm/Resources/`，并在 Xcode 勾选加入 Target（Copy Bundle Resources）。若暂无现成音乐，可用设备/系统自带的一段先顶替。

- [ ] **Step 2: 核对 RingLibrary 清单与文件一一对应**
  每段在 `RingLibrary.bundled` 有对应条目，且工程能编译、试听能出声。

---

### Task 8: 自定义铃声接入系统通知（锁屏可靠响铃）

**Files:**
- Modify: `HoneyAlarm/NotificationScheduler.swift`（`scheduleAlarm` 的声音设置）
- Modify: `HoneyAlarm/Audio/MixEngine.swift`（导出为可被通知识别的文件）

**Interfaces:**
- Consumes: Task 6 的 `MixEngine` 导出结果、`Ringtone.fileName`
- Produces: 通知 `sound` 用 Bundle 内 `Library/Sounds` 文件（`UNNotificationSound(named: ...)`），保证锁屏/后台响铃（Review Focus 第 1 条）。

- [ ] **Step 1: 把自定义铃声导出为通知可用文件**
  每次混音保存时，把 `MixEngine` 导出文件放入 App 的 `Library/Sounds` 沙盒目录并刷新到 Bundle 资源表（作为"随 App 打包"的一部分），文件名 = `custom_<id>.caf`。

- [ ] **Step 2: scheduleAlarm 选用自定义声音**
  依据 `alarm.ringtoneID` 查 `RingLibrary`，内置 → 系统/内置名；自定义 → `UNNotificationSound(named: UNNotificationSoundName(fileName))`。兜底：文件缺失用系统默认音并记录（Review Focus 第 1 条）。

- [ ] **Step 3: 真机锁屏验证**
  在 iPhone 上设一个 1 分钟后的闹钟，锁屏待机，确认到点响铃且声音为用户混音结果。

- [ ] **Step 4: 测试 + 提交**

---

### Task 9: 真机签名与安装（免费 Apple ID）

**Files:**
- Modify: `HoneyAlarm.xcodeproj`（Signing & Capabilities）

**Interfaces:**
- Consumes: 全部已完成任务、已就绪的 Xcode 16
- Produces: 安装到 iPhone/iPad 的可运行 App（免费 ID，7 天重签）。

- [ ] **Step 1: Xcode 登录免费 Apple ID**
  Xcode → Settings → Accounts 添加 Apple ID（免费）。

- [ ] **Step 2: 设 Team 与自动签名**
  工程 Target → Signing & Capabilities → 勾 Automatically manage signing，选 Team，Bundle Identifier 设唯一（如 `com.yourname.HoneyAlarm`）。设备经 USB 连接，选择设备运行。

- [ ] **Step 3: 真机运行 + 信任**
  首次运行时 iPhone 设置 → 通用 → VPN 与设备管理 → 信任开发者。运行 App 验证核心功能：闹钟锁屏响铃、定时器到点、录音混音生成自定义铃声。

- [ ] **Step 4: 记录重签周期**
  在工程 `README` 标注"免费 ID 证书 7 天过期，需重装"。

---

### Task 10: 收尾：集成测试 + 文档

**Files:**
- Create: `README.md`
- Modify: 各处按需

**Interfaces:**
- Consumes: 全部任务
- Produces: 可交付、可自我说明的 App 与文档。

- [ ] **Step 1: 端到端验证清单**
  在真机上跑一遍：新建闹钟（含自定义混音铃声）→ 锁屏到点响铃；定时器到点；App 完全离线启动无网络依赖。

- [ ] **Step 2: 补 `README.md`**
  说明功能、安装（免费 ID 7 天重签）、内置音乐来源/版权、混音使用方法。

- [ ] **Step 3: 提交最终变更**

---