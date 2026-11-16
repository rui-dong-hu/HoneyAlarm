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

    /// 获取铃声对应的本地文件 URL（内置从 Bundle 获取，自定义/导入从沙盒获取）。
    public static func soundFileURL(for ringtone: Ringtone) -> URL? {
        if ringtone.kind == "builtin" {
            let base = (ringtone.fileName as NSString).deletingPathExtension
            let ext = (ringtone.fileName as NSString).pathExtension
            return Bundle.main.url(forResource: base, withExtension: ext)
        } else {
            // 自定义混音或导入文件存放在 Library/Sounds 或 Documents/ImportedAudio
            let fm = FileManager.default
            let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let soundsDir = library.appendingPathComponent("Sounds")
            let fileURL = soundsDir.appendingPathComponent(ringtone.fileName)
            return fm.fileExists(atPath: fileURL.path) ? fileURL : nil
        }
    }
}