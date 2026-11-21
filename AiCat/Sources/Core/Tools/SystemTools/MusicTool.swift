import Foundation
import AVFoundation

public final class MusicTool: ObservableObject {
    public static let shared = MusicTool()
    
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    
    private init() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        try? audioEngine.start()
    }
    
    // Генерация короткого стильного бита (Lo-Fi, Cyberpunk, 8-Bit) офлайн
    public func generateBeat(style: String) -> String {
        let selectedStyle = style.lowercased()
        
        switch selectedStyle {
        case "lo-fi", "lofi":
            playTonePattern(frequencies: [261.63, 329.63, 392.00, 493.88], noteDuration: 0.4)
            return "Сгенерировал расслабляющий Lo-Fi бит. Мурчу в такт басам..."
            
        case "cyberpunk", "киберпанк":
            playTonePattern(frequencies: [110.00, 146.83, 164.81, 220.00], noteDuration: 0.2)
            return "Запустил неоновый киберпанк-синт. Время надеть темные очки!"
            
        case "8-bit", "8bit", "ретро":
            playTonePattern(frequencies: [440.00, 554.37, 659.25, 880.00], noteDuration: 0.15)
            return "Сгенерировал ностальгический 8-битный саундтрек для кошачьих приключений."
            
        default:
            playTonePattern(frequencies: [329.63, 392.00, 440.00], noteDuration: 0.3)
            return "Сгенерировал авторскую кошачью мелодию."
        }
    }
    
    private func playTonePattern(frequencies: [Double], noteDuration: Double) {
        let sampleRate = 44100.0
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        var fullAudioData = [Float]()
        
        for freq in frequencies {
            let samplesCount = Int(sampleRate * noteDuration)
            for i in 0..<samplesCount {
                let time = Double(i) / sampleRate
                // Гармонический синтез с легким затуханием (ADSR)
                let envelope = max(0.0, 1.0 - (Double(i) / Double(samplesCount)))
                let sample = Float(sin(2.0 * Double.pi * freq * time) * envelope * 0.4)
                fullAudioData.append(sample)
            }
        }
        
        let frameCount = AVAudioFrameCount(fullAudioData.count)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return }
        pcmBuffer.frameLength = frameCount
        
        if let channelData = pcmBuffer.floatChannelData?[0] {
            for (index, val) in fullAudioData.enumerated() {
                channelData[index] = val
            }
        }
        
        playerNode.stop()
        playerNode.scheduleBuffer(pcmBuffer, at: nil, options: .interrupts) {
            // Завершено воспроизведение
        }
        playerNode.play()
    }
}
