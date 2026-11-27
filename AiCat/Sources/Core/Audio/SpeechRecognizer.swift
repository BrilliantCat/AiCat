import Combine
import Foundation
import Speech
import AVFoundation

@MainActor
public final class OfflineSpeechRecognizer: ObservableObject {
    public static let shared = OfflineSpeechRecognizer()
    
    @Published public var transcribedText: String = ""
    @Published public var isRecording: Bool = false
    @Published private(set) var isTranscribing = false
    @Published public var errorMessage: String?
    
    let finishedUtterance = PassthroughSubject<String, Never>()
    private var receivedFinal = false
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasTap = false
    private var ownsSession = false
    private var useLocalAfterError = false
    private var recorder: AVAudioRecorder?
    private var deadline: Task<Void, Never>?
    private var recordingID = UUID()
    private var localModel: URL? {
        Self.bundledModel
    }

    nonisolated static var bundledModel: URL? {
        Bundle.main.url(forResource: "ggml-base-q5_1", withExtension: "bin", subdirectory: "Speech")
    }
    
    private init() {
        // Подбираем русский распознаватель речи
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    }
    
    public func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else {
                    self.errorMessage = "Разреши доступ к микрофону в настройках AiCat."
                    completion(false)
                    return
                }
                if self.speechRecognizer?.supportsOnDeviceRecognition == true,
                   SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                    SFSpeechRecognizer.requestAuthorization { _ in DispatchQueue.main.async { completion(true) } }
                } else { completion(true) }
            }
        }
    }
    
    public func startListening() throws {
        stopListening()
        receivedFinal = false
        
        CatSpeechSynthesizer.shared.stop()
        CatPurrFeedback.shared.stop()
        MusicTool.shared.cancelBeat()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        ownsSession = true
        guard !useLocalAfterError, let recognizer = speechRecognizer, recognizer.supportsOnDeviceRecognition, recognizer.isAvailable,
              SFSpeechRecognizer.authorizationStatus() == .authorized else {
            do { try startLocalRecording() } catch { stopListening(); throw error }
            return
        }
        
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
                if let error {
                    if self.localModel != nil && self.transcribedText.isEmpty {
                        self.useLocalAfterError = true
                        self.errorMessage = "Системная диктовка прервалась. Нажми микрофон ещё раз для локального распознавания."
                    } else { self.errorMessage = error.localizedDescription }
                }
                if error != nil || result?.isFinal == true {
                    self.receivedFinal = result?.isFinal == true && error == nil
                    if self.isTranscribing { self.recognitionRequest = nil }
                    else {
                        self.stopListening()
                        if self.receivedFinal { self.finishedUtterance.send(self.transcribedText) }
                    }
                }
            }
        }
    }

    private func startLocalRecording() throws {
        guard localModel != nil else { throw speechError("В сборке отсутствует модель русского голоса Whisper.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AiCat-input-\(UUID()).caf")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
                                       AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16]
        let capture = try AVAudioRecorder(url: url, settings: settings)
        recorder = capture
        guard capture.record(forDuration: 30) else { throw speechError("Не удалось включить микрофон.") }
        isRecording = true
        transcribedText = ""
        errorMessage = nil
        deadline = Task {
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            _ = await finishListening()
        }
    }

    private func speechError(_ message: String) -> NSError {
        NSError(domain: "AiCat.Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    func finishListening() async -> String {
        guard isRecording else { return "" }
        deadline?.cancel()
        deadline = nil
        let id = recordingID
        isTranscribing = true
        isRecording = false
        if let capture = recorder, let model = localModel {
            recorder = nil
            capture.stop()
            releaseSession()
            let url = capture.url
            let text = await Task.detached(priority: .userInitiated) { () -> String? in
                defer { try? FileManager.default.removeItem(at: url) }
                return Self.transcribe(recording: url, model: model)
            }.value
            guard id == recordingID else { return "" }
            transcribedText = text ?? ""
            receivedFinal = !transcribedText.isEmpty
        } else {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            // Let Speech deliver the final words before cancelling the request.
            for _ in 0..<15 {
                if recognitionRequest == nil || id != recordingID { break }
                try? await Task.sleep(for: .milliseconds(80))
            }
            guard id == recordingID else { return "" }
        }
        stopListening()
        if transcribedText.isEmpty { errorMessage = "Не расслышал. Попробуй сказать фразу ещё раз." }
        if receivedFinal && !transcribedText.isEmpty { finishedUtterance.send(transcribedText) }
        return transcribedText
    }
    
    nonisolated static func transcribe(recording url: URL, model: URL) -> String? {
        guard let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false),
              file.processingFormat.sampleRate == 16000, file.processingFormat.channelCount == 1,
              (3200...496000).contains(file.length),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, let samples = buffer.floatChannelData?[0] else { return nil }
        let pcm = UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength))
        let energy = pcm.reduce(Float.zero) { $0 + $1 * $1 }
        guard energy > Float(pcm.count) * 0.000001 else { return nil }
        return AiCatTranscribeRussian(model.path, Data(buffer: pcm))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func stopListening() {
        recordingID = UUID()
        deadline?.cancel()
        deadline = nil
        if let recorder {
            recorder.stop()
            try? FileManager.default.removeItem(at: recorder.url)
        }
        recorder = nil
        isTranscribing = false
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
        releaseSession()
    }

    private func releaseSession() {
        if ownsSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            ownsSession = false
        }
    }
}
