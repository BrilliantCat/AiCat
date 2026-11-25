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
    @Published private(set) var usingCamera = false
    var isPushupWorkout: Bool { isWorkoutActive && workoutType == "pushups" }
    private let camera = PushupCamera()
    private var nearSince: TimeInterval?
    private var workoutMusic: Task<Void, Never>?
    private var workoutType = "pushups"
    private let motionManager = CMMotionManager()
    private var lastRepTime: TimeInterval = 0
    private var isSquattingDown: Bool = false
    
    private init() {
        camera.onStatus = { [weak self] in self?.catCheerMessage = $0 }
        camera.onRep = { [weak self] in
            guard let self, self.isPushupWorkout, self.usingCamera, !self.isPaused else { return }
            self.recordRep()
        }
        camera.onUnavailable = { [weak self] in
            guard let self else { return }
            self.useProximity()
            self.catCheerMessage = "Камера недоступна. " + self.catCheerMessage
        }
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func backgrounded() { if isWorkoutActive { pause() } }

    func toggleCamera() {
        guard isPushupWorkout, !isPaused else { return }
        if usingCamera { useProximity(); return }
        usingCamera = true
        nearSince = nil
        UIDevice.current.isProximityMonitoringEnabled = false
        catCheerMessage = "Для счёта положи iPhone экраном вверх под лицом."
        camera.start()
    }

    private func useProximity() {
        camera.stop()
        usingCamera = false
        nearSince = nil
        UIDevice.current.isProximityMonitoringEnabled = true
        catCheerMessage = UIDevice.current.isProximityMonitoringEnabled
            ? "Опустись к верхнему краю экрана, затем поднимись. Можно выбрать камеру или +1."
            : "Для автоматического счёта выбери камеру. Вручную — кнопкой +1."
    }
    
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
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProximityChange), name: UIDevice.proximityStateDidChangeNotification, object: nil)
        useProximity()
        
        CatActionHandler.shared.state.moodEmoji = "💪"
        CatActionHandler.shared.state.statusText = "Считает отжимания: 0/\(targetReps)"
        
        workoutMusic = Task { _ = await MusicTool.shared.generateBeat(style: "cyberpunk", forWorkout: true) }
        
        return "Цель — \(targetReps) отжиманий. Положи iPhone экраном вверх под лицом. \(catCheerMessage)"
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
        
        workoutMusic = Task { _ = await MusicTool.shared.generateBeat(style: "lo-fi", forWorkout: true) }
        
        return "Держи телефон в руке или в кармане. Начинай глубокие приседания — я оцениваю повторения по движению телефона. При необходимости используй +1."
    }
    
    // Ручной тап по баннеру тренировки (для проверки или если датчик недоступен)
    public func manualRecordRep() {
        guard isWorkoutActive, !isPaused else { return }
        nearSince = nil
        if usingCamera { camera.resetCountCycle() }
        recordRep()
    }
    
    @objc private func handleProximityChange() {
        guard isPushupWorkout, !isPaused, !usingCamera, UIDevice.current.isProximityMonitoringEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if UIDevice.current.proximityState {
            if nearSince == nil { nearSince = now }
        } else if let start = nearSince {
            nearSince = nil
            guard now - start >= 0.10, now - lastRepTime >= 0.55 else { return }
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
            guard let self = self, self.isWorkoutActive, self.workoutType == "squats",
                  !self.isPaused, let acc = data?.acceleration else { return }
            
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
        workoutMusic?.cancel()
        MusicTool.shared.cancelBeat(workoutOnly: true)
        camera.stop()
        nearSince = nil
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
        catCheerMessage = "Продолжаем"
        if workoutType == "squats" { startMotionTracking() }
        else if usingCamera { camera.start() }
        else { useProximity() }
    }

    public func stopWorkout() {
        workoutMusic?.cancel()
        MusicTool.shared.cancelBeat(workoutOnly: true)
        workoutMusic = nil
        isWorkoutActive = false
        isPaused = false
        camera.stop()
        usingCamera = false
        nearSince = nil
        UIDevice.current.isProximityMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
        motionManager.stopAccelerometerUpdates()
        
        CatActionHandler.shared.state.moodEmoji = "😼"
        CatActionHandler.shared.state.statusText = "Тренировка завершена"
    }
}
