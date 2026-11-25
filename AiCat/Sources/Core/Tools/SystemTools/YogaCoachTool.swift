import Combine
import Foundation

public struct YogaExercise: Identifiable {
    public let id = UUID()
    public let name: String
    public let durationSeconds: Int
    public let catComment: String
    public let instructions: String
    let motion: CatMotion
}

struct BreathStep {
    let inhale: Bool
    let duration: TimeInterval
    let end: Date

    func phase(at now: Date) -> Float {
        let progress = Float(min(1, max(0, 1 - end.timeIntervalSince(now) / duration)))
        return (inhale ? progress : 1 + progress) * 0.5
    }
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
            instructions: "Мягкое вытяжение позвоночника и снятие зажимов после долгого сидения.", motion: .yoga
        ),
        YogaExercise(
            name: "Кошачьи потягивания («Лапки вперед»)",
            durationSeconds: 30,
            catComment: "Тяни руки вперед, грудь к полу. Представь, что тянешься за самой вкусной рыбкой на столе!",
            instructions: "Раскрытие плечевых суставов и грудной клетки.", motion: .stretch
        ),
        YogaExercise(
            name: "Королевская планка с котом",
            durationSeconds: 45,
            catComment: "Держи планку! Я сижу у тебя между лопаток. Не провисай, держи спину ровно!",
            instructions: "Укрепление мышц кора, пресса и рук.", motion: .plank
        ),
        YogaExercise(
            name: "Скрутка на коврике («Свернуться калачиком»)",
            durationSeconds: 30,
            catComment: "Ложись на спину, колени к груди. Расслабься и сделай глубокий выдох. Можешь даже помурчать.",
            instructions: "Полный релакс и снятие усталости.", motion: .curl
        )
    ]
    
    @Published public private(set) var isPaused = false
    @Published public private(set) var plan = "yoga"
    private var timer: Timer?
    private var deadline: Date?
    private let storageKey = "aicat.lesson"
    private let storage: UserDefaults
    private let speak: (String?) -> Void
    private let updateStatus: (String, String) -> Void
    private let stopFitness: () -> Void

    public var routine: [YogaExercise] {
        switch plan {
        case "breathing":
            return (0..<4).flatMap { _ in [
                YogaExercise(name: "Вдох", durationSeconds: 4, catComment: "Спокойно вдохни носом.", instructions: "Дыши в удобном темпе.", motion: .breath),
                YogaExercise(name: "Выдох", durationSeconds: 6, catComment: "Медленно выдохни, расслабь плечи.", instructions: "Без задержки дыхания.", motion: .breath)
            ] }
        case "mobility":
            return [
                YogaExercise(name: "Плечи", durationSeconds: 30, catComment: "Медленно подними и опусти плечи. Затем сделай небольшие круги.", instructions: "Двигайся плавно.", motion: .shoulders),
                YogaExercise(name: "Шаг на месте", durationSeconds: 45, catComment: "Шагай на месте в удобном темпе.", instructions: "Дыши свободно.", motion: .walk),
                YogaExercise(name: "Потягивания", durationSeconds: 30, catComment: "Потяни руки вверх, затем мягко опусти.", instructions: "Выбирай комфортную амплитуду.", motion: .stretch)
            ]
        case "plank":
            return [YogaExercise(name: "Планка", durationSeconds: 20, catComment: "Локти под плечами. Можно опереться на колени. Дыши свободно.", instructions: "Остановись при боли.", motion: .plank),
                    YogaExercise(name: "Отдых", durationSeconds: 30, catComment: "Расслабься, кожаный. Сделай спокойный вдох.", instructions: "Восстанови дыхание.", motion: .breath)]
        default: return Self.yoga
        }
    }

    private convenience init() {
        self.init(storage: .standard, speak: { text in
            if let text { CatSpeechSynthesizer.shared.speak(text: text) }
            else { CatSpeechSynthesizer.shared.stop() }
        }, updateStatus: { status, action in
            CatActionHandler.shared.state.statusText = status
            LiveActivityManager.shared.update(status: status, mood: action == "На связи" ? "😼" : "🧘‍♂️", action: action)
        }, stopFitness: { CatFitnessCoach.shared.stopWorkout() })
    }

    init(storage: UserDefaults, speak: @escaping (String?) -> Void,
         updateStatus: @escaping (String, String) -> Void, stopFitness: @escaping () -> Void) {
        self.storage = storage
        self.speak = speak
        self.updateStatus = updateStatus
        self.stopFitness = stopFitness
        if let saved = storage.dictionary(forKey: storageKey),
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

    var breathStep: BreathStep? {
        guard isSessionActive, plan == "breathing", let deadline else { return nil }
        return BreathStep(inhale: currentExerciseIndex.isMultiple(of: 2),
                          duration: Double(currentExercise.durationSeconds), end: deadline)
    }

    public func startWorkout(type: String = "yoga") -> String {
        stopFitness()
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
        updateStatus(status, isPaused ? "Пауза" : "Занятие")
        speak("\(currentExercise.name). \(currentExercise.catComment)")
    }

    public func pause() {
        guard isSessionActive, !isPaused else { return }
        if let deadline { remainingSeconds = max(1, Int(ceil(deadline.timeIntervalSinceNow))) }
        isPaused = true
        timer?.invalidate()
        timer = nil
        deadline = nil
        persist()
        speak(nil)
        updateStatus(currentExercise.name, "Пауза")
    }

    public func resume() {
        guard isSessionActive, isPaused else { return }
        stopFitness()
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
        storage.set(["plan": plan, "index": currentExerciseIndex,
                                   "seconds": remainingSeconds], forKey: storageKey)
    }

    public func stopWorkout(completed: Bool = false) -> String {
        guard isSessionActive else { return "Занятие уже остановлено." }
        isSessionActive = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        deadline = nil
        storage.removeObject(forKey: storageKey)
        let message = completed ? "Занятие завершено, кожаный! Отличная работа." : "Остановил занятие."
        if completed {
            storage.set(storage.integer(forKey: "aicat.completedLessons") + 1,
                                      forKey: "aicat.completedLessons")
        }
        updateStatus(message, "На связи")
        speak(message)
        return message
    }
}
