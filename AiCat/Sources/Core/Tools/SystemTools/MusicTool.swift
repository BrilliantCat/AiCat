import Foundation
import AVFoundation

public final class MusicTool: ObservableObject {
    public static let shared = MusicTool()
    
    @Published public var isPlaying: Bool = false
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 44100.0
    private lazy var audioFormat: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }()
    
    private init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
            try engine.start()
            
            self.audioEngine = engine
            self.playerNode = player
        } catch {
            print("MusicTool setup failed: \(error.localizedDescription)")
        }
    }
    
    // Генерация короткого стильного бита (Lo-Fi, Cyberpunk, 8-Bit) офлайн
    public func generateBeat(style: String) -> String {
        let selectedStyle = style.lowercased()
        
        switch selectedStyle {
        case "lo-fi", "lofi":
            playTonePattern(frequencies: [261.63, 329.63, 392.00, 523.25, 392.00, 329.63], noteDuration: 0.35, waveType: .sine)
            return "Сгенерировал расслабляющий Lo-Fi бит. Мурчу в такт басам..."
            
        case "cyberpunk", "киберпанк":
            playTonePattern(frequencies: [110.00, 110.00, 146.83, 110.00, 164.81, 220.00], noteDuration: 0.22, waveType: .sawtooth)
            return "Запустил неоновый киберпанк-синт. Время надеть темные очки!"
            
        case "8-bit", "8bit", "ретро":
            playTonePattern(frequencies: [440.00, 554.37, 659.25, 880.00, 659.25, 880.00], noteDuration: 0.16, waveType: .square)
            return "Сгенерировал ностальгический 8-битный саундтрек для кошачьих приключений."
            
        default:
            playTonePattern(frequencies: [329.63, 392.00, 440.00, 523.25], noteDuration: 0.28, waveType: .sine)
            return "Сгенерировал авторскую кошачью мелодию."
        }
    }
    
    private enum WaveType { case sine, square, sawtooth }
    
    private func playTonePattern(frequencies: [Double], noteDuration: Double, waveType: WaveType) {
        if audioEngine == nil || !(audioEngine?.isRunning ?? false) {
            setupAudioEngine()
        }
        
        guard let player = playerNode, let engine = audioEngine, engine.isRunning else { return }
        
        var fullAudioDataLeft = [Float]()
        var fullAudioDataRight = [Float]()
        
        for (noteIndex, freq) in frequencies.enumerated() {
            let samplesCount = Int(sampleRate * noteDuration)
            let pan = sin(Double(noteIndex)) * 0.3 // легкий стерео-паннинг
            
            for i in 0..<samplesCount {
                let time = Double(i) / sampleRate
                let phase = 2.0 * Double.pi * freq * time
                
                var waveSample: Double = 0.0
                switch waveType {
                case .sine:
                    waveSample = sin(phase)
                case .square:
                    waveSample = sin(phase) >= 0 ? 0.7 : -0.7
                case .sawtooth:
                    waveSample = 2.0 * (time * freq - floor(time * freq + 0.5))
                }
                
                // ADSR огибающая с мягким затуханием
                let progress = Double(i) / Double(samplesCount)
                let envelope: Double
                if progress < 0.1 {
                    envelope = progress / 0.1 // Attack
                } else {
                    envelope = max(0.0, 1.0 - (progress - 0.1) / 0.9) // Decay
                }
                
                let sample = Float(waveSample * envelope * 0.45)
                fullAudioDataLeft.append(sample * Float(1.0 - pan))
                fullAudioDataRight.append(sample * Float(1.0 + pan))
            }
        }
        
        let frameCount = AVAudioFrameCount(fullAudioDataLeft.count)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return }
        pcmBuffer.frameLength = frameCount
        
        if let channels = pcmBuffer.floatChannelData {
            let leftChannel = channels[0]
            let rightChannel = channels[1]
            for i in 0..<Int(frameCount) {
                leftChannel[i] = fullAudioDataLeft[i]
                rightChannel[i] = fullAudioDataRight[i]
            }
        }
        
        DispatchQueue.main.async { self.isPlaying = true }
        
        player.stop()
        player.scheduleBuffer(pcmBuffer, at: nil, options: .interrupts) { [weak self] in
            DispatchQueue.main.async { self?.isPlaying = false }
        }
        player.play()
    }
}
