import Foundation
import UserNotifications
import SwiftData

/// 通知调度模块：闹钟用日历触发（跨午夜用 24 小时制），定时器用时间间隔触发。
enum NotificationScheduler {

    /// 定时器通知的固定标识。
    static let timerNotificationID = "honeyalarm.timer"

    /// 请求通知权限（`.alert, .sound`）。返回 true 表示已授权。
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// 检查通知权限。已授权或暂未授权返回 true，仅彻底被拒返回 false。
    static func checkAuthorization() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus != .denied
    }

    /// 确保通知权限：从未询问时当场发起请求，返回最终是否已授权。
    /// 注意：iOS 对 .notDetermined 状态下的通知请求会静默丢弃（无横幅无声），
    /// 因此调度闹钟前必须先走这一步。
    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        default: // .denied / .restricted
            return false
        }
    }

    /// 为闹钟生成通知标识列表。
    /// - 一次性闹钟：单个标识 `alarm.id`。
    /// - 重复闹钟：按每个重复日各一条，标识 `alarm.id.<weekday>`（weekday 1=周日 … 7=周六）。
    @available(iOS 17, *)
    static func identifiers(for alarm: Alarm) -> [String] {
        if alarm.repeats.isEmpty {
            return [alarm.id.uuidString]
        }
        return alarm.repeats.map { "\(alarm.id.uuidString).\($0)" }
    }

    /// 构建闹钟的触发。禁用闹钟返回空数组。
    /// 时刻用 24 小时制；重复闹钟为每条重复日各建一个 `repeats: true` 触发。
    @available(iOS 17, *)
    static func triggers(for alarm: Alarm) -> [(identifier: String, trigger: UNCalendarNotificationTrigger)] {
        guard alarm.isEnabled else { return [] }
        let base = alarmTimeComponents(alarm.time)
        if alarm.repeats.isEmpty {
            return [(identifiers(for: alarm)[0],
                     UNCalendarNotificationTrigger(dateMatching: base, repeats: false))]
        }
        return alarm.repeats.compactMap { weekday -> (String, UNCalendarNotificationTrigger)? in
            var comps = base
            comps.weekday = weekday
            return (("\(alarm.id.uuidString).\(weekday)"),
                    UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        }
    }

    /// 调度闹钟通知。声音根据 ringtoneID 解析：内置用系统默认；自定义/混音/导入用
    /// `UNNotificationSound(named:)` 指向沙盒 Library/Sounds 文件，文件缺失时兜底为系统默认并记录。
    @available(iOS 17, *)
    static func scheduleAlarm(_ alarm: Alarm, customRingtones: [Ringtone] = []) {
        let sound = soundFor(alarm.ringtoneID, custom: customRingtones)
        for entry in triggers(for: alarm) {
            let content = UNMutableNotificationContent()
            content.title = alarm.label.isEmpty ? "闹钟" : alarm.label
            content.body = "该起床啦"
            content.sound = sound
            content.userInfo = [
                "alarmID": alarm.id.uuidString,
                "kind": "alarm",
            ]
            let request = UNNotificationRequest(
                identifier: entry.identifier,
                content: content,
                trigger: entry.trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// 依据 ringtoneID 解析通知声音。内置或无对应条目/文件缺失 → 系统默认并记录。
    @available(iOS 17, *)
    private static func soundFor(_ ringtoneID: String, custom: [Ringtone]) -> UNNotificationSound {
        guard !ringtoneID.isEmpty else { return .default }
        guard let ringtone = RingLibrary.resolve(ringtoneID, custom: custom) else {
            NSLog("HoneyAlarm: ringtone not found for id %@", ringtoneID)
            return .default
        }
        if ringtone.kind == "builtin" {
            // 内置音乐已在 Bundle，用文件名作为通知声音名
            return UNNotificationSound(named: UNNotificationSoundName(ringtone.fileName))
        }
        // 自定义/混音/导入：文件在 Library/Sounds
        guard RingLibrary.customSoundExists(ringtone.fileName) else {
            NSLog("HoneyAlarm: sound file missing %@, falling back to default", ringtone.fileName)
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName(ringtone.fileName))
    }

    /// 取消闹钟的所有通知（一次性 + 全部重复日）。
    static func cancel(_ alarmID: UUID) {
        let center = UNUserNotificationCenter.current()
        let prefix = alarmID.uuidString
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0 == prefix || $0.hasPrefix(prefix + ".") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 为定时器构建时间间隔触发；非正秒数返回 nil。
    static func timeIntervalTrigger(for seconds: Int) -> UNTimeIntervalNotificationTrigger? {
        guard seconds > 0 else { return nil }
        return UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
    }

    /// 调度定时器通知。
    @available(iOS 17, *)
    static func scheduleTimer(_ timer: TimerModel, fireAfter seconds: Int) {
        guard let trigger = timeIntervalTrigger(for: seconds) else { return }
        let content = UNMutableNotificationContent()
        content.title = timer.label.isEmpty ? "定时器" : timer.label
        content.body = "时间到"
        content.sound = .default
        content.userInfo = [
            "alarmID": timer.id.uuidString,
            "kind": "timer",
        ]
        let request = UNNotificationRequest(
            identifier: timerNotificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 取消定时器通知。
    static func cancelTimer() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [timerNotificationID])
    }
}