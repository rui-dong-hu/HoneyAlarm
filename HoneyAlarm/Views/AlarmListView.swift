import SwiftUI
import SwiftData

/// 闹钟列表：显示每条闹钟（时间、重复日、开关），顶部有权限被拒提示条与新建按钮。
@available(iOS 17, *)
struct AlarmListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Alarm.time) private var alarms: [Alarm]
    @Query(filter: #Predicate<Ringtone> { $0.kind != "builtin" }) private var customRingtones: [Ringtone]
    @State private var draft: Alarm?
    @State private var editing: Alarm?

    private var weekdaySymbols: [String] { ["日", "一", "二", "三", "四", "五", "六"] }

    var body: some View {
        NavigationStack {
            List {
                permissionBanner
                ForEach(alarms) { alarm in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timeText(alarm.time))
                                .font(.title)
                                .fontWeight(.semibold)
                            if !alarm.repeats.isEmpty {
                                Text(repeatText(alarm.repeats))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if !alarm.label.isEmpty {
                                Text(alarm.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: binding(for: alarm))
                            .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editing = alarm
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("闹钟")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addAlarm()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $draft) { alarm in
                AlarmEditView(alarm: alarm, isNew: true)
            }
            .sheet(item: $editing) { alarm in
                AlarmEditView(alarm: alarm, isNew: false)
            }
            .onAppear(perform: sync)
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !notificationAuthorized {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Text("通知权限未开启，闹钟到点无法响铃。请在设置中开启通知。")
                        .font(.footnote)
                    Spacer()
                    Button("去设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.footnote)
                }
            }
        }
    }

    @State private var notificationAuthorized = false

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func repeatText(_ days: [Int]) -> String {
        // repeats 用 1=周日 ... 7=周六
        let ordered = days.sorted()
        return ordered.map { "周" + weekdaySymbols[($0 - 1)] }.joined(separator: "、")
    }

    private func binding(for alarm: Alarm) -> Binding<Bool> {
        Binding(
            get: { alarm.isEnabled },
            set: { newValue in
                alarm.isEnabled = newValue
                try? context.save()
                sync(for: alarm)
            }
        )
    }

    /// 新建闹钟：仅在点击时创建并插入一次，避免 sheet 内容闭包随界面重绘反复插入。
    private func addAlarm() {
        let a = Alarm()
        context.insert(a)
        draft = a
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            let a = alarms[i]
            NotificationScheduler.cancel(a.id)
            context.delete(a)
        }
        try? context.save()
    }

    private func sync() {
        Task {
            // 仅在状态不明时请求，已拒则不再反复申请
            let authorized = await NotificationScheduler.checkAuthorization()
            notificationAuthorized = authorized
            
            for alarm in alarms {
                if alarm.isEnabled {
                    NotificationScheduler.scheduleAlarm(alarm, customRingtones: customRingtones)
                } else {
                    NotificationScheduler.cancel(alarm.id)
                }
            }
        }
    }

    private func sync(for alarm: Alarm) {
        if alarm.isEnabled {
            NotificationScheduler.scheduleAlarm(alarm, customRingtones: customRingtones)
        } else {
            NotificationScheduler.cancel(alarm.id)
        }
    }
}

@available(iOS 17, *)
#Preview {
    AlarmListView()
}