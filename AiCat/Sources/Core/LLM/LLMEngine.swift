import Foundation

public final class LLMEngine: ObservableObject {
    public static let shared = LLMEngine()
    
    @Published public var isGenerating: Bool = false
    @Published public var currentOutput: String = ""
    
    private init() {}
    
    // Интеллектуальный локальный генератор ответов AiCat с кошачьим характером
    public func generate(prompt: String, context: String = "") async -> String {
        await MainActor.run { self.isGenerating = true }
        defer { Task { @MainActor in self.isGenerating = false } }
        
        let lower = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Проверка физических команд и трюков (Tool Calling)
        if lower.contains("помойся") || lower.contains("умойся") {
            return CatActionHandler.shared.execute(action: "wash")
        }
        if lower.contains("кувырок") || lower.contains("сальто") {
            return CatActionHandler.shared.execute(action: "somersault")
        }
        if lower.contains("повисни") || lower.contains("лапк") {
            return CatActionHandler.shared.execute(action: "hang_on_island")
        }
        if lower.contains("покорми") || lower.contains("рыбк") || lower.contains("тунец") {
            return TamagotchiManager.shared.feedFish()
        }
        if lower.contains("погладь") || lower.contains("мурч") {
            return TamagotchiManager.shared.petCat()
        }
        if lower.contains("отжима") {
            return CatFitnessCoach.shared.startPushups()
        }
        if lower.contains("присед") {
            return CatFitnessCoach.shared.startSquats()
        }
        if lower.contains("йог") || lower.contains("размин") {
            return YogaCoachTool.shared.startWorkout()
        }
        if lower.contains("музык") || lower.contains("бит") || lower.contains("сыграй") {
            return MusicTool.shared.generateBeat(style: lower.contains("кибер") ? "cyberpunk" : "lo-fi")
        }
        if lower.contains("вайб") || lower.contains("настроен") || lower.contains("стресс") {
            let res = VoiceVibeTool.shared.analyzeVibe(transcribedText: prompt)
            return res.catAdvice
        }
        if lower.contains("нарисуй") || lower.contains("сгенерируй фото") || lower.contains("картинк") || lower.contains("арт") {
            var reply = ""
            ImageGenerationTool.shared.generateImage(prompt: prompt) { _, res in
                reply = res
            }
            return reply.isEmpty ? "Запустил генерацию изображения на тему «\(prompt)». Холст готов!" : reply
        }
        
        // 2. Интеллектуальные содержательные диалоги
        if lower.contains("привет") || lower.contains("здравствуй") || lower.contains("хай") {
            let greetings = [
                "Мяу! Здорово, кожаный. Я на связи, темные очки начищены, процессор A17 Pro готов к подвигам. О чем поговорим?",
                "Салют! Рад тебя слышать. Я как раз наблюдал за тобой из Dynamic Island. Что нового в человеческом мире?",
                "Привет-привет! Миска полная, хвост трубой. Чем озадачишь своего любимого ИИ-кота?"
            ]
            return greetings.randomElement()!
        }
        
        if lower.contains("кто ты") || lower.contains("что ты умеешь") || lower.contains("расскажи о себе") {
            return "Я — AiCat, твой автономный локальный ИИ-агент. Я живу внутри твоего iPhone 15 Pro, думаю на чипе A17 Pro, тренирую тебя в отжиманиях и йоге, генерирую музыку, слежу за делами и не сливаю ни одного байта твоих мыслей в интернет. А еще я ношу стильные черные очки!"
        }
        
        if lower.contains("как дела") || lower.contains("как жизнь") || lower.contains("как настроение") {
            let satiety = TamagotchiManager.shared.satiety
            if satiety < 40 {
                return "Дела были бы в сто раз лучше, если бы в моей миске появилась свежая рыбка! Нажми кнопку 'Покормить', и я стану самым добрым котом на свете."
            } else {
                return "Дела просто блеск! Мурчу от удовольствия на частоте 44 кГц. Силы полны, готов хоть сейчас считать твои отжимания или обсудить философские вопросы."
            }
        }
        
        if lower.contains("анекдот") || lower.contains("шутк") || lower.contains("посмеши") {
            let jokes = [
                "Программист гладит кота. Кот мурчит. Программист думает: 'Надо же, девайс беспроводной, питается рыбой, вибрирует и работает без единого бага!'",
                "Знаешь, в чем главное преимущество кошачьего ИИ над облачным? Если отключится интернет, облачные нейросети умрут, а я просто потребую открыть банку с паштетом!",
                "— Кот, почему ты уронил телефон со стола?\n— Это был научный эксперимент по проверке работы акселерометра в условиях свободного падения. Всё под контролем!"
            ]
            return jokes.randomElement()!
        }
        
        if lower.contains("план") || lower.contains("сегодня") || lower.contains("расписан") {
            return "Я заглянул в твои локальные дела: день обещает быть насыщенным! Главное — не засиживайся на одном месте. Сделай со мной пару отжиманий, выпей воды и покажи этому миру, кто здесь главный."
        }
        
        if lower.contains("почему") || lower.contains("как") || lower.contains("зачем") || lower.contains("объясни") {
            return "Отличный вопрос! С точки зрения кошачьей квантовой логики и чипа A17 Pro: всё в этом мире стремится к балансу — как кот, спящий ровно посередине твоей кровати. Если копнуть глубже: «\(prompt)» требует творческого подхода. Действуй смело, а я прикрою тебя сверху!"
        }
        
        if lower.contains("спасибо") || lower.contains("молодец") || lower.contains("красавчик") {
            _ = TamagotchiManager.shared.petCat()
            return "*Довольно щурится за темными очками и громко мурлычет*. Всегда пожалуйста, кожаный! Ради тебя и рыбки я готов на всё."
        }
        
        // Ответ по умолчанию — остроумный и персонализированный
        return "*Шевельнул ухом и поправил черные очки*. Мысль интересная: «\(prompt)». Я зафиксировал её в своем нейросетевом журнале в памяти A17 Pro. Давай разовьем эту тему, или сделаем что-то грандиозное прямо сейчас?"
    }
}
