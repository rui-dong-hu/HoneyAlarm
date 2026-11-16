import Foundation
import SwiftData

/// 把某个 `Date` 归一化为 24 小时制时分（0-23 小时、0-59 分钟）。
/// 秒与亚秒被清零，避免比较/调度时因秒差产生误差。
func alarmTimeComponents(_ time: Date) -> DateComponents {
    let cal = Calendar.current
    var comps = cal.dateComponents([.hour, .minute, .second, .nanosecond], from: time)
    comps.second = 0
    comps.nanosecond = 0
    return comps
}

/// 闹钟模型。SwiftData 持久化，@Model 依赖 iOS 17+。
@Model
@available(iOS 17, *)
public final class Alarm {
    @Attribute(.unique) public var id: UUID
    public var time: Date
    public var repeats: [Int]
    public var label: String
    public var isEnabled: Bool
    public var ringtoneID: String

    public init(
        id: UUID = UUID(),
        time: Date = Date(),
        repeats: [Int] = [],
        label: String = "",
        isEnabled: Bool = true,
        ringtoneID: String = ""
    ) {
        self.id = id
        self.time = time
        self.repeats = repeats
        self.label = label
        self.isEnabled = isEnabled
        self.ringtoneID = ringtoneID
    }
}

/// 定时器模型。
@Model
@available(iOS 17, *)
public final class TimerModel {
    @Attribute(.unique) public var id: UUID
    public var seconds: Int
    public var label: String

    public init(id: UUID = UUID(), seconds: Int = 60, label: String = "") {
        self.id = id
        self.seconds = seconds
        self.label = label
    }
}

/// 铃声模型。kind 取值："builtin"（内置音乐）/ "mixed"（自定义混音）。
@Model
@available(iOS 17, *)
public final class Ringtone {
    @Attribute(.unique) public var id: String
    public var name: String
    public var kind: String
    public var sourceFileURL: String?
    public var voiceFileURL: String?
    public var musicVolume: Double
    public var voiceVolume: Double
    public var fileName: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        kind: String,
        sourceFileURL: String? = nil,
        voiceFileURL: String? = nil,
        musicVolume: Double = 0.5,
        voiceVolume: Double = 0.5,
        fileName: String
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.sourceFileURL = sourceFileURL
        self.voiceFileURL = voiceFileURL
        self.musicVolume = musicVolume
        self.voiceVolume = voiceVolume
        self.fileName = fileName
    }
}