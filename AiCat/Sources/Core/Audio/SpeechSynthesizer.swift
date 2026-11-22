import Combine
import Foundation
import AVFoundation

public final class CatSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    public static let shared = CatSpeechSynthesizer()
    
    @Published public var isSpeaking: Bool = false
    @Published public var isVoiceEnabled: Bool = true
    
    private let synthesizer = AVSpeechSynthesizer()
    
    override private init() {
        super.init()
        synthesizer.delegate = self
        // Не активируем аудиосессию при старте приложения, чтобы не глушить музыку пользователя (duckOthers)
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback гарантирует звук через динамик ДАЖЕ ЕСЛИ телефон в беззвучном режиме (переключатель Silent Switch)
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Ошибка настройки AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    public func speak(text: String) {
        guard isVoiceEnabled else { return }
        
        let cleanedText = cleanTextForSpeech(text)
        guard !cleanedText.isEmpty else { return }
        
        stop()
        setupAudioSession()
        
        let utterance = AVSpeechUtterance(string: cleanedText)
        
        // Подбираем лучший русский голос
        let ruVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "ru") }
        utterance.voice = ruVoices.filter { $0.gender == .male }.sorted { $0.quality.rawValue > $1.quality.rawValue }.first
                       ?? ruVoices.first(where: { $0.quality == .enhanced || $0.quality == .premium })
                       ?? ruVoices.first
                       ?? AVSpeechSynthesisVoice(language: "ru-RU")
                       ?? AVSpeechSynthesisVoice(language: "en-US")
        
        // Фирменный голос AiCat: энергичный, кошачий, живой
        utterance.rate = 0.46
        utterance.pitchMultiplier = 0.95
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        DispatchQueue.main.async { self.isSpeaking = false }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        var clean = text
        // Убираем markdown блоки, кавычки и звездочки для чистого звучания
        clean = clean.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "[#_`~]", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
        // Освобождаем аудиосессию, чтобы музыка пользователя восстановила исходную громкость
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
