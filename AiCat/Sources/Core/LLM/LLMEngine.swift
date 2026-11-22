import Foundation
import UIKit

public final class LLMEngine: ObservableObject {
    public static let shared = LLMEngine()
    
    @Published public var isGenerating: Bool = false
    @Published public var lastToolExecuted: String? = nil
    
    private init() {}
    
    // Асинхронный цикл агента: Запрос -> (Поиск RAG) -> Модель / Диспетчер -> Вызов инструмента -> Финальный ответ
    public func generate(prompt: String, context: String = "") async -> (text: String, image: UIImage?) {
        await MainActor.run { self.isGenerating = true }
        defer { Task { @MainActor in self.isGenerating = false } }
        
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("*Кот с любопытством посмотрел на тебя из-под черных очков*: Ты позвал меня, но ничего не сказал, кожаный!", nil)
        }
        
        // 1. Извлекаем контекст из локальной базы знаний (RAG BM25)
        let ragContext = RAGTool.shared.searchKnowledge(query: trimmed, topK: 2)
        
        // 2. Проверяем наличие установленной GGUF модели
        let isModelLoaded = await MainActor.run { ModelManager.shared.isModelLoaded }
        
        // 3. Выполняем инференс или интеллектуальный офлайн-диспетчер
        if isModelLoaded {
            return await runGGUFAgentLoop(userPrompt: trimmed, ragContext: ragContext)
        } else {
            return await runDirectToolAgentLoop(userPrompt: trimmed, ragContext: ragContext)
        }
    }
    
    // Агентский цикл с реальным парсингом JSON вызова инструментов
    private func runGGUFAgentLoop(userPrompt: String, ragContext: String) async -> (text: String, image: UIImage?) {
        let systemPrompt = PromptBuilder.buildSystemPrompt(ragContext: ragContext)
        let moodPrompt = await MainActor.run { TamagotchiManager.shared.moodContextPrompt() }
        let fullSystem = systemPrompt + "\n" + moodPrompt
        
        // Запрос к модели Qwen 2.5
        let rawModelOutput = await ModelManager.shared.infer(prompt: userPrompt, system: fullSystem)
        
        // Парсинг JSON-вызова инструмента
        if let toolCall = parseToolCall(from: rawModelOutput) {
            let toolRes = await ToolRegistry.shared.executeTool(name: toolCall.tool, parameters: toolCall.parameters ?? [:])
            await MainActor.run { self.lastToolExecuted = toolCall.tool }
            
            // Если инструмент вернул reply_text из JSON модели
            if let customReply = toolCall.reply_text, !customReply.isEmpty {
                return (customReply, toolRes.image)
            }
            return (toolRes.result, toolRes.image)
        }
        
        return (rawModelOutput, nil)
    }
    
    // Офлайн агентский диспетчер прямого вызова (когда GGUF еще не скачан в Models)
    private func runDirectToolAgentLoop(userPrompt: String, ragContext: String) async -> (text: String, image: UIImage?) {
        let lower = userPrompt.lowercased()
        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let wordSet = Set(words)
        
        func hasWord(_ target: String) -> Bool { wordSet.contains(target) }
        func hasAnyWord(_ targets: [String]) -> Bool { !wordSet.isDisjoint(with: targets) }
        
        // 1. ПРИОРИТЕТ: Разговорные приветствия и самочувствие
        if lower.contains("как дела") || lower.contains("как жизнь") || lower.contains("как настроение") || lower.contains("как ты") {
            let (satiety, happiness) = await MainActor.run { (TamagotchiManager.shared.satiety, TamagotchiManager.shared.happiness) }
            if satiety < 40 {
                return ("Дела были бы в сто раз лучше, если бы в моей миске появилась свежая рыбка! Нажми 'Покормить', и я стану самым добрым котом на свете.", nil)
            } else if happiness < 40 {
                return ("Скучаю без дела и почесываний за ушком. Погладь меня, кожаный!", nil)
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
                "О, ты вернулся! Я как раз полировал очки и следил за порядком на экране. Готов к делам!"
            ]
            return (greetings.randomElement()!, nil)
        }
        
        // 2. ФИЗИЧЕСКИЕ КОМАНДЫ КОТУ (cat_action)
        if hasAnyWord(["помойся", "умойся", "умыться"]) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "wash"])
            return (res.result, nil)
        }
        if hasAnyWord(["кувырок", "сальто", "трюк"]) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "somersault"])
            return (res.result, nil)
        }
        if hasAnyWord(["повисни", "повиснуть"]) || (hasWord("лапки") && hasWord("остров")) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "hang_on_island"])
            return (res.result, nil)
        }
        if hasAnyWord(["поиграй", "клубок", "лазер"]) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "play"])
            return (res.result, nil)
        }
        if hasAnyWord(["покорми", "рыбка", "рыбку", "тунец"]) || (hasWord("еда") && !hasWord("беседа") && !hasWord("победа")) {
            let res = await MainActor.run { TamagotchiManager.shared.feedFish() }
            return (res, nil)
        }
        if hasAnyWord(["погладь", "почеши", "мурчи", "мурлыкни"]) {
            let res = await MainActor.run { TamagotchiManager.shared.petCat() }
            return (res, nil)
        }
        if hasAnyWord(["спать", "усни", "дремать", "отдыхай"]) {
            let res = await MainActor.run { TamagotchiManager.shared.sleep() }
            return (res, nil)
        }
        if hasAnyWord(["проснись", "подъем", "вставай"]) {
            let res = await MainActor.run { TamagotchiManager.shared.wake() }
            return (res, nil)
        }
        
        // 3. СИСТЕМНЫЕ ДЕЙСТВИЯ: ФОНАРИК, ТАЙМЕР
        if lower.contains("фонарик") || lower.contains("свет") {
            if lower.contains("выключ") || lower.contains("погаси") {
                let res = await ToolRegistry.shared.executeTool(name: "device_action", parameters: ["command": "flashlight_off"])
                return (res.result, nil)
            } else {
                let res = await ToolRegistry.shared.executeTool(name: "device_action", parameters: ["command": "flashlight_on"])
                return (res.result, nil)
            }
        }
        
        // 4. ТРЕНИРОВКИ: ОТЖИМАНИЯ, ПРИСЕДАНИЯ, ЙОГА
        if hasAnyWord(["отжимания", "отжимайся", "отжиматься"]) {
            let res = await ToolRegistry.shared.executeTool(name: "start_workout", parameters: ["workoutType": "pushups"])
            return (res.result, nil)
        }
        if hasAnyWord(["приседания", "приседай", "приседать"]) {
            let res = await ToolRegistry.shared.executeTool(name: "start_workout", parameters: ["workoutType": "squats"])
            return (res.result, nil)
        }
        if hasAnyWord(["йога", "йогу", "разминка", "растяжка"]) {
            let res = await ToolRegistry.shared.executeTool(name: "start_workout", parameters: ["workoutType": "yoga"])
            return (res.result, nil)
        }
        
        // 5. МУЗЫКА И СИНТЕЗАТОР
        if (hasWord("бит") || hasWord("музыка") || hasWord("сыграй") || hasWord("трек") || hasWord("мелодия")) {
            let style = lower.contains("кибер") ? "cyberpunk" : (lower.contains("8-bit") || lower.contains("ретро") ? "8-bit" : "lo-fi")
            let res = await ToolRegistry.shared.executeTool(name: "play_music", parameters: ["style": style])
            return (res.result, nil)
        }
        
        // 6. ГЕНЕРАЦИЯ ИЗОБРАЖЕНИЙ
        if (hasWord("арт") || hasWord("нарисуй") || hasWord("сгенерируй") || hasWord("рисунок") || hasWord("иллюстрация") || hasWord("картинка")) {
            let res = await ToolRegistry.shared.executeTool(name: "generate_image", parameters: ["prompt": userPrompt])
            return (res.result, res.image)
        }
        
        // 7. НАПОМИНАНИЯ И КАЛЕНДАРЬ (EventKit)
        if lower.contains("напомни") || lower.contains("создай напоминание") {
            let taskText = userPrompt.replacingOccurrences(of: "напомни", with: "", options: .caseInsensitive)
                                     .replacingOccurrences(of: "создай напоминание", with: "", options: .caseInsensitive)
                                     .trimmingCharacters(in: .whitespaces)
            let res = await ToolRegistry.shared.executeTool(name: "create_reminder", parameters: ["title": taskText.isEmpty ? "Важное дело" : taskText])
            return (res.result, nil)
        }
        
        if lower.contains("напоминания") || lower.contains("какие задачи") {
            let res = await ToolRegistry.shared.executeTool(name: "get_reminders", parameters: ["date": "today"])
            return (res.result, nil)
        }
        
        if lower.contains("календарь") || lower.contains("какие планы") || lower.contains("планы на сегодня") || lower.contains("встречи") {
            let res = await ToolRegistry.shared.executeTool(name: "get_calendar_events", parameters: ["date": "today"])
            return (res.result, nil)
        }
        
        // 8. ЗАПУСК ПРИЛОЖЕНИЙ
        if lower.contains("открой") || lower.contains("запусти") {
            for app in ["telegram", "телеграм", "youtube", "ютуб", "whatsapp", "ватсап", "камера", "настройки", "музыка", "карты", "калькулятор", "заметки"] {
                if lower.contains(app) {
                    let res = await ToolRegistry.shared.executeTool(name: "open_app", parameters: ["appName": app])
                    return (res.result, nil)
                }
            }
        }
        
        // 9. ЗАМЕТКИ И БАЗА ЗНАНИЙ (RAG BM25)
        if lower.contains("заметка") || lower.contains("запиши заметку") {
            let noteContent = userPrompt.replacingOccurrences(of: "запиши заметку", with: "", options: .caseInsensitive)
                                        .replacingOccurrences(of: "заметка", with: "", options: .caseInsensitive)
                                        .trimmingCharacters(in: .whitespaces)
            let res = await ToolRegistry.shared.executeTool(name: "create_note", parameters: ["title": "Заметка от AiCat", "content": noteContent])
            return (res.result, nil)
        }
        
        if !ragContext.isEmpty {
            return ("Раскопал в твоих документах:\n\n\(ragContext)\n\nС кошачьей точки зрения всё сходится, кожаный!", nil)
        }
        
        if lower.contains("найди в документах") || lower.contains("поищи в файлах") {
            let q = userPrompt.replacingOccurrences(of: "найди в документах", with: "", options: .caseInsensitive)
                              .trimmingCharacters(in: .whitespaces)
            let res = await ToolRegistry.shared.executeTool(name: "search_knowledge_base", parameters: ["query": q])
            return (res.result, nil)
        }
        
        // 10. ПЕРСОНА И ОБЩЕНИЕ
        if hasAnyWord(["кто"]) && (hasWord("ты") || hasWord("такой")) {
            return ("Я — AiCat, твой персональный 3D-агент в черных очках. Живу локально в чипе A17 Pro твоего iPhone 15 Pro, считаю отжимания и йогу через датчики, ставлю напоминания, включаю фонарик, генерирую арт и музыку. Настоящий цифровой кот!", nil)
        }
        
        if hasAnyWord(["анекдот", "шутка", "посмеши", "прикол"]) {
            let jokes = [
                "Программист гладит кота. Кот мурчит. Программист думает: 'Надо же, девайс беспроводной, питается рыбой, вибрирует и работает без единого бага!'",
                "Знаешь, в чем главное преимущество кошачьего ИИ над облачным? Если отключится интернет, облачные нейросети умрут, а я просто потребую открыть банку с тунцом!",
                "— Кот, почему ты уронил телефон со стола?\n— Это был научный эксперимент по проверке работы акселерометра в условиях свободного падения. Всё под контролем!",
                "Ученые доказали: кот состоит на 70% из грации, на 20% из наглости и на 10% из желания сбросить кружку на пол."
            ]
            return (jokes.randomElement()!, nil)
        }
        
        // 11. СТАТУС КОТА
        if lower.contains("статус") || lower.contains("инфо") || lower.contains("сертификат") {
            let res = await ToolRegistry.shared.executeTool(name: "get_status", parameters: [:])
            return (res.result, nil)
        }
        
        // 12. СОДЕРЖАТЕЛЬНЫЙ ИНТЕЛЛЕКТУАЛЬНЫЙ ОТВЕТ ПО УМОЛЧАНИЮ
        let intros = [
            "*Шевельнул ухом и поправил черные очки*. Мысль интересная: «\(userPrompt)». Мой процессор A17 Pro обработал запрос. С кошачьей колокольни скажу так: в любой непонятной ситуации держи хвост пистолетом и двигайся вперед!",
            "Услышал тебя четко: «\(userPrompt)». Разложил данные по локальным кластерам памяти. Мое экспертное заключение: задача стоящая, мы справимся с ней играючи!",
            "*Потерся мордочкой о край экрана*. Насчет «\(userPrompt)» — идея смелая! Я зафиксировал её в своем нейрожурнале. Давай сделаем это, а потом отметим победу свежей рыбкой."
        ]
        return (intros.randomElement()!, nil)
    }
    
    // Робастный парсер вызова инструмента из ответа модели
    public func parseToolCall(from text: String) -> ToolCallPayload? {
        // Ищем JSON блок с ключом "tool"
        guard let regex = try? NSRegularExpression(pattern: "\\{[\\s\\S]*?\"tool\"[\\s\\S]*?\\}", options: []) else {
            return nil
        }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        
        for m in matches {
            let jsonString = ns.substring(with: m.range)
            if let data = jsonString.data(using: .utf8),
               let payload = try? JSONDecoder().decode(ToolCallPayload.self, from: data) {
                return payload
            }
        }
        return nil
    }
}
