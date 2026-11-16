import Foundation
import AVFoundation

/// 录音器：使用 AVAudioRecorder 录制 m4a 格式音频，上限 60 秒。
public final class VoiceRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?

    public var onMaxDurationReached: (() -> Void)?
    public var onProgress: ((TimeInterval) -> Void)?

    /// 检查并请求麦克风权限
    public static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// 开始录音
    public func start() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        self.recordingURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let newRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        newRecorder.delegate = self
        newRecorder.record(forDuration: 60.0) // 自动限制 60 秒
        self.recorder = newRecorder

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let r = self.recorder, r.isRecording else { return }
            self.onProgress?(r.currentTime)
        }

        return fileURL
    }

    /// 停止录音并返回音频文件 URL
    public func stop() -> URL? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        return recordingURL
    }

    /// 取消并删除录音文件
    public func cancel() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
    }

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        timer?.invalidate()
        timer = nil
        if flag {
            onMaxDurationReached?()
        }
    }
}