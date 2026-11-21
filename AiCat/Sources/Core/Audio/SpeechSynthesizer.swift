import Foundation
import AVFoundation

public final class CatSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    public static let shared = CatSpeechSynthesizer()
    
    @Published public var isSpeaking: Bool = false
    @Published public var isVoiceEnabled: Bool = true
    
    private let synthesizer = AVSpeechSynthesizer()
    private var russianVoice: AVSpeechSynthesisVoice?
    
    override private init() {
        super.init()
        synthesizer.delegate = self
        
        // Подбираем лучший офлайн русский голос (например, Milena или Yuri)
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ru-RU" }
        self.russianVoice = voices.first(where: { $0.quality == .enhanced || $0.quality == .premium }) ?? voices.first
    }
    
    public func speak(text: String) {
        guard isVoiceEnabled else { return }
        
        // Очищаем текст от технической разметки и JSON, если они просочились
        let cleanedText = cleanTextForSpeech(text)
        guard !cleanedText.isEmpty else { return }
        
        stop()
        
        let utterance = AVSpeechUtterance(string: cleanedText)
        utterance.voice = russianVoice ?? AVSpeechSynthesisVoice(language: "ru-RU")
        
        // Фирменная интонация кота: чуть ускоренный темп и немного приподнятый питч
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.15
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        var clean = text
        // Убираем markdown блоки кода и смайлы при озвучке
        clean = clean.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
