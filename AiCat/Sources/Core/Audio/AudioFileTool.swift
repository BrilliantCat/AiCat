import Combine
import AVFoundation

@MainActor
final class AudioFileTool: ObservableObject {
    private let speech = AVSpeechSynthesizer()

    func exportSpeech(_ text: String) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AiCat-\(UUID()).caf")
        let utterance = CatSpeechSynthesizer.shared.utterance(for: text)
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var finished = false
            var writer: AVAudioFile?
            speech.write(utterance) { buffer in
                lock.lock()
                defer { lock.unlock() }
                guard !finished, let pcm = buffer as? AVAudioPCMBuffer else { return }
                do {
                    if pcm.frameLength == 0 {
                        finished = true
                        let hasAudio = (writer?.length ?? 0) > 0
                        writer = nil
                        if hasAudio { continuation.resume(returning: url) }
                        else {
                            continuation.resume(throwing: NSError(domain: "AiCat.Audio", code: 4,
                                userInfo: [NSLocalizedDescriptionKey: "Выбранный голос не вернул звук. Выбери другой голос в меню AiCat."]))
                        }
                        return
                    }
                    if writer == nil {
                        writer = try AVAudioFile(forWriting: url, settings: pcm.format.settings,
                                                     commonFormat: pcm.format.commonFormat,
                                                     interleaved: pcm.format.isInterleaved)
                    }
                    try writer?.write(from: pcm)
                } catch {
                    finished = true
                    writer = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func trim(url: URL, start: Double, end: Double) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else {
            throw NSError(domain: "AiCat.Audio", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось определить длину аудио."])
        }
        guard start.isFinite, end.isFinite, start >= 0, end > start, end <= duration,
              let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "AiCat.Audio", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Укажи начало и конец в пределах записи (\(Int(duration)) с)."])
        }
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("AiCat-\(UUID()).m4a")
        export.outputURL = target
        export.outputFileType = .m4a
        export.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                      end: CMTime(seconds: end, preferredTimescale: 600))
        await export.export()
        guard export.status == .completed else {
            throw export.error ?? NSError(domain: "AiCat.Audio", code: 2,
                                          userInfo: [NSLocalizedDescriptionKey: "Не удалось сохранить фрагмент."])
        }
        return target
    }
}
