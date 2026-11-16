import SwiftUI
import AVFoundation

/// 定时器主界面：设置时长、开始/暂停/复位，倒计时显示，到点触发通知。
@available(iOS 17, *)
struct TimerView: View {
    @Environment(\.modelContext) private var context

    @State private var durationSeconds: Int = 300
    @State private var remaining: Int = 0
    @State private var isRunning = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// 前台到点时本地播放提示音
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(formatted(remaining))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .padding(.top, 40)

                if !isRunning && remaining == 0 {
                    // 设置时长
                    Picker("分钟", selection: $durationSeconds) {
                        ForEach(1...60, id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes * 60)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 160)
                }

                HStack(spacing: 40) {
                    Button {
                        reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title)
                    }
                    .disabled(remaining == 0)

                    Button {
                        isRunning ? pause() : start()
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title)
                            .padding(24)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundStyle(.white)
                    }

                    Button {
                        reset()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title)
                    }
                    .disabled(remaining == 0)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("定时器")
            .onReceive(timer) { _ in
                guard isRunning else { return }
                if remaining > 0 {
                    remaining -= 1
                    if remaining == 0 {
                        fire()
                    }
                }
            }
        }
    }

    private func start() {
        if remaining == 0 {
            remaining = durationSeconds
        }
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        Task {
            // 确保通知权限（从未请求过则弹窗申请）
            _ = await NotificationScheduler.requestAuthorization()
        }
        schedule()
    }

    private func pause() {
        isRunning = false
        NotificationScheduler.cancelTimer()
        timer.upstream.connect().cancel()
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func reset() {
        pause()
        remaining = 0
    }

    private func fire() {
        isRunning = false
        // App 在前台时：倒计时归零往往早于系统通知触发器，先取消通知、改为本地直接播放，
        // 否则下面这行原本的 cancelTimer 会把即将响铃的通知删掉导致无声。
        if UIApplication.shared.applicationState == .active {
            NotificationScheduler.cancelTimer()
            playLocalSound()
        }
        // 后台/锁屏时不清除通知，由系统触发响铃。
    }

    /// 前台到点本地播放内置摇篮曲（.playback 类别不受静音开关影响）。
    private func playLocalSound() {
        guard let url = Bundle.main.url(forResource: "lullaby", withExtension: "caf") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            audioPlayer = player
        } catch {
            NSLog("HoneyAlarm: play local timer sound failed %@", error.localizedDescription)
        }
    }

    private func schedule() {
        let timerModel = TimerModel(label: "定时器")
        NotificationScheduler.scheduleTimer(timerModel, fireAfter: remaining)
    }

    private func formatted(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

@available(iOS 17, *)
#Preview {
    TimerView()
}