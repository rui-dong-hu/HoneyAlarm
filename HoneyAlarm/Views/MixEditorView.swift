import SwiftUI
import SwiftData
import AVFoundation

/// 混音编辑：选择预置音乐或导入音频 + 录音/选择人声 + 调节音量 + 试听 + 保存为混音铃声。
@available(iOS 17, *)
public struct MixEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMusic: Ringtone?
    @State private var voiceFileURL: URL?
    @State private var musicVolume: Double = 0.7
    @State private var voiceVolume: Double = 0.7
    @State private var isPlaying = false
    @State private var recorder: VoiceRecorder?
    @State private var showRecorder = false
    @State private var showPicker = false
    @State private var mixResultURL: URL?
    @State private var mixError: String?
    /// 试听播放器
    @State private var audioPlayer: AVAudioPlayer?

    @Query private var importedRingtones: [Ringtone]

    private var availableMusic: [Ringtone] {
        RingLibrary.bundled + importedRingtones.filter { $0.kind == "imported" }
    }

    /// 之前录制并已持久化的人声
    private var recordedVoices: [Ringtone] {
        importedRingtones.filter { $0.kind == "recorded" }
    }

    public init() {
        _recorder = State(initialValue: VoiceRecorder())
    }

    public var body: some View {
        NavigationStack {
            formView
        }
        .sheet(isPresented: $showRecorder) {
            if let rec = recorder {
                VoiceRecorderView(recorder: rec, onDone: { url in
                    showRecorder = false
                    if let url = url {
                        persistRecording(url)
                    }
                })
            }
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            Task {
                do {
                    guard let selectedURL = try result.get().first else { return }
                    let valid = await LocalFileImporter.validateAudioDuration(url: selectedURL)
                    guard valid else {
                        mixError = "人声文件超过 1 分钟限制"
                        return
                    }
                    voiceFileURL = selectedURL
                } catch {
                    mixError = "选择失败：\(error.localizedDescription)"
                }
            }
        }
        .alert("提示", isPresented: Binding(get: { mixError != nil }, set: { if !$0 { mixError = nil } })) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(mixError ?? "")
        }
    }

    private var formView: some View {
        Form {
            musicSection
            voiceSection
            volumeSection
            previewSection
        }
        .navigationTitle("制作混音")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    stopPlayback()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveMix() }
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private var musicSection: some View {
        Section("选择背景音乐") {
            ForEach(availableMusic, id: \.id) { ringtone in
                HStack {
                    Text(ringtone.name)
                    Spacer()
                    if selectedMusic?.id == ringtone.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedMusic = ringtone
                }
            }
        }
    }

    private var voiceSection: some View {
        Section("添加人声") {
            HStack {
                Button("录制人声") {
                    showRecorder = true
                }
                .disabled(isPlaying)
                Spacer()
                Button("选择已导入的人声") {
                    showPicker = true
                }
                .disabled(isPlaying)
            }
            if voiceFileURL != nil {
                Text("已添加人声文件")
            }
            if !recordedVoices.isEmpty {
                ForEach(recordedVoices, id: \.id) { ringtone in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.orange)
                        Text(ringtone.name)
                        Spacer()
                        if voiceFileURL?.lastPathComponent == ringtone.fileName {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedVoice(ringtone)
                    }
                }
            }
        }
    }

    private var volumeSection: some View {
        Section("音量调节") {
            HStack {
                Text("背景音乐")
                Spacer()
                Text("\(Int(musicVolume * 100))%")
            }
            Slider(value: $musicVolume, in: 0...1, step: 0.1)
            HStack {
                Text("人声音量")
                Spacer()
                Text("\(Int(voiceVolume * 100))%")
            }
            Slider(value: $voiceVolume, in: 0...1, step: 0.1)
        }
    }

    private var previewSection: some View {
        Section("试听") {
            HStack {
                Button {
                    if isPlaying {
                        stopPlayback()
                    } else {
                        startPlayback()
                    }
                } label: {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                Spacer()
                if mixResultURL != nil {
                    Button("试听混音") {
                        startPlayback()
                    }
                    .disabled(isPlaying)
                }
            }
        }
    }

    private func startPlayback() {
        guard let musicURL = selectedMusic.flatMap({ RingLibrary.soundFileURL(for: $0) }),
              let voiceURL = voiceFileURL else {
            mixError = "请先选择背景音乐和人声"
            return
        }

        Task {
            do {
                let fm = FileManager.default
                let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
                let soundsDir = library.appendingPathComponent("Sounds")
                try fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
                let outURL = soundsDir.appendingPathComponent("custom_mix_\(UUID().uuidString).caf")

                try await MixEngine.mix(
                    musicURL: musicURL,
                    voiceURL: voiceURL,
                    musicVolume: Float(musicVolume),
                    voiceVolume: Float(voiceVolume),
                    outURL: outURL
                )
                mixResultURL = outURL
                play(url: outURL)
            } catch {
                mixError = "混音失败：\(error.localizedDescription)"
            }
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    /// 用 AVAudioPlayer 实际播放试听文件
    private func play(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            audioPlayer = player
            isPlaying = true
        } catch {
            isPlaying = false
            mixError = "试听失败：\(error.localizedDescription)"
        }
    }

    /// 将录音从临时目录持久化到 Library/Sounds，并登记为「录音」铃声，方便下次复用。
    private func persistRecording(_ tmpURL: URL) {
        guard FileManager.default.fileExists(atPath: tmpURL.path) else {
            mixError = "录音文件不存在"
            return
        }
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let soundsDir = library.appendingPathComponent("Sounds")
        try? fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        let fileName = "voice_\(UUID().uuidString).m4a"
        let destURL = soundsDir.appendingPathComponent(fileName)
        do {
            try fm.copyItem(at: tmpURL, to: destURL)
        } catch {
            mixError = "保存录音失败：\(error.localizedDescription)"
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let ringtone = Ringtone(
            name: "录音 \(formatter.string(from: Date()))",
            kind: "recorded",
            voiceFileURL: destURL.absoluteString,
            fileName: fileName
        )
        context.insert(ringtone)
        try? context.save()
        voiceFileURL = destURL
    }

    /// 选择一条已保存的录音作为人声
    private func selectedVoice(_ ringtone: Ringtone) {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let url = library.appendingPathComponent("Sounds").appendingPathComponent(ringtone.fileName)
        guard fm.fileExists(atPath: url.path) else {
            mixError = "录音文件已不存在"
            return
        }
        voiceFileURL = url
    }

    private func saveMix() {
        guard let music = selectedMusic,
              let outURL = mixResultURL,
              let voiceURL = voiceFileURL else {
            mixError = "请先完成混音"
            return
        }

        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let soundsDir = library.appendingPathComponent("Sounds")
        let finalURL = soundsDir.appendingPathComponent("custom_mix_\(UUID().uuidString).caf")

        try? fm.moveItem(at: outURL, to: finalURL)

        let newRingtone = Ringtone(
            name: "\(music.name) + 混音",
            kind: "mixed",
            sourceFileURL: RingLibrary.soundFileURL(for: music)?.absoluteString,
            voiceFileURL: voiceURL.absoluteString,
            musicVolume: musicVolume,
            voiceVolume: voiceVolume,
            fileName: finalURL.lastPathComponent
        )
        context.insert(newRingtone)
        try? context.save()
        dismiss()
    }
}

@available(iOS 17, *)
private struct VoiceRecorderView: View {
    let recorder: VoiceRecorder
    let onDone: (URL?) -> Void

    @State private var isRecording = false
    @State private var progress: TimeInterval = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(isRecording ? "录音中... \(Int(progress))/60" : "准备录音")
                    .font(.title)
                ProgressView(value: progress, total: 60)
                Spacer()
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(isRecording ? Color.red : Color.accentColor)
                }
                Spacer()
            }
            .navigationTitle("录制人声")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { recorder.cancel(); onDone(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { onDone(recorder.stop()) }
                        .disabled(!isRecording && progress == 0)
                }
            }
        }
        .onAppear {
            recorder.onProgress = { p in
                DispatchQueue.main.async {
                    self.progress = p
                }
            }
            recorder.onMaxDurationReached = {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }
    }

    private func startRecording() {
        do {
            _ = try recorder.start()
            isRecording = true
        } catch {
            // 处理权限错误等
        }
    }

    private func stopRecording() {
        _ = recorder.stop()
        isRecording = false
    }
}