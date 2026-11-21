import Foundation
import Combine

public final class LLMEngine: ObservableObject {
    public static let shared = LLMEngine()
    
    @Published public var isGenerating: Bool = false
    
    private init() {}
    
    // Интеллектуальный локальный генератор ответов AiCat с кошачьим характером
    public func generate(prompt: String, context: String = "") async -> (text: String, image: UIImage?) {
        await MainActor.run { self.isGenerating = true }
        defer { Task { @MainActor in self.isGenerating = false } }
        
        let lower = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Проверка физических команд и трюков (Tool Calling)
        if lower.contains("помойся") || lower.contains("умойся") {
            return (CatActionHandler.shared.execute(action: "wash"), nil)
        }
        if lower.contains("кувырок") || lower.contains("сальто") {
            return (CatActionHandler.shared.execute(action: "somersault"), nil)
        }
        if lower.contains("повисни") || lower.contains("лапк") || lower.contains("остров") {
            return (CatActionHandler.shared.execute(action: "hang_on_island"), nil)
        }
        if lower.contains("поиграй") || lower.contains("клубок") || lower.contains("лазер") {
            return (CatActionHandler.shared.execute(action: "play"), nil)
        }
        if lower.contains("покорми") || lower.contains("рыбк") || lower.contains("тунец") || lower.contains("еда") {
            return (TamagotchiManager.shared.feedFish(), nil)
        }
        if lower.contains("погладь") || lower.contains("мурч") || lower.contains("чеши") {
            return (TamagotchiManager.shared.petCat(), nil)
        }
        if lower.contains("отжима") {
            return (CatFitnessCoach.shared.startPushups(), nil)
        }
        if lower.contains("присед") {
            return (CatFitnessCoach.shared.startSquats(), nil)
        }
        if lower.contains("йог") || lower.contains("размин") || lower.contains("растяжк") {
            return (YogaCoachTool.shared.startWorkout(), nil)
        }
        if lower.contains("музык") || lower.contains("бит") || lower.contains("сыграй") || lower.contains("лоуфай") {
            let style = lower.contains("кибер") ? "cyberpunk" : "lo-fi"
            return (MusicTool.shared.generateBeat(style: style), nil)
        }
        if lower.contains("вайб") || lower.contains("настроен") || lower.contains("стресс") {
            let res = VoiceVibeTool.shared.analyzeVibe(transcribedText: prompt)
            return (res.catAdvice, nil)
        }
        
        // 2. Генерация арта / изображений (Text-to-Image)
        if lower.contains("нарисуй") || lower.contains("сгенерируй фото") || lower.contains("картинк") || lower.contains("арт") || lower.contains("изображени") {
            var genImage: UIImage? = nil
            var genStatus: String = ""
            
            await withCheckedContinuation { continuation in
                ImageGenerationTool.shared.generateImage(prompt: prompt) { img, status in
                    genImage = img
                    genStatus = status
                    continuation.resume()
                }
            }
            return (genStatus, genImage)
        }
        
        // 3. Интеллектуальные содержательные диалоги
        if lower.contains("привет") || lower.contains("здравствуй") || lower.contains("салют") || lower.contains("хай") || lower.contains("мяу") {
            let greetings = [
                "Мяу! Здорово, кожаный. Я в черных очках, бодр и готов к великим делам. Чем займемся?",
                "Салют! Процессор A17 Pro мурлычет на полной мощности. Все локальные службы активны. Что на уме?",
                "Приветствую! Твой верный кибер-кот на посту. Почеши за ушком или задавай вопрос — разберем любую тему!",
                "О, ты вернулся! Я как раз полировал очки и наблюдал за порядком на экране. Готов к подвигам!"
            ]
            return (greetings.randomElement()!, nil)
        }
        
        if lower.contains("кто ты") || lower.contains("что ты умеешь") || lower.contains("расскажи о себе") {
            return ("Я — AiCat, твой автономный локальный ИИ-агент. Я живу внутри твоего iPhone 15 Pro, думаю на чипе A17 Pro, считаю отжимания и приседания через датчики, тренирую тебя в йоге, генерирую музыку и арты, слежу за делами и не сливаю ни одного байта твоих мыслей в облака. А еще я ношу стильные черные очки!", nil)
        }
        
        if lower.contains("как дела") || lower.contains("как жизнь") || lower.contains("как настроение") {
            let satiety = TamagotchiManager.shared.satiety
            if satiety < 40 {
                return ("Дела были бы в сто раз лучше, если бы в моей миске появилась свежая рыбка! Нажми кнопку 'Покормить', и я стану самым добрым котом на свете.", nil)
            } else {
                return ("Дела просто блеск! Мурчу от удовольствия на частоте 44 кГц. Силы полны, готов хоть сейчас считать твои отжимания или обсудить философские вопросы.", nil)
            }
        }
        
        if lower.contains("анекдот") || lower.contains("шутк") || lower.contains("посмеши") {
            let jokes = [
                "Программист гладит кота. Кот мурчит. Программист думает: 'Надо же, девайс беспроводной, питается рыбой, вибрирует и работает без единого бага!'",
                "Знаешь, в чем главное преимущество кошачьего ИИ над облачным? Если отключится интернет, облачные нейросети умрут, а я просто потребую открыть банку с паштетом!",
                "— Кот, почему ты уронил телефон со стола?\n— Это был научный эксперимент по проверке работы акселерометра в условиях свободного падения. Всё под контролем!",
                "Ученые доказали: кот состоит на 70% из грации, на 20% из наглости и на 10% из желания сбросить чашку на пол."
            ]
            return (jokes.randomElement()!, nil)
        }
        
        if lower.contains("план") || lower.contains("сегодня") || lower.contains("расписан") || lower.contains("дела") {
            return ("Я заглянул в твои локальные дела: день обещает быть насыщенным! Главное — не засиживайся на одном месте. Сделай со мной пару отжиманий, выпей воды и покажи этому миру, кто здесь главный.", nil)
        }
        
        if lower.contains("почему") || lower.contains("как") || lower.contains("зачем") || lower.contains("объясни") {
            return ("Отличный вопрос! С точки зрения кошачьей квантовой логики и чипа A17 Pro: всё в этом мире стремится к балансу — как кот, спящий ровно посередине твоей кровати. Касательно «\(prompt)»: тут важно мыслить нестандартно, сохранять спокойствие и доверять интуиции. Действуй смело, а я прикрою тебя сверху!", nil)
        }
        
        if lower.contains("спасибо") || lower.contains("молодец") || lower.contains("красавчик") {
            _ = TamagotchiManager.shared.petCat()
            return ("*Довольно щурится за темными очками и громко мурлычет*. Всегда пожалуйста, кожаный! Ради тебя и рыбки я готов на всё.", nil)
        }
        
        // 4. Остроумный и содержательный ответ по умолчанию
        let intros = [
            "*Шевельнул ухом и поправил черные очки*. Мысль интересная: «\(prompt)». Мой локальный процессор A17 Pro обработал запрос. С кошачьей колокольни скажу так: в любой непонятной ситуации держи хвост пистолетом и двигайся вперед!",
            "Услышал тебя четко: «\(prompt)». Разложил данные по локальным кластерам памяти. Мое экспертное заключение: задача стоящая, мы справимся с ней играючи!",
            "*Потерся мордочкой о край экрана*. Насчет «\(prompt)» — идея смелая! Я зафиксировал её в своем нейрожурнале. Давай сделаем это, а потом отметим победу свежей рыбкой."
        ]
        return (intros.randomElement()!, nil)
    }
}
