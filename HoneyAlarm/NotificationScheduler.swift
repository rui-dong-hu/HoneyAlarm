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

    /// 调度闹钟通知。
    @available(iOS 17, *)
    static func scheduleAlarm(_ alarm: Alarm) {
        for entry in triggers(for: alarm) {
            let content = UNMutableNotificationContent()
            content.title = alarm.label.isEmpty ? "闹钟" : alarm.label
            content.body = "该起床啦"
            content.sound = .default
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