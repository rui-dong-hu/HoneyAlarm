import SwiftUI
import SwiftData

/// 闹钟编辑：时间选择（DatePicker 时刻）、重复日多选、标签、开关。
@available(iOS 17, *)
struct AlarmEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Ringtone> { $0.kind != "builtin" }) private var customRingtones: [Ringtone]

    @Bindable private var alarm: Alarm
    private let weekdaySymbols: [String] = ["日", "一", "二", "三", "四", "五", "六"]
    /// 是否为新建闹钟（尚未插入 SwiftData 上下文）。新建时取消不残留空记录。
    private let isNew: Bool

    @State private var time: Date

    /// 铃声选项：内置音乐 + 自定义/导入铃声。
    private var allRingtones: [Ringtone] {
        RingLibrary.bundled + customRingtones
    }

    /// 铃声选择绑定：回写 alarm.ringtoneID。
    private var ringtoneSelection: Binding<String> {
        Binding(
            get: { alarm.ringtoneID.isEmpty ? RingLibrary.bundled.first?.id ?? "" : alarm.ringtoneID },
            set: { alarm.ringtoneID = $0 }
        )
    }

    init(alarm: Alarm, isNew: Bool = false) {
        self.alarm = alarm
        self.isNew = isNew
        // 用 alarmTimeComponents 归一化的 24 小时制时刻，避免秒差
        let comps = alarmTimeComponents(alarm.time)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let cal = Calendar.current
        let base = cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        _time = State(initialValue: base)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    DatePicker("时刻", selection: $time, displayedComponents: .hourAndMinute)
                }
                Section("铃声") {
                    Picker("铃声", selection: ringtoneSelection) {
                        ForEach(allRingtones) { r in
                            Text(r.name).tag(r.id)
                        }
                    }
                }
                RepeatSectionView(alarm: alarm, toggle: toggle)
                Section("标签") {
                    TextField("标签（可选）", text: $alarm.label)
                }
            }
            .navigationTitle(alarm.id.uuidString.isEmpty ? "新建闹钟" : "编辑闹钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private func toggle(_ weekday: Int) {
        if let idx = alarm.repeats.firstIndex(of: weekday) {
            alarm.repeats.remove(at: idx)
        } else {
            alarm.repeats.append(weekday)
        }
    }

    private func save() {
        let comps = alarmTimeComponents(time)
        let cal = Calendar.current
        var dateComps = cal.dateComponents([.year, .month, .day], from: alarm.time)
        dateComps.hour = comps.hour
        dateComps.minute = comps.minute
        dateComps.second = 0
        alarm.time = cal.date(from: dateComps) ?? time
        try? context.save()
        let enabled = alarm.isEnabled
        Task {
            // 调度前先确保通知权限（.notDetermined 时系统会静默丢弃通知）
            let authorized = await NotificationScheduler.ensureAuthorization()
            if enabled && authorized {
                NotificationScheduler.scheduleAlarm(alarm, customRingtones: customRingtones)
            } else {
                NotificationScheduler.cancel(alarm.id)
            }
        }
        dismiss()
    }

    private func cancel() {
        if isNew {
            context.delete(alarm)
            try? context.save()
        }
        dismiss()
    }
}

@available(iOS 17, *)
#Preview {
    AlarmEditView(alarm: Alarm())
}

@available(iOS 17, *)
private struct RepeatSectionView: View {
    let alarm: Alarm
    let toggle: (Int) -> Void

    private let weekdaySymbols: [String] = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        Section("重复") {
            ForEach(1...7, id: \.self) { weekday in
                RepeatRowView(weekday: weekday, alarm: alarm, toggle: toggle)
            }
        }
    }
}

@available(iOS 17, *)
private struct RepeatRowView: View {
    let weekday: Int
    let alarm: Alarm
    let toggle: (Int) -> Void

    private let weekdaySymbols: [String] = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        Button {
            toggle(weekday)
        } label: {
            HStack {
                Text("每周" + weekdaySymbols[weekday - 1])
                Spacer()
                if alarm.repeats.contains(weekday) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}