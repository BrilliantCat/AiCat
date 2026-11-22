import Combine
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
    
    @Published public private(set) var isPaused = false
    private var workoutType = "pushups"
    private let motionManager = CMMotionManager()
    private var lastRepTime: TimeInterval = 0
    private var isSquattingDown: Bool = false
    
    private init() {}
    
    // Запуск режима подсчета отжиманий (через датчик приближения Dynamic Island)
    public func startPushups(reps: Int = 15) -> String {
        _ = YogaCoachTool.shared.stopWorkout()
        stopWorkout()
        workoutType = "pushups"
        isPaused = false
        lastRepTime = 0
        isWorkoutActive = true
        currentExerciseName = "Отжимания хищника"
        currentRepsCount = 0
        targetReps = min(100, max(1, reps))
        catCheerMessage = "Датчик считает приближения. Для ручного счёта нажимай +1."
        
        UIDevice.current.isProximityMonitoringEnabled = true
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProximityChange), name: UIDevice.proximityStateDidChangeNotification, object: nil)
        
        CatActionHandler.shared.state.moodEmoji = "💪"
        CatActionHandler.shared.state.statusText = "Считает отжимания: 0/\(targetReps)"
        
        _ = MusicTool.shared.generateBeat(style: "cyberpunk")
        
        return "Положи iPhone под грудь экраном вверх! Начинай отжиматься — я считаю приближения к датчику. Цель: \(targetReps) раз. Погнали!"
    }
    
    // Запуск приседаний (с отслеживанием 3D-вектора ускорения)
    public func startSquats(reps: Int = 20) -> String {
        _ = YogaCoachTool.shared.stopWorkout()
        stopWorkout()
        workoutType = "squats"
        isPaused = false
        isWorkoutActive = true
        currentExerciseName = "Приседания пантеры"
        currentRepsCount = 0
        targetReps = min(100, max(1, reps))
        catCheerMessage = "Держи телефон в руке или в кармане. Приседай глубоко!"
        
        UIDevice.current.isProximityMonitoringEnabled = false
        startMotionTracking()
        
        CatActionHandler.shared.state.moodEmoji = "🐆"
        CatActionHandler.shared.state.statusText = "Считает приседания: 0/\(targetReps)"
        
        _ = MusicTool.shared.generateBeat(style: "lo-fi")
        
        return "Держи телефон в руке или в кармане. Начинай глубокие приседания — я оцениваю повторения по движению телефона. При необходимости используй +1."
    }
    
    // Ручной тап по баннеру тренировки (для проверки или если датчик недоступен)
    public func manualRecordRep() {
        guard isWorkoutActive, !isPaused else { return }
        recordRep()
    }
    
    @objc private func handleProximityChange() {
        guard isWorkoutActive, !isPaused else { return }
        
        if UIDevice.current.proximityState {
            let now = Date().timeIntervalSince1970
            guard now - lastRepTime > 0.65 else { return }
            lastRepTime = now
            recordRep()
        }
    }
    
    private func recordRep() {
        currentRepsCount += 1
        LiveActivityManager.shared.update(status: "\(currentRepsCount)/\(targetReps)", mood: "💪", action: currentExerciseName)
        CatActionHandler.shared.state.statusText = "\(currentExerciseName): \(currentRepsCount)/\(targetReps)"
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        if currentRepsCount >= targetReps {
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "aicat.completedWorkouts") + 1, forKey: "aicat.completedWorkouts")
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
            guard let self = self, self.isWorkoutActive, !self.isPaused, let acc = data?.acceleration else { return }
            
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
    
    public func pause() {
        guard isWorkoutActive, !isPaused else { return }
        isPaused = true
        motionManager.stopAccelerometerUpdates()
        UIDevice.current.isProximityMonitoringEnabled = false
        catCheerMessage = "Пауза"
        LiveActivityManager.shared.update(status: currentExerciseName, mood: "💪", action: "Пауза")
    }

    public func resume() {
        guard isWorkoutActive, isPaused else { return }
        isPaused = false
        lastRepTime = 0
        isSquattingDown = false
        if workoutType == "squats" { startMotionTracking() }
        else { UIDevice.current.isProximityMonitoringEnabled = true }
        catCheerMessage = "Продолжаем"
    }

    public func stopWorkout() {
        isWorkoutActive = false
        isPaused = false
        UIDevice.current.isProximityMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
        motionManager.stopAccelerometerUpdates()
        
        CatActionHandler.shared.state.moodEmoji = "😼"
        CatActionHandler.shared.state.statusText = "Тренировка завершена"
    }
}
