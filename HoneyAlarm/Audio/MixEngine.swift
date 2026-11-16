import Foundation
import AVFoundation

/// 混音引擎：将背景音乐文件与录音文件按指定音量做逐采样混合，导出为单条铃声文件。
/// 采用离线 PCM 混合（读入两个文件，逐采样相加），比实时引擎更稳定、可测试。
public enum MixEngine {
    public static func mix(
        musicURL: URL,
        voiceURL: URL,
        musicVolume: Float,
        voiceVolume: Float,
        outURL: URL
    ) async throws {
        let musicFile = try AVAudioFile(forReading: musicURL)
        let voiceFile = try AVAudioFile(forReading: voiceURL)

        // 统一采样格式：取较大采样率与声道数
        let sampleRate = max(musicFile.processingFormat.sampleRate, voiceFile.processingFormat.sampleRate)
        let channels = max(musicFile.processingFormat.channelCount, voiceFile.processingFormat.channelCount)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!

        // 读取两个文件的所有 PCM 采样
        let musicFrames = try await readAllFrames(from: musicFile, targetFormat: format)
        let voiceFrames = try await readAllFrames(from: voiceFile, targetFormat: format)

        let outLength = max(musicFrames.count, voiceFrames.count)
        var outFrames = [Float](repeating: 0, count: outLength)

        for i in 0..<outLength {
            var sample: Float = 0
            if i < musicFrames.count {
                sample += musicFrames[i] * musicVolume
            }
            if i < voiceFrames.count {
                sample += voiceFrames[i] * voiceVolume
            }
            outFrames[i] = max(-1.0, min(1.0, sample))
        }

        // 写入输出文件（CAF）
        let outputFile = try AVAudioFile(
            forWriting: outURL,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )

        let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFile.processingFormat, frameCapacity: AVAudioFrameCount(outLength))!
        outBuffer.frameLength = AVAudioFrameCount(outLength)
        // 单声道写入第 0 通道
        if let data = outBuffer.floatChannelData {
            for i in 0..<outLength {
                data[0][i] = outFrames[i]
            }
        }
        try outputFile.write(from: outBuffer)
    }

    /// 将音频文件全部采样读取为单通道 Float 数组（取平均），并按目标采样率重采样。
    private static func readAllFrames(from file: AVAudioFile, targetFormat: AVAudioFormat) async throws -> [Float] {
        let srcRate = file.processingFormat.sampleRate
        let srcChannels = Int(file.processingFormat.channelCount)
        let totalFrames = Int(file.length)

        // 读出全部数据
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(totalFrames))!
        buf.frameLength = AVAudioFrameCount(totalFrames)
        try file.read(into: buf, frameCount: AVAudioFrameCount(totalFrames))

        // 平均为单声道
        var mono = [Float](repeating: 0, count: totalFrames)
        if let data = buf.floatChannelData {
            for f in 0..<totalFrames {
                var sum: Float = 0
                for ch in 0..<srcChannels {
                    sum += data[ch][f]
                }
                mono[f] = sum / Float(srcChannels)
            }
        }

        // 重采样到目标采样率
        let ratio = targetFormat.sampleRate / srcRate
        if abs(ratio - 1.0) < 0.0001 {
            return mono
        }
        let newCount = Int(Double(totalFrames) * ratio)
        var resampled = [Float](repeating: 0, count: newCount)
        for i in 0..<newCount {
            let srcIdx = min(Int(Double(i) / ratio), totalFrames - 1)
            resampled[i] = mono[srcIdx]
        }
        return resampled
    }
}