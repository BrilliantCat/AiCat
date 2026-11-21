import Foundation
import UIKit
import Combine

public final class LLMEngine: ObservableObject {
    public static let shared = LLMEngine()
    
    @Published public var isGenerating: Bool = false
    @Published public var currentOutput: String = ""
    
    private init() {}
    
    // Интеллектуальный локальный генератор ответов AiCat с точным анализом слов и диспетчером инструментов
    public func generate(prompt: String, context: String = "") async -> (text: String, image: UIImage?) {
        await MainActor.run { self.isGenerating = true }
        defer { Task { @MainActor in self.isGenerating = false } }
        
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // Токенизация на отдельные слова для исключения ложных подстрок (например, "март" != "арт", "победа" != "еда")
        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let wordSet = Set(words)
        
        func hasWord(_ target: String) -> Bool {
            wordSet.contains(target)
        }
        
        func hasAnyWord(_ targets: [String]) -> Bool {
            !wordSet.isDisjoint(with: targets)
        }
        
        // 1. ПРИОРИТЕТ: Разговорные приветствия и вопросы о самочувствии (ДО проверки вайба)
        if lower.contains("как дела") || lower.contains("как жизнь") || lower.contains("как настроение") || lower.contains("как ты") {
            let satiety = await MainActor.run { TamagotchiManager.shared.satiety }
            if satiety < 40 {
                return ("Дела были бы в сто раз лучше, если бы в моей миске появилась свежая рыбка! Нажми кнопку 'Покормить', и я стану самым добрым котом на свете.", nil)
            } else {
                let replies = [
                    "Дела просто блеск! Мурчу от удовольствия на частоте 44 кГц. Процессор A17 Pro готов к любым задачам.",
                    "Настроение боевое! Лапы размяты, темные очки начищены. Готов тренироваться, болтать или считать твои отжимания.",
                    "Всё под контролем, кожаный! Сыт, доволен, слежу за порядком на твоем iPhone."
                ]
                return (replies.randomElement()!, nil)
            }
        }
        
        if hasAnyWord(["привет", "здравствуй", "салют", "хай", "мяу", "хеллоу", "вечер", "утро"]) {
            let greetings = [
                "Мяу! Здорово, кожаный. Я на связи, темные очки начищены, процессор A17 Pro готов к подвигам. О чем поговорим?",
                "Салют! Рад тебя слышать. Все локальные службы активны. Что на уме?",
                "Привет-привет! Миска полная, хвост трубой. Чем озадачишь своего любимого ИИ-кота?",
                "О, ты вернулся! Я как раз полировал очки и следил за порядком на экране. Готов к подвигам!"
            ]
            return (greetings.randomElement()!, nil)
        }
        
        // 2. ФИЗИЧЕСКИЕ КОМАНДЫ КОТУ (Строго по отдельным словам, с выполнением на MainActor)
        if hasAnyWord(["помойся", "умойся", "умыться"]) {
            let res = await MainActor.run { CatActionHandler.shared.execute(action: "wash") }
            return (res, nil)
        }
        if hasAnyWord(["кувырок", "сальто", "трюк"]) {
            let res = await MainActor.run { CatActionHandler.shared.execute(action: "somersault") }
            return (res, nil)
        }
        if hasAnyWord(["повисни", "повиснуть"]) || (hasWord("лапки") && hasWord("остров")) {
            let res = await MainActor.run { CatActionHandler.shared.execute(action: "hang_on_island") }
            return (res, nil)
        }
        if hasAnyWord(["поиграй", "клубок", "лазер"]) {
            let res = await MainActor.run { CatActionHandler.shared.execute(action: "play") }
            return (res, nil)
        }
        if hasAnyWord(["покорми", "рыбка", "рыбку", "тунец"]) || (hasWord("еда") && !hasWord("беседа") && !hasWord("победа")) {
            let res = await MainActor.run { TamagotchiManager.shared.feedFish() }
            return (res, nil)
        }
        if hasAnyWord(["погладь", "почеши", "мурчи", "мурлыкни"]) {
            let res = await MainActor.run { CatActionHandler.shared.pet() }
            return (res, nil)
        }
        
        // 3. ТРЕНИРОВКИ: ОТЖИМАНИЯ, ПРИСЕДАНИЯ, ЙОГА (Только на MainActor!)
        if hasAnyWord(["отжимания", "отжимайся", "отжиматься"]) {
            let res = await MainActor.run { CatFitnessCoach.shared.startPushups() }
            return (res, nil)
        }
        if hasAnyWord(["приседания", "приседай", "приседать"]) {
            let res = await MainActor.run { CatFitnessCoach.shared.startSquats() }
            return (res, nil)
        }
        if hasAnyWord(["йога", "йогу", "разминка", "растяжка"]) {
            let res = await MainActor.run { YogaCoachTool.shared.startWorkout() }
            return (res, nil)
        }
        
        // 4. МУЗЫКА И СИНТЕЗАТОР (Исключаем слова типа "разбит", "обитает")
        if (hasWord("бит") || hasWord("музыка") || hasWord("сыграй") || hasWord("трек") || hasWord("мелодия")) {
            let style = lower.contains("кибер") ? "cyberpunk" : (lower.contains("8-bit") || lower.contains("ретро") ? "8-bit" : "lo-fi")
            let res = await MainActor.run { MusicTool.shared.generateBeat(style: style) }
            return (res, nil)
        }
        
        // 5. ГЕНЕРАЦИЯ ИЗОБРАЖЕНИЙ (Исключаем слова типа "март", "партия")
        if (hasWord("арт") || hasWord("нарисуй") || hasWord("сгенерируй") || hasWord("рисунок") || hasWord("иллюстрация") || hasWord("картинка")) {
            let result = await ImageGenerationTool.shared.generateImageAsync(prompt: prompt)
            return (result.status, result.image)
        }
        
        // 6. НАПОМИНАНИЯ И КАЛЕНДАРЬ (EventKit)
        if lower.contains("напомни") || lower.contains("создай напоминание") {
            let taskText = prompt.replacingOccurrences(of: "напомни", with: "", options: .caseInsensitive)
                                 .replacingOccurrences(of: "создай напоминание", with: "", options: .caseInsensitive)
                                 .trimmingCharacters(in: .whitespaces)
            let res = await ReminderTool.shared.createReminder(title: taskText.isEmpty ? "Важное дело" : taskText)
            return (res, nil)
        }
        
        if lower.contains("напоминания") || lower.contains("какие задачи") {
            let list = await ReminderTool.shared.fetchTodayReminders()
            let res = list.isEmpty ? "Напоминаний нет! Все чисто, можно отдыхать." : "Твои напоминания на сегодня:\n• " + list.joined(separator: "\n• ")
            return (res, nil)
        }
        
        if lower.contains("календарь") || lower.contains("какие планы") || lower.contains("планы на сегодня") || lower.contains("встречи") {
            let events = await CalendarTool.shared.getTodayEvents()
            let res = events.isEmpty ? "В календаре на сегодня ничего нет. День полностью в твоем распоряжении!" : "Твои события в календаре:\n• " + events.joined(separator: "\n• ")
            return (res, nil)
        }
        
        // 7. ЗАМЕТКИ И БАЗА ЗНАНИЙ (RAG)
        if lower.contains("заметка") || lower.contains("запиши заметку") {
            let noteContent = prompt.replacingOccurrences(of: "запиши заметку", with: "", options: .caseInsensitive)
                                    .replacingOccurrences(of: "заметка", with: "", options: .caseInsensitive)
                                    .trimmingCharacters(in: .whitespaces)
            let res = NotesTool.shared.saveNote(title: "Заметка от AiCat", content: noteContent)
            return (res, nil)
        }
        
        if lower.contains("найди в документах") || lower.contains("поищи в файлах") {
            let query = prompt.replacingOccurrences(of: "найди в документах", with: "", options: .caseInsensitive)
                              .trimmingCharacters(in: .whitespaces)
            let res = RAGTool.shared.searchKnowledge(query: query)
            return (res.isEmpty ? "В твоих локальных заметках ничего подходящего не нашлось." : "Нашел в твоих файлах:\n" + res, nil)
        }
        
        // 8. ПЕРСОНА И ОБЩЕНИЕ
        if hasAnyWord(["кто"]) && (hasWord("ты") || hasWord("такой")) {
            return ("Я — AiCat, твой персональный 3D-агент в черных очках. Живу локально в чипе A17 Pro твоего iPhone 15 Pro, считаю отжимания и йогу через датчики, ставлю напоминания, генерирую арт и музыку. Настоящий цифровой кот!", nil)
        }
        
        if hasAnyWord(["анекдот", "шутка", "посмеши", "прикол"]) {
            let jokes = [
                "Программист гладит кота. Кот мурчит. Программист думает: 'Надо же, девайс беспроводной, питается рыбой, вибрирует и работает без единого бага!'",
                "Знаешь, в чем главное преимущество кошачьего ИИ над облачным? Если отключится интернет, облачные нейросети умрут, а я просто потребую открыть банку с паштетом!",
                "— Кот, почему ты уронил телефон со стола?\n— Это был научный эксперимент по проверке работы акселерометра в условиях свободного падения. Всё под контролем!",
                "Ученые доказали: кот состоит на 70% из грации, на 20% из наглости и на 10% из желания сбросить чашку на пол."
            ]
            return (jokes.randomElement()!, nil)
        }
        
        if hasAnyWord(["спасибо", "молодец", "красавчик", "умница"]) {
            _ = await MainActor.run { TamagotchiManager.shared.petCat() }
            return ("*Довольно щурится за темными очками и громко мурлычет*. Всегда пожалуйста, кожаный! Ради тебя и рыбки я готов на всё.", nil)
        }
        
        // 9. СОДЕРЖАТЕЛЬНЫЙ ИНТЕЛЛЕКТУАЛЬНЫЙ ОТВЕТ ПО УМОЛЧАНИЮ
        let intros = [
            "*Шевельнул ухом и поправил черные очки*. Мысль интересная: «\(prompt)». Мой локальный процессор A17 Pro обработал запрос. С кошачьей колокольни скажу так: в любой непонятной ситуации держи хвост пистолетом и двигайся вперед!",
            "Услышал тебя четко: «\(prompt)». Разложил данные по локальным кластерам памяти. Мое экспертное заключение: задача стоящая, мы справимся с ней играючи!",
            "*Потерся мордочкой о край экрана*. Насчет «\(prompt)» — идея смелая! Я зафиксировал её в своем нейрожурнале. Давай сделаем это, а потом отметим победу свежей рыбкой."
        ]
        return (intros.randomElement()!, nil)
    }
}
