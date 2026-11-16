import SwiftUI

/// 定时器主界面：设置时长、开始/暂停/复位，倒计时显示，到点触发通知。
@available(iOS 17, *)
struct TimerView: View {
    @Environment(\.modelContext) private var context

    @State private var durationSeconds: Int = 300
    @State private var remaining: Int = 0
    @State private var isRunning = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        schedule()
    }

    private func pause() {
        isRunning = false
        NotificationScheduler.cancelTimer()
        timer.upstream.connect().cancel()
    }

    private func reset() {
        pause()
        remaining = 0
    }

    private func fire() {
        isRunning = false
        NotificationScheduler.cancelTimer()
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