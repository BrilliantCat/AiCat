import AVFoundation
import CoreHaptics
import UIKit

@MainActor
final class CatPurrFeedback {
    static let shared = CatPurrFeedback()
    private var engine: CHHapticEngine?
    private var vibration: CHHapticAdvancedPatternPlayer?
    private var audio: AVAudioPlayer?
    private var timeout: Task<Void, Never>?
    private var active = false

    func respond(for duration: TimeInterval) {
        guard UIApplication.shared.applicationState == .active else { return }
        if !active {
            active = true
            startVibration()
        }
        let speech = CatSpeechSynthesizer.shared
        if speech.isVoiceEnabled, !speech.isSpeaking, !OfflineSpeechRecognizer.shared.isRecording {
            if audio == nil, let url = Bundle.main.url(forResource: "Purr", withExtension: "wav", subdirectory: "CatModel") {
                audio = try? AVAudioPlayer(contentsOf: url)
                audio?.numberOfLoops = -1
            }
            if let audio, !audio.isPlaying {
                audio.currentTime = 0
                audio.volume = 0
                audio.play()
            }
            audio?.setVolume(0.75, fadeDuration: 0.12)
        }
        timeout?.cancel()
        timeout = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(duration))
                audio?.setVolume(0, fadeDuration: 0.15)
                try await Task.sleep(for: .milliseconds(160))
                stop()
            } catch { /* A fresh stroke extended playback. */ }
        }
    }

    private func startVibration() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                try engine.start()
                self.engine = engine
                let events = (0..<16).map { i in
                    let pulse = Float(0.26 + 0.23 * abs(sin(Double(i) * .pi / 8)))
                    return CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: pulse),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08)
                    ], relativeTime: Double(i) * 0.095, duration: 0.080)
                }
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makeAdvancedPlayer(with: pattern)
                player.loopEnabled = true
                try player.start(atTime: CHHapticTimeImmediate)
                vibration = player
                return
            } catch { engine?.stop(completionHandler: nil); engine = nil }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
    }

    func stop() {
        timeout?.cancel()
        timeout = nil
        audio?.stop()
        try? vibration?.stop(atTime: CHHapticTimeImmediate)
        vibration = nil
        engine?.stop(completionHandler: nil)
        engine = nil
        active = false
    }
}
