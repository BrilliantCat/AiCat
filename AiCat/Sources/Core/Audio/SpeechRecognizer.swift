import Combine
import Foundation
import Speech
import AVFoundation

@MainActor
public final class OfflineSpeechRecognizer: ObservableObject {
    public static let shared = OfflineSpeechRecognizer()
    
    @Published public var transcribedText: String = ""
    @Published public var isRecording: Bool = false
    @Published public var errorMessage: String?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasTap = false
    private var ownsSession = false
    
    private init() {
        // Подбираем русский распознаватель речи
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU")) ?? SFSpeechRecognizer()
    }
    
    public func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if !granted {
                                self.errorMessage = "Предоставь доступ к микрофону в Настройки -> AiCat"
                            }
                            completion(granted)
                        }
                    }
                default:
                    self.errorMessage = "Предоставь доступ к Распознаванию речи в Настройки -> AiCat"
                    completion(false)
                }
            }
        }
    }
    
    public func startListening() throws {
        stopListening()
        
        guard let recognizer = speechRecognizer else {
            let err = "Распознавание речи недоступно на данном устройстве."
            DispatchQueue.main.async { self.errorMessage = err }
            throw NSError(domain: "AiCat", code: 1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        
        guard recognizer.supportsOnDeviceRecognition else {
            throw NSError(domain: "AiCat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Русское офлайн-распознавание речи недоступно на этом устройстве."])
        }
        CatSpeechSynthesizer.shared.stop()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        ownsSession = true
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        
        // Включаем частичные результаты в реальном времени
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        
        let inputNode = audioEngine.inputNode
        let busFormat = inputNode.outputFormat(forBus: 0)
        guard busFormat.sampleRate > 0, busFormat.channelCount > 0 else {
            stopListening()
            throw NSError(domain: "AiCat", code: 3, userInfo: [NSLocalizedDescriptionKey: "Микрофон сейчас недоступен."])
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: busFormat) { buffer, _ in request.append(buffer) }
        hasTap = true
        
        audioEngine.prepare()
        do { try audioEngine.start() }
        catch {
            stopListening()
            throw error
        }
        isRecording = true
        transcribedText = ""
        errorMessage = nil
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self, weak request] result, error in
            DispatchQueue.main.async {
                guard let self, let request, self.recognitionRequest === request else { return }
                if let result { self.transcribedText = result.bestTranscription.formattedString }
                if let error { self.errorMessage = error.localizedDescription }
                if error != nil || result?.isFinal == true { self.stopListening() }
            }
        }
    }
    
    public func stopListening() {
        if audioEngine.isRunning { audioEngine.stop() }
        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        if ownsSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            ownsSession = false
        }
    }
}
