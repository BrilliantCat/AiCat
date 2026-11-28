import Combine
import Foundation
import AVFoundation

public final class CatSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    public static let shared = CatSpeechSynthesizer()
    
    @Published public var isSpeaking: Bool = false
    @Published public var isVoiceEnabled = UserDefaults.standard.object(forKey: "aicat.voiceEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isVoiceEnabled, forKey: "aicat.voiceEnabled")
            if !isVoiceEnabled { stop() }
        }
    }
    
    @Published var preferredVoiceID = UserDefaults.standard.string(forKey: "aicat.speechVoice") ?? "" {
        didSet { UserDefaults.standard.set(preferredVoiceID, forKey: "aicat.speechVoice") }
    }

    @Published var tone = UserDefaults.standard.string(forKey: "aicat.voiceTone") ?? "soft" {
        didSet { UserDefaults.standard.set(tone, forKey: "aicat.voiceTone") }
    }

    var russianVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ru") }.sorted {
            if ($0.gender == .male) != ($1.gender == .male) { return $0.gender == .male }
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func utterance(for text: String) -> AVSpeechUtterance {
        let clean = text.replacingOccurrences(of: "\\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: "\\\"«»“”„`")).joined()
        let result = AVSpeechUtterance(string: clean)
        let voices = russianVoices
        result.voice = voices.first { $0.identifier == preferredVoiceID } ?? voices.first ?? AVSpeechSynthesisVoice(language: "ru-RU")
        switch tone {
        case "deep": result.rate = AVSpeechUtteranceDefaultSpeechRate * 0.86; result.pitchMultiplier = 0.74
        case "bright": result.rate = AVSpeechUtteranceDefaultSpeechRate * 1.06; result.pitchMultiplier = 1.16
        default: result.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96; result.pitchMultiplier = 0.94
        }
        return result
    }
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?
    
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
        
        let utterance = utterance(for: cleanedText)
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        guard activeUtterance != nil else { return }
        activeUtterance = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        var clean = text
        // Убираем markdown блоки, кавычки и звездочки для чистого звучания
        clean = clean.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\*([^*]+)\\*", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "[#_`~]", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if self.activeUtterance === utterance { self.isSpeaking = true }
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(utterance)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    private func finish(_ utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard self.activeUtterance === utterance else { return }
            self.activeUtterance = nil
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }
}
