import Combine
import Foundation

public struct YogaExercise: Identifiable {
    public let id = UUID()
    public let name: String
    public let durationSeconds: Int
    public let catComment: String
    public let instructions: String
}

@MainActor
public final class YogaCoachTool: ObservableObject {
    public static let shared = YogaCoachTool()
    
    @Published public var isSessionActive: Bool = false
    @Published public var currentExerciseIndex: Int = 0
    @Published public var remainingSeconds: Int = 30
    
    private static let yoga: [YogaExercise] = [
        YogaExercise(
            name: "Поза Марджариасана («Кошачья спина»)",
            durationSeconds: 30,
            catComment: "Вставай на четвереньки и выгибай спину дугой! Вдох — мягкий прогиб, выдох — спина вверх.",
            instructions: "Мягкое вытяжение позвоночника и снятие зажимов после долгого сидения."
        ),
        YogaExercise(
            name: "Кошачьи потягивания («Лапки вперед»)",
            durationSeconds: 30,
            catComment: "Тяни руки вперед, грудь к полу. Представь, что тянешься за самой вкусной рыбкой на столе!",
            instructions: "Раскрытие плечевых суставов и грудной клетки."
        ),
        YogaExercise(
            name: "Королевская планка с котом",
            durationSeconds: 45,
            catComment: "Держи планку! Я сижу у тебя между лопаток. Не провисай, держи спину ровно!",
            instructions: "Укрепление мышц кора, пресса и рук."
        ),
        YogaExercise(
            name: "Скрутка на коврике («Свернуться калачиком»)",
            durationSeconds: 30,
            catComment: "Ложись на спину, колени к груди. Расслабься и сделай глубокий выдох. Можешь даже помурчать.",
            instructions: "Полный релакс и снятие усталости."
        )
    ]
    
    @Published public private(set) var isPaused = false
    @Published public private(set) var plan = "yoga"
    private var timer: Timer?
    private var deadline: Date?
    private let storageKey = "aicat.lesson"

    public var routine: [YogaExercise] {
        switch plan {
        case "breathing":
            return (0..<4).flatMap { _ in [
                YogaExercise(name: "Вдох", durationSeconds: 4, catComment: "Спокойно вдохни носом.", instructions: "Дыши в удобном темпе."),
                YogaExercise(name: "Выдох", durationSeconds: 6, catComment: "Медленно выдохни, расслабь плечи.", instructions: "Без задержки дыхания.")
            ] }
        case "mobility":
            return [
                YogaExercise(name: "Плечи", durationSeconds: 30, catComment: "Медленно подними и опусти плечи. Затем сделай небольшие круги.", instructions: "Двигайся плавно."),
                YogaExercise(name: "Шаг на месте", durationSeconds: 45, catComment: "Шагай на месте в удобном темпе.", instructions: "Дыши свободно."),
                YogaExercise(name: "Потягивания", durationSeconds: 30, catComment: "Потяни руки вверх, затем мягко опусти.", instructions: "Выбирай комфортную амплитуду.")
            ]
        case "plank":
            return [YogaExercise(name: "Планка", durationSeconds: 20, catComment: "Локти под плечами. Можно опереться на колени. Дыши свободно.", instructions: "Остановись при боли."),
                    YogaExercise(name: "Отдых", durationSeconds: 30, catComment: "Расслабься, кожаный. Сделай спокойный вдох.", instructions: "Восстанови дыхание.")]
        default: return Self.yoga
        }
    }

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: storageKey),
           let type = saved["plan"] as? String,
           let index = saved["index"] as? Int,
           let seconds = saved["seconds"] as? Int {
            plan = type
            if routine.indices.contains(index) && seconds > 0 {
                currentExerciseIndex = index
                remainingSeconds = seconds
                isSessionActive = true
                isPaused = true
            }
        }
    }

    public var currentExercise: YogaExercise { routine[currentExerciseIndex] }

    public func startWorkout(type: String = "yoga") -> String {
        CatFitnessCoach.shared.stopWorkout()
        timer?.invalidate()
        plan = ["yoga", "breathing", "mobility", "plank"].contains(type) ? type : "yoga"
        currentExerciseIndex = 0
        isSessionActive = true
        isPaused = false
        remainingSeconds = currentExercise.durationSeconds
        beginStep()
        return "Начинаем занятие. \(currentExercise.name). \(currentExercise.catComment)"
    }

    private func beginStep() {
        deadline = Date().addingTimeInterval(Double(remainingSeconds))
        persist()
        announce()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard isSessionActive, !isPaused, let deadline else { return }
        let value = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        if remainingSeconds != value { remainingSeconds = value; persist() }
        if value == 0 { nextPose() }
    }

    private func announce() {
        let status = "\(currentExercise.name) · \(currentExerciseIndex + 1)/\(routine.count)"
        CatActionHandler.shared.state.statusText = status
        LiveActivityManager.shared.update(status: status, mood: "🧘‍♂️", action: isPaused ? "Пауза" : "Занятие")
        CatSpeechSynthesizer.shared.speak(text: "\(currentExercise.name). \(currentExercise.catComment)")
    }

    public func pause() {
        guard isSessionActive, !isPaused else { return }
        if let deadline { remainingSeconds = max(1, Int(ceil(deadline.timeIntervalSinceNow))) }
        isPaused = true
        timer?.invalidate()
        timer = nil
        deadline = nil
        persist()
        CatSpeechSynthesizer.shared.stop()
        LiveActivityManager.shared.update(status: currentExercise.name, mood: "🧘‍♂️", action: "Пауза")
    }

    public func resume() {
        guard isSessionActive, isPaused else { return }
        CatFitnessCoach.shared.stopWorkout()
        isPaused = false
        beginStep()
    }

    public func nextPose() {
        guard isSessionActive else { return }
        if currentExerciseIndex + 1 == routine.count {
            _ = stopWorkout(completed: true)
            return
        }
        currentExerciseIndex += 1
        remainingSeconds = currentExercise.durationSeconds
        persist()
        if !isPaused { beginStep() }
    }

    private func persist() {
        UserDefaults.standard.set(["plan": plan, "index": currentExerciseIndex,
                                   "seconds": remainingSeconds], forKey: storageKey)
    }

    public func stopWorkout(completed: Bool = false) -> String {
        guard isSessionActive else { return "Занятие уже остановлено." }
        isSessionActive = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        deadline = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        let message = completed ? "Занятие завершено, кожаный! Отличная работа." : "Остановил занятие."
        if completed {
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "aicat.completedLessons") + 1,
                                      forKey: "aicat.completedLessons")
        }
        LiveActivityManager.shared.update(status: message, mood: "😼", action: "На связи")
        CatSpeechSynthesizer.shared.speak(text: message)
        return message
    }
}
