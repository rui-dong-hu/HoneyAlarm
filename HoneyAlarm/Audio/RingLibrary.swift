import Foundation

/// 内置铃声清单与资源定位。
@available(iOS 17, *)
public enum RingLibrary {
    /// 预置的免版权轻柔音乐。资源文件应放置在 App Bundle 中。
    public static let bundled: [Ringtone] = [
        Ringtone(id: "builtin_lullaby", name: "摇篮曲", kind: "builtin", fileName: "lullaby.caf"),
        Ringtone(id: "builtin_morning", name: "晨光", kind: "builtin", fileName: "morning.caf"),
        Ringtone(id: "builtin_forest", name: "森林之声", kind: "builtin", fileName: "forest.caf")
    ]

    /// 按 id 在所有铃声（内置 + 自定义）中解析对应条目。
    public static func resolve(_ id: String, custom: [Ringtone]) -> Ringtone? {
        bundled.first { $0.id == id } ?? custom.first { $0.id == id }
    }

    /// 判断自定义铃声文件是否已存在于沙盒 Library/Sounds。
    public static func customSoundExists(_ fileName: String) -> Bool {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let url = library.appendingPathComponent("Sounds").appendingPathComponent(fileName)
        return fm.fileExists(atPath: url.path)
    }

    /// 获取铃声对应的本地文件 URL（内置从 Bundle 获取，自定义/导入从沙盒获取）。
    public static func soundFileURL(for ringtone: Ringtone) -> URL? {
        if ringtone.kind == "builtin" {
            let base = (ringtone.fileName as NSString).deletingPathExtension
            let ext = (ringtone.fileName as NSString).pathExtension
            return Bundle.main.url(forResource: base, withExtension: ext)
        } else {
            // 自定义混音/导入/录音文件：优先 Library/Sounds，兼容旧的 Documents/ImportedAudio
            let fm = FileManager.default
            let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let soundsURL = library.appendingPathComponent("Sounds").appendingPathComponent(ringtone.fileName)
            if fm.fileExists(atPath: soundsURL.path) { return soundsURL }
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let legacyURL = docs.appendingPathComponent("ImportedAudio").appendingPathComponent(ringtone.fileName)
            return fm.fileExists(atPath: legacyURL.path) ? legacyURL : nil
        }
    }
}