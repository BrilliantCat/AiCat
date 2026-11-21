import Foundation
import UIKit
import CoreMotion

public struct FitnessExercise: Identifiable {
    public let id = UUID()
    public let name: String
    public let targetReps: Int?
    public let durationSeconds: Int?
    public let catComment: String
    public let instructions: String
}

public final class CatFitnessCoach: ObservableObject {
    public static let shared = CatFitnessCoach()
    
    @Published public var isWorkoutActive: Bool = false
    @Published public var currentExerciseName: String = ""
    @Published public var currentRepsCount: Int = 0
    @Published public var targetReps: Int = 15
    @Published public var catCheerMessage: String = ""
    
    private let motionManager = CMMotionManager()
    
    // Комплекс: Силовые (Отжимания, Приседания) + Йога/Растяжка
    public let exercises: [FitnessExercise] = [
        FitnessExercise(
            name: "Отжимания хищника («Грудью к миске»)",
            targetReps: 15,
            durationSeconds: nil,
            catComment: "Положи телефон экраном вверх на пол под грудь! Опускайся низко — датчик телефона сам посчитает каждое чистое повторение. Не халтурить!",
            instructions: "Классические отжимания от пола. Касаемся подбородком или грудью виртуальной линии."
        ),
        FitnessExercise(
            name: "Тигриные приседания («Прыжок за добычей»)",
            targetReps: 20,
            durationSeconds: nil,
            catComment: "Держи телефон в руке или в кармане! Приседай глубоко, пятки не отрывай. Каждое приседание сделает твои задние лапы стальными!",
            instructions: "Глубокие приседания, колени смотрят по направлению носков."
        ),
        FitnessExercise(
            name: "Поза кошки (Марджариасана)",
            targetReps: nil,
            durationSeconds: 30,
            catComment: "Вставай на четвереньки, плавно выгибай спину дугой на вдохе и округляй на выдохе.",
            instructions: "Снятие напряжения со спины после отжиманий."
        ),
        FitnessExercise(
            name: "Королевская планка с котом",
            targetReps: nil,
            durationSeconds: 45,
            catComment: "Замри в планке! Я сижу у тебя между лопаток. Если сдашься — упадешь прямо в мой лоток!",
            instructions: "Статическая нагрузка на весь мышечный корсет."
        )
    ]
    
    private init() {}
    
    // Запуск режима подсчета отжиманий (через датчик приближения Proximity Sensor)
    public func startPushups() -> String {
        isWorkoutActive = true
        currentExerciseName = "Отжимания хищника"
        currentRepsCount = 0
        targetReps = 15
        
        // Включаем сенсор приближения iPhone (срабатывает, когда грудь опускается к экрану!)
        UIDevice.current.isProximityMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleProximityChange), name: UIDevice.proximityStateDidChangeNotification, object: nil)
        
        CatActionHandler.shared.state.moodEmoji = "💪"
        CatActionHandler.shared.state.statusText = "Считает твои отжимания"
        
        return "Положи iPhone на пол под грудь экраном вверх! Начинай отжиматься — я сам считаю каждое касание. Цель: 15 раз. Погнали!"
    }
    
    // Запуск приседаний (с отслеживанием через акселерометр)
    public func startSquats() -> String {
        isWorkoutActive = true
        currentExerciseName = "Тигриные приседания"
        currentRepsCount = 0
        targetReps = 20
        
        startMotionTracking()
        
        CatActionHandler.shared.state.moodEmoji = "🐯"
        CatActionHandler.shared.state.statusText = "Считает приседания"
        
        return "Держи телефон в руке или положи в карман. Начинай глубокие приседания — датчики A17 Pro зафиксируют каждое движение!"
    }
    
    @objc private func handleProximityChange() {
        if UIDevice.current.proximityState {
            // Грудь опустилась к телефону — засчитываем отжимание!
            currentRepsCount += 1
            
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
            if currentRepsCount >= targetReps {
                catCheerMessage = "15! КРАСАВЧИК! Отжался на максимум. Ты зверь, кожаный!"
                CatSpeechSynthesizer.shared.speak(text: "Пятнадцать! Отличная работа, кожаный!")
                stopWorkout()
            } else {
                CatSpeechSynthesizer.shared.speak(text: "\(currentRepsCount)!")
            }
        }
    }
    
    private func startMotionTracking() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        
        var isDown = false
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let z = data?.acceleration.z else { return }
            
            // Детектируем фазу приседа (опускание и подъем)
            if z < -0.7 && !isDown {
                isDown = true
            } else if z > -0.2 && isDown {
                isDown = false
                self.currentRepsCount += 1
                CatSpeechSynthesizer.shared.speak(text: "\(self.currentRepsCount)")
                
                if self.currentRepsCount >= self.targetReps {
                    self.stopWorkout()
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
        CatActionHandler.shared.state.statusText = "Тренировка окончена"
    }
}
