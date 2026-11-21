import Foundation

public struct YogaExercise: Identifiable {
    public let id = UUID()
    public let name: String
    public let durationSeconds: Int
    public let catComment: String
    public let instructions: String
}

public final class YogaCoachTool: ObservableObject {
    public static let shared = YogaCoachTool()
    
    @Published public var isSessionActive: Bool = false
    @Published public var currentExerciseIndex: Int = 0
    @Published public var remainingSeconds: Int = 0
    
    public let routine: [YogaExercise] = [
        YogaExercise(
            name: "Поза Марджариасана («Кошачья спина»)",
            durationSeconds: 30,
            catComment: "Вставай на четвереньки и выгибай спину дугой, как я, когда вижу пылесос! Вдох — прогиб, выдох — спина вверх.",
            instructions: "Мягкое вытяжение позвоночника и снятие зажимов после долгого сидения."
        ),
        YogaExercise(
            name: "Кошачьи потягивания («Лапки вперед»)",
            durationSeconds: 30,
            catComment: "Тяни руки вперед, грудь к полу. Представь, что тянешься за самой вкусной сосиской на столе!",
            instructions: "Раскрытие плечевых суставов и грудной клетки."
        ),
        YogaExercise(
            name: "Королевская планка с котом",
            durationSeconds: 45,
            catComment: "Стоим в планке! Не провисай, держи корпус! Я сижу у тебя на спине и внимательно слежу за техникой.",
            instructions: "Укрепление мышц кора и пресса."
        ),
        YogaExercise(
            name: "Скрутка на коврике («Свернуться калачиком»)",
            durationSeconds: 30,
            catComment: "Ложись на спину, колени к груди. Расслабься и сделай глубокий выдох. Можешь даже помурчать.",
            instructions: "Мягкий релакс и снятие усталости."
        )
    ]
    
    private var timer: Timer?
    
    private init() {}
    
    public func startWorkout() -> String {
        isSessionActive = true
        currentExerciseIndex = 0
        let first = routine[0]
        remainingSeconds = first.durationSeconds
        
        CatActionHandler.shared.state.moodEmoji = "🧘‍♂️"
        CatActionHandler.shared.state.statusText = "Тренирует тебя: «\(first.name)»"
        
        return "Включаю режим кошачьего фитнес-тренера! Первое упражнение: «\(first.name)». \(first.catComment)"
    }
    
    public func stopWorkout() -> String {
        isSessionActive = false
        timer?.invalidate()
        timer = nil
        CatActionHandler.shared.state.moodEmoji = "😼"
        CatActionHandler.shared.state.statusText = "Тренировка завершена"
        return "Отличная разминка, кожаный! Теперь твоя спина гибка, как у настоящего хищника. Время отдохнуть!"
    }
}
