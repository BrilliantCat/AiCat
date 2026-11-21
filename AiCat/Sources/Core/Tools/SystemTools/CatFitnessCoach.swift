import Foundation
import UIKit
import CoreMotion

public final class CatFitnessCoach: ObservableObject {
    public static let shared = CatFitnessCoach()
    
    @Published public var isWorkoutActive: Bool = false
    @Published public var currentExerciseName: String = ""
    @Published public var currentRepsCount: Int = 0
    @Published public var targetReps: Int = 15
    @Published public var catCheerMessage: String = ""
    
    private let motionManager = CMMotionManager()
    private var lastRepTime: TimeInterval = 0
    
    private init() {}
    
    // Запуск режима подсчета отжиманий (через датчик приближения)
    public func startPushups() -> String {
        isWorkoutActive = true
        currentExerciseName = "Отжимания хищника"
        currentRepsCount = 0
        targetReps = 15
        catCheerMessage = "Положи телефон экраном вверх под грудь! Опускайся к экрану — я считаю."
        
        UIDevice.current.isProximityMonitoringEnabled = true
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProximityChange), name: UIDevice.proximityStateDidChangeNotification, object: nil)
        
        CatActionHandler.shared.state.moodEmoji = "💪"
        CatActionHandler.shared.state.statusText = "Считает отжимания: 0/\(targetReps)"
        
        _ = MusicTool.shared.generateBeat(style: "cyberpunk")
        
        return "Положи iPhone под грудь экраном вверх! Начинай отжиматься — я вслух считаю каждое чистое повторение. Цель: 15 раз. Погнали!"
    }
    
    // Запуск приседаний (с отслеживанием через акселерометр)
    public func startSquats() -> String {
        isWorkoutActive = true
        currentExerciseName = "Тигриные приседания"
        currentRepsCount = 0
        targetReps = 20
        catCheerMessage = "Держи телефон в руке или в кармане. Приседай глубоко!"
        
        startMotionTracking()
        
        CatActionHandler.shared.state.moodEmoji = "🐯"
        CatActionHandler.shared.state.statusText = "Считает приседания: 0/\(targetReps)"
        
        _ = MusicTool.shared.generateBeat(style: "8-bit")
        
        return "Держи телефон в руке или в кармане. Начинай глубокие приседания — я фиксирую каждое движение!"
    }
    
    @objc private func handleProximityChange() {
        guard isWorkoutActive else { return }
        
        if UIDevice.current.proximityState {
            let now = Date().timeIntervalSince1970
            // Защита от дребезга (не чаще чем раз в 0.7 секунды)
            guard now - lastRepTime > 0.7 else { return }
            lastRepTime = now
            
            DispatchQueue.main.async {
                self.currentRepsCount += 1
                CatActionHandler.shared.state.statusText = "Отжимания: \(self.currentRepsCount)/\(self.targetReps)"
                
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                
                if self.currentRepsCount >= self.targetReps {
                    self.catCheerMessage = "15! КРАСАВЧИК! Отжался на максимум. Ты зверь, кожаный!"
                    CatSpeechSynthesizer.shared.speak(text: "Пятнадцать! Отличная работа, кожаный! Ты зверь!")
                    self.stopWorkout()
                } else {
                    let phrases = ["Раз!", "Два!", "Три!", "Четыре!", "Пять, отлично!", "Шесть!", "Семь!", "Восемь, жми!", "Девять!", "Десять, еще пять!", "Одиннадцать!", "Двенадцать!", "Тринадцать!", "Четырнадцать!"]
                    let text = self.currentRepsCount <= phrases.count ? phrases[self.currentRepsCount - 1] : "\(self.currentRepsCount)!"
                    CatSpeechSynthesizer.shared.speak(text: text)
                }
            }
        }
    }
    
    private func startMotionTracking() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        
        var isDown = false
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, self.isWorkoutActive, let z = data?.acceleration.z else { return }
            
            if z < -0.65 && !isDown {
                isDown = true
            } else if z > -0.25 && isDown {
                isDown = false
                self.currentRepsCount += 1
                CatActionHandler.shared.state.statusText = "Приседания: \(self.currentRepsCount)/\(self.targetReps)"
                
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                if self.currentRepsCount >= self.targetReps {
                    CatSpeechSynthesizer.shared.speak(text: "Двадцать! Приседания окончены, стальные лапы обеспечены!")
                    self.stopWorkout()
                } else {
                    CatSpeechSynthesizer.shared.speak(text: "\(self.currentRepsCount)")
                }
            }
        }
    }
    
    public func stopWorkout() {
        isWorkoutActive = false
        UIDevice.current.isProximityMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
        motionManager.stopAccelerometerUpdates()
        
        CatActionHandler.shared.state.moodEmoji = "😼"
        CatActionHandler.shared.state.statusText = "Тренировка завершена"
    }
}
