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
    
    public let routine: [YogaExercise] = [
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
    
    private var timer: Timer?
    
    private init() {}
    
    public var currentExercise: YogaExercise {
        if currentExerciseIndex < routine.count {
            return routine[currentExerciseIndex]
        }
        return routine[0]
    }
    
    public func startWorkout() -> String {
        isSessionActive = true
        currentExerciseIndex = 0
        let first = routine[0]
        remainingSeconds = first.durationSeconds
        
        CatActionHandler.shared.state.moodEmoji = "🧘‍♂️"
        CatActionHandler.shared.state.statusText = "Йога: «\(first.name)»"
        
        startTimer()
        
        // Включаем медитативный Lo-Fi
        _ = MusicTool.shared.generateBeat(style: "lo-fi")
        
        let intro = "Начинаем кошачью йогу! Первое упражнение: «\(first.name)». \(first.catComment)"
        CatSpeechSynthesizer.shared.speak(text: intro)
        return intro
    }
    
    public func nextPose() {
        if currentExerciseIndex + 1 < routine.count {
            currentExerciseIndex += 1
            let next = routine[currentExerciseIndex]
            remainingSeconds = next.durationSeconds
            CatActionHandler.shared.state.statusText = "Йога: «\(next.name)»"
            CatSpeechSynthesizer.shared.speak(text: "Следующая поза: «\(next.name)». \(next.catComment)")
        } else {
            _ = stopWorkout()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isSessionActive else { return }
            
            if self.remainingSeconds > 1 {
                self.remainingSeconds -= 1
                if self.remainingSeconds == 10 {
                    CatSpeechSynthesizer.shared.speak(text: "Осталось 10 секунд, держись!")
                }
            } else {
                self.nextPose()
            }
        }
    }
    
    public func stopWorkout() -> String {
        isSessionActive = false
        timer?.invalidate()
        timer = nil
        
        CatActionHandler.shared.state.moodEmoji = "😼"
        CatActionHandler.shared.state.statusText = "Йога завершена"
        
        let completionText = "Отличная разминка! Тело гибкое, разум спокоен. Время погладить кота!"
        CatSpeechSynthesizer.shared.speak(text: completionText)
        return completionText
    }
}
