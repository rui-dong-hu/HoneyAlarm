import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

/// 试听播放完成代理：播放结束时回调，用于把播放按钮还原成播放态。
private final class PreviewPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?()
        }
    }
}

/// 铃声库标签页：管理内置音乐、导入的本地音频、录音以及自定义混音铃声。
@available(iOS 17, *)
public struct RingLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query private var customRingtones: [Ringtone]

    @State private var showImporter = false
    @State private var showMixEditor = false
    @State private var importError: String?
    /// 试听播放器（内置音乐与自定义铃声通用）
    @State private var previewPlayer: AVAudioPlayer?
    @State private var previewingID: String?
    @State private var previewDelegate = PreviewPlayerDelegate()

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("内置轻柔音乐") {
                    ForEach(RingLibrary.bundled, id: \.id) { ringtone in
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundStyle(Color.accentColor)
                            Text(ringtone.name)
                            Spacer()
                            Text("内置").font(.caption).foregroundStyle(.secondary)
                            Button {
                                togglePreview(ringtone)
                            } label: {
                                Image(systemName: previewingID == ringtone.id ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section("我的铃声 / 自定义混音") {
                    if customRingtones.isEmpty {
                        Text("暂无自定义铃声。点击右上角「＋ 制作混音」或左上角「导入音频」添加。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(customRingtones, id: \.id) { ringtone in
                            HStack {
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundStyle(.green)
                                Text(ringtone.name)
                                Spacer()
                                Text(ringtone.kind == "mixed" ? "混音" : (ringtone.kind == "recorded" ? "录音" : "导入")).font(.caption).foregroundStyle(.secondary)
                                Button {
                                    togglePreview(ringtone)
                                } label: {
                                    Image(systemName: previewingID == ringtone.id ? "stop.circle.fill" : "play.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete(perform: deleteCustomRingtones)
                    }
                }
            }
            .navigationTitle("铃声库")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showMixEditor = true
                    } label: {
                        Label("制作混音", systemImage: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("导入音频") {
                        showImporter = true
                    }
                }
            }
            .sheet(isPresented: $showMixEditor) {
                MixEditorView()
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    do {
                        guard let selectedURL = try result.get().first else { return }
                        if customRingtones.contains(where: { $0.name == selectedURL.lastPathComponent }) {
                            importError = "已存在同名铃声「\(selectedURL.lastPathComponent)」，请勿重复上传。"
                            return
                        }
                        let valid = await LocalFileImporter.validateAudioDuration(url: selectedURL)
                        guard valid else {
                            importError = "音频时长超过 1 分钟限制，请选择更短的音频文件。"
                            return
                        }
                        let savedURL = try await LocalFileImporter.importAudioFile(from: selectedURL)
                        let newRingtone = Ringtone(
                            name: selectedURL.lastPathComponent,
                            kind: "imported",
                            sourceFileURL: savedURL.absoluteString,
                            fileName: savedURL.lastPathComponent
                        )
                        context.insert(newRingtone)
                        try? context.save()
                    } catch {
                        importError = "导入失败：\(error.localizedDescription)"
                    }
                }
            }
            .alert("提示", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func deleteCustomRingtones(at offsets: IndexSet) {
        for index in offsets {
            let item = customRingtones[index]
            if previewingID == item.id { stopPreview() }
            context.delete(item)
        }
        try? context.save()
    }

    /// 播放/停止试听
    private func togglePreview(_ ringtone: Ringtone) {
        if previewingID == ringtone.id {
            stopPreview()
            return
        }
        stopPreview()
        guard let url = RingLibrary.soundFileURL(for: ringtone) else {
            importError = "找不到音频文件"
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            previewDelegate.onFinish = { [self] in
                previewPlayer = nil
                previewingID = nil
            }
            player.delegate = previewDelegate
            player.play()
            previewPlayer = player
            previewingID = ringtone.id
        } catch {
            importError = "试听失败：\(error.localizedDescription)"
        }
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewingID = nil
    }
}