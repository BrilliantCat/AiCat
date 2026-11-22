import Combine
import Foundation
import Speech
import AVFoundation

public final class OfflineSpeechRecognizer: ObservableObject {
    public static let shared = OfflineSpeechRecognizer()
    
    @Published public var transcribedText: String = ""
    @Published public var isRecording: Bool = false
    @Published public var errorMessage: String?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
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
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        
        // Включаем частичные результаты в реальном времени
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        
        let inputNode = audioEngine.inputNode
        let busFormat = inputNode.outputFormat(forBus: 0)
        let format = busFormat.sampleRate > 0 ? busFormat : AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.transcribedText = ""
            self.errorMessage = nil
        }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let recognized = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = recognized
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                // Код 216 - нормальная остановка пользователем
                if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                    print("Speech recognition warning: \(error.localizedDescription)")
                }
                self.stopListening()
            }
            
            if result?.isFinal ?? false {
                self.stopListening()
            }
        }
    }
    
    public func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Освобождаем сессию записи
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
