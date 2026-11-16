import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// 本地音频导入器：支持选择 m4a/mp3/wav 格式，限制时长 ≤ 60 秒。
public enum LocalFileImporter {
    /// 校验音频文件时长是否 ≤ 60 秒。
    public static func validateAudioDuration(url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds <= 60.5 // 留出 0.5 秒容差
        } catch {
            return false
        }
    }

    /// 将选中的音频复制进沙盒 Document/ImportedAudio 目录
    public static func importAudioFile(from sourceURL: URL) async throws -> URL {
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "LocalFileImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法访问安全资源"])
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let targetDir = docs.appendingPathComponent("ImportedAudio", isDirectory: true)
        if !fm.fileExists(atPath: targetDir.path) {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let fileName = "imported_\(UUID().uuidString).\(ext)"
        let targetURL = targetDir.appendingPathComponent(fileName)

        if fm.fileExists(atPath: targetURL.path) {
            try fm.removeItem(at: targetURL)
        }
        try fm.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }
}