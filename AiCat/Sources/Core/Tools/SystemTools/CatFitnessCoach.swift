import Foundation
import UIKit
import CoreMotion

@MainActor
public final class CatFitnessCoach: ObservableObject {
    public static let shared = CatFitnessCoach()
    
    @Published public var isWorkoutActive: Bool = false
    @Published public var currentExerciseName: String = ""
    @Published public var currentRepsCount: Int = 0
    @Published public var targetReps: Int = 15
    @Published public var catCheerMessage: String = ""
    
    private let motionManager = CMMotionManager()
    private var lastRepTime: TimeInterval = 0
    private var isSquattingDown: Bool = false
    
    private init() {}
    
    // Запуск режима подсчета отжиманий (через датчик приближения Dynamic Island)
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
    
    // Запуск приседаний (с отслеживанием 3D-вектора ускорения)
    public func startSquats() -> String {
        isWorkoutActive = true
        currentExerciseName = "Приседания пантеры"
        currentRepsCount = 0
        targetReps = 20
        catCheerMessage = "Держи телефон в руке или в кармане. Приседай глубоко!"
        
        UIDevice.current.isProximityMonitoringEnabled = false
        startMotionTracking()
        
        CatActionHandler.shared.state.moodEmoji = "🐆"
        CatActionHandler.shared.state.statusText = "Считает приседания: 0/\(targetReps)"
        
        _ = MusicTool.shared.generateBeat(style: "lo-fi")
        
        return "Держи телефон в руке или в кармане. Начинай глубокие приседания — я фиксирую каждое движение!"
    }
    
    // Ручной тап по баннеру тренировки (для проверки или если датчик недоступен)
    public func manualRecordRep() {
        guard isWorkoutActive else { return }
        recordRep()
    }
    
    @objc private func handleProximityChange() {
        guard isWorkoutActive else { return }
        
        if UIDevice.current.proximityState {
            let now = Date().timeIntervalSince1970
            guard now - lastRepTime > 0.65 else { return }
            lastRepTime = now
            recordRep()
        }
    }
    
    private func recordRep() {
        currentRepsCount += 1
        CatActionHandler.shared.state.statusText = "\(currentExerciseName): \(currentRepsCount)/\(targetReps)"
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        if currentRepsCount >= targetReps {
            catCheerMessage = "Молодец! Отличный результат!"
            CatSpeechSynthesizer.shared.speak(text: "Цель выполнена! \(targetReps) раз! Ты настоящий тигр, кожаный!")
            stopWorkout()
        } else {
            let cheers = ["Четко!", "Отлично!", "Давай еще!", "Красава!"]
            catCheerMessage = cheers.randomElement()!
            CatSpeechSynthesizer.shared.speak(text: "\(currentRepsCount)")
        }
    }
    
    private func startMotionTracking() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.05
        isSquattingDown = false
        lastRepTime = 0
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, self.isWorkoutActive, let acc = data?.acceleration else { return }
            
            // Расчет 3D магнитуды вектора ускорения: sqrt(x^2 + y^2 + z^2)
            // В покое = 1.0g. При опускании тела ускорение проседает < 0.85g.
            // При торможении внизу и выталкивании вверх > 1.25g.
            let mag = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
            let now = Date().timeIntervalSince1970
            
            if mag < 0.85 && !self.isSquattingDown && (now - self.lastRepTime > 0.7) {
                self.isSquattingDown = true
            } else if mag > 1.25 && self.isSquattingDown {
                self.isSquattingDown = false
                self.lastRepTime = now
                self.recordRep()
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
