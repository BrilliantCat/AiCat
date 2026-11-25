import AVFoundation
import Combine

@MainActor
public final class MusicTool: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = MusicTool()
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var isPlaying = false
    private var player: AVAudioPlayer?
    private var request = UUID()
    private var playingForWorkout = false
    private var workoutFile: URL?

    public func generateBeat(style: String, forWorkout: Bool = false) async -> String {
        guard !Task.isCancelled else { return "Создание бита остановлено." }
        let id = UUID()
        request = id
        stopPlayback()
        playingForWorkout = forWorkout
        if !forWorkout { lastExportURL = nil }
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                try Self.render(style: style.lowercased())
            }.value
            guard request == id, !Task.isCancelled else {
                try? FileManager.default.removeItem(at: url)
                return "Создание бита остановлено."
            }
            if !forWorkout { lastExportURL = url }
            do {
                try play(url)
                if forWorkout { workoutFile = url }
                return "Бит готов. Его можно послушать ещё раз или сохранить."
            } catch {
                if forWorkout { try? FileManager.default.removeItem(at: url) }
                return "Файл создан. Воспроизвести сейчас не удалось: \(error.localizedDescription)"
            }
        } catch {
            return "Не удалось создать бит: \(error.localizedDescription)"
        }
    }

    func replay() throws {
        guard let url = lastExportURL else { return }
        cancelBeat()
        try play(url)
    }

    private func play(_ url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        let next = try AVAudioPlayer(contentsOf: url)
        next.delegate = self
        guard next.play() else {
            throw NSError(domain: "AiCat.Music", code: 1, userInfo: [NSLocalizedDescriptionKey: "Аудиовыход недоступен."])
        }
        player = next
        isPlaying = true
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        if let workoutFile { try? FileManager.default.removeItem(at: workoutFile) }
        workoutFile = nil
    }

    func cancelBeat(workoutOnly: Bool = false) {
        guard !workoutOnly || playingForWorkout else { return }
        request = UUID()
        playingForWorkout = false
        stopPlayback()
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ sender: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(sender)
        Task { @MainActor in
            if let player = self.player, ObjectIdentifier(player) == id { self.stopPlayback() }
        }
    }

    // Write a PCM WAV before playback so sharing also works without an available audio route.
    nonisolated static func render(style: String) throws -> URL {
        let chip = ["8-bit","8bit","ретро"].contains(style)
        let synth = ["cyberpunk","киберпанк"].contains(style)
        let rate = 22050.0
        let beat = 60.0 / (chip ? 112.0 : synth ? 98.0 : 82.0)
        let frames = Int(rate * beat * 8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AiCat-beat-\(UUID()).wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let samples = buffer.floatChannelData?[0] else {
            throw NSError(domain: "AiCat.Music", code: 2, userInfo: [NSLocalizedDescriptionKey: "Недостаточно памяти для звука."])
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        let bass = [130.8128, 103.8262, 116.5409, 97.9989]
        let twoPi = 2 * Double.pi
        var random = UInt32.random(in: 1...UInt32.max)
        var previousNoise = 0.0
        for i in 0..<frames {
            let t = Double(i) / rate
            let b = Int(t / beat)
            let local = t - Double(b) * beat
            let half = local.truncatingRemainder(dividingBy: beat / 2)
            let root = bass[(b / 2) % bass.count]
            let tone = twoPi * root * local
            random = random &* 1664525 &+ 1013904223
            let noise = Double(random) / Double(UInt32.max) * 2 - 1
            let hiss = noise - previousNoise
            previousNoise = noise
            let kick = b.isMultiple(of: 2) ? sin(twoPi * (47*local + 1.3*(1-exp(-32*local)))) * exp(-12*local) : 0
            let snare = b.isMultiple(of: 2) ? 0 : noise * exp(-26*local)
            let envelope = min(1, local * 85) * exp(-3.4 * local)
            let keys = sin(tone*2) + 0.62*sin(tone*2.3784) + 0.47*sin(tone*2.9966)
            let melody = chip ? tanh(3.3*sin(tone*4)) : synth ? sin(tone*2 + 1.3*sin(tone*3)) : keys*0.46
            let mix = 0.37*kick + 0.18*snare + 0.055*hiss*exp(-58*half) + envelope*(0.24*melody + 0.23*sin(tone/2))
            let fade = min(1, Double(i)/100, Double(frames-1-i)/650)
            samples[i] = Float(fade * tanh(mix))
        }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
        return url
    }
}
